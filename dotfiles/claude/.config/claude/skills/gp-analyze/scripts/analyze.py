#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "PyGuitarPro>=0.9.3",
#   "music21>=9.1",
#   "numpy>=1.26",
#   "matplotlib>=3.8",
# ]
# ///
"""Entry point for the gp-analyze skill.

Parses a Guitar Pro file (.gp3/.gp4/.gp5) and writes analysis.json describing
chord content, modal sections, voice-leading transitions, and structure.
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

from chords import per_beat_chords
from implied_chords import (
    attach_roman_local as attach_harmony_roman_local,
    extract_implied_chords,
    harmonic_transitions,
)
from modes import analyze_segments
from parse import load_score
from per_track_harmony import attach_per_track
from report import write_report
from segment import annotate_segments, find_segments, form_string
from voice_leading import transitions


def main() -> int:
    ap = argparse.ArgumentParser(description="Analyze a Guitar Pro tab.")
    ap.add_argument("file", type=Path)
    ap.add_argument("--out", type=Path, default=None)
    ap.add_argument("--ambiguity-threshold", type=float, default=0.6)
    ap.add_argument(
        "--window-quarters",
        type=float,
        default=None,
        help="Implied-chord window size in quarter notes (default: one measure)",
    )
    ap.add_argument(
        "--riff-lengths",
        type=str,
        default="1,2,4,8",
        help="Comma-separated candidate riff lengths (in bars) for the repeat "
        "detector. Smaller wins on ties. Default '1,2,4,8'.",
    )
    ap.add_argument(
        "--similarity-threshold",
        type=float,
        default=0.75,
        help="Per-bar fingerprint similarity above which two bars are treated "
        "as the same riff identity. Default 0.75.",
    )
    args = ap.parse_args()

    try:
        riff_lengths = tuple(
            int(x.strip()) for x in args.riff_lengths.split(",") if x.strip()
        )
    except ValueError:
        print(
            f"error: --riff-lengths must be comma-separated integers, got "
            f"{args.riff_lengths!r}",
            file=sys.stderr,
        )
        return 2
    if not riff_lengths or any(L < 1 for L in riff_lengths):
        print("error: --riff-lengths must contain at least one positive integer", file=sys.stderr)
        return 2

    if not args.file.exists():
        print(f"error: {args.file} not found", file=sys.stderr)
        return 2

    ext = args.file.suffix.lower()
    if ext not in {".gp3", ".gp4", ".gp5"}:
        print(
            f"error: unsupported format {ext!r}. only .gp3/.gp4/.gp5 are supported.",
            file=sys.stderr,
        )
        return 2

    out = args.out or Path(
        f"/tmp/gp-analyze-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    )
    out.mkdir(parents=True, exist_ok=True)

    parsed = load_score(args.file)

    beats = per_beat_chords(parsed, ambiguity_threshold=args.ambiguity_threshold)
    harmony = extract_implied_chords(
        parsed,
        beats,
        window_quarters=args.window_quarters,
        confidence_threshold=args.ambiguity_threshold,
    )

    # Segment by bar-fingerprint repetition detection, then analyse modes
    # per segment with no global-key prior.
    raw_segments = find_segments(
        beats,
        harmony,
        parsed,
        riff_lengths=riff_lengths,
        similarity_threshold=args.similarity_threshold,
    )
    segments = analyze_segments(
        raw_segments, beats, harmony, ambiguity_threshold=args.ambiguity_threshold
    )
    annotate_segments(segments, parsed)
    attach_per_track(segments, parsed)
    form = form_string(segments)

    attach_harmony_roman_local(harmony, segments)
    _attach_roman_local(beats, segments, parsed)
    h_trans = harmonic_transitions(harmony)
    trans = transitions(beats)

    analysis = {
        "file": parsed.file_meta,
        "tracks": parsed.track_meta,
        "global": {
            "key_estimate": parsed.global_key,
            "form": form,
            "note": (
                "Global key is an informational K-S estimate. Mode/key per "
                "segment is analysed independently — many pieces have no "
                "single tonic and the per-segment fields are authoritative. "
                "`form` is a one-line scannable summary derived from segments[]."
            ),
        },
        "segments": segments,
        "harmony": harmony,
        "harmonic_transitions": h_trans,
        "beats": beats,
        "transitions": trans,
    }

    json_path = out / "analysis.json"
    json_path.write_text(json.dumps(analysis, indent=2))
    report_path = out / "report.md"
    write_report(analysis, report_path)
    print(str(json_path))
    print(str(report_path))
    return 0


def _attach_roman_local(beats, sections, parsed) -> None:
    """Set beat['chord']['roman_local'] using the section's tonic as local key."""
    from chords import _short_quality
    from roman_numeral import roman_from_names

    if not sections:
        return

    def section_for(measure):
        for s in sections:
            lo, hi = s["measures"]
            if lo <= measure <= hi:
                return s
        return None

    for b in beats:
        ch = b.get("chord")
        if not ch or ch.get("ambiguous"):
            continue
        m = b.get("measure")
        if m is None:
            continue
        sec = section_for(m)
        if not sec:
            continue
        ch["roman_local"] = roman_from_names(
            ch.get("root"), _short_quality(ch.get("quality", "")), sec["mode"]["tonic"]
        )


if __name__ == "__main__":
    raise SystemExit(main())
