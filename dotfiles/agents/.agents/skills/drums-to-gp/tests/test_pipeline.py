from __future__ import annotations

import math
import subprocess
from pathlib import Path

import guitarpro
import httpx
import mido
import numpy as np
import pytest

from drums_to_gp import cli
from drums_to_gp import pipeline


def make_drum_midi(path: Path) -> None:
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(120), time=0))
    midi.tracks.append(meta)
    drums = mido.MidiTrack()
    drums.extend(
        [
            mido.Message("note_on", channel=9, note=35, velocity=100, time=0),
            mido.Message("note_off", channel=9, note=35, velocity=0, time=60),
            mido.Message("note_on", channel=9, note=38, velocity=90, time=420),
            mido.Message("note_off", channel=9, note=38, velocity=0, time=60),
        ]
    )
    midi.tracks.append(drums)
    midi.save(path)


def test_cli_defaults_to_straight_sixteenth_grid() -> None:
    args = cli._parse_args(["drums.wav"])

    assert args.subdivision == 16
    assert not args.adaptive_grid


def test_cli_accepts_remote_stem_splitter() -> None:
    args = cli._parse_args(
        ["mix.flac", "--stem-splitter-url", "http://splitter.test:18080/"]
    )

    assert args.stem_splitter_url == "http://splitter.test:18080/"
    assert args.stem_splitter_timeout == 3600.0


def _install_splitter_transport(monkeypatch, handler) -> None:
    real_client = httpx.AsyncClient
    transport = httpx.MockTransport(handler)
    monkeypatch.setattr(
        pipeline.httpx,
        "AsyncClient",
        lambda *args, **kwargs: real_client(transport=transport, **kwargs),
    )


def test_remote_stem_splitter_uploads_polls_and_downloads(
    monkeypatch, tmp_path: Path
) -> None:
    source = tmp_path / "full mix.flac"
    pipeline.sf.write(source, np.zeros((441, 2)), 44100, subtype="PCM_16")
    source_bytes = source.read_bytes()
    expected = tmp_path / "expected.wav"
    pipeline.sf.write(expected, np.zeros((441, 2)), 44100, subtype="PCM_16")

    requests = []
    polls = 0

    async def handler(request: httpx.Request) -> httpx.Response:
        nonlocal polls
        body = await request.aread()
        requests.append((request.method, str(request.url), body))
        if request.url.path.endswith("/api/split"):
            return httpx.Response(200, json={"job_id": "job/one"})
        if request.url.path.endswith("/stems/drums"):
            return httpx.Response(200, content=expected.read_bytes())
        polls += 1
        if polls == 1:
            return httpx.Response(200, json={"status": "running"})
        return httpx.Response(
            200,
            json={
                "status": "done",
                "stems": ["drums"],
                "duration_seconds": 0.01,
            },
        )

    _install_splitter_transport(monkeypatch, handler)
    output = tmp_path / "download" / "drums.wav"

    result = pipeline.extract_drums_via_splitter(
        source,
        "http://splitter.test:18080/",
        output,
        poll_interval_s=0,
    )

    assert result == output
    assert pipeline.probe(output).channels == 2
    assert requests[0][0] == "POST"
    assert requests[0][1] == "http://splitter.test:18080/api/split"
    assert source_bytes in requests[0][2]
    assert requests[1][1].endswith("/api/jobs/job%2Fone")
    assert requests[-1][1].endswith("/api/jobs/job%2Fone/stems/drums")


def test_splitter_rejects_nonfinite_timeout() -> None:
    with pytest.raises(pipeline.PipelineError, match="finite"):
        pipeline.extract_drums_via_splitter(
            Path("mix.wav"),
            "http://splitter.test",
            Path("drums.wav"),
            timeout_s=float("nan"),
        )

    with pytest.raises(SystemExit):
        cli._parse_args(
            ["mix.wav", "--stem-splitter-timeout", "nan"]
        )


