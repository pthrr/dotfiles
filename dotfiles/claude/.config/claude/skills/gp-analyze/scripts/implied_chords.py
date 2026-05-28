"""Implied-chord extraction over harmonic windows.

For monophonic riffs / arpeggios / lead lines, the "chord" isn't vertical —
it's the pitch collection outlined over a window of time. This module
aggregates pitches per window (default: one measure), fits the best chord
template, and exposes the resulting chord + bass + non-chord-tones so the
voice-leading layer can connect successive implied chords.
"""

from __future__ import annotations

import re

from roman_numeral import roman_label

_PC_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]


# Map detailed chord qualities to a compact "harmonic identity" suffix.
# Voicing variations (maj7, add9, 6) collapse onto the bare triad. Genuinely
# distinct sonorities (sus, °, +, dom7, power) are preserved.
_QUALITY_TO_BASE: dict[str, str] = {
    "maj": "", "maj7": "", "maj9": "", "add9": "", "6": "",
    "min": "m", "min7": "m", "m6": "m", "madd9": "m", "m9": "m", "mMaj7": "m",
    "dim": "°", "dim7": "°", "m7b5": "ø",
    "aug": "+",
    "7": "7", "9": "7", "7sus4": "7sus4",
    "sus4": "sus4",
    "sus2": "sus2",
    "5": "5",
}


def normalize_chord_label(label: str | None, keep_bass: bool = False) -> str | None:
    """Reduce a full chord label to its harmonic identity.

    Examples:
        Cmaj7              -> C
        Cadd9              -> C
        Cmaj7#5/E          -> C  (bass dropped unless keep_bass=True)
        Bbm9               -> Bbm
        F#m7b5             -> F#ø
        Db5                -> Db5
        Bbmin/Db           -> Bbm
    """
    if not label:
        return None
    if "/" in label:
        head, bass = label.split("/", 1)
    else:
        head, bass = label, None

    m = re.match(r"^([A-G][b#]?)(.*)$", head)
    if not m:
        return label
    root, quality = m.group(1), m.group(2)
    suffix = _QUALITY_TO_BASE.get(quality, quality)
    out = f"{root}{suffix}"
    if keep_bass and bass:
        out += f"/{bass}"
    return out


# (label, intervals from root, "anchor" pcs that must be present)
# Anchor pcs are the structural notes: root + 3rd (or sus/5), required for a confident fit.
_TEMPLATES: list[tuple[str, tuple[int, ...], tuple[int, ...]]] = [
    # power / open intervals
    ("5", (0, 7), (0, 7)),
    # triads
    ("maj", (0, 4, 7), (0, 4)),
    ("min", (0, 3, 7), (0, 3)),
    ("dim", (0, 3, 6), (0, 3, 6)),
    ("aug", (0, 4, 8), (0, 4, 8)),
    ("sus4", (0, 5, 7), (0, 5)),
    ("sus2", (0, 2, 7), (0, 2)),
    # sevenths
    ("maj7", (0, 4, 7, 11), (0, 4, 11)),
    ("min7", (0, 3, 7, 10), (0, 3, 10)),
    ("7", (0, 4, 7, 10), (0, 4, 10)),
    ("m7b5", (0, 3, 6, 10), (0, 3, 6, 10)),
    ("dim7", (0, 3, 6, 9), (0, 3, 6, 9)),
    ("mMaj7", (0, 3, 7, 11), (0, 3, 11)),
    ("7sus4", (0, 5, 7, 10), (0, 5, 10)),
    # added-tone
    ("6", (0, 4, 7, 9), (0, 4, 9)),
    ("m6", (0, 3, 7, 9), (0, 3, 9)),
    ("add9", (0, 2, 4, 7), (0, 2, 4)),
    ("madd9", (0, 2, 3, 7), (0, 2, 3)),
    # extensions
    ("maj9", (0, 2, 4, 7, 11), (0, 4, 11)),
    ("m9", (0, 2, 3, 7, 10), (0, 3, 10)),
    ("9", (0, 2, 4, 7, 10), (0, 4, 10)),
]


def _pc_to_name(pc: int) -> str:
    return _PC_NAMES[pc % 12]


