"""Ad-hoc plotting helpers used by the agent when the user requests a chart.

These are NOT called by analyze.py. They live here so the agent can write a
short matplotlib script that imports from this module and renders against the
data in analysis.json.

Run such a script via:

    uv run --with matplotlib --with music21 --with numpy plot_my_thing.py

Or call the helpers from inside a PEP 723 script with the same inline deps.
"""

from __future__ import annotations

import math

import matplotlib.pyplot as plt

_PC_NAMES = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
# Going clockwise from C: C G D A E B F# Db Ab Eb Bb F
_FIFTHS_ORDER = [0, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10, 5]


def _angle(pc: int, fifths: bool) -> float:
    idx = _FIFTHS_ORDER.index(pc) if fifths else pc
    return math.pi / 2 - 2 * math.pi * idx / 12


def _xy(pc: int, fifths: bool, r: float = 1.0) -> tuple[float, float]:
    a = _angle(pc, fifths)
    return r * math.cos(a), r * math.sin(a)


def _draw_ring(ax, fifths: bool) -> None:
    ax.set_aspect("equal")
    ax.axis("off")
    for pc in range(12):
        x, y = _xy(pc, fifths, r=1.18)
        ax.text(x, y, _PC_NAMES[pc], ha="center", va="center", fontsize=10)
    th = [i * 2 * math.pi / 200 for i in range(201)]
    ax.plot(
        [math.cos(t) for t in th],
        [math.sin(t) for t in th],
        color="lightgray",
        lw=0.5,
    )


def circle_of_fifths(chord_roots, transitions, ax=None):
    """Plot chord roots on the fifths circle with transition arrows.

    `chord_roots`: list of pitch name strings (e.g. ["E", "G", "D"]) or None.
    `transitions`: list of dicts with `voice_leading_distance` and
      `common_tones` (per beats[]/transitions[] in analysis.json).
    """
    from music21 import pitch as m21pitch

    if ax is None:
        _, ax = plt.subplots(figsize=(6, 6))
    _draw_ring(ax, fifths=True)

    pts: list[tuple[float, float] | None] = []
    for r in chord_roots:
        if not r:
            pts.append(None)
            continue
        try:
            pc = m21pitch.Pitch(r).pitchClass
        except Exception:
            pts.append(None)
            continue
        pts.append(_xy(pc, fifths=True))

    for i, t in enumerate(transitions):
        if i + 1 >= len(pts):
            break
        p, q = pts[i], pts[i + 1]
        if not p or not q:
            continue
        d = t.get("voice_leading_distance", 1) or 1
        lw = max(0.6, 3.0 / (d + 1))
        ct = len(t.get("common_tones", []))
        color = "tab:green" if ct >= 2 else ("tab:orange" if ct == 1 else "tab:red")
        ax.annotate(
            "",
            xy=q,
            xytext=p,
            arrowprops=dict(arrowstyle="->", lw=lw, color=color, alpha=0.7),
        )

    for p in pts:
        if p:
            ax.plot(*p, "o", color="black", markersize=8, zorder=3)
    return ax


def chromatic_circle(pc_histogram, mode_template=None, ax=None):
    """Plot a pc histogram on the chromatic circle, with optional mode overlay.

    `pc_histogram`: dict mapping pc-as-str ("0".."11") to float weight.
    `mode_template`: list of pitch classes (tonic-relative or absolute, same
      coordinate system as the histogram). If provided, draws an outline.
    """
    if ax is None:
        _, ax = plt.subplots(figsize=(6, 6))
    _draw_ring(ax, fifths=False)

    vals = [float(pc_histogram.get(str(i), 0.0)) for i in range(12)]
    vmax = max(vals) or 1.0
    for pc, v in enumerate(vals):
        if v == 0:
            continue
        x, y = _xy(pc, fifths=False, r=0.4 + 0.55 * (v / vmax))
        ax.plot(
            x,
            y,
            "o",
            color="steelblue",
            markersize=8 + 12 * (v / vmax),
            alpha=0.7,
        )

    if mode_template:
        xs, ys = [], []
        for pc in mode_template:
            x, y = _xy(pc % 12, fifths=False, r=0.97)
            xs.append(x)
            ys.append(y)
        xs.append(xs[0])
        ys.append(ys[0])
        ax.plot(xs, ys, color="orange", lw=1.5, alpha=0.7)
    return ax