def test_splitter_rejects_invalid_stems_list(monkeypatch, tmp_path: Path) -> None:
    source = tmp_path / "mix.wav"
    pipeline.sf.write(source, np.zeros((441, 1)), 44100, subtype="PCM_16")

    async def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/api/split"):
            return httpx.Response(200, json={"job_id": "job"})
        return httpx.Response(200, json={"status": "done", "stems": None})

    _install_splitter_transport(monkeypatch, handler)

    with pytest.raises(pipeline.PipelineError, match="invalid stems list"):
        pipeline.extract_drums_via_splitter(
            source,
            "http://splitter.test",
            tmp_path / "drums.wav",
        )


def test_splitter_does_not_replace_output_with_empty_audio(
    monkeypatch, tmp_path: Path
) -> None:
    source = tmp_path / "mix.wav"
    pipeline.sf.write(source, np.zeros((441, 1)), 44100, subtype="PCM_16")
    empty = tmp_path / "empty.wav"
    pipeline.sf.write(empty, np.zeros((0, 2)), 44100, subtype="PCM_16")
    output = tmp_path / "drums.wav"
    output.write_bytes(b"existing")

    async def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/api/split"):
            return httpx.Response(200, json={"job_id": "job"})
        if request.url.path.endswith("/stems/drums"):
            return httpx.Response(200, content=empty.read_bytes())
        return httpx.Response(200, json={"status": "done", "stems": ["drums"]})

    _install_splitter_transport(monkeypatch, handler)

    with pytest.raises(pipeline.PipelineError, match="empty drums stem"):
        pipeline.extract_drums_via_splitter(
            source,
            "http://splitter.test",
            output,
        )

    assert output.read_bytes() == b"existing"
    assert not list(tmp_path.glob(".*.part"))


def test_splitter_poll_transport_errors_are_controlled(
    monkeypatch, tmp_path: Path
) -> None:
    source = tmp_path / "mix.wav"
    pipeline.sf.write(source, np.zeros((441, 1)), 44100, subtype="PCM_16")

    async def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/api/split"):
            return httpx.Response(200, json={"job_id": "job"})
        raise httpx.ReadTimeout("read timed out", request=request)

    _install_splitter_transport(monkeypatch, handler)
    with pytest.raises(pipeline.PipelineError, match="after three retries"):
        pipeline.extract_drums_via_splitter(
            source,
            "http://splitter.test",
            tmp_path / "drums.wav",
            poll_interval_s=0,
        )


def test_splitter_third_poll_retry_can_recover(monkeypatch, tmp_path: Path) -> None:
    source = tmp_path / "mix.wav"
    pipeline.sf.write(source, np.zeros((441, 1)), 44100, subtype="PCM_16")
    expected = source.read_bytes()
    failures = 0

    async def handler(request: httpx.Request) -> httpx.Response:
        nonlocal failures
        if request.url.path.endswith("/api/split"):
            return httpx.Response(200, json={"job_id": "job"})
        if request.url.path.endswith("/stems/drums"):
            return httpx.Response(200, content=expected)
        if failures < 3:
            failures += 1
            raise httpx.ReadTimeout("read timed out", request=request)
        return httpx.Response(200, json={"status": "done", "stems": ["drums"]})

    _install_splitter_transport(monkeypatch, handler)
    output = tmp_path / "drums.wav"

    pipeline.extract_drums_via_splitter(
        source,
        "http://splitter.test",
        output,
        poll_interval_s=0,
    )

    assert failures == 3
    assert pipeline.probe(output).duration_s == pytest.approx(0.01)


def test_splitter_enforces_one_total_wall_clock_timeout(
    monkeypatch, tmp_path: Path
) -> None:
    source = tmp_path / "mix.wav"
    pipeline.sf.write(source, np.zeros((441, 1)), 44100, subtype="PCM_16")

    async def handler(request: httpx.Request) -> httpx.Response:
        await pipeline.asyncio.sleep(1)
        return httpx.Response(200, json={"job_id": "job"})

    _install_splitter_transport(monkeypatch, handler)

    with pytest.raises(pipeline.PipelineError, match="total timeout"):
        pipeline.extract_drums_via_splitter(
            source,
            "http://splitter.test",
            tmp_path / "drums.wav",
            timeout_s=0.01,
        )


