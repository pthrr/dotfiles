"""Per-section modal analysis via pc-histogram template matching."""

from __future__ import annotations

import numpy as np

from modes_library import MODES, find_template

_PC_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

_DEGREE_LABEL = {
    0: "1",
    1: "b2",
    2: "2",
    3: "b3",
    4: "3",
    5: "4",
    6: "b5",
    7: "5",
    8: "b6",
    9: "6",
    10: "b7",
    11: "7",
}


def _histogram_from_beats(beats: list[dict]) -> np.ndarray:
    hist = np.zeros(12, dtype=float)
    for b in beats:
        dur = b.get("duration_quarters", 1.0)
        for pc in b.get("pitch_classes", []):
            hist[pc] += dur
    s = hist.sum()
    if s > 0:
        hist /= s
    return hist


# Prior weight by template cardinality. Diatonic 7-modes are the default;
# smaller (pentatonic) and symmetric (whole-tone, augmented) templates need
# stronger evidence to win, otherwise they over-fit sparse per-measure data.
_SIZE_PRIOR = {
    5: 0.65,
    6: 0.80,
    7: 1.00,
    8: 0.85,
}


def _best_mode(
    hist: np.ndarray,
    tonic_hint_pc: int | None = None,
) -> tuple[str, str, float]:
    """Pick (tonic, mode) maximising duration-coverage × cardinality-prior.

    inside-coverage = fraction of the histogram's duration that lies inside
    the template. The cardinality prior nudges toward 7-mode diatonic shapes
    when sparse input would otherwise let pentatonics dominate.

    `tonic_hint_pc` is an optional tonic candidate from the segment's bass
    or longest-held pc — a small bonus, not a hard constraint.
    """
    if hist.sum() == 0:
        return ("C", "Ionian", 0.0)
    best: tuple[str, str, float] = ("C", "Ionian", -1.0)
    for mode_name, template_pcs in MODES:
        prior = _SIZE_PRIOR.get(len(template_pcs), 0.5)
        for tonic in range(12):
            inside = 0.0
            for p in template_pcs:
                inside += hist[(p + tonic) % 12]
            score = inside * prior
            if tonic_hint_pc is not None and tonic == tonic_hint_pc:
                score += 0.03
            if score > best[2]:
                best = (_PC_NAMES[tonic], mode_name, float(score))
    # Clip confidence into [0, 1] for display.
    return (best[0], best[1], max(0.0, min(1.0, best[2])))


def _characteristic_degrees(tonic_pc: int, mode_pcs: tuple[int, ...]) -> list[str]:
    """Degrees of this mode, labeled relative to tonic. Highlights the modal flavour."""
    return [_DEGREE_LABEL[p % 12] for p in mode_pcs if p % 12 != 0]


# Named set classes that come up in metal / prog / non-tonal contexts.
# Keyed by Forte class string. music21 returns e.g. "6-20", "8-28".
_NAMED_SET_CLASSES = {
    "3-11A": "minor triad",
    "3-11B": "major triad",
    "3-12": "augmented triad",
    "3-10": "diminished triad",
    "4-19": "major-minor tetrachord",
    "4-25": "French augmented sixth",
    "4-26": "minor seventh chord",
    "4-27A": "half-diminished seventh",
    "4-27B": "dominant seventh",
    "4-28": "diminished seventh",
    "5-Z17": "all-trichord pentachord",
    "5-35": "diatonic pentatonic",
    "6-20": "hexatonic (augmented) collection",
    "6-30": "Petrushka chord (octatonic hexachord)",
    "6-35": "whole-tone collection",
    "6-Z19": "all-trichord hexachord",
    "6-Z25": "hexatonic Z-related (Locrian)",
    "6-Z47": "hexatonic Z-related (acoustic)",
    "7-31": "octatonic minus one (heptachord)",
    "7-32A": "harmonic minor",
    "7-32B": "harmonic major",
    "7-34": "ascending melodic minor",
    "7-35": "diatonic",
    "8-28": "octatonic collection",
}


def _set_class_info(pcs: list[int]) -> dict | None:
    """Compute Forte set-class info for a pc collection via music21."""
    from music21 import chord as m21chord
    from music21 import pitch as m21pitch

    unique_pcs = sorted(set(pcs))
    if not unique_pcs:
        return None
    try:
        c = m21chord.Chord([m21pitch.Pitch(midi=60 + p) for p in unique_pcs])
        forte = c.forteClass
        return {
            "cardinality": len(unique_pcs),
            "pcs": unique_pcs,
            "prime_form": list(c.primeForm),
            "forte_class": forte,
            "interval_vector": list(c.intervalVector),
            "name": _NAMED_SET_CLASSES.get(forte),
        }
    except Exception:
        return {
            "cardinality": len(unique_pcs),
            "pcs": unique_pcs,
            "prime_form": None,
            "forte_class": None,
            "interval_vector": None,
            "name": None,
        }


