"""Roman-numeral labeling for chords.

Replaces music21's figured-bass output (which produces things like `i#874`
for non-functional/extended chords) with a clean scale-degree + quality
notation suited to modal and chromatic music.
"""

from __future__ import annotations

_PC_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

# Major-scale scale-degree names. Anything off the major scale becomes
# bII / bIII / #IV / bVI / bVII / b/#I etc.
_MAJOR_DEGREE = {0: "I", 2: "II", 4: "III", 5: "IV", 7: "V", 9: "VI", 11: "VII"}
_ALTERED = {1: "bII", 3: "bIII", 6: "#IV", 8: "bVI", 10: "bVII"}

# Qualities that take a lowercase Roman numeral.
_MINOR_QUALITIES = {"min", "min7", "m7b5", "mMaj7", "m6", "madd9", "m9", "dim", "dim7"}

# Quality suffix as it should appear after the Roman numeral.
_SUFFIX = {
    "maj": "",
    "min": "",
    "5": "5",
    "maj7": "M7",
    "min7": "7",
    "7": "7",
    "m7b5": "ø7",
    "dim": "°",
    "dim7": "°7",
    "mMaj7": "M7",
    "aug": "+",
    "sus2": "sus2",
    "sus4": "sus4",
    "7sus4": "7sus4",
    "6": "6",
    "m6": "6",
    "add9": "add9",
    "madd9": "add9",
    "maj9": "M9",
    "m9": "9",
    "9": "9",
}


def _pc_of_name(name: str | None) -> int | None:
    if not name:
        return None
    if name in _PC_NAMES:
        return _PC_NAMES.index(name)
    try:
        from music21 import pitch as m21pitch

        return m21pitch.Pitch(name).pitchClass
    except Exception:
        return None


def roman_label(
    root_pc: int,
    quality: str,
    tonic_pc: int,
    bass_pc: int | None = None,
) -> str:
    """Build a Roman-numeral chord label.

    Args:
        root_pc: pitch-class of the chord root (0..11).
        quality: short quality tag (e.g. "maj", "min7", "m7b5", "sus4").
        tonic_pc: pitch-class of the key tonic.
        bass_pc: optional bass pc, used to add slash notation when distinct from root.
    """
    semitones = (root_pc - tonic_pc) % 12
    base = _MAJOR_DEGREE.get(semitones) or _ALTERED.get(semitones) or "?"
    if quality in _MINOR_QUALITIES:
        base = base.lower()
    suffix = _SUFFIX.get(quality, quality)
    label = base + suffix
    if bass_pc is not None and bass_pc != root_pc:
        bass_semitones = (bass_pc - tonic_pc) % 12
        bass_deg = _MAJOR_DEGREE.get(bass_semitones) or _ALTERED.get(bass_semitones)
        if bass_deg:
            label += f"/{bass_deg.lower() if bass_deg in _MAJOR_DEGREE.values() else bass_deg}"
    return label


def roman_from_names(
    root_name: str | None,
    quality: str,
    tonic_name: str | None,
    bass_name: str | None = None,
) -> str | None:
    root_pc = _pc_of_name(root_name)
    tonic_pc = _pc_of_name(tonic_name)
    if root_pc is None or tonic_pc is None or not quality:
        return None
    bass_pc = _pc_of_name(bass_name) if bass_name else None
    return roman_label(root_pc, quality, tonic_pc, bass_pc)
