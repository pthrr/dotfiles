#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "matplotlib>=3.8",
#   "music21>=9.1",
#   "numpy>=1.26",
# ]
# ///
"""Voice-leading circle-of-fifths plot per segment.

Usage:
    uv run plot_voice_leading.py <analysis.json> [--out PNG] [--segments A,B,...]

Each panel:
  - Outer ring: pitch-class names.
  - Numbered dots: chord roots in order of first appearance within the segment.
  - Arrows: unique chord transitions.
        Colour: green ≥2 common tones, orange = 1, red = 0.
        Thickness ∝ 1 / voice-leading distance.
  - Right column: chord legend + unique transitions with VL metrics.
"""

from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path

import matplotlib

# Default to non-interactive Agg so the script works under uv run without
# needing tkinter. Override with MPLBACKEND=... if you want an interactive
# window.
matplotlib.use(os.environ.get("MPLBACKEND", "Agg"))

import matplotlib.gridspec as gridspec  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import FancyArrowPatch  # noqa: E402
from music21 import pitch as m21pitch  # noqa: E402

_PC_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
_FIFTHS_ORDER = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5]


def _angle(pc: int) -> float:
    return math.pi / 2 - 2 * math.pi * _FIFTHS_ORDER.index(pc) / 12


def _xy(pc: int, r: float = 1.0) -> tuple[float, float]:
    a = _angle(pc)
    return r * math.cos(a), r * math.sin(a)


def _colour_for_common(n: int) -> str:
    return "#2ca02c" if n >= 2 else ("#ff7f0e" if n == 1 else "#d62728")


def _lw_for_vl(d: int) -> float:
    return max(0.9, 3.6 / (d + 1))


def _draw_ring(ax) -> None:
    ax.set_aspect("equal")
    ax.set_xlim(-1.45, 1.45)
    ax.set_ylim(-1.45, 1.45)
    ax.axis("off")
    for pc in range(12):
        x, y = _xy(pc, r=1.22)
        ax.text(x, y, _PC_NAMES[pc], ha="center", va="center",
                fontsize=9, color="dimgray")
    th = [i * 2 * math.pi / 200 for i in range(201)]
    ax.plot([math.cos(t) for t in th], [math.sin(t) for t in th],
            color="lightgray", lw=0.6)


def _segment_data(seg: dict, harmony: list[dict], transitions: list[dict]):
    """Return (unique_chords_in_order, unique_transitions_in_order)."""
    lo, hi = seg["measures"]
    seg_harm = [h for h in harmony if lo <= h["measures"][0] <= hi and h.get("chord")]

    order_idx: dict[str, int] = {}
    unique_chords: list[dict] = []
    for h in seg_harm:
        lab = h["chord"]["label"]
        if lab not in order_idx:
            order_idx[lab] = len(unique_chords)
            unique_chords.append({"label": lab, "root": h["chord"]["root"]})

    seq_labels: list[str] = []
    for h in seg_harm:
        lab = h["chord"]["label"]
        if not seq_labels or seq_labels[-1] != lab:
            seq_labels.append(lab)

    seen_pairs: set[tuple[str, str]] = set()
    pairs: list[dict] = []
    for i in range(len(seq_labels) - 1):
        key = (seq_labels[i], seq_labels[i + 1])
        if key in seen_pairs:
            continue
        seen_pairs.add(key)
        rec = None
        for t in transitions:
            if (
                t.get("from_label") == key[0]
                and t.get("to_label") == key[1]
                and lo <= t["from_measures"][0] <= hi
                and lo <= t["to_measures"][0] <= hi
            ):
                rec = t
                break
        if rec:
            pairs.append({
                "from_idx": order_idx[key[0]],
                "to_idx": order_idx[key[1]],
                "from_label": key[0],
                "to_label": key[1],
                "root_motion": rec.get("root_motion_semitones"),
                "vl": rec.get("voice_leading_distance", 0),
                "ct": len(rec.get("common_tones", [])),
                "common_tones": rec.get("common_tones", []),
            })
    return unique_chords, pairs


_MAX_ARROWS_DRAWN = 15


def _draw_circle(ax, unique_chords, pairs):
    chord_pcs: list[int | None] = []
    for c in unique_chords:
        try:
            chord_pcs.append(m21pitch.Pitch(c["root"]).pitchClass)
        except Exception:
            chord_pcs.append(None)

    counts: dict[int | None, int] = {}
    for pc in chord_pcs:
        counts[pc] = counts.get(pc, 0) + 1
    seen: dict[int | None, int] = {}
    radii: list[float] = []
    for pc in chord_pcs:
        n = counts.get(pc, 1)
        s = seen.get(pc, 0)
        if n == 1:
            radii.append(1.0)
        else:
            spread = 0.13
            start = 1.0 - spread * (n - 1) / 2
            radii.append(start + s * spread)
        seen[pc] = s + 1

    _draw_ring(ax)

    for p in pairs:
        a, b = chord_pcs[p["from_idx"]], chord_pcs[p["to_idx"]]
        if a is None or b is None or a == b:
            continue
        p1 = _xy(a, radii[p["from_idx"]])
        p2 = _xy(b, radii[p["to_idx"]])
        ax.add_patch(FancyArrowPatch(
            p1, p2,
            arrowstyle="-|>",
            mutation_scale=14,
            lw=_lw_for_vl(p["vl"]),
            color=_colour_for_common(p["ct"]),
            alpha=0.85,
            shrinkA=9, shrinkB=9,
            zorder=2,
        ))

    for i, (pc, r) in enumerate(zip(chord_pcs, radii)):
        if pc is None:
            continue
        x, y = _xy(pc, r)
        ax.plot(x, y, "o", color="black", markersize=20, zorder=3)
        ax.text(x, y, str(i + 1), ha="center", va="center",
                color="white", fontsize=10, fontweight="bold", zorder=4)


