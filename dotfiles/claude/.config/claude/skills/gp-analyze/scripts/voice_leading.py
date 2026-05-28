"""Voice-leading metrics between consecutive chord beats."""

from __future__ import annotations

import itertools

_PC_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]


def _pc_of_name(name: str) -> int:
    try:
        return _PC_NAMES.index(name)
    except ValueError:
        from music21 import pitch as m21pitch

        return m21pitch.Pitch(name).pitchClass


def _circular_dist(a: int, b: int) -> int:
    d = (a - b) % 12
    return min(d, 12 - d)


def _vl_distance(a_pcs: list[int], b_pcs: list[int]) -> int:
    """Min-cost sum of |Δ| pairing each pc of the shorter set to the longer.

    Brute force over permutations — fine for chord sizes up to ~5 notes.
    """
    if not a_pcs or not b_pcs:
        return 0
    long, short = (a_pcs, b_pcs) if len(a_pcs) >= len(b_pcs) else (b_pcs, a_pcs)
    if len(long) > 6:
        # fallback: greedy nearest neighbour
        total = 0
        for p in short:
            total += min(_circular_dist(p, q) for q in long)
        return total
    best = None
    for perm in itertools.permutations(long, len(short)):
        cost = sum(_circular_dist(p, q) for p, q in zip(perm, short))
        if best is None or cost < best:
            best = cost
    return int(best or 0)


def _common_tones(a_pcs: list[int], b_pcs: list[int]) -> list[str]:
    return [_PC_NAMES[pc] for pc in sorted(set(a_pcs) & set(b_pcs))]


def _signed_root_motion(root_a: str | None, root_b: str | None) -> int | None:
    if not root_a or not root_b:
        return None
    pa = _pc_of_name(root_a)
    pb = _pc_of_name(root_b)
    diff = (pb - pa) % 12
    if diff > 6:
        diff -= 12
    return diff


def transitions(beats: list[dict]) -> list[dict]:
    out: list[dict] = []
    prev = None
    for b in beats:
        if not b.get("chord"):
            continue
        if prev is None:
            prev = b
            continue
        a_pcs = prev.get("pitch_classes", [])
        b_pcs = b.get("pitch_classes", [])
        out.append(
            {
                "from_offset": prev["offset_quarters"],
                "to_offset": b["offset_quarters"],
                "from_measure": prev.get("measure"),
                "to_measure": b.get("measure"),
                "root_motion_semitones": _signed_root_motion(
                    prev["chord"].get("root"), b["chord"].get("root")
                ),
                "voice_leading_distance": _vl_distance(a_pcs, b_pcs),
                "common_tones": _common_tones(a_pcs, b_pcs),
            }
        )
        prev = b
    return out
