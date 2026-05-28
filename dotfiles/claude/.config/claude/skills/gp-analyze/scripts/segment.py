"""Musician-oriented structural segmentation via bar-fingerprint repetition.

Three stages:

1. Per-bar fingerprints. Each bar is described by (pc-content, bass-pc,
   active tracks, note density, onset-count). Bars are clustered greedily —
   each bar joins the first prior cluster whose representative fingerprint
   is similar enough; otherwise opens a new cluster.

2. Section detection. Scanning left-to-right, at each position we look for
   the longest L-bar pattern (L in --riff-lengths) that repeats consecutively
   at least twice. The whole repetition run becomes a single section. When no
   repeat is found, the bar becomes a singleton; runs of singletons get
   coalesced into a heterogeneous block (intro / bridge / outro material).

3. Labelling. Same riff unit in two places gets the same letter. Position +
   recurrence assigns a role hint (intro / outro / bridge / main).

This matches how a musician learns a song — "Intro (8 bars) | Riff A x4 |
Bridge | Riff A x4 | Outro" — rather than describing pitch-content novelty
regions.
"""

from __future__ import annotations


_PC_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

_SILENT = -1  # bar-identity sentinel for bars with no sounding notes
_HETEROGENEOUS = "HET"  # unit marker for coalesced singleton runs


# ---------------------------------------------------------------------------
# Stage 1: per-bar fingerprints
# ---------------------------------------------------------------------------


def _bar_fingerprint(measure: int, beats: list[dict], parsed) -> dict | None:
    """Compact features describing what plays in this bar. None = silent."""
    bar_beats = [b for b in beats if b.get("measure") == measure]
    all_pitches = [p for b in bar_beats for p in b.get("pitches", [])]
    if not all_pitches:
        return None

    pcs = frozenset(pc for b in bar_beats for pc in b.get("pitch_classes", []))
    bass_pc = min(all_pitches) % 12
    onsets_count = sum(1 for b in bar_beats if b.get("pitches"))

    active_tracks: frozenset[int] = frozenset()
    if parsed is not None and parsed.track_bars:
        active_tracks = frozenset(
            i for i, bars in parsed.track_bars.items() if measure in bars
        )

    return {
        "pcs": pcs,
        "bass_pc": bass_pc,
        "onsets_count": onsets_count,
        "active": active_tracks,
        "density": len(all_pitches),
    }


def _jaccard(a: frozenset, b: frozenset) -> float:
    if not a and not b:
        return 1.0
    union = a | b
    return len(a & b) / len(union) if union else 1.0


def _bar_similarity(a: dict | None, b: dict | None) -> float:
    """Weighted blend of pc / track-set / rhythmic-density similarity.

    Bass pc is not weighted directly — it's already inside the pc set, and
    inversions (Cmaj/G vs Cmaj/C) shouldn't break clustering. Texture (active
    tracks + onset count) carries most of the rhythmic context.
    """
    if a is None and b is None:
        return 1.0
    if a is None or b is None:
        return 0.0

    pc_sim = _jaccard(a["pcs"], b["pcs"])
    if a["active"] or b["active"]:
        active_sim = _jaccard(a["active"], b["active"])
    else:
        active_sim = 1.0

    oa, ob = a["onsets_count"], b["onsets_count"]
    onset_sim = 1.0 - abs(oa - ob) / max(oa, ob, 1)

    da, db = a["density"], b["density"]
    den_sim = 1.0 - abs(da - db) / max(da, db, 1)

    return (
        0.55 * pc_sim
        + 0.20 * active_sim
        + 0.15 * onset_sim
        + 0.10 * den_sim
    )


