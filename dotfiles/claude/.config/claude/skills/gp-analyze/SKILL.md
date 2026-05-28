---
name: gp-analyze
description: Analyze Guitar Pro tabs (.gp3/.gp4/.gp5) for harmonic content — per-segment Roman-numeral chord labels, modal analysis (all modes), per-track per-segment harmonic decomposition (bass vs rhythm vs lead can outline different harmony over the same segment), voice-leading metrics, and musician-oriented structural segmentation (bar-fingerprint repetition detection — finds riffs, not novelty peaks). Use when the user references a `.gp3`, `.gp4`, or `.gp5` file or asks to analyze a Guitar Pro tab.
---

# Guitar Pro Tab Analyzer

Parses Guitar Pro files and emits two outputs:

- `analysis.json` — full structured data for tooling
- `report.md` — human-readable markdown report (form, per-segment per-track harmony, voice leading)

Visualisation primitives ship via `plot_voice_leading.py` and `viz_helpers.py` — read the JSON and write ad-hoc matplotlib snippets for custom plots.

## Invocation

```
uv run ~/.claude/skills/gp-analyze/scripts/analyze.py <file.gp*> \
    [--out <dir>] [--ambiguity-threshold 0.6] \
    [--window-quarters N] \
    [--riff-lengths 1,2,4,8] [--similarity-threshold 0.75]
```

Default `--out`: `/tmp/gp-analyze-<timestamp>/`. Writes `analysis.json` and `report.md` there and prints both paths.

**Tuning the segmenter.**
- `--riff-lengths` — candidate periods (in bars) for the repeat detector. Smaller wins on ties. Default `1,2,4,8`.
- `--similarity-threshold` — bar fingerprints cluster when similarity ≥ this. Lower (e.g. `0.65`) → coarser sections that tolerate more bar-to-bar variation; higher (`0.85`) → stricter, more fragmentary sections. Default `0.75`.

## Supported formats

`.gp3`, `.gp4`, `.gp5` only. `.gp` (GP6+) and `.gpx` are not supported in v1 — the script exits with a clear error.

## Outputs

### `report.md` — start here

Human-readable per-segment narrative. For each segment shows:
- header (role / label / repetitions / bar range / `recurs` flag)
- mode + tonality classification + characteristic degrees + cadences
- chord progression (compact one-line render)
- **per-track harmonic table**: for each track, notes/bar, MIDI range, the implied chord that track outlines on its own, scale degrees relative to the segment tonic, non-chord pcs, chord-tone fraction
- **voice leading**: each non-trivial consecutive-chord transition with root/bass motion, VL distance, common tones

The per-track table is the key feature: it shows that bass / rhythm / lead can outline *different* harmony over the same segment (e.g. bass pedals C while rhythm plays Cm9 and lead arpeggiates Cmaj9 with chromatic passing). Read each track's row independently.

### `analysis.json` — full data

**Many pieces have no single global key** — the analysis is driven by structural segmentation, and mode/key is determined *per segment*. Read `segments[]` first.

**Top level**
- `file` — title / artist / format / initial tempo
- `tracks` — name / role (`bass`, `guitar_main`, `guitar_lead`) / tuning
- `global.key_estimate` — K-S global estimate, **informational only**
- `global.form` — one-line scannable form summary derived from `segments[]`

**`segments[]`** — produced by bar-fingerprint repetition detection (see below). Each entry:
- `measures: [lo, hi]` — bar range
- `label` — riff identity (`A`, `B`, `C` … — same label means same riff content)
- `role` — `intro` / `outro` / `main` (most-common recurring riff) / `section` (everything else)
- `riff_bars` — periodicity of the repeat unit (e.g. `4` = 4-bar riff)
- `repetitions` — how many times the unit cycles in this section
- `recurs` — true if this label appears in more than one section
- `chord_progression: [{label, measures}]` — chord sequence inside the segment
- `tonality` — `tonal` / `fragmentary` / `symmetric` / `non_tonal`. **Use this to decide how to trust the mode label.**
- `mode: {tonic, name, confidence, ambiguous}` — locally-detected best-fit mode
- `set_class` — Forte class + colloquial name where known
- `pc_histogram`, `characteristic_degrees`, `cadence_patterns`
- `track_divergence: {main_track_notes, divergence_ratio, main_pair_indices}` — note-count ratio between the two main guitar tracks
- **`per_track[]`** — one record per track that played in this segment:
  - `track_name`, `track_role`, `note_count`, `density_notes_per_bar`, `midi_range`
  - `pcs`, `bass_pc`, `pc_durations`
  - `scale_degrees_over_tonic` — pcs labeled relative to the segment's tonic
  - `implied_chord` — best-fit chord this track *alone* outlines (label, root, quality, chord_tones_pc, non_chord_tones_pc, missing_template_tones_pc, confidence)
  - `note_classification` — chord-tone count / non-chord-tone count / fraction / non-chord-tone pcs

