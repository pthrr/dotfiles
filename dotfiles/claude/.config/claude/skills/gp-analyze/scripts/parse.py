"""Parse a .gp3/.gp4/.gp5 file into a ParsedScore.

Output combines a music21 Score (for chordify + key analysis) with per-measure
metadata extracted directly from PyGuitarPro (for repeat barlines, markers,
time signatures).
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import guitarpro
from music21 import chord as m21chord
from music21 import meter as m21meter
from music21 import note as m21note
from music21 import stream


@dataclass
class ParsedScore:
    score: stream.Score
    file_meta: dict
    track_meta: list[dict]
    global_key: dict
    measures: list[dict]  # per-measure metadata, indexed from first track
    # Per-track per-bar note stats: track_bars[track_meta_index][bar_number] =
    # {note_count, min_midi, max_midi}. Empty bars are absent.
    track_bars: dict[int, dict[int, dict]] = None


def _decode_text(s: str | None) -> str | None:
    """PyGuitarPro decodes GP3/4/5 text as latin1. When the source was actually
    cp1251 (Cyrillic / Eastern European), we get mojibake. Detect and re-decode.
    """
    if not s:
        return s
    if not any(0xC0 <= ord(c) <= 0xFF for c in s):
        return s
    try:
        recoded = s.encode("latin1", errors="strict").decode("cp1251", errors="strict")
    except Exception:
        return s
    if all(c.isprintable() or c.isspace() for c in recoded):
        return recoded
    return s


def _beat_duration_quarters(b) -> float:
    """Compute the quarter-length of a Beat from its Duration."""
    # Duration.value: 1=whole, 2=half, 4=quarter, 8=eighth, 16=sixteenth, ...
    base = 4.0 / b.duration.value
    if b.duration.isDotted:
        base *= 1.5
    if b.duration.tuplet.enters > 1 and b.duration.tuplet.times > 0:
        base *= b.duration.tuplet.times / b.duration.tuplet.enters
    return base


def _beat_pitches(b, track) -> list[int]:
    """MIDI pitches for all sounding notes on a Beat (skipping dead notes)."""
    out = []
    for n in b.notes:
        if n.type == guitarpro.NoteType.dead:
            continue
        # n.string is 1-indexed
        if n.string < 1 or n.string > len(track.strings):
            continue
        open_pitch = track.strings[n.string - 1].value
        out.append(open_pitch + n.value)
    return out


def load_score(path: Path) -> ParsedScore:
    song = guitarpro.parse(str(path))

    pitched_tracks = [
        (i, t) for i, t in enumerate(song.tracks) if not t.isPercussionTrack
    ]

    score = stream.Score()
    track_meta: list[dict] = []
    measures_meta: list[dict] = []
    track_bars: dict[int, dict[int, dict]] = {}

    for tidx, (orig_idx, t) in enumerate(pitched_tracks):
        part = stream.Part()
        track_bars[tidx] = {}
        for mi, m in enumerate(t.measures):
            bar_pitches: list[int] = []
            ts = m.header.timeSignature
            ts_num = ts.numerator
            ts_den = ts.denominator.value
            m_obj = stream.Measure(number=mi + 1)
            if mi == 0:
                m_obj.timeSignature = m21meter.TimeSignature(f"{ts_num}/{ts_den}")

            voice = m.voices[0] if m.voices else None
            beat_offset = 0.0
            if voice is not None:
                for b in voice.beats:
                    dur_q = _beat_duration_quarters(b)
                    pitches = _beat_pitches(b, t)
                    elem: Any
                    if not pitches:
                        elem = m21note.Rest(quarterLength=dur_q)
                    elif len(pitches) == 1:
                        elem = m21note.Note(midi=pitches[0], quarterLength=dur_q)
                    else:
                        elem = m21chord.Chord(pitches, quarterLength=dur_q)
                    m_obj.insert(beat_offset, elem)
                    beat_offset += dur_q
                    bar_pitches.extend(pitches)

            if bar_pitches:
                track_bars[tidx][mi + 1] = {
                    "note_count": len(bar_pitches),
                    "min_midi": min(bar_pitches),
                    "max_midi": max(bar_pitches),
                }

            if tidx == 0:
                marker = m.header.marker
                measures_meta.append(
                    {
                        "index": mi + 1,
                        "time_signature": f"{ts_num}/{ts_den}",
                        "repeat_open": bool(m.header.isRepeatOpen),
                        "repeat_close": (m.header.repeatClose or 0) > 0,
                        "marker": _decode_text(marker.title) if marker else None,
                    }
                )

            part.append(m_obj)

        track_meta.append(
            {
                "index": orig_idx,
                "name": _decode_text(t.name),
                "tuning": [s.value for s in t.strings],
                "is_drums": False,
            }
        )
        score.insert(0, part)

    try:
        k = score.analyze("key.krumhanslschmuckler")
        global_key = {
            "tonic": k.tonic.name,
            "mode": k.mode,
            "confidence": float(k.correlationCoefficient),
        }
    except Exception:
        global_key = {"tonic": None, "mode": None, "confidence": 0.0}

    file_meta = {
        "path": str(path),
        "format": path.suffix.lstrip(".").lower(),
        "title": _decode_text(song.title) or None,
        "artist": _decode_text(song.artist) or None,
        "tempo": song.tempo,
    }

    # Tag track roles using tuning + total note count heuristics.
    _tag_track_roles(track_meta, track_bars)

    return ParsedScore(
        score=score,
        file_meta=file_meta,
        track_meta=track_meta,
        global_key=global_key,
        measures=measures_meta,
        track_bars=track_bars,
    )


def _tag_track_roles(track_meta: list[dict], track_bars: dict[int, dict[int, dict]]) -> None:
    """Add a `role` field to each track: 'bass', 'guitar_main', 'guitar_lead', or 'other'.

    Bass: 4 strings AND lowest open string < MIDI 30.
    Main guitars: the top two by total note count among non-bass tracks.
    Other guitars: lead / aux.
    """
    note_totals = {
        idx: sum(b.get("note_count", 0) for b in bars.values())
        for idx, bars in track_bars.items()
    }
    bass_indices = set()
    for i, t in enumerate(track_meta):
        tuning = t["tuning"]
        if len(tuning) == 4 and min(tuning) < 30:
            t["role"] = "bass"
            bass_indices.add(i)

    # Rank non-bass by total notes.
    non_bass = [i for i in range(len(track_meta)) if i not in bass_indices]
    non_bass.sort(key=lambda i: note_totals.get(i, 0), reverse=True)
    main_pair = set(non_bass[:2])

    for i, t in enumerate(track_meta):
        if "role" in t:
            continue
        if i in main_pair:
            t["role"] = "guitar_main"
        else:
            t["role"] = "guitar_lead"