def _cluster_bars(
    measures: list[int],
    fps: dict[int, dict | None],
    threshold: float,
) -> dict[int, int]:
    """Greedy: each bar joins the first earlier cluster meeting `threshold`."""
    ids: dict[int, int] = {}
    cluster_reps: list[dict] = []
    for m in measures:
        fp = fps.get(m)
        if fp is None:
            ids[m] = _SILENT
            continue
        best_cid: int | None = None
        best_sim = 0.0
        for cid, rep in enumerate(cluster_reps):
            sim = _bar_similarity(fp, rep)
            if sim > best_sim:
                best_sim = sim
                best_cid = cid
        if best_cid is not None and best_sim >= threshold:
            ids[m] = best_cid
        else:
            ids[m] = len(cluster_reps)
            cluster_reps.append(fp)
    return ids


def _smooth_sequence(seq: list[int]) -> list[int]:
    """Absorb short interruptions surrounded by the same identity.

    Catches small ornaments / fills / one-bar chord-change variations inside
    an otherwise uniform riff. Absorbs an interruption of length k when both
    surrounding runs are >= 2*k bars of the same identity — i.e. the alien
    is at most 1/3 the length of its surroundings.
    """
    runs: list[list[int]] = []
    for x in seq:
        if runs and runs[-1][0] == x:
            runs[-1][1] += 1
        else:
            runs.append([x, 1])

    changed = True
    while changed:
        changed = False
        i = 1
        while i < len(runs) - 1:
            prev_id, prev_n = runs[i - 1]
            _, cur_n = runs[i]
            next_id, next_n = runs[i + 1]
            if (
                prev_id == next_id
                and prev_id != _SILENT
                and prev_n >= 2 * cur_n
                and next_n >= 2 * cur_n
            ):
                runs[i - 1][1] = prev_n + cur_n + next_n
                del runs[i : i + 2]
                changed = True
                continue
            i += 1

    expanded: list[int] = []
    for x, n in runs:
        expanded.extend([x] * n)
    return expanded


def _index_to_label(n: int) -> str:
    """0 -> A, 25 -> Z, 26 -> AA, 27 -> AB, ... (Excel-column scheme)."""
    s = ""
    n += 1
    while n > 0:
        n -= 1
        s = chr(ord("A") + n % 26) + s
        n //= 26
    return s


# ---------------------------------------------------------------------------
# Stage 2: section detection
# ---------------------------------------------------------------------------


def _detect_sections(
    seq: list[int],
    riff_lengths: tuple[int, ...],
) -> list[dict]:
    """Greedy left-to-right scan: at each i, pick L maximising coverage.

    Coverage = repetitions × L (total bars consumed by the repeat run).
    Ties broken toward smaller L (smaller riffs are more musically meaningful).
    """
    n = len(seq)
    sections: list[dict] = []
    i = 0
    while i < n:
        best: dict | None = None
        for L in sorted(set(riff_lengths)):
            if L <= 0 or i + 2 * L > n:
                continue
            unit = tuple(seq[i : i + L])
            if all(x == _SILENT for x in unit):
                continue
            reps = 1
            j = i + L
            while j + L <= n and tuple(seq[j : j + L]) == unit:
                reps += 1
                j += L
            if reps < 2:
                continue
            bars = reps * L
            if (
                best is None
                or bars > best["bars"]
                or (bars == best["bars"] and L < best["L"])
            ):
                best = {"L": L, "reps": reps, "bars": bars, "unit": unit}
        if best is None:
            sections.append(
                {
                    "start": i,
                    "end": i,
                    "riff_bars": 1,
                    "repetitions": 1,
                    "unit": (seq[i],),
                }
            )
            i += 1
        else:
            sections.append(
                {
                    "start": i,
                    "end": i + best["bars"] - 1,
                    "riff_bars": best["L"],
                    "repetitions": best["reps"],
                    "unit": best["unit"],
                }
            )
            i += best["bars"]
    return sections