**`harmony[]`** — per-window implied chord across all tracks combined. Same fields as before: `label`, `root`, `quality`, `chord_tones_pc`, `non_chord_tones_pc`, `missing_template_tones_pc`, `is_slash`, `slash_bass`, `roman_global`, `roman_local`. Default window is one bar; override with `--window-quarters`.

**`harmonic_transitions[]`** — voice-leading metrics between consecutive non-ambiguous implied chords: `from_label`, `to_label`, `root_motion_semitones`, `bass_motion_semitones`, `voice_leading_distance`, `common_tones`.

**Secondary layers.** `beats[]` (per-beat chordify output), `transitions[]` (per-beat voice leading).

## How segmentation works

Three stages:

1. **Per-bar fingerprints.** Each bar gets a feature vector: pc-set (weight 0.55), active-tracks set (0.20), onset-count similarity (0.15), note-density similarity (0.10). Bass pc isn't weighted directly — it's already in the pc set, and inversions shouldn't break clustering.

2. **Sequence smoothing.** Short interruptions (1–2 bars) inside an otherwise uniform run get absorbed when the surroundings are at least 2× as long. Catches single-bar variations / fills.

3. **Repetition detection.** Greedy left-to-right scan: at each position, find the L (in `--riff-lengths`) that produces the longest repeated run (≥2 repetitions). Adjacent sections with the same riff unit get merged. Runs of unique 1-bar sections (intros / bridges / outros) get coalesced into a single heterogeneous block.

This matches how a musician learns a song — "Intro (8 bars) | Riff A ×4 | Bridge | Riff A ×4 | Outro" — rather than pitch-content novelty regions.

## Mode coverage

Modes of major, harmonic minor, melodic minor, harmonic major, double harmonic; whole tone, augmented, diminished W-H and H-W; pentatonics (major, minor, blues, Hirajoshi, Insen, Iwato, In, Yo); bebop dominant/major/minor.

## How to use the data

- **Form first**: read `global.form` and `segments[]` for the structural skeleton.
- **Per-track divergence** is the headline feature — for each segment, check `per_track[]` to see whether bass / rhythm / lead outline the same harmony or different ones. Different outlines = modal mixture, polychord, or pedal-vs-arpeggio writing.
- **Single-track arpeggio**: `per_track[i].implied_chord.label` is the chord that track alone outlines. `non_chord_tones_pc` are colour / passing tones in that track.
- **Voice leading within a section**: `report.md` lists non-trivial consecutive chord transitions per segment. For raw data filter `harmonic_transitions[]` to the segment's measure range.
- **Voice-leading distance**: small + many `common_tones` → smooth. Big + zero common tones → disjunct / chromatic mediant.
- **Modal flavour**: `segments[].characteristic_degrees` shows which scale degrees give the segment its sound.
- **Ambiguity**: trust `mode.name` only when `tonality == "tonal"` and `mode.ambiguous == false`. Otherwise rely on `set_class` and the per-track outlines.
- **Roman numerals**: prefer `chord.roman_local` (relative to the segment's tonic). `roman_global` assumes the K-S global estimate, which is often wrong for modal/modulating pieces.

## Ad-hoc visualization

Two ways to plot:

**Ready-made: voice leading per segment** —
```
uv run ~/.claude/skills/gp-analyze/scripts/plot_voice_leading.py <analysis.json> \
    [--out PNG] [--segments A,D,E]
```
Emits one circle-of-fifths panel per unique structural segment, with a legend listing numbered chords and the unique transitions (root motion, VL distance, common tones). Default output is `voice_leading.png` next to the input. `--segments` filters to specific labels.

**Custom plots**: write a short matplotlib script that imports primitives from `scripts/viz_helpers.py`:

- `circle_of_fifths(chord_roots, transitions, ax=None)` — chords as points on the fifths circle, edges weighted by inverse VL distance
- `chromatic_circle(pc_histogram, mode_template=None, ax=None)` — pc wheel with optional mode-template overlay

Run via `uv run`. Custom scripts must accept the analysis path as a CLI argument — **never hardcode** the JSON path. The PEP 723 deps line is `matplotlib`, `music21`, `numpy` (PyGuitarPro is not needed for plotting).