def fit_chord(
    pcs: set[int],
    durations: dict[int, float] | None = None,
    bass_pc: int | None = None,
) -> dict | None:
    """Return best (root, quality) fit for `pcs`, scored by anchor coverage."""
    if not pcs:
        return None

    total_w = sum(durations.values()) if durations else float(len(pcs))

    best = None
    for root in range(12):
        if root not in pcs:
            continue
        for name, intervals, anchors in _TEMPLATES:
            template = {(root + i) % 12 for i in intervals}
            anchor_set = {(root + i) % 12 for i in anchors}
            present_anchor = anchor_set & pcs
            anchor_cov = len(present_anchor) / len(anchor_set)
            if anchor_cov < 1.0:
                continue  # all anchor tones must be present

            present_all = template & pcs
            full_cov = len(present_all) / len(template)
            # how much of the window is explained by chord tones
            if durations and total_w > 0:
                explained = sum(durations.get(pc, 0.0) for pc in present_all) / total_w
            else:
                explained = len(present_all) / len(pcs)

            # base score: prefer fuller templates that explain more of the window
            score = 0.55 * full_cov + 0.45 * explained
            # small bias for bass-as-root
            if bass_pc is not None and bass_pc == root:
                score += 0.05
            # slight penalty per template size to break ties toward simpler labels
            score -= 0.005 * len(intervals)

            if best is None or score > best["score"]:
                best = {
                    "root_pc": root,
                    "quality": name,
                    "template_pcs": sorted(template),
                    "anchor_pcs": sorted(anchor_set),
                    "non_chord_tones_pc": sorted(pcs - template),
                    "missing_template_tones_pc": sorted(template - pcs),
                    "score": score,
                    "full_coverage": full_cov,
                    "explained": explained,
                }

    return best


def _slash_label(root_pc: int, quality: str, bass_pc: int | None) -> str:
    base = f"{_pc_to_name(root_pc)}{quality if quality != 'maj' else ''}"
    if bass_pc is not None and bass_pc != root_pc:
        return f"{base}/{_pc_to_name(bass_pc)}"
    return base


def _roman(root_pc: int, quality: str, tonic_pc: int | None, bass_pc: int | None = None) -> str | None:
    if tonic_pc is None:
        return None
    return roman_label(root_pc, quality, tonic_pc, bass_pc=bass_pc)


def _group_beats_by_window(
    beats: list[dict], window_quarters: float | None = None
) -> list[dict]:
    """Group beats into windows. Default: one window per measure."""
    if not beats:
        return []

    if window_quarters is None:
        by_measure: dict[int, list[dict]] = {}
        for b in beats:
            m = b.get("measure")
            if m is None:
                continue
            by_measure.setdefault(m, []).append(b)
        out = []
        for m in sorted(by_measure):
            wb = by_measure[m]
            out.append(
                {
                    "measures": [m, m],
                    "beats": wb,
                    "offset_start": wb[0]["offset_quarters"],
                    "offset_end": wb[-1]["offset_quarters"] + wb[-1]["duration_quarters"],
                }
            )
        return out

    # Fixed-size windows on the absolute timeline
    out = []
    first = beats[0]["offset_quarters"]
    last = beats[-1]["offset_quarters"] + beats[-1]["duration_quarters"]
    win_start = first
    while win_start < last:
        win_end = win_start + window_quarters
        in_win = [
            b
            for b in beats
            if b["offset_quarters"] < win_end
            and b["offset_quarters"] + b["duration_quarters"] > win_start
        ]
        if in_win:
            measures = sorted({b["measure"] for b in in_win if b.get("measure")})
            out.append(
                {
                    "measures": [measures[0], measures[-1]] if measures else [None, None],
                    "beats": in_win,
                    "offset_start": win_start,
                    "offset_end": win_end,
                }
            )
        win_start = win_end
    return out


def extract_implied_chords(
    parsed,
    beats: list[dict],
    window_quarters: float | None = None,
    confidence_threshold: float = 0.55,
) -> list[dict]:
    """Return one implied-chord record per window."""
    global_tonic_pc: int | None = None
    if parsed.global_key.get("tonic"):
        try:
            global_tonic_pc = _PC_NAMES.index(parsed.global_key["tonic"])
        except ValueError:
            from music21 import pitch as m21pitch

            try:
                global_tonic_pc = m21pitch.Pitch(parsed.global_key["tonic"]).pitchClass
            except Exception:
                global_tonic_pc = None

    windows = _group_beats_by_window(beats, window_quarters)
    harmony: list[dict] = []
    for w in windows:
        midis: list[int] = []
        durations_by_pc: dict[int, float] = {}
        for b in w["beats"]:
            for p in b.get("pitches", []):
                midis.append(p)
                pc = p % 12
                durations_by_pc[pc] = durations_by_pc.get(pc, 0.0) + b.get(
                    "duration_quarters", 1.0
                )
        if not midis:
            continue
        pcs = set(durations_by_pc.keys())
        bass_midi = min(midis)
        top_midi = max(midis)
        bass_pc = bass_midi % 12

        fit = fit_chord(pcs, durations=durations_by_pc, bass_pc=bass_pc)
        if fit is None:
            harmony.append(
                {
                    "measures": w["measures"],
                    "offset_start": w["offset_start"],
                    "offset_end": w["offset_end"],
                    "pitches": sorted(set(midis)),
                    "pitch_classes": sorted(pcs),
                    "bass": _pc_to_name(bass_pc),
                    "top": _pc_to_name(top_midi % 12),
                    "chord": None,
                    "confidence": 0.0,
                    "ambiguous": True,
                }
            )
            continue

        ambiguous = fit["score"] < confidence_threshold
        label = _slash_label(
            fit["root_pc"], fit["quality"], bass_pc if not ambiguous else None
        )
        harmony.append(
            {
                "measures": w["measures"],
                "offset_start": w["offset_start"],
                "offset_end": w["offset_end"],
                "pitches": sorted(set(midis)),
                "pitch_classes": sorted(pcs),
                "bass": _pc_to_name(bass_pc),
                "top": _pc_to_name(top_midi % 12),
                "chord": {
                    "label": label,
                    "root": _pc_to_name(fit["root_pc"]),
                    "quality": fit["quality"],
                    "chord_tones_pc": fit["template_pcs"],
                    "non_chord_tones_pc": fit["non_chord_tones_pc"],
                    "missing_template_tones_pc": fit["missing_template_tones_pc"],
                    "is_slash": bass_pc != fit["root_pc"],
                    "slash_bass": _pc_to_name(bass_pc)
                    if bass_pc != fit["root_pc"]
                    else None,
                    "roman_global": _roman(
                        fit["root_pc"], fit["quality"], global_tonic_pc, bass_pc=bass_pc
                    )
                    if not ambiguous
                    else None,
                    "roman_local": None,  # filled later when sections known
                },
                "confidence": float(fit["score"]),
                "ambiguous": ambiguous,
            }
        )

    return harmony