def test_splitter_uses_source_duration_when_job_omits_it(
    monkeypatch, tmp_path: Path
) -> None:
    source = tmp_path / "mix.wav"
    pipeline.sf.write(source, np.zeros((88200, 1)), 44100, subtype="PCM_16")
    truncated = tmp_path / "truncated.wav"
    pipeline.sf.write(truncated, np.zeros((4410, 1)), 44100, subtype="PCM_16")

    async def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("/api/split"):
            return httpx.Response(200, json={"job_id": "job"})
        if request.url.path.endswith("/stems/drums"):
            return httpx.Response(200, content=truncated.read_bytes())
        return httpx.Response(200, json={"status": "done", "stems": ["drums"]})

    _install_splitter_transport(monkeypatch, handler)

    with pytest.raises(pipeline.PipelineError, match="duration does not match"):
        pipeline.extract_drums_via_splitter(
            source,
            "http://splitter.test",
            tmp_path / "drums.wav",
        )


def test_splitter_url_rejects_query_and_fragment() -> None:
    with pytest.raises(pipeline.PipelineError, match="query string"):
        pipeline._splitter_url("http://splitter.test/?token=secret", "/api/split")


def test_cli_adaptive_grid_is_explicit_opt_in() -> None:
    args = cli._parse_args(["drums.wav", "--adaptive-grid"])

    assert args.adaptive_grid


def _quarter_note_snare_midi(path: Path) -> None:
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    track = mido.MidiTrack()
    midi.tracks.append(track)
    for beat in range(4):
        track.append(
            mido.Message(
                "note_on",
                channel=9,
                note=38,
                velocity=100,
                time=0 if beat == 0 else 480,
            )
        )
    midi.save(path)


def _first_measure_snare_slots(path: Path) -> list[int]:
    song = guitarpro.parse(path)
    beats = song.tracks[0].measures[0].voices[0].beats
    return [
        index
        for index, beat in enumerate(beats)
        if any(note.value == 38 for note in beat.notes)
    ]


def test_beat_synced_export_preserves_four_snare_pattern_by_default(
    tmp_path: Path,
) -> None:
    source = tmp_path / "four-snares.mid"
    output = tmp_path / "four-snares.gp5"
    _quarter_note_snare_midi(source)

    pipeline.export_gp5(
        source,
        output,
        subdivision=16,
        beat_times=[index * 0.5 for index in range(9)],
    )

    assert _first_measure_snare_slots(output) == [0, 4, 8, 12]


def test_measure_linearization_does_not_notate_short_beat_tracker_jitter(
    tmp_path: Path,
) -> None:
    source = tmp_path / "middle-snare.mid"
    output = tmp_path / "middle-snare.gp5"
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(120), time=0))
    midi.tracks.append(meta)
    drums = mido.MidiTrack()
    drums.append(mido.Message("note_on", channel=9, note=38, velocity=100, time=960))
    midi.tracks.append(drums)
    midi.save(source)

    pipeline.export_gp5(
        source,
        output,
        subdivision=16,
        beat_times=[0.0, 0.4, 1.1, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0],
    )

    assert _first_measure_snare_slots(output) == [8]


def test_straight_grid_upgrades_to_32nds_instead_of_collapsing_hits(
    tmp_path: Path,
) -> None:
    source = tmp_path / "close-hits.mid"
    output = tmp_path / "close-hits.gp5"
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(120), time=0))
    midi.tracks.append(meta)
    drums = mido.MidiTrack()
    drums.append(mido.Message("note_on", channel=9, note=38, velocity=100, time=0))
    drums.append(mido.Message("note_on", channel=9, note=38, velocity=100, time=58))
    midi.tracks.append(drums)
    midi.save(source)

    pipeline.export_gp5(
        source,
        output,
        subdivision=16,
        beat_times=[index * 0.5 for index in range(9)],
    )

    beats = guitarpro.parse(output).tracks[0].measures[0].voices[0].beats
    assert beats[0].duration.value == 32
    assert _first_measure_snare_slots(output) == [0, 1]