_MAX_CHORDS_SHOWN = 12
_MAX_TRANS_SHOWN = 10


def _draw_legend(ax, seg, unique_chords, pairs):
    ax.axis("off")
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)

    lo, hi = seg["measures"]
    mode = seg["mode"]
    sc = seg.get("set_class") or {}
    td = seg.get("track_divergence") or {}
    header = (
        f'Segment {seg["label"]} · m{lo}-{hi}  ({hi - lo + 1} bars)\n'
        f'{mode["tonic"]} {mode["name"]}  ·  tonality: {seg["tonality"]}'
        f'  ·  div: {td.get("divergence_ratio", 1.0):.2f}\n'
        f'set: {sc.get("forte_class","?")}  card={sc.get("cardinality","?")}  '
        f'prime={sc.get("prime_form","?")}'
    )

    chord_lines = [f"  {i+1}. {c['label']}" for i, c in enumerate(unique_chords[:_MAX_CHORDS_SHOWN])]
    overflow = len(unique_chords) - _MAX_CHORDS_SHOWN
    if overflow > 0:
        chord_lines.append(f"  … and {overflow} more")
    chord_block = "chords (order of first appearance):\n" + "\n".join(chord_lines)

    if pairs:
        # Rank shown transitions by interestingness: prefer non-trivial root
        # motion and low common-tone count (the harmonically active moves).
        ranked = sorted(
            pairs,
            key=lambda p: (
                abs(p.get("root_motion") or 0) == 0,  # stable roots last
                p.get("ct", 0),  # fewer common tones first
                -(p.get("vl") or 0),  # higher VL first
            ),
        )
        shown = ranked[:_MAX_TRANS_SHOWN]
        rows = []
        for p in shown:
            ct = ",".join(p["common_tones"]) if p["common_tones"] else "—"
            rm = p["root_motion"] if p["root_motion"] is not None else 0
            rows.append(
                f"  {p['from_idx']+1}→{p['to_idx']+1}  root{rm:+d}  VL={p['vl']}  ct={p['ct']} ({ct})"
            )
        more = len(pairs) - _MAX_TRANS_SHOWN
        if more > 0:
            rows.append(f"  … and {more} more")
        trans_block = "transitions (most active first):\n" + "\n".join(rows)
    else:
        trans_block = "no inter-chord motion (single-chord segment)"

    ax.text(0.0, 1.0, header, ha="left", va="top",
            fontsize=10, fontweight="bold")
    ax.text(0.0, 0.78, chord_block, ha="left", va="top",
            fontsize=9, family="monospace")
    ax.text(
        0.0, 0.78 - 0.045 * (len(chord_lines) + 1),
        trans_block, ha="left", va="top",
        fontsize=8.5, family="monospace",
    )


def _representatives(segments: list[dict], filter_labels: set[str] | None) -> list[dict]:
    """Pick one segment per unique structural label (first occurrence)."""
    seen, reps = set(), []
    for s in segments:
        if s["label"] in seen:
            continue
        if filter_labels is not None and s["label"] not in filter_labels:
            continue
        seen.add(s["label"])
        reps.append(s)
    reps = [s for s in reps if any(p.get("label") for p in s.get("chord_progression", []))]
    return reps


def plot(analysis: dict, output: Path, filter_labels: set[str] | None = None) -> Path:
    segments = analysis["segments"]
    H = analysis["harmony"]
    T = analysis["harmonic_transitions"]
    reps = _representatives(segments, filter_labels)
    if not reps:
        raise SystemExit("no segments to plot (after filtering)")

    nrows = len(reps)
    fig = plt.figure(figsize=(13, 4.6 * nrows))
    gs = gridspec.GridSpec(
        nrows, 2,
        figure=fig,
        width_ratios=[1.0, 1.1],
        hspace=0.35, wspace=0.08,
        left=0.04, right=0.98, top=0.96, bottom=0.02,
    )

    for i, seg in enumerate(reps):
        ax_c = fig.add_subplot(gs[i, 0])
        ax_l = fig.add_subplot(gs[i, 1])
        uc, pairs = _segment_data(seg, H, T)
        _draw_circle(ax_c, uc, pairs)
        _draw_legend(ax_l, seg, uc, pairs)

    title = analysis.get("file", {}).get("path") or "analysis"
    fig.suptitle(
        f"Voice leading per segment (circle of fifths) — {Path(title).name}\n"
        "arrow colour: green ≥2 common tones · orange 1 · red 0   |   "
        "thickness ∝ 1 / voice-leading distance   |   numbers = order of first appearance",
        fontsize=12, y=0.995,
    )
    fig.savefig(output, dpi=140, bbox_inches="tight", facecolor="white")
    return output


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input", type=Path, help="path to analysis.json")
    ap.add_argument(
        "--out", type=Path, default=None,
        help="output image path (default: alongside input, named voice_leading.png)",
    )
    ap.add_argument(
        "--segments", type=str, default=None,
        help="comma-separated structural labels to include (e.g. 'A,D,E'). default: all.",
    )
    args = ap.parse_args()

    if not args.input.exists():
        raise SystemExit(f"not found: {args.input}")

    analysis = json.loads(args.input.read_text())
    out = args.out or (args.input.parent / "voice_leading.png")
    filter_labels = set(args.segments.split(",")) if args.segments else None
    written = plot(analysis, out, filter_labels)
    print(str(written))


if __name__ == "__main__":
    main()