def harmonic_transitions(harmony: list[dict]) -> list[dict]:
    """Voice-leading metrics between consecutive implied chords.

    Uses chord-tone pc sets (not raw window pcs) so the VL distance reflects
    motion between the IMPLIED harmonies, not between every passing tone.
    """
    import itertools

    def _circ(a: int, b: int) -> int:
        d = (a - b) % 12
        return min(d, 12 - d)

    def _vl(a_pcs: list[int], b_pcs: list[int]) -> int:
        if not a_pcs or not b_pcs:
            return 0
        long, short = (a_pcs, b_pcs) if len(a_pcs) >= len(b_pcs) else (b_pcs, a_pcs)
        if len(long) > 6:
            return sum(min(_circ(p, q) for q in long) for p in short)
        best = None
        for perm in itertools.permutations(long, len(short)):
            cost = sum(_circ(p, q) for p, q in zip(perm, short))
            if best is None or cost < best:
                best = cost
        return int(best or 0)

    out: list[dict] = []
    prev = None
    for h in harmony:
        if not h.get("chord"):
            prev = h if h.get("pitch_classes") else prev
            continue
        if prev is None:
            prev = h
            continue
        prev_ch = prev.get("chord") if prev else None
        if not prev_ch:
            prev = h
            continue
        a_tones = prev_ch["chord_tones_pc"]
        b_tones = h["chord"]["chord_tones_pc"]
        a_root = _PC_NAMES.index(prev_ch["root"])
        b_root = _PC_NAMES.index(h["chord"]["root"])
        rm = (b_root - a_root) % 12
        if rm > 6:
            rm -= 12
        common = sorted(set(a_tones) & set(b_tones))
        out.append(
            {
                "from_measures": prev["measures"],
                "to_measures": h["measures"],
                "from_label": prev_ch["label"],
                "to_label": h["chord"]["label"],
                "root_motion_semitones": rm,
                "voice_leading_distance": _vl(a_tones, b_tones),
                "common_tones": [_pc_to_name(pc) for pc in common],
                "bass_motion_semitones": (
                    (_PC_NAMES.index(h["bass"]) - _PC_NAMES.index(prev["bass"])) % 12
                ),
            }
        )
        prev = h
    return out


def attach_roman_local(harmony: list[dict], sections: list[dict]) -> None:
    """Fill in roman_local on each harmony entry using its section's tonic."""
    if not sections or not harmony:
        return

    def section_for(measure):
        for s in sections:
            lo, hi = s["measures"]
            if lo <= measure <= hi:
                return s
        return None

    for h in harmony:
        ch = h.get("chord")
        if not ch or h.get("ambiguous"):
            continue
        m = h["measures"][0]
        sec = section_for(m)
        if not sec:
            continue
        tonic = sec["mode"]["tonic"]
        try:
            tonic_pc = _PC_NAMES.index(tonic)
        except ValueError:
            continue
        try:
            root_pc = _PC_NAMES.index(ch["root"])
        except ValueError:
            continue
        bass_pc = _PC_NAMES.index(h["bass"]) if h.get("bass") in _PC_NAMES else None
        ch["roman_local"] = roman_label(
            root_pc, ch["quality"], tonic_pc, bass_pc=bass_pc
        )
