from __future__ import annotations

import argparse
import math
import sys
import tempfile
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

from drums_to_gp import pipeline


def _log(msg: str) -> None:
    print(msg, file=sys.stderr)


def _positive_finite_float(value: str) -> float:
    try:
        parsed = float(value)
    except ValueError as error:
        raise argparse.ArgumentTypeError("must be a number") from error
    if not math.isfinite(parsed) or parsed <= 0:
        raise argparse.ArgumentTypeError("must be finite and greater than zero")
    return parsed


def _display_url(value: str) -> str:
    """Hide URL credentials and query values in progress logs."""
    try:
        parsed = urlsplit(value)
        host = parsed.hostname or ""
        if ":" in host and not host.startswith("["):
            host = f"[{host}]"
        netloc = f"{host}:{parsed.port}" if parsed.port is not None else host
        return urlunsplit((parsed.scheme, netloc, parsed.path, "", ""))
    except (ValueError, TypeError):
        return "<configured stem splitter>"


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="drums-to-gp",
        description=(
            "Transcribe a drum stem, or source-separate a full mix, into a "
            "Guitar Pro file."
        ),
    )
    p.add_argument(
        "stem", type=Path,
        help="isolated drum stem, or a full mix with --stem-splitter-url",
    )
    p.add_argument(
        "-o", "--out-dir", type=Path, default=Path.cwd(),
        help="output directory (default: cwd)",
    )
    p.add_argument(
        "--bpm", type=float, default=None,
        help="tempo in BPM; auto-detected via librosa if omitted",
    )
    grid = p.add_mutually_exclusive_group()
    grid.add_argument(
        "--subdivision", type=int, choices=pipeline.SUPPORTED_SUBDIVISIONS,
        default=16,
        help="fixed GP quantization grid (default: 16, straight sixteenth notes)",
    )
    grid.add_argument(
        "--adaptive-grid", action="store_true",
        help="infer each measure's grid from detected hits (may select tuplets)",
    )
    p.add_argument(
        "--structure-gp5", type=Path, default=None,
        help="optional GP5 whose time signatures/repeats define the song structure",
    )
    p.add_argument(
        "--midi-only", action="store_true",
        help="stop after MIDI + tempo; skip Guitar Pro export",
    )
    p.add_argument(
        "--stem-splitter-url",
        help=(
            "treat the input as a full mix: upload it to this four-stem service "
            "and transcribe the returned drums stem"
        ),
    )
    p.add_argument(
        "--stem-splitter-timeout",
        type=_positive_finite_float,
        default=3600.0,
        help="maximum seconds to wait for remote source separation (default: 3600)",
    )
    return p.parse_args(argv)


def _run(args: argparse.Namespace, stem: Path, out_dir: Path) -> int:
    try:
        info = pipeline.probe(stem)
    except pipeline.PipelineError as e:
        _log(str(e))
        return 1
    _log(
        f"stem: {info.path.name}  sr={info.sample_rate}Hz  "
        f"ch={info.channels}  dur={info.duration_s:.1f}s"
    )

    bpm = args.bpm
    if bpm is None:
        bpm = pipeline.estimate_tempo(stem)
        _log(f"tempo (estimated): {bpm:.2f} BPM")
    else:
        _log(f"tempo (given): {bpm:.2f} BPM")

    try:
        beat_times = pipeline.estimate_beat_times(stem)
    except pipeline.PipelineError as e:
        _log(str(e))
        return 1
    local_bpms = [
        60 / (later - earlier)
        for earlier, later in zip(beat_times[:-1], beat_times[1:], strict=True)
        if later > earlier
    ]
    _log(
        f"beat grid: {len(beat_times)} pulses, "
        f"first pulse at {beat_times[0]:.6f}s, "
        f"{min(local_bpms):.1f}-{max(local_bpms):.1f} instantaneous BPM"
    )

    try:
        _log(
            "transcription: six-stem drum classification + neural onset priors "
            "(CPU inference can be slow)"
        )
        raw_mid = pipeline.transcribe(stem, out_dir)
    except pipeline.PipelineError as e:
        _log(str(e))
        return 1
    _log(f"wrote MIDI: {raw_mid}")

    tempo_mid = out_dir / f"{stem.stem}.tempo.mid"
    try:
        pipeline.set_tempo(raw_mid, tempo_mid, bpm)
    except pipeline.PipelineError as e:
        _log(str(e))
        return 1
    _log(f"wrote tempo-tagged MIDI: {tempo_mid}")

    if args.midi_only:
        print(tempo_mid)
        return 0

    gp_out = out_dir / f"{stem.stem}.gp5"
    try:
        pipeline.export_gp5(
            tempo_mid,
            gp_out,
            None if args.adaptive_grid else args.subdivision,
            beat_times=beat_times,
            structure_gp5=args.structure_gp5,
        )
    except pipeline.PipelineError as e:
        _log(str(e))
        return 1

    _log(f"wrote Guitar Pro 5: {gp_out}")
    print(gp_out)
    return 0


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)

    source = args.stem.resolve()
    if not source.is_file():
        _log(f"not a file: {source}")
        return 2
    out_dir = args.out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    if not args.stem_splitter_url:
        return _run(args, source, out_dir)

    with tempfile.TemporaryDirectory(prefix="drums-to-gp-source-separate-") as work:
        drums = Path(work) / f"{source.stem}_drums.wav"
        _log(f"source separation: {_display_url(args.stem_splitter_url)}")
        try:
            pipeline.extract_drums_via_splitter(
                source,
                args.stem_splitter_url,
                drums,
                timeout_s=args.stem_splitter_timeout,
            )
        except pipeline.PipelineError as error:
            _log(str(error))
            return 1
        _log(f"received drums stem: {drums.name}")
        return _run(args, drums, out_dir)