def test_straight_grid_upgrades_to_64ths_instead_of_collapsing_hits(
    tmp_path: Path,
) -> None:
    source = tmp_path / "closer-hits.mid"
    output = tmp_path / "closer-hits.gp5"
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(120), time=0))
    midi.tracks.append(meta)
    drums = mido.MidiTrack()
    drums.append(mido.Message("note_on", channel=9, note=38, velocity=100, time=91))
    drums.append(mido.Message("note_on", channel=9, note=38, velocity=100, time=58))
    midi.tracks.append(drums)
    midi.save(source)

    pipeline.export_gp5(
        source,
        output,
        subdivision=16,
        beat_times=[index * 0.5 for index in range(9)],
    )

    beats = guitarpro.parse(output).tracks[0].measures[0].voices[0].beats
    notes = [note for beat in beats for note in beat.notes]
    assert beats[0].duration.value == 64
    assert len(notes) == 2


def test_measure_boundary_promotion_never_creates_a_negative_slot(
    tmp_path: Path,
) -> None:
    source = tmp_path / "early-downbeat.mid"
    output = tmp_path / "early-downbeat.gp5"
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(120), time=0))
    midi.tracks.append(meta)
    drums = mido.MidiTrack()
    drums.append(mido.Message("note_on", channel=9, note=38, velocity=100, time=1910))
    drums.append(mido.Message("note_on", channel=9, note=35, velocity=100, time=490))
    midi.tracks.append(drums)
    midi.save(source)

    pipeline.export_gp5(
        source,
        output,
        subdivision=16,
        beat_times=[index * 0.5 for index in range(13)],
    )

    song = guitarpro.parse(output)
    first = song.tracks[0].measures[0].voices[0].beats
    second = song.tracks[0].measures[1].voices[0].beats
    assert not any(beat.notes for beat in first)
    assert [
        index
        for index, beat in enumerate(second)
        if any(note.value == 38 for note in beat.notes)
    ] == [0]


def test_integer_tempos_track_cumulative_measure_phase() -> None:
    starts = [0.0, 4.0, 8.0, 12.0, 16.0]
    target_times = [0.0, 2.0, 4.6, 6.5, 8.8]

    tempos = pipeline._phase_locked_integer_tempos(starts, target_times)
    actual_ends = np.cumsum([4 * 60 / tempo for tempo in tempos])

    assert max(abs(actual_ends - np.asarray(target_times[1:]))) < 0.012


def test_gp_midi_gp_round_trip_is_semantically_idempotent(tmp_path: Path) -> None:
    source = tmp_path / "quarter-snares.mid"
    output = tmp_path / "quarter-snares.gp5"
    _quarter_note_snare_midi(source)

    pipeline.export_gp5(
        source,
        output,
        subdivision=16,
        beat_times=[index * 0.5 for index in range(9)],
    )

    pipeline.verify_gp5_idempotent(output, subdivision=16)


def test_round_trip_keeps_an_existing_odd_32nd_position(tmp_path: Path) -> None:
    source = tmp_path / "odd-32nd.mid"
    output = tmp_path / "odd-32nd.gp5"
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(120), time=0))
    midi.tracks.append(meta)
    drums = mido.MidiTrack()
    drums.append(mido.Message("note_on", channel=9, note=38, velocity=100, time=60))
    drums.append(mido.Message("note_on", channel=9, note=38, velocity=100, time=120))
    midi.tracks.append(drums)
    midi.save(source)

    pipeline.export_gp5(source, output, subdivision=32)

    pipeline.verify_gp5_idempotent(output, subdivision=16)


def test_round_trip_keeps_an_existing_odd_64th_position(tmp_path: Path) -> None:
    source = tmp_path / "odd-64th.mid"
    output = tmp_path / "odd-64th.gp5"
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(120), time=0))
    midi.tracks.append(meta)
    drums = mido.MidiTrack()
    drums.append(mido.Message("note_on", channel=9, note=38, velocity=100, time=30))
    midi.tracks.append(drums)
    midi.save(source)

    pipeline.export_gp5(source, output, subdivision=64)

    pipeline.verify_gp5_idempotent(output, subdivision=16)


