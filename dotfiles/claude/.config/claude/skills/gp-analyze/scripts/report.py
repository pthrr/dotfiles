"""Human-readable markdown report from analysis.json.

The JSON is for tools; report.md is what a musician reads. One section per
structural segment, with per-track harmonic decomposition surfaced as a
table and the chord progression rendered as a compact bar map.
"""

from __future__ import annotations

from typing import Any


def _heading_meta(file_meta: dict, tracks: list[dict], global_block: dict) -> list[str]:
    title = file_meta.get("title") or file_meta.get("path", "(unknown)")
    artist = file_meta.get("artist") or ""
    tempo = file_meta.get("tempo")
    track_names = ", ".join(
        f"{t.get('name','?')} [{t.get('role','?')}]" for t in tracks
    )
    key = global_block.get("key_estimate") or {}
    lines = [
        f"# {title}" + (f" — {artist}" if artist else ""),
        "",
        f"- **Format**: {file_meta.get('format','?')}",
        f"- **Tempo (initial)**: {tempo}",
        f"- **Tracks**: {track_names}",
        (
            f"- **K-S global key estimate (informational)**: "
            f"{key.get('tonic')} {key.get('mode')} "
            f"(confidence {key.get('confidence', 0):.2f})"
        ),
        "",
    ]
    return lines


def _form_block(global_block: dict) -> list[str]:
    form = global_block.get("form") or "(no form detected)"
    lines = ["## Form", "", form, ""]
    return lines


def _format_chord_progression(prog: list[dict]) -> str:
    """Compact one-line progression: `Cm9 (17-20) | F (21-22) | ...`."""
    if not prog:
        return "_(no chord progression extracted)_"
    parts = []
    for p in prog:
        lab = p.get("label") or "?"
        lo, hi = p.get("measures", [None, None])
        if lo == hi:
            parts.append(f"{lab} ({lo})")
        else:
            parts.append(f"{lab} ({lo}-{hi})")
    return " | ".join(parts)


def _format_per_track_table(per_track: list[dict]) -> list[str]:
    if not per_track:
        return ["_(no track-level content)_", ""]
    rows = [
        "| Track | Role | Notes/bar | Range (MIDI) | Outlines | Degrees | Non-chord pcs | CT frac |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for t in per_track:
        ch = t.get("implied_chord") or {}
        label = ch.get("label", "—")
        confidence = ch.get("confidence")
        if confidence is not None:
            label = f"{label} ({confidence:.2f})"
        nct = ", ".join(_pc_name(pc) for pc in t.get("note_classification", {}).get("non_chord_tones_pc", []))
        degrees = ", ".join(t.get("scale_degrees_over_tonic", []))
        midi_lo, midi_hi = t.get("midi_range", [None, None])
        ct_frac = t.get("note_classification", {}).get("chord_tone_fraction")
        ct_str = f"{ct_frac:.2f}" if ct_frac is not None else "—"
        rows.append(
            f"| {t.get('track_name','?')} "
            f"| {t.get('track_role','?')} "
            f"| {t.get('density_notes_per_bar','—')} "
            f"| {midi_lo}–{midi_hi} "
            f"| {label} "
            f"| {degrees} "
            f"| {nct or '—'} "
            f"| {ct_str} |"
        )
    rows.append("")
    return rows


_PC_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]


def _pc_name(pc: int) -> str:
    try:
        return _PC_NAMES[int(pc) % 12]
    except Exception:
        return str(pc)


def _signed(n: int | None) -> str:
    if n is None:
        return "?"
    return f"+{n}" if n > 0 else str(n)


def _format_transitions_in_segment(
    seg: dict, transitions: list[dict]
) -> list[str]:
    """Voice-leading transitions between consecutive implied chords inside seg."""
    lo, hi = seg.get("measures", [None, None])
    if lo is None or hi is None:
        return []
    matched = [
        t
        for t in transitions
        if t.get("from_measures") and t.get("to_measures")
        and lo <= t["from_measures"][0] <= hi
        and lo <= t["to_measures"][0] <= hi
        # Drop trivial self-transitions (same chord repeating bar after bar)
        and not (
            t.get("from_label") == t.get("to_label")
            and t.get("voice_leading_distance", 0) == 0
        )
    ]
    if not matched:
        return []
    lines = ["**Voice leading (consecutive chords)**:", ""]
    for t in matched:
        common = ", ".join(t.get("common_tones") or []) or "none"
        lines.append(
            f"- {t.get('from_label','?')} → {t.get('to_label','?')}: "
            f"root {_signed(t.get('root_motion_semitones'))}, "
            f"bass {_signed(t.get('bass_motion_semitones'))}, "
            f"VL distance {t.get('voice_leading_distance','?')}, "
            f"common tones: {common}"
        )
    lines.append("")
    return lines


def _segment_block(seg: dict, idx: int, transitions: list[dict]) -> list[str]:
    lo, hi = seg.get("measures", [None, None])
    bars = (hi - lo + 1) if (lo is not None and hi is not None) else None
    label = seg.get("label", "?")
    role = seg.get("role", "section")
    reps = seg.get("repetitions", 1)
    riff_bars = seg.get("riff_bars", 1)
    recurs = "recurs" if seg.get("recurs") else "unique"

    mode = seg.get("mode") or {}
    tonality = seg.get("tonality") or "?"
    mode_str = (
        f"{mode.get('tonic','?')} {mode.get('name','?')} "
        f"(conf {mode.get('confidence',0):.2f}, {tonality}"
        + (", ambiguous" if mode.get("ambiguous") else "")
        + ")"
    )

    set_class = seg.get("set_class") or {}
    sc_name = set_class.get("name") or set_class.get("forte_class") or "—"
    chars = ", ".join(seg.get("characteristic_degrees", []))

    cadences = seg.get("cadence_patterns") or []
    cad_str = ", ".join(cadences) if cadences else "—"

    rep_str = f"×{reps}, {riff_bars}-bar riff" if reps > 1 else f"{bars} bars"

    lines = [
        f"### {idx}. **{role.capitalize()} {label}** ({rep_str}, m.{lo}-{hi}, {recurs})",
        "",
        f"- **Mode**: {mode_str}",
        f"- **Set class**: {sc_name}",
        f"- **Characteristic degrees**: {chars or '—'}",
        f"- **Cadences**: {cad_str}",
        "",
        "**Chord progression**:",
        "",
        _format_chord_progression(seg.get("chord_progression") or []),
        "",
        "**Per-track harmonic content**:",
        "",
    ]
    lines.extend(_format_per_track_table(seg.get("per_track") or []))
    lines.extend(_format_transitions_in_segment(seg, transitions))
    return lines


def build_report(analysis: dict) -> str:
    parts: list[str] = []
    parts.extend(
        _heading_meta(
            analysis.get("file", {}),
            analysis.get("tracks", []),
            analysis.get("global", {}),
        )
    )
    parts.extend(_form_block(analysis.get("global", {})))
    parts.append("## Segments")
    parts.append("")
    transitions = analysis.get("harmonic_transitions") or []
    for i, seg in enumerate(analysis.get("segments", []), start=1):
        parts.extend(_segment_block(seg, i, transitions))
    return "\n".join(parts)


def write_report(analysis: dict, out_path: Any) -> None:
    """Write a markdown report to `out_path`."""
    from pathlib import Path

    Path(out_path).write_text(build_report(analysis))
