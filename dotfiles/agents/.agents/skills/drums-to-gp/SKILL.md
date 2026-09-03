---
name: drums-to-gp
description: Transcribe an isolated drum stem (WAV/FLAC/MP3) into tempo-tagged GM drum MIDI and a Guitar Pro 5 percussion score. Use when the user asks for drum MIDI, a Guitar Pro drum tab, or a .gp5 file. For a full mix, use a compatible four-stem splitter service first via --stem-splitter-url.
---

# Drums Stem -> MIDI + Guitar Pro 5

This skill is a Python package under this directory. Its CLI probes a drum stem,
estimates or accepts tempo, separates the kit into six instrument stems, combines
that classification with ADTOF onset priors, tags the MIDI tempo, then writes a
quantized Guitar Pro 5 percussion score.

```bash
uv run --project ~/.agents/skills/drums-to-gp drums-to-gp \
  "$STEM" -o "$OUT_DIR"
```

For an isolated input, the default outputs are `<stem>.mid`,
`<stem>.tempo.mid`, and `<stem>.gp5`. A full-mix input produces
`<mix>_drums.mid`, `<mix>_drums.tempo.mid`, and `<mix>_drums.gp5`.
For a full mix, the skill can call the local Stem Splitter API and feed its
returned drums stem into the same transcription pipeline:

```bash
SPLITTER_URL=http://192.168.178.58:18080/
uv run --project ~/.agents/skills/drums-to-gp drums-to-gp \
  "$MIX" --stem-splitter-url "$SPLITTER_URL" -o "$OUT_DIR"
```

Optional flags:
- `--bpm 128` skips aggregate tempo detection for the tempo-tagged MIDI.
- `--midi-only` stops after the tempo-tagged MIDI.
- `--stem-splitter-url URL` treats the input as a full mix, uploads it to a
  compatible `POST /api/split` service, polls its job endpoint, and downloads
  `/stems/drums`. `--stem-splitter-timeout` is a finite end-to-end deadline,
  including upload and download.
- By default, GP export follows the audio's changing pulse on a straight
  sixteenth-note grid. A measure upgrades to straight 32nds or 64ths only when
  needed to preserve existing fine positions or keep distinct detected hits
  from collapsing. This does not add tuplets.
- `--adaptive-grid` opts into selecting a grid independently for each measure;
  use it only when the source is known to contain tuplets.
- `--subdivision 16` explicitly selects the default GP5 grid. Use `12` for eighth-note
  triplets, `24` for sixteenth-note triplets, `32` for dense straight detail,
  or `64` for the finest supported straight grid.
- `--structure-gp5 reference.gp5` uses the reference score's time signatures
  and unrolled repeats while deriving the actual tempo curve from the audio.
- Beat-synced export preserves detected drum classes. It does not apply
  genre-specific rules that add, delete, or relocate snare hits.

## Input requirement

The classifier itself requires a drums-only stem. For a full mix, pass a
compatible four-stem service with `--stem-splitter-url`; without that option,
stop and ask for source separation instead of silently classifying the mix.
Do not send an already isolated drum stem through the four-stem service again.

### Stem Splitter compatibility contract

- `POST /api/split` accepts multipart field `file` and returns a string
  `job_id`. The client streams the upload from disk instead of buffering the
  full mix in memory.
- `GET /api/jobs/{job_id}` returns `queued`, `running`, `done`, `error`, or
  `cancelled` in `status`. A completed job must include a string list `stems`
  containing `drums`; `duration_seconds` is optional but validated when present.
- `GET /api/jobs/{job_id}/stems/drums` returns readable, non-empty audio. The
  client streams it to a temporary sibling, checks its duration against the job
  when available, then atomically installs it.
- Poll transport errors are retried three times. HTTP, JSON, protocol, audio,
  and total-timeout failures become concise pipeline errors rather than raw
  tracebacks. URLs with query strings or fragments are rejected so credentials
  cannot be misplaced by endpoint composition; logs redact URL user info.

## Environments and prerequisites

- `uv` is required. Do not install it silently.
- ADTOF and its legacy TensorFlow/Keras stack are pinned in `adtof-env/uv.lock`
  and run in an isolated Python 3.10 environment.