def test_set_tempo_preserves_wall_clock_timing(tmp_path: Path) -> None:
    source = tmp_path / "source.mid"
    output = tmp_path / "tempo.mid"
    make_drum_midi(source)
    before = mido.MidiFile(source).length

    pipeline.set_tempo(source, output, 150)

    result = mido.MidiFile(output)
    tempos = [
        message.tempo
        for track in result.tracks
        for message in track
        if message.type == "set_tempo"
    ]
    assert math.isclose(result.length, before, abs_tol=0.003)
    assert math.isclose(mido.tempo2bpm(tempos[0]), 150, abs_tol=0.01)


def test_export_gp5_round_trip(tmp_path: Path) -> None:
    source = tmp_path / "source.mid"
    output = tmp_path / "drums.gp5"
    make_drum_midi(source)

    pipeline.export_gp5(source, output)

    song = guitarpro.parse(output)
    notes = [
        note
        for measure in song.tracks[0].measures
        for voice in measure.voices
        for beat in voice.beats
        for note in beat.notes
    ]
    assert output.stat().st_size > 0
    assert song.tracks[0].isPercussionTrack
    assert song.tracks[0].channel.isPercussionChannel
    assert song.tempo == 120
    assert sorted(note.value for note in notes) == [35, 38]
    assert sorted(note.velocity for note in notes) == [79, 95]


def test_gp5_semantic_verifier_rejects_a_different_note_grid(
    tmp_path: Path,
) -> None:
    output = tmp_path / "mismatch.gp5"
    song = guitarpro.models.Song()
    song.tracks[0].isPercussionTrack = True

    with pytest.raises(pipeline.PipelineError, match="semantic verification"):
        pipeline._write_verified_gp5(song, output, [(((38, 95),),)])


def test_export_gp5_integer_tempo_does_not_drift(tmp_path: Path) -> None:
    source = tmp_path / "fractional-tempo.mid"
    output = tmp_path / "drums.gp5"
    tempo = mido.bpm2tempo(132.51)
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=tempo, time=0))
    midi.tracks.append(meta)
    drums = mido.MidiTrack()
    tick = round(300 * 1_000_000 / tempo * midi.ticks_per_beat)
    drums.append(mido.Message("note_on", channel=9, note=35, velocity=100, time=tick))
    drums.append(mido.Message("note_off", channel=9, note=35, velocity=0, time=60))
    midi.tracks.append(drums)
    midi.save(source)

    pipeline.export_gp5(source, output, subdivision=24)

    song = guitarpro.parse(output)
    note_beat = next(
        beat
        for measure in song.tracks[0].measures
        for voice in measure.voices
        for beat in voice.beats
        if beat.notes
    )
    played_seconds = (
        (note_beat.start - guitarpro.models.Duration.quarterTime)
        / guitarpro.models.Duration.quarterTime
        * 60
        / song.tempo
    )
    assert math.isclose(played_seconds, 300, abs_tol=0.05)


def test_export_gp5_supports_triplet_grid(tmp_path: Path) -> None:
    source = tmp_path / "source.mid"
    output = tmp_path / "triplets.gp5"
    make_drum_midi(source)

    pipeline.export_gp5(source, output, subdivision=24)

    song = guitarpro.parse(output)
    duration = song.tracks[0].measures[0].voices[0].beats[0].duration
    assert duration.value == 16
    assert duration.tuplet == guitarpro.models.Tuplet(enters=3, times=2)


def test_beat_synced_export_selects_readable_grid_and_preserves_pitches(
    tmp_path: Path,
) -> None:
    source = tmp_path / "beat-synced.mid"
    output = tmp_path / "beat-synced.gp5"
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    meta = mido.MidiTrack()
    meta.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(120), time=0))
    midi.tracks.append(meta)
    drums = mido.MidiTrack()
    drums.extend(
        [
            mido.Message("note_on", channel=9, note=49, velocity=100, time=0),
            mido.Message("note_on", channel=9, note=35, velocity=100, time=160),
            mido.Message("note_on", channel=9, note=35, velocity=100, time=160),
            mido.Message("note_on", channel=9, note=49, velocity=100, time=160),
        ]
    )
    midi.tracks.append(drums)
    midi.save(source)

    pipeline.export_gp5(
        source,
        output,
        subdivision=None,
        beat_times=[index * 0.5 for index in range(9)],
    )

    song = guitarpro.parse(output)
    beats = song.tracks[0].measures[0].voices[0].beats
    notes = [note for beat in beats for note in beat.notes]
    assert beats[0].duration.value == 8
    assert beats[0].duration.tuplet == guitarpro.models.Tuplet(enters=3, times=2)
    assert sorted(note.value for note in notes) == [35, 35, 49, 49]