def _classify_tonality(pcs: list[int], mode_confidence: float, set_info: dict | None) -> str:
    """Classify the segment's tonality character.

    Returns one of:
        "tonal"        — clean 7-mode fit with sufficient pc support
        "fragmentary"  — too few pcs to commit to a mode; mode label is best-guess
        "symmetric"    — pc-set is a recognised symmetric collection (WT, octatonic, aug)
        "non_tonal"    — fits no clean mode and is not a familiar symmetric set
    """
    n = len(set(pcs))
    forte = set_info.get("forte_class") if set_info else None
    if forte in {"6-20", "6-35", "8-28", "4-25", "4-28", "3-12"}:
        return "symmetric"
    if n >= 7 and mode_confidence >= 0.95:
        return "tonal"
    if n <= 4:
        return "fragmentary"
    if mode_confidence < 0.85:
        return "non_tonal"
    return "tonal"


def _cadence_patterns(measure_beats: list[dict], tonic_pc: int) -> list[str]:
    """Detect simple modal cadence patterns by Roman-numeral-like root motion.

    Currently spots: bII-i (Phrygian), bVII-i (Aeolian/Mixolydian-borrowed),
    V-i, iv-i, bVI-bVII-i (Aeolian closing).
    """
    roots = []
    for b in measure_beats:
        ch = b.get("chord")
        if not ch or not ch.get("root"):
            continue
        try:
            pc = _PC_NAMES.index(ch["root"])
        except ValueError:
            from music21 import pitch as m21pitch

            pc = m21pitch.Pitch(ch["root"]).pitchClass
        roots.append((pc - tonic_pc) % 12)
    found: list[str] = []
    # check last two/three roots ending on tonic
    if len(roots) >= 2 and roots[-1] == 0:
        prev = roots[-2]
        if prev == 1:
            found.append("bII-i")
        elif prev == 10:
            found.append("bVII-i")
        elif prev == 7:
            found.append("V-i")
        elif prev == 5:
            found.append("iv-i")
    if len(roots) >= 3 and roots[-1] == 0 and roots[-2] == 10 and roots[-3] == 8:
        found.append("bVI-bVII-i")
    return found


def _tonic_hint_for_segment(seg_beats: list[dict], harmony_in_seg: list[dict]) -> int | None:
    """Heuristic tonic candidate per segment.

    Prefer the bass-note pc that appears in the most bars; fall back to the
    longest-held pc in the duration-weighted histogram. This is a soft hint
    for mode detection, not a commitment.
    """
    from collections import Counter

    bass_counts: Counter = Counter()
    for h in harmony_in_seg:
        bass = h.get("bass")
        if bass and bass in _PC_NAMES:
            bass_counts[_PC_NAMES.index(bass)] += 1
    if bass_counts:
        return bass_counts.most_common(1)[0][0]
    hist = _histogram_from_beats(seg_beats)
    if hist.sum() == 0:
        return None
    return int(np.argmax(hist))


def analyze_segments(
    segments: list[dict],
    beats: list[dict],
    harmony: list[dict],
    ambiguity_threshold: float = 0.6,
) -> list[dict]:
    """One mode per pre-computed structural segment.

    No global-key prior — each segment is analysed in isolation, using only
    its own beats and a within-segment tonic hint (most common bass pc).
    """
    if not segments:
        return []

    beats_by_measure: dict[int, list[dict]] = {}
    for b in beats:
        m = b.get("measure")
        if m is None:
            continue
        beats_by_measure.setdefault(m, []).append(b)

    harmony_by_measure: dict[int, dict] = {h["measures"][0]: h for h in harmony}

    out: list[dict] = []
    for seg in segments:
        lo, hi = seg["measures"]
        seg_beats: list[dict] = []
        seg_harmony: list[dict] = []
        for m in range(lo, hi + 1):
            seg_beats.extend(beats_by_measure.get(m, []))
            if m in harmony_by_measure:
                seg_harmony.append(harmony_by_measure[m])

        hist = _histogram_from_beats(seg_beats)
        tonic_hint = _tonic_hint_for_segment(seg_beats, seg_harmony)
        tonic_name, mode_name, conf = _best_mode(hist, tonic_hint_pc=tonic_hint)
        tonic_pc = _PC_NAMES.index(tonic_name)
        mode_pcs = find_template(mode_name) or ()

        present_pcs = [i for i in range(12) if hist[i] > 0]
        set_info = _set_class_info(present_pcs)
        tonality = _classify_tonality(present_pcs, conf, set_info)

        out.append(
            {
                **seg,
                "tonality": tonality,
                "mode": {
                    "tonic": tonic_name,
                    "name": mode_name,
                    "confidence": conf,
                    "ambiguous": conf < ambiguity_threshold or tonality
                    in {"non_tonal", "symmetric", "fragmentary"},
                },
                "set_class": set_info,
                "pc_histogram": {str(i): float(hist[i]) for i in range(12)},
                "characteristic_degrees": _characteristic_degrees(tonic_pc, mode_pcs),
                "cadence_patterns": _cadence_patterns(seg_beats, tonic_pc),
            }
        )
    return out
