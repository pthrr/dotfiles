"""Per-track per-segment harmonic content.

For each (segment, track) emit: pcs played, duration-weighted pc histogram,
midi range, scale degrees relative to the segment's tonic, and the best-fit
implied chord/arpeggio outlined by *that track alone*.

The key idea: harmonic content can differ greatly per track. The bass might
pedal a single root while the lead arpeggiates an extended chord on top.
This module exposes each track's harmonic outline independently.
"""

from __future__ import annotations

from music21 import chord as m21chord
from music21 import note as m21note
from music21 import stream

from implied_chords import fit_chord

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


def _track_notes(parsed, track_idx: int, lo: int, hi: int) -> list[dict]:
    """All sounding notes from `track_idx` in measures [lo, hi]."""
    if track_idx >= len(parsed.score.parts):
        return []
    part = parsed.score.parts[track_idx]
    out: list[dict] = []
    for m in part.getElementsByClass(stream.Measure):
        if not (lo <= m.number <= hi):
            continue
        for el in m.notes:
            if isinstance(el, m21note.Note):
                out.append(
                    {
                        "midi": int(el.pitch.midi),
                        "pc": int(el.pitch.pitchClass),
                        "duration": float(el.quarterLength),
                        "offset_in_measure": float(el.offset),
                        "measure": int(m.number),
                    }
                )
            elif isinstance(el, m21chord.Chord):
                for p in el.pitches:
                    out.append(
                        {
                            "midi": int(p.midi),
                            "pc": int(p.pitchClass),
                            "duration": float(el.quarterLength),
                            "offset_in_measure": float(el.offset),
                            "measure": int(m.number),
                        }
                    )
    return out


def _tonic_pc(seg: dict) -> int | None:
    mode = seg.get("mode") or {}
    name = mode.get("tonic")
    if name in _PC_NAMES:
        return _PC_NAMES.index(name)
    return None


def _slash_label(root_pc: int, quality: str, bass_pc: int | None) -> str:
    base = f"{_PC_NAMES[root_pc]}{quality if quality != 'maj' else ''}"
    if bass_pc is not None and bass_pc != root_pc:
        return f"{base}/{_PC_NAMES[bass_pc]}"
    return base


def _classify_notes(notes: list[dict], chord_pcs: set[int] | None) -> dict:
    """Tally each note as chord-tone vs non-chord-tone against `chord_pcs`."""
    if not chord_pcs:
        return {
            "chord_tone_notes": 0,
            "non_chord_tone_notes": 0,
            "chord_tone_fraction": None,
            "non_chord_tones_pc": [],
        }
    ct = 0
    nct = 0
    nct_set: set[int] = set()
    for n in notes:
        if n["pc"] in chord_pcs:
            ct += 1
        else:
            nct += 1
            nct_set.add(n["pc"])
    total = ct + nct
    return {
        "chord_tone_notes": ct,
        "non_chord_tone_notes": nct,
        "chord_tone_fraction": round(ct / total, 2) if total else None,
        "non_chord_tones_pc": sorted(nct_set),
    }


def _summarize_track_in_segment(
    parsed, track_idx: int, seg: dict
) -> dict | None:
    """One per-track record for a single segment, or None if track is silent."""
    lo, hi = seg["measures"]
    notes = _track_notes(parsed, track_idx, lo, hi)
    if not notes:
        return None

    pc_dur: dict[int, float] = {}
    for n in notes:
        pc_dur[n["pc"]] = pc_dur.get(n["pc"], 0.0) + n["duration"]
    pcs = set(pc_dur.keys())

    midi_min = min(n["midi"] for n in notes)
    midi_max = max(n["midi"] for n in notes)
    bass_pc = midi_min % 12

    fit = fit_chord(pcs, durations=pc_dur, bass_pc=bass_pc)

    tonic_pc = _tonic_pc(seg)
    if tonic_pc is not None:
        degrees = sorted({(pc - tonic_pc) % 12 for pc in pcs})
        degree_labels = [_DEGREE_LABEL[d] for d in degrees]
    else:
        degree_labels = []

    bars = max(hi - lo + 1, 1)
    track_meta = parsed.track_meta[track_idx]

    chord_block: dict | None = None
    classification: dict
    if fit is not None:
        chord_block = {
            "label": _slash_label(fit["root_pc"], fit["quality"], bass_pc),
            "root": _PC_NAMES[fit["root_pc"]],
            "quality": fit["quality"],
            "chord_tones_pc": fit["template_pcs"],
            "non_chord_tones_pc": fit["non_chord_tones_pc"],
            "missing_template_tones_pc": fit["missing_template_tones_pc"],
            "confidence": round(float(fit["score"]), 2),
        }
        classification = _classify_notes(notes, set(fit["template_pcs"]))
    else:
        classification = _classify_notes(notes, None)

    return {
        "track_idx": track_idx,
        "track_name": track_meta.get("name"),
        "track_role": track_meta.get("role"),
        "note_count": len(notes),
        "density_notes_per_bar": round(len(notes) / bars, 1),
        "midi_range": [midi_min, midi_max],
        "pcs": sorted(pcs),
        "bass_pc": _PC_NAMES[bass_pc],
        "pc_durations": {
            _PC_NAMES[pc]: round(d, 2) for pc, d in sorted(pc_dur.items())
        },
        "scale_degrees_over_tonic": degree_labels,
        "implied_chord": chord_block,
        "note_classification": classification,
    }


def attach_per_track(segments: list[dict], parsed) -> None:
    """Add `per_track[]` to each segment summarising each track's content."""
    if not segments or parsed is None or not parsed.track_meta:
        return
    n_tracks = len(parsed.track_meta)
    for seg in segments:
        per_track: list[dict] = []
        for idx in range(n_tracks):
            entry = _summarize_track_in_segment(parsed, idx, seg)
            if entry is not None:
                per_track.append(entry)
        seg["per_track"] = per_track