def test_reference_repeat_count_is_fitted_to_audio_length(tmp_path: Path) -> None:
    reference = tmp_path / "reference.gp5"
    song = guitarpro.models.Song()
    song.measureHeaders[0].isRepeatOpen = True
    song.measureHeaders[0].repeatClose = 3
    guitarpro.write(song, reference, version=(5, 1, 0))

    specs = pipeline._reference_measure_specs(reference, minimum_quarters=12)

    assert specs == [(4, 4), (4, 4), (4, 4)]


def test_adtof_transcriber_uses_locked_project(
    monkeypatch, tmp_path: Path
) -> None:
    stem = tmp_path / "drums.wav"
    stem.write_bytes(b"test")
    out_dir = tmp_path / "out"

    monkeypatch.setattr(pipeline.shutil, "which", lambda _: "/bin/uv")

    def fake_run(command, **kwargs):
        assert "--isolated" in command
        assert "--locked" in command
        assert command[command.index("--project") + 1] == str(pipeline.ADTOF_PROJECT)
        work = Path(command[-1])
        (work / "drums.wav.mid").write_bytes(b"midi")
        return subprocess.CompletedProcess(command, 0, "", "")

    monkeypatch.setattr(pipeline.subprocess, "run", fake_run)

    result = pipeline._transcribe_adtof(stem, out_dir)

    assert result == out_dir / "drums.mid"
    assert result.read_bytes() == b"midi"


def test_drumsep_uses_locked_cpu_project(monkeypatch, tmp_path: Path) -> None:
    stem = tmp_path / "drums.wav"
    stem.write_bytes(b"test")
    out_dir = tmp_path / "stems"

    monkeypatch.setattr(pipeline.shutil, "which", lambda _: "/bin/uv")

    def fake_run(command, **kwargs):
        assert "--isolated" in command
        assert "--locked" in command
        assert command[command.index("--project") + 1] == str(
            pipeline.DRUMSEP_PROJECT
        )
        assert kwargs["env"]["CUDA_VISIBLE_DEVICES"] == ""
        work = Path(command[-1])
        for instrument in pipeline.DRUMSEP_CLASSES:
            (work / f"drums_{instrument}.wav").write_bytes(b"wav")
        return subprocess.CompletedProcess(command, 0, "", "")

    monkeypatch.setattr(pipeline.subprocess, "run", fake_run)

    result = pipeline._separate_drum_stems(stem, out_dir)

    assert set(result) == set(pipeline.DRUMSEP_CLASSES)
    assert all(path.is_file() for path in result.values())


def test_two_means_boundary_separates_quiet_bleed() -> None:
    low, high, boundary = pipeline._two_means_boundary(
        np.asarray([-42.0, -40.0, -39.0, -15.0, -13.0, -12.0])
    )

    assert low < boundary < high
    assert boundary == pytest.approx((low + high) / 2)


def test_cymbal_conflict_uses_strongest_normalized_stem() -> None:
    result = pipeline._strongest_per_attack(
        [
            pipeline.DrumCandidate(1.000, "hh", 0.4, 90),
            pipeline.DrumCandidate(1.012, "ride", 1.2, 100),
            pipeline.DrumCandidate(2.000, "crash", 0.8, 110),
        ]
    )

    assert [(candidate.time_s, candidate.instrument) for candidate in result] == [
        (1.012, "ride"),
        (2.000, "crash"),
    ]