- DrumSep and CPU-only PyTorch are pinned separately in
  `drumsep-env/uv.lock`; this avoids downloading unused CUDA libraries. The
  first run downloads a checksum-verified 418 MB DrumSep checkpoint, and CPU
  separation can take several times the audio duration.
- The DrumSep code is MIT-licensed. The community checkpoint has no formally
  documented license from its original authors; treat generated use as
  non-commercial-safe only unless that changes.
- PyGuitarPro writes a genuine `.gp5` file, reparses it, verifies every
  serialized drum pitch and rhythmic slot against the intended score grid,
  then requires a semantic `GP -> MIDI -> GP` round trip to be idempotent.
- The optional flake dev shell provides stable system tools:

```bash
nix develop ~/.agents/skills/drums-to-gp
```

The flake owns native tools (`ffmpeg`, `git`, `uv`); uv owns the incompatible
Python environments. The skill must not mutate or deploy a user's flake.

## Behavior worth flagging

- The GP exporter beat-tracks the source instead of forcing the whole live
  performance onto one aggregate BPM. Stabilize the local tempo prior against
  half/double-tempo jumps, map attacks through each measure's playable linear
  time model, then use integer-tempo phase feedback so timing error does not
  accumulate through the song.
- ADTOF supplies coarse attack-time priors, including a baseline snare stream.
  DrumSep supplies independent kick, snare, tom, hi-hat, ride, and crash audio.
  A baseline snare is retained only when the separated snare stem supports it;
  strong separated snare attacks missing from the baseline are added. A per-stem
  two-level clustering step rejects quiet cross-stem bleed without song-specific
  dB thresholds. A timing prior never supplies an instrument label. Marginal
  candidates inside a small normalized boundary hysteresis survive only when
  both that independent neural prior and a prominent whole-drum onset agree;
  deeply rejected candidates stay rejected.
- Toms are clustered by resonance into low, mid, and high GM toms. Only strong
  tom hits fit those global bands; marginal corroborated hits can be assigned
  to a band but cannot redefine the rest of the song. For cymbals, use the
  neural plate stream's onset and coarse label only when a prominent whole-drum
  onset independently supports it. Do not create cymbal notes from separated
  plate-stem peaks: ringing tails cause false retriggers and hit-to-hit label
  flicker. ADTOF's five-class model combines cymbal and ride as `CY+RD`; serialize
  that coarse class as GM 49 without claiming crash-versus-ride identity. The GP
  exporter preserves every resulting GM pitch exactly and never relabels
  instruments from rhythm, genre, or bar position.
- GP5 stores integer BPM. The exporter rescales note positions when rounding
  tempo so playback timing cannot accumulate drift.
- GP5 stores velocity in eight dynamic levels. First-write verification checks
  the exact GP5-quantized velocity as well as every rhythmic slot and pitch.
- The score begins at the first musical beat. When the source file has leading
  silence or count-in time, rendered comparison audio must retain that measured
  pre-roll before the GP playback. The CLI logs the first tracked pulse at
  microsecond precision so the alignment is reproducible.
- Silent MIDI usually means the input is not a drum stem or is too quiet.
- Semantic round-trip validation proves that GP5 serialization preserved the
  exporter output and that conversion is idempotent for meter, tempo, note
  position, pitch, and velocity. It does not prove that the transcription model
  identified the performance correctly. Compare rendered GP playback against
  the source audio before claiming quality.

## Development

```bash
uv run --project ~/.agents/skills/drums-to-gp --group dev pytest \
  ~/.agents/skills/drums-to-gp/tests
```

Keep audio probing, transcription, tempo correction, and GP5 export in
`pipeline.py`; keep argument parsing and orchestration in `cli.py`.

## Layout

```text
~/.agents/skills/drums-to-gp/
|- SKILL.md
|- flake.nix
|- pyproject.toml
|- adtof-env/
|  |- pyproject.toml
|  |- transcribe.py
|  `- uv.lock
|- drumsep-env/
|  |- pyproject.toml
|  |- separate.py
|  `- uv.lock
|- src/drums_to_gp/
|  |- cli.py
|  `- pipeline.py
`- tests/test_pipeline.py
```
