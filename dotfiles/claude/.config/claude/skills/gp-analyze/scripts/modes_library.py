"""Mode template library.

Each entry is `(mode_name, pcs)` where pcs is a tuple of pitch classes relative
to the mode's own tonic (tonic == 0). Modal detection rotates these templates
over all 12 tonics.
"""

from __future__ import annotations

_MAJOR = (0, 2, 4, 5, 7, 9, 11)
_HARMONIC_MINOR = (0, 2, 3, 5, 7, 8, 11)
_MELODIC_MINOR = (0, 2, 3, 5, 7, 9, 11)
_HARMONIC_MAJOR = (0, 2, 4, 5, 7, 8, 11)
_DOUBLE_HARMONIC = (0, 1, 4, 5, 7, 8, 11)


def _rotate(parent: tuple[int, ...], degree: int) -> tuple[int, ...]:
    """Build the template for the mode starting on `degree`-th note of `parent`."""
    root_pc = parent[degree]
    return tuple(sorted((p - root_pc) % 12 for p in parent))


def _family(parent: tuple[int, ...], names: list[str]) -> list[tuple[str, tuple[int, ...]]]:
    return [(names[i], _rotate(parent, i)) for i in range(len(parent))]


_MAJOR_NAMES = ["Ionian", "Dorian", "Phrygian", "Lydian", "Mixolydian", "Aeolian", "Locrian"]
_HM_NAMES = [
    "Harmonic Minor",
    "Locrian #6",
    "Ionian #5",
    "Dorian #4",
    "Phrygian Dominant",
    "Lydian #2",
    "Super Locrian bb7",
]
_MM_NAMES = [
    "Melodic Minor",
    "Dorian b2",
    "Lydian #5",
    "Lydian Dominant",
    "Mixolydian b6",
    "Locrian #2",
    "Altered",
]
_HMAJ_NAMES = [
    "Harmonic Major",
    "Dorian b5",
    "Phrygian b4",
    "Lydian b3",
    "Mixolydian b2",
    "Lydian Augmented #2",
    "Locrian bb7",
]
_DH_NAMES = [
    "Double Harmonic",
    "Lydian #2 #6",
    "Ultraphrygian",
    "Hungarian Minor",
    "Oriental",
    "Ionian #2 #5",
    "Locrian bb3 bb7",
]


MODES: list[tuple[str, tuple[int, ...]]] = [
    *_family(_MAJOR, _MAJOR_NAMES),
    *_family(_HARMONIC_MINOR, _HM_NAMES),
    *_family(_MELODIC_MINOR, _MM_NAMES),
    *_family(_HARMONIC_MAJOR, _HMAJ_NAMES),
    *_family(_DOUBLE_HARMONIC, _DH_NAMES),
    # symmetric / synthetic
    ("Whole Tone", (0, 2, 4, 6, 8, 10)),
    ("Augmented", (0, 3, 4, 7, 8, 11)),
    ("Diminished W-H", (0, 2, 3, 5, 6, 8, 9, 11)),
    ("Diminished H-W", (0, 1, 3, 4, 6, 7, 9, 10)),
    # pentatonics / hexatonics
    ("Major Pentatonic", (0, 2, 4, 7, 9)),
    ("Minor Pentatonic", (0, 3, 5, 7, 10)),
    ("Blues", (0, 3, 5, 6, 7, 10)),
    ("Hirajoshi", (0, 2, 3, 7, 8)),
    ("Insen", (0, 1, 5, 7, 10)),
    ("Iwato", (0, 1, 5, 6, 10)),
    ("In", (0, 1, 5, 7, 8)),
    ("Yo", (0, 2, 5, 7, 9)),
    # bebop
    ("Bebop Dominant", (0, 2, 4, 5, 7, 9, 10, 11)),
    ("Bebop Major", (0, 2, 4, 5, 7, 8, 9, 11)),
    ("Bebop Minor", (0, 2, 3, 4, 5, 7, 9, 10)),
]


def find_template(name: str) -> tuple[int, ...] | None:
    for n, pcs in MODES:
        if n == name:
            return pcs
    return None