def test_cymbal_conflicts_do_not_chain_distinct_attacks() -> None:
    result = pipeline._strongest_per_attack(
        [
            pipeline.DrumCandidate(1.000, "hh", 0.4, 90),
            pipeline.DrumCandidate(1.020, "ride", 1.2, 100),
            pipeline.DrumCandidate(1.040, "crash", 0.8, 110),
        ],
        tolerance_s=0.030,
    )

    assert [(candidate.time_s, candidate.instrument) for candidate in result] == [
        (1.020, "ride"),
        (1.040, "crash"),
    ]


def test_classification_snaps_to_prior_time_without_prior_label() -> None:
    result = pipeline._snap_to_prior_attacks(
        [pipeline.DrumCandidate(1.012, "toms", 1.0, 80)],
        [(1.000, 35, 117)],
    )

    assert result == [
        pipeline.DrumCandidate(1.000, "toms", 1.0, 117, prior_aligned=True)
    ]


@pytest.mark.parametrize("count", [8, 9, 12])
def test_identical_tom_resonances_remain_one_mid_tom(count: int) -> None:
    labels, pitches = pipeline._cluster_tom_resonances(
        np.full(count, 100.0)
    )

    assert pitches == [47]
    assert np.all(labels == 0)


def test_marginal_tom_does_not_redefine_strong_resonance_bands() -> None:
    values = np.asarray(
        [80, 81, 82, 83, 105, 106, 107, 108, 140, 141, 142, 143, 300],
        dtype=float,
    )
    strong = np.asarray([True] * 12 + [False])

    pitches = pipeline._assign_tom_pitches(values, strong)

    assert pitches[:4] == [43] * 4
    assert pitches[4:8] == [47] * 4
    assert pitches[8:] == [50] * 5


def test_strong_separated_snare_is_added_when_adtof_misses_it(
    monkeypatch, tmp_path: Path
) -> None:
    adtof = tmp_path / "empty.mid"
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    midi.tracks.append(mido.MidiTrack())
    midi.save(adtof)
    separated = {}
    for instrument in pipeline.DRUMSEP_CLASSES:
        path = tmp_path / f"stem_{instrument}.wav"
        pipeline.sf.write(path, np.zeros(4410), 44100)
        separated[instrument] = path

    def fake_candidates(path, instrument):
        if instrument == "snare":
            return [pipeline.DrumCandidate(0.050, "snare", 1.0, 100)]
        return []

    monkeypatch.setattr(pipeline, "_separated_onset_candidates", fake_candidates)
    output = tmp_path / "classified.mid"

    pipeline._write_classified_midi(adtof, separated, output)

    hits = pipeline._drum_hits_seconds(mido.MidiFile(output))
    assert [(round(time, 3), pitch) for time, pitch, _ in hits] == [(0.05, 38)]


def _one_snare_prior(path: Path) -> None:
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    meta = mido.MidiTrack()
    meta.append(
        mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(120), time=0)
    )
    midi.tracks.append(meta)
    drums = mido.MidiTrack()
    drums.append(
        mido.Message("note_on", channel=9, note=38, velocity=100, time=48)
    )
    midi.tracks.append(drums)
    midi.save(path)


def _silent_separated_stems(tmp_path: Path) -> dict[str, Path]:
    separated = {}
    for instrument in pipeline.DRUMSEP_CLASSES:
        path = tmp_path / f"stem_{instrument}.wav"
        pipeline.sf.write(path, np.zeros(4410), 44100)
        separated[instrument] = path
    return separated


def test_unsupported_adtof_snare_is_not_copied(
    monkeypatch, tmp_path: Path
) -> None:
    adtof = tmp_path / "prior.mid"
    _one_snare_prior(adtof)
    separated = _silent_separated_stems(tmp_path)
    monkeypatch.setattr(
        pipeline,
        "_separated_onset_candidates",
        lambda path, instrument: [],
    )
    output = tmp_path / "classified.mid"

    pipeline._write_classified_midi(adtof, separated, output)

    assert pipeline._drum_hits_seconds(mido.MidiFile(output)) == []


