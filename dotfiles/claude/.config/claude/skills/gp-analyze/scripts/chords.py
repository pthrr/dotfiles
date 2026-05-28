"""Per-beat chord identification via music21 chordify, with Roman labeling."""

from __future__ import annotations

from music21 import chord as m21chord
from music21 import key as m21key
from music21 import stream

from parse import ParsedScore
from roman_numeral import roman_from_names

_QUALITY_MAP = {
    "major triad": "maj",
    "minor triad": "min",
    "diminished triad": "dim",
    "augmented triad": "aug",
    "dominant seventh chord": "7",
    "major seventh chord": "maj7",
    "minor seventh chord": "min7",
    "half-diminished seventh chord": "m7b5",
    "diminished seventh chord": "dim7",
    "minor-major seventh chord": "mMaj7",
    "augmented major seventh chord": "maj7",
}


def _short_quality(common_name: str) -> str:
    return _QUALITY_MAP.get(common_name, common_name)


def _label_chord(c: m21chord.Chord, global_tonic_name: str | None) -> dict:
    pcs = sorted({p.pitchClass for p in c.pitches})
    midi = sorted({p.midi for p in c.pitches})

    if len(pcs) == 0:
        return {
            "pitches": [],
            "pitch_classes": [],
            "chord": None,
        }

    if len(pcs) == 1:
        return {
            "pitches": midi,
            "pitch_classes": pcs,
            "chord": {
                "root": c.pitches[0].name,
                "quality": "unison",
                "inversion": 0,
                "roman_global": None,
                "roman_local": None,
                "ambiguous": True,
            },
        }

    try:
        root_name = c.root().name
        quality = c.commonName
        inv = c.inversion()
        ambiguous = not (c.isTriad() or c.isSeventh())
    except Exception:
        return {
            "pitches": midi,
            "pitch_classes": pcs,
            "chord": {
                "root": None,
                "quality": "?",
                "inversion": 0,
                "roman_global": None,
                "roman_local": None,
                "ambiguous": True,
            },
        }

    short_q = _short_quality(quality)
    roman_global: str | None = None
    if global_tonic_name and not ambiguous:
        roman_global = roman_from_names(root_name, short_q, global_tonic_name)

    return {
        "pitches": midi,
        "pitch_classes": pcs,
        "chord": {
            "root": root_name,
            "quality": quality,
            "inversion": inv,
            "roman_global": roman_global if not ambiguous else "?",
            "roman_local": None,
            "ambiguous": ambiguous,
        },
    }


def per_beat_chords(parsed: ParsedScore, ambiguity_threshold: float = 0.6) -> list[dict]:
    """Chordify the merged score and emit one record per chord/note event.

    The threshold is currently used only via the ambiguous flag on chord shape;
    we keep the parameter so future confidence-based gating can plug in.
    """
    chordified = parsed.score.chordify(removeRedundantPitches=True)

    global_tonic_name = parsed.global_key.get("tonic") or None

    beats: list[dict] = []
    for m in chordified.recurse().getElementsByClass(stream.Measure):
        for el in m.notes:
            if not isinstance(el, m21chord.Chord):
                if hasattr(el, "pitches"):
                    el = m21chord.Chord(list(el.pitches), quarterLength=el.quarterLength)
                else:
                    continue

            label = _label_chord(el, global_tonic_name)
            beats.append(
                {
                    "measure": m.number,
                    "beat": float(el.offset) + 1.0,
                    "offset_quarters": float(el.getOffsetInHierarchy(parsed.score)) if hasattr(el, "getOffsetInHierarchy") else float(el.offset),
                    "duration_quarters": float(el.quarterLength),
                    **label,
                }
            )

    return beats