def _merge_adjacent(sections: list[dict]) -> list[dict]:
    """Fold consecutive sections that share the same riff unit + length."""
    out: list[dict] = []
    for s in sections:
        if (
            out
            and out[-1]["unit"] == s["unit"]
            and out[-1]["riff_bars"] == s["riff_bars"]
        ):
            out[-1]["end"] = s["end"]
            out[-1]["repetitions"] += s["repetitions"]
        else:
            out.append(dict(s))
    return out


def _coalesce_singletons(sections: list[dict], min_run: int = 2) -> list[dict]:
    """Collapse runs of 1-bar non-repeating sections into one heterogeneous block.

    Without this, an intro / bridge / outro made of distinct bars would emit
    one section per bar. min_run=2 keeps single one-off bars (fills, transitions)
    as their own section.
    """
    out: list[dict] = []
    i = 0
    while i < len(sections):
        s = sections[i]
        is_singleton = s["repetitions"] == 1 and s["riff_bars"] == 1
        if not is_singleton:
            out.append(s)
            i += 1
            continue
        j = i
        while (
            j < len(sections)
            and sections[j]["repetitions"] == 1
            and sections[j]["riff_bars"] == 1
        ):
            j += 1
        run = sections[i:j]
        if len(run) >= min_run:
            out.append(
                {
                    "start": run[0]["start"],
                    "end": run[-1]["end"],
                    "riff_bars": run[-1]["end"] - run[0]["start"] + 1,
                    "repetitions": 1,
                    "unit": (_HETEROGENEOUS, run[0]["start"], run[-1]["end"]),
                }
            )
        else:
            out.extend(run)
        i = j
    return out


# ---------------------------------------------------------------------------
# Stage 3: labels + form string
# ---------------------------------------------------------------------------


def _assign_form_labels(sections: list[dict]) -> None:
    """Letters A/B/C by riff unit; minimal role hint (intro/outro/main only).

    Role hints beyond intro/outro/main are too speculative without lead-vs-rhythm
    classification — left unset so readers don't trust a guess as a verdict.
    """
    next_idx = 0
    unit_to_label: dict[tuple, str] = {}
    for s in sections:
        unit = s["_unit"]
        if unit[0] == _HETEROGENEOUS:
            # Heterogeneous blocks never share labels.
            s["label"] = _index_to_label(next_idx)
            next_idx += 1
            continue
        if unit not in unit_to_label:
            unit_to_label[unit] = _index_to_label(next_idx)
            next_idx += 1
        s["label"] = unit_to_label[unit]

    label_counts: dict[str, int] = {}
    for s in sections:
        label_counts[s["label"]] = label_counts.get(s["label"], 0) + 1
    most_common = max(label_counts, key=label_counts.get) if label_counts else None

    for idx, s in enumerate(sections):
        s["recurs"] = label_counts[s["label"]] > 1
        if idx == 0 and not s["recurs"]:
            s["role"] = "intro"
        elif idx == len(sections) - 1 and not s["recurs"]:
            s["role"] = "outro"
        elif s["label"] == most_common and s["recurs"]:
            s["role"] = "main"
        else:
            s["role"] = "section"


def form_string(sections: list[dict]) -> str:
    """One-line scannable form summary."""
    parts: list[str] = []
    for s in sections:
        lo, hi = s["measures"]
        role = s.get("role", "section")
        label = s.get("label", "?")
        reps = s.get("repetitions", 1)
        L = s.get("riff_bars", 1)
        bars = hi - lo + 1
        if reps > 1:
            parts.append(
                f"{role.capitalize()} {label} ×{reps} (m.{lo}-{hi}, {L}-bar riff)"
            )
        else:
            parts.append(f"{role.capitalize()} {label} (m.{lo}-{hi}, {bars} bars)")
    return " | ".join(parts)


# ---------------------------------------------------------------------------
# Chord progression per section
# ---------------------------------------------------------------------------