def test_quiet_separated_snare_is_rejected_even_when_aligned_to_prior(
    monkeypatch, tmp_path: Path
) -> None:
    adtof = tmp_path / "prior.mid"
    _one_snare_prior(adtof)
    separated = _silent_separated_stems(tmp_path)

    def fake_candidates(path, instrument):
        if instrument == "snare":
            return [pipeline.DrumCandidate(0.060, "snare", -0.5, 50)]
        return []

    monkeypatch.setattr(pipeline, "_separated_onset_candidates", fake_candidates)
    output = tmp_path / "classified.mid"

    pipeline._write_classified_midi(adtof, separated, output)

    assert pipeline._drum_hits_seconds(mido.MidiFile(output)) == []


def test_marginal_snare_requires_prior_and_whole_stem_corroboration(
    monkeypatch, tmp_path: Path
) -> None:
    adtof = tmp_path / "prior.mid"
    _one_snare_prior(adtof)
    separated = _silent_separated_stems(tmp_path)
    whole = tmp_path / "whole.wav"
    pipeline.sf.write(whole, np.zeros(4410), 44100)

    def fake_candidates(path, instrument):
        if instrument == "snare":
            return [pipeline.DrumCandidate(0.060, "snare", -0.08, 50)]
        if instrument == "whole":
            return [pipeline.DrumCandidate(0.055, "whole", 1.0, 100)]
        return []

    monkeypatch.setattr(pipeline, "_separated_onset_candidates", fake_candidates)
    output = tmp_path / "classified.mid"

    pipeline._write_classified_midi(
        adtof, separated, output, drum_stem=whole
    )

    hits = pipeline._drum_hits_seconds(mido.MidiFile(output))
    assert [(round(time, 3), pitch, velocity) for time, pitch, velocity in hits] == [
        (0.05, 38, 100)
    ]


def test_cymbal_stream_uses_supported_neural_label_without_separator_retriggers(
    monkeypatch, tmp_path: Path
) -> None:
    adtof = tmp_path / "cymbal-priors.mid"
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    meta = mido.MidiTrack()
    meta.append(
        mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(120), time=0)
    )
    midi.tracks.append(meta)
    drums = mido.MidiTrack()
    drums.append(mido.Message("note_on", channel=9, note=49, velocity=100, time=48))
    midi.tracks.append(drums)
    midi.save(adtof)
    separated = _silent_separated_stems(tmp_path)
    whole = tmp_path / "whole.wav"
    pipeline.sf.write(whole, np.zeros(4410), 44100)

    def fake_candidates(path, instrument):
        if instrument == "hh":
            return [pipeline.DrumCandidate(0.010, "hh", 1.0, 100)]
        if instrument == "ride":
            return [
                pipeline.DrumCandidate(0.050, "ride", 2.0, 100),
                pipeline.DrumCandidate(0.084, "ride", 1.5, 90),
            ]
        if instrument == "whole":
            return [pipeline.DrumCandidate(0.055, "whole", 1.0, 100)]
        return []

    monkeypatch.setattr(pipeline, "_separated_onset_candidates", fake_candidates)
    output = tmp_path / "classified.mid"

    pipeline._write_classified_midi(
        adtof, separated, output, drum_stem=whole
    )

    hits = pipeline._drum_hits_seconds(mido.MidiFile(output))
    assert [(round(time, 3), pitch) for time, pitch, _ in hits] == [(0.05, 49)]


def test_cymbal_prior_without_whole_stem_onset_is_rejected(
    monkeypatch, tmp_path: Path
) -> None:
    adtof = tmp_path / "cymbal-prior.mid"
    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    midi.tracks.append(mido.MidiTrack())
    drums = mido.MidiTrack()
    drums.append(mido.Message("note_on", channel=9, note=49, velocity=100, time=48))
    midi.tracks.append(drums)
    midi.save(adtof)
    separated = _silent_separated_stems(tmp_path)
    whole = tmp_path / "whole.wav"
    pipeline.sf.write(whole, np.zeros(4410), 44100)
    monkeypatch.setattr(
        pipeline,
        "_separated_onset_candidates",
        lambda path, instrument: [],
    )
    output = tmp_path / "classified.mid"

    pipeline._write_classified_midi(
        adtof, separated, output, drum_stem=whole
    )

    assert pipeline._drum_hits_seconds(mido.MidiFile(output)) == []