def _chord_prog_for_range(lo: int, hi: int, harmony: list[dict]) -> list[dict]:
    prog: list[dict] = []
    for h in harmony:
        m_range = h.get("measures") or [None, None]
        m = m_range[0]
        if m is None or not (lo <= m <= hi):
            continue
        ch = h.get("chord")
        lab = ch["label"] if (ch and not h.get("ambiguous")) else None
        if not prog or prog[-1]["label"] != lab:
            prog.append({"label": lab, "measures": [m, m]})
        else:
            prog[-1]["measures"][1] = m
    return prog


# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------


def find_segments(
    beats: list[dict],
    harmony: list[dict],
    parsed,
    riff_lengths: tuple[int, ...] = (1, 2, 4, 8),
    similarity_threshold: float = 0.75,
) -> list[dict]:
    """Detect form via per-bar fingerprint clustering + repetition detection.

    Parameters:
        beats: per-beat output of chords.per_beat_chords (used for bar pcs/
            bass/density)
        harmony: per-window implied-chord output (used for chord progression
            per section)
        parsed: ParsedScore (used for track_bars to fingerprint active tracks)
        riff_lengths: candidate L values for the repeat detector.
        similarity_threshold: bars cluster together if bar-similarity >= this.

    Returns segments with: measures [lo, hi], label, role, riff_bars,
    repetitions, chord_progression.
    """
    if not beats:
        return []

    measures = sorted({b["measure"] for b in beats if b.get("measure") is not None})
    if not measures:
        return []

    fps = {m: _bar_fingerprint(m, beats, parsed) for m in measures}
    bar_ids = _cluster_bars(measures, fps, similarity_threshold)
    seq = _smooth_sequence([bar_ids[m] for m in measures])

    raw = _detect_sections(seq, riff_lengths)
    merged = _merge_adjacent(raw)
    coalesced = _coalesce_singletons(merged)

    out: list[dict] = []
    for s in coalesced:
        lo = measures[s["start"]]
        hi = measures[s["end"]]
        out.append(
            {
                "measures": [lo, hi],
                "riff_bars": s["riff_bars"],
                "repetitions": s["repetitions"],
                "chord_progression": _chord_prog_for_range(lo, hi, harmony),
                "_unit": s["unit"],
            }
        )

    _assign_form_labels(out)
    for s in out:
        s.pop("_unit", None)
    return out


# ---------------------------------------------------------------------------
# Post-segmentation annotation (unchanged in spirit from earlier version)
# ---------------------------------------------------------------------------


def _track_divergence(seg: dict, parsed) -> dict:
    """Note-count ratio between main guitar tracks in this segment."""
    if parsed is None or parsed.track_bars is None:
        return {
            "main_track_notes": {},
            "divergence_ratio": 1.0,
            "main_pair_indices": [],
        }
    main_indices = [
        i for i, t in enumerate(parsed.track_meta) if t.get("role") == "guitar_main"
    ]
    lo, hi = seg["measures"]
    counts: dict[int, int] = {}
    for i in main_indices:
        c = 0
        for m in range(lo, hi + 1):
            bar = parsed.track_bars.get(i, {}).get(m)
            if bar:
                c += bar["note_count"]
        counts[i] = c
    if len(counts) >= 2:
        vals = list(counts.values())
        denom = max(min(vals), 1)
        ratio = max(vals) / denom
    else:
        ratio = 1.0
    return {
        "main_track_notes": counts,
        "divergence_ratio": round(float(ratio), 2),
        "main_pair_indices": main_indices,
    }


def annotate_segments(segments: list[dict], parsed) -> None:
    """Attach per-segment raw data: track divergence, label recurrence."""
    if not segments:
        return
    label_counts: dict[str, int] = {}
    for s in segments:
        label_counts[s["label"]] = label_counts.get(s["label"], 0) + 1
    for s in segments:
        s["track_divergence"] = _track_divergence(s, parsed)
        # recurs may already be set by _assign_form_labels; recompute consistently
        s["recurs"] = label_counts.get(s["label"], 1) > 1
