from __future__ import annotations

import asyncio
import os
import shutil
import subprocess
import tempfile
from bisect import bisect_right
from collections import defaultdict
from dataclasses import dataclass
from itertools import product
from math import ceil, isfinite
from pathlib import Path
from urllib.parse import quote

import guitarpro
import httpx
import librosa
import mido
import numpy as np
import soundfile as sf
from guitarpro import models as gp
from scipy.ndimage import median_filter


class PipelineError(RuntimeError):
    """Any recoverable failure in a pipeline stage. CLI turns these into exit 1."""


@dataclass(frozen=True)
class StemInfo:
    path: Path
    sample_rate: int
    channels: int
    duration_s: float


PROJECT_ROOT = Path(__file__).resolve().parents[2]
ADTOF_PROJECT = PROJECT_ROOT / "adtof-env"
ADTOF_RUNNER = ADTOF_PROJECT / "transcribe.py"
DRUMSEP_PROJECT = PROJECT_ROOT / "drumsep-env"
DRUMSEP_RUNNER = DRUMSEP_PROJECT / "separate.py"
SUPPORTED_SUBDIVISIONS = (12, 16, 24, 32, 64)
ADAPTIVE_SLOTS_PER_QUARTER = (2, 3, 4, 6, 8, 12, 16)
DRUMSEP_CLASSES = ("kick", "snare", "toms", "hh", "ride", "crash")
EVIDENCE_HYSTERESIS = 0.10
ONSET_MATCH_TOLERANCE_S = 0.050


@dataclass(frozen=True)
class DrumCandidate:
    time_s: float
    instrument: str
    confidence: float
    velocity: int
    prior_aligned: bool = False


def probe(path: Path) -> StemInfo:
    try:
        info = sf.info(str(path))
    except sf.LibsndfileError as e:
        raise PipelineError(f"cannot read audio: {path}: {e}") from e
    return StemInfo(
        path=path,
        sample_rate=info.samplerate,
        channels=info.channels,
        duration_s=info.frames / info.samplerate,
    )


def _splitter_url(base_url: str, endpoint: str) -> str:
    try:
        parsed = httpx.URL(base_url)
    except httpx.InvalidURL as error:
        raise PipelineError(f"invalid stem splitter URL: {error}") from error
    if parsed.scheme not in ("http", "https") or not parsed.host:
        raise PipelineError(
            "stem splitter URL must be an absolute http:// or https:// URL"
        )
    if parsed.query or parsed.fragment:
        raise PipelineError(
            "stem splitter URL must not contain a query string or fragment"
        )
    return str(parsed.copy_with(path=f"{parsed.path.rstrip('/')}{endpoint}"))


async def _splitter_json(
    client: httpx.AsyncClient,
    method: str,
    url: str,
    **kwargs,
) -> dict:
    try:
        response = await client.request(method, url, **kwargs)
        response.raise_for_status()
        payload = response.json()
    except httpx.HTTPStatusError as error:
        detail = error.response.text[:4096].strip()
        raise PipelineError(
            f"stem splitter returned HTTP {error.response.status_code}"
            + (f": {detail}" if detail else "")
        ) from error
    except (httpx.HTTPError, OSError, TimeoutError) as error:
        raise PipelineError(f"stem splitter request failed: {error}") from error
    except ValueError as error:
        raise PipelineError("stem splitter returned invalid JSON") from error
    if not isinstance(payload, dict):
        raise PipelineError("stem splitter returned a non-object JSON response")
    return payload


def _source_audio_duration(source: Path) -> float:
    try:
        duration = probe(source).duration_s
    except PipelineError as soundfile_error:
        ffprobe = shutil.which("ffprobe")
        if ffprobe is None:
            raise PipelineError(
                "cannot validate full-mix duration: ffprobe is not installed"
            ) from soundfile_error
        try:
            result = subprocess.run(
                [
                    ffprobe,
                    "-v",
                    "error",
                    "-show_entries",
                    "format=duration",
                    "-of",
                    "default=nw=1:nk=1",
                    str(source),
                ],
                check=True,
                capture_output=True,
                text=True,
            )
            duration = float(result.stdout.strip())
        except (OSError, ValueError, subprocess.CalledProcessError) as error:
            raise PipelineError(
                f"cannot determine full-mix duration: {error}"
            ) from error
    if not isfinite(duration) or duration <= 0:
        raise PipelineError("full mix has no positive audio duration")
    return duration


async def _extract_drums_via_splitter_async(
    source: Path,
    base_url: str,
    out: Path,
    *,
    source_duration: float,
    transport_timeout_s: float,
    poll_interval_s: float,
) -> Path:
    operation_timeout = httpx.Timeout(
        connect=min(10.0, transport_timeout_s),
        read=min(30.0, transport_timeout_s),
        write=min(120.0, transport_timeout_s),
        pool=min(10.0, transport_timeout_s),
    )
    async with httpx.AsyncClient(timeout=operation_timeout) as client:
        try:
            source_file = source.open("rb")
        except OSError as error:
            raise PipelineError(f"cannot read full mix for upload: {error}") from error
        with source_file:
            response = await _splitter_json(
                client,
                "POST",
                _splitter_url(base_url, "/api/split"),
                files={
                    "file": (
                        source.name,
                        source_file,
                        "application/octet-stream",
                    )
                },
            )
        job_id = response.get("job_id")
        if not isinstance(job_id, str) or not job_id:
            raise PipelineError("stem splitter upload response has no job_id")
        quoted_job_id = quote(job_id, safe="")
        job_url = _splitter_url(base_url, f"/api/jobs/{quoted_job_id}")

        poll_failures = 0
        while True:
            try:
                job = await _splitter_json(client, "GET", job_url)
                poll_failures = 0
            except PipelineError as error:
                poll_failures += 1
                if poll_failures > 3:
                    raise PipelineError(
                        f"stem splitter job {job_id} polling failed after three "
                        f"retries: "
                        f"{error}"
                    ) from error
                await asyncio.sleep(poll_interval_s)
                continue
            status = job.get("status")
            if status == "done":
                stems = job.get("stems")
                if not isinstance(stems, list) or not all(
                    isinstance(stem, str) for stem in stems
                ):
                    raise PipelineError(
                        "stem splitter completed with an invalid stems list"
                    )
                if "drums" not in stems:
                    raise PipelineError(
                        "stem splitter completed without a drums stem"
                    )
                expected_duration = job.get("duration_seconds")
                if expected_duration is not None and (
                    isinstance(expected_duration, bool) or
                    not isinstance(expected_duration, (int, float))
                    or not isfinite(expected_duration)
                    or expected_duration <= 0
                ):
                    raise PipelineError(
                        "stem splitter returned an invalid source duration"
                    )
                expected_duration = (
                    float(expected_duration)
                    if expected_duration is not None
                    else source_duration
                )
                if abs(expected_duration - source_duration) > max(
                    1.0, source_duration * 0.01
                ):
                    raise PipelineError(
                        "stem splitter job duration does not match the full mix "
                        f"({expected_duration:.3f}s vs {source_duration:.3f}s)"
                    )
                break
            if status in ("error", "cancelled"):
                detail = job.get("error") or status
                raise PipelineError(
                    f"stem splitter job {job_id} failed: {detail}"
                )
            if status not in ("queued", "running"):
                raise PipelineError(
                    f"stem splitter job {job_id} returned unknown status {status!r}"
                )
            await asyncio.sleep(poll_interval_s)

        stem_url = _splitter_url(
            base_url,
            f"/api/jobs/{quoted_job_id}/stems/drums",
        )
        try:
            out.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(
                prefix=f".{out.name}.",
                suffix=".part",
                dir=out.parent,
                delete=False,
            ) as temporary:
                temporary_path = Path(temporary.name)
        except OSError as error:
            raise PipelineError(
                f"cannot create temporary drums download: {error}"
            ) from error
        try:
            try:
                with temporary_path.open("wb") as destination:
                    async with client.stream("GET", stem_url) as download:
                        download.raise_for_status()
                        async for chunk in download.aiter_bytes(
                            chunk_size=64 * 1024
                        ):
                            destination.write(chunk)
            except httpx.HTTPStatusError as error:
                raise PipelineError(
                    f"stem splitter returned HTTP "
                    f"{error.response.status_code} for the drums stem"
                ) from error
            except (httpx.HTTPError, OSError, TimeoutError) as error:
                raise PipelineError(
                    f"stem splitter drums download failed: {error}"
                ) from error

            info = probe(temporary_path)
            if info.duration_s <= 0 or info.sample_rate <= 0 or info.channels <= 0:
                raise PipelineError("stem splitter returned an empty drums stem")
            if abs(info.duration_s - expected_duration) > max(
                1.0, expected_duration * 0.01
            ):
                raise PipelineError(
                    "stem splitter drums duration does not match the source "
                    f"({info.duration_s:.3f}s vs {expected_duration:.3f}s)"
                )
            try:
                os.replace(temporary_path, out)
            except OSError as error:
                raise PipelineError(f"cannot install drums stem: {error}") from error
        finally:
            try:
                temporary_path.unlink(missing_ok=True)
            except OSError:
                pass
    return out


def extract_drums_via_splitter(
    source: Path,
    base_url: str,
    out: Path,
    *,
    timeout_s: float = 3600.0,
    poll_interval_s: float = 2.0,
) -> Path:
    """Upload a full mix and download its drum stem under one hard deadline."""
    if (
        not isfinite(timeout_s)
        or timeout_s <= 0
        or not isfinite(poll_interval_s)
        or poll_interval_s < 0
    ):
        raise PipelineError("stem splitter timeout values must be finite and positive")
    if not source.is_file():
        raise PipelineError(f"full mix is not a file: {source}")
    try:
        asyncio.get_running_loop()
    except RuntimeError:
        pass
    else:
        raise PipelineError(
            "the synchronous stem-splitter API cannot run inside an active "
            "asyncio event loop"
        )

    source_duration = _source_audio_duration(source)

    async def run_with_deadline() -> Path:
        async with asyncio.timeout(timeout_s):
            return await _extract_drums_via_splitter_async(
                source,
                base_url,
                out,
                source_duration=source_duration,
                transport_timeout_s=timeout_s,
                poll_interval_s=poll_interval_s,
            )

    try:
        return asyncio.run(run_with_deadline())
    except TimeoutError as error:
        raise PipelineError(
            f"stem splitter reached its {timeout_s:g}s total timeout"
        ) from error


def estimate_tempo(path: Path) -> float:
    y, sr = librosa.load(str(path), sr=None, mono=True)
    tempo, _ = librosa.beat.beat_track(y=y, sr=sr)
    # librosa returns a 0-d ndarray in recent versions, a scalar in older ones.
    return float(tempo.item() if hasattr(tempo, "item") else tempo)


def estimate_beat_times(path: Path) -> list[float]:
    """Track the recording's changing quarter-note pulse in seconds.

    A single aggregate BPM is not enough for a live performance: the notes can
    remain close to their audio attacks while sliding through the notated bars.
    A frame-wise tempo prior keeps librosa's beat tracker on the local pulse.
    """
    y, sr = librosa.load(str(path), sr=22050, mono=True)
    hop_length = 256
    onset = librosa.onset.onset_strength(y=y, sr=sr, hop_length=hop_length)
    local_tempo = librosa.feature.tempo(
        onset_envelope=onset,
        sr=sr,
        hop_length=hop_length,
        aggregate=None,
        ac_size=8.0,
    )
    finite_tempos = local_tempo[np.isfinite(local_tempo)]
    if not len(finite_tempos):
        raise PipelineError("could not estimate a local tempo prior from the audio")
    center_tempo = float(np.median(finite_tempos))
    local_tempo = np.where(np.isfinite(local_tempo), local_tempo, center_tempo)
    # Local autocorrelation can jump to half or double tempo during sparse
    # passages and fills. Constrain it to the continuous neighborhood around
    # the track's median and remove short excursions before beat decoding.
    local_tempo = np.clip(
        local_tempo,
        center_tempo * 0.78,
        center_tempo * 1.32,
    )
    window_frames = max(3, round(5.0 * sr / hop_length))
    if window_frames % 2 == 0:
        window_frames += 1
    local_tempo = median_filter(local_tempo, size=window_frames, mode="nearest")
    _, frames = librosa.beat.beat_track(
        onset_envelope=onset,
        sr=sr,
        hop_length=hop_length,
        bpm=local_tempo,
        tightness=100,
        trim=False,
        units="frames",
    )
    times = librosa.frames_to_time(frames, sr=sr, hop_length=hop_length)
    if len(times) < 2:
        raise PipelineError("could not track a stable beat grid from the audio")
    return [float(value) for value in times]


def _transcribe_adtof(stem: Path, out_dir: Path) -> Path:
    """Run ADTOF and return the path of the produced .mid.

    ADTOF needs legacy Keras, so it lives in a locked, isolated Python 3.10
    uv project instead of dragging those constraints into this package.
    """
    if shutil.which("uv") is None:
        raise PipelineError("uv not on PATH; see https://docs.astral.sh/uv/")
    if not ADTOF_RUNNER.is_file():
        raise PipelineError(f"ADTOF runner missing: {ADTOF_RUNNER}")

    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="drums-to-gp-") as work:
        env = os.environ.copy()
        env.pop("UV_PROJECT_ENVIRONMENT", None)
        env.pop("VIRTUAL_ENV", None)
        env.update(
            {
                "CUDA_VISIBLE_DEVICES": "",
                "TF_CPP_MIN_LOG_LEVEL": "2",
                "TF_USE_LEGACY_KERAS": "1",
                "UV_NO_PROGRESS": "1",
            }
        )
        proc = subprocess.run(
            [
                "uv",
                "run",
                "--quiet",
                "--isolated",
                "--project",
                str(ADTOF_PROJECT),
                "--locked",
                "python",
                str(ADTOF_RUNNER),
                str(stem),
                work,
            ],
            capture_output=True,
            text=True,
            env=env,
        )
        if proc.returncode != 0:
            raise PipelineError(
                f"ADTOF failed (exit {proc.returncode}):\n{proc.stderr.strip()}"
            )

        produced = next(iter(Path(work).glob("*.mid")), None)
        if produced is None:
            raise PipelineError(f"ADTOF produced no .mid in {work}")

        dst = out_dir / f"{stem.stem}.mid"
        shutil.move(str(produced), str(dst))

    return dst


def _separate_drum_stems(stem: Path, out_dir: Path) -> dict[str, Path]:
    """Split a drum stem into six instrument stems with locked DrumSep."""
    if shutil.which("uv") is None:
        raise PipelineError("uv not on PATH; see https://docs.astral.sh/uv/")
    if not DRUMSEP_RUNNER.is_file():
        raise PipelineError(f"DrumSep runner missing: {DRUMSEP_RUNNER}")

    out_dir.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.pop("UV_PROJECT_ENVIRONMENT", None)
    env.pop("VIRTUAL_ENV", None)
    env.update({"CUDA_VISIBLE_DEVICES": "", "UV_NO_PROGRESS": "1"})
    proc = subprocess.run(
        [
            "uv",
            "run",
            "--quiet",
            "--isolated",
            "--project",
            str(DRUMSEP_PROJECT),
            "--locked",
            "python",
            str(DRUMSEP_RUNNER),
            str(stem),
            str(out_dir),
        ],
        capture_output=True,
        text=True,
        env=env,
    )
    if proc.returncode != 0:
        raise PipelineError(
            f"DrumSep failed (exit {proc.returncode}):\n{proc.stderr.strip()}"
        )

    result = {
        instrument: out_dir / f"{stem.stem}_{instrument}.wav"
        for instrument in DRUMSEP_CLASSES
    }
    missing = [path for path in result.values() if not path.is_file()]
    if missing:
        raise PipelineError(
            "DrumSep did not produce expected stems: "
            + ", ".join(path.name for path in missing)
        )
    return result


def set_tempo(mid_in: Path, mid_out: Path, bpm: float) -> None:
    """Set BPM without changing the transcription's wall-clock timing."""
    if bpm <= 0:
        raise PipelineError(f"tempo must be positive, got {bpm}")

    mid = mido.MidiFile(str(mid_in))
    old_tempos = [
        message.tempo
        for track in mid.tracks
        for message in track
        if message.type == "set_tempo"
    ]
    old_tempo = old_tempos[0] if old_tempos else mido.bpm2tempo(120)
    new_tempo = mido.bpm2tempo(bpm)
    scale = old_tempo / new_tempo

    for track in mid.tracks:
        absolute_tick = 0
        emitted_tick = 0
        rewritten = []
        for message in track:
            absolute_tick += message.time
            scaled_tick = round(absolute_tick * scale)
            if message.type == "set_tempo":
                continue
            rewritten.append(message.copy(time=scaled_tick - emitted_tick))
            emitted_tick = scaled_tick
        track[:] = rewritten

    mid.tracks[0].insert(
        0, mido.MetaMessage("set_tempo", tempo=new_tempo, time=0)
    )
    mid_out.parent.mkdir(parents=True, exist_ok=True)
    mid.save(str(mid_out))


def _drum_hits(mid: mido.MidiFile) -> list[tuple[int, int, int]]:
    hits = []
    for track in mid.tracks:
        absolute_tick = 0
        for message in track:
            absolute_tick += message.time
            if (
                message.type == "note_on"
                and message.velocity > 0
                and message.channel == 9
            ):
                hits.append((absolute_tick, message.note, message.velocity))
    return hits


def _drum_hits_seconds(mid: mido.MidiFile) -> list[tuple[float, int, int]]:
    """Return channel-10 note-ons in wall-clock seconds."""
    tempo = mido.bpm2tempo(120)
    elapsed = 0.0
    hits = []
    for message in mido.merge_tracks(mid.tracks):
        elapsed += mido.tick2second(message.time, mid.ticks_per_beat, tempo)
        if message.type == "set_tempo":
            tempo = message.tempo
        elif (
            message.type == "note_on"
            and message.velocity > 0
            and message.channel == 9
        ):
            hits.append((elapsed, message.note, message.velocity))
    return hits


def _two_means_boundary(values: np.ndarray) -> tuple[float, float, float]:
    """Fit a deterministic two-level model to one stem's candidate strengths."""
    if not len(values):
        raise PipelineError("cannot cluster an empty onset-strength array")
    if len(values) == 1:
        value = float(values[0])
        return value, value, value
    low, high = np.quantile(values, [0.25, 0.75])
    for _ in range(100):
        high_group = np.abs(values - high) < np.abs(values - low)
        next_low = float(values[~high_group].mean()) if (~high_group).any() else low
        next_high = float(values[high_group].mean()) if high_group.any() else high
        if abs(next_low - low) + abs(next_high - high) < 1e-6:
            break
        low, high = next_low, next_high
    if low > high:
        low, high = high, low
    return float(low), float(high), float((low + high) / 2)


def _separated_onset_candidates(
    path: Path,
    instrument: str,
) -> list[DrumCandidate]:
    """Detect attacks in one separated stem and reject its quiet bleed cluster."""
    audio, sample_rate = sf.read(str(path), always_2d=True)
    signal = audio.mean(axis=1).astype(np.float32)
    hop_length = 256
    envelope = librosa.onset.onset_strength(
        y=signal,
        sr=sample_rate,
        hop_length=hop_length,
    )
    frames = librosa.onset.onset_detect(
        onset_envelope=envelope,
        sr=sample_rate,
        hop_length=hop_length,
        units="frames",
        normalize=True,
        delta=0.10,
        wait=max(1, round(0.045 * sample_rate / hop_length)),
    )
    if not len(frames):
        return []

    rms = librosa.feature.rms(
        y=signal,
        frame_length=2048,
        hop_length=hop_length,
    )[0]
    strengths_db = np.asarray(
        [
            20
            * np.log10(
                np.max(rms[max(0, frame - 1) : frame + 3]) + 1e-12
            )
            for frame in frames
        ]
    )
    low, high, boundary = _two_means_boundary(strengths_db)
    # If there is no meaningful quiet/loud split, all locally prominent
    # attacks belong to the one level represented by this stem.
    if high - low < 6.0 or len(frames) < 4:
        boundary = float(strengths_db.min())
    scale = max(1.0, high - boundary)
    times = librosa.frames_to_time(
        frames,
        sr=sample_rate,
        hop_length=hop_length,
    )
    high_strengths = strengths_db[strengths_db >= boundary]
    velocity_low, velocity_high = np.quantile(high_strengths, [0.10, 0.90])
    velocity_scale = max(1.0, float(velocity_high - velocity_low))
    return [
        DrumCandidate(
            time_s=float(time),
            instrument=instrument,
            confidence=float((strength - boundary) / scale),
            velocity=int(
                np.clip(
                    60 + 60 * (strength - velocity_low) / velocity_scale,
                    45,
                    127,
                )
            ),
        )
        for time, strength in zip(times, strengths_db, strict=True)
    ]


def _strongest_per_attack(
    candidates: list[DrumCandidate],
    tolerance_s: float = 0.030,
) -> list[DrumCandidate]:
    """Choose one class when separated cymbal stems fire for the same attack."""
    ordered = sorted(candidates, key=lambda candidate: candidate.time_s)
    groups: list[list[DrumCandidate]] = []
    for candidate in ordered:
        if (
            not groups
            or candidate.time_s - groups[-1][0].time_s > tolerance_s
        ):
            groups.append([candidate])
        else:
            groups[-1].append(candidate)
    return [
        max(group, key=lambda candidate: candidate.confidence)
        for group in groups
    ]


def _snap_to_prior_attacks(
    candidates: list[DrumCandidate],
    priors: list[tuple[float, int, int]],
    tolerance_s: float = 0.050,
) -> list[DrumCandidate]:
    """Reuse a nearby neural onset time without trusting its old class label."""
    pairs = sorted(
        (abs(candidate.time_s - prior[0]), candidate_index, prior_index)
        for candidate_index, candidate in enumerate(candidates)
        for prior_index, prior in enumerate(priors)
        if abs(candidate.time_s - prior[0]) <= tolerance_s
    )
    candidate_to_prior = {}
    used_priors = set()
    for _, candidate_index, prior_index in pairs:
        if candidate_index in candidate_to_prior or prior_index in used_priors:
            continue
        candidate_to_prior[candidate_index] = prior_index
        used_priors.add(prior_index)
    return [
        DrumCandidate(
            time_s=priors[candidate_to_prior[index]][0],
            instrument=candidate.instrument,
            confidence=candidate.confidence,
            velocity=priors[candidate_to_prior[index]][2],
            prior_aligned=True,
        )
        if index in candidate_to_prior
        else candidate
        for index, candidate in enumerate(candidates)
    ]


def _candidate_is_supported(
    candidate: DrumCandidate,
    whole_onsets: list[float],
) -> bool:
    """Require strong stem evidence or three-way marginal corroboration."""
    if candidate.confidence >= 0:
        return True
    if (
        candidate.confidence < -EVIDENCE_HYSTERESIS
        or not candidate.prior_aligned
        or not whole_onsets
    ):
        return False
    return _has_nearby_onset(candidate.time_s, whole_onsets)


def _has_nearby_onset(
    time_s: float,
    onsets: list[float],
    tolerance_s: float = ONSET_MATCH_TOLERANCE_S,
) -> bool:
    """Return whether a sorted onset stream independently supports a time."""
    if not onsets:
        return False
    index = bisect_right(onsets, time_s)
    neighbors = onsets[max(0, index - 1) : index + 1]
    return any(abs(onset - time_s) <= tolerance_s for onset in neighbors)


def _cluster_tom_resonances(values: np.ndarray) -> tuple[np.ndarray, list[int]]:
    """Select one, two, or three stable resonance groups by silhouette."""
    if len(values) < 4 or np.ptp(values) < 5.0:
        return np.zeros(len(values), dtype=int), [47]

    options = []
    for cluster_count in (2, 3):
        if len(values) < cluster_count * 2:
            continue
        centers = np.quantile(
            values,
            (np.arange(cluster_count) + 0.5) / cluster_count,
        )
        for _ in range(100):
            labels = np.argmin(
                np.abs(values[:, None] - centers),
                axis=1,
            )
            if any((labels == index).sum() < 2 for index in range(cluster_count)):
                break
            next_centers = np.asarray(
                [values[labels == index].mean() for index in range(cluster_count)]
            )
            if np.allclose(centers, next_centers):
                break
            centers = next_centers
        if any((labels == index).sum() < 2 for index in range(cluster_count)):
            continue
        ordered_centers = np.sort(centers)
        if np.diff(ordered_centers).min() < 5.0:
            continue

        silhouettes = []
        for value_index, value in enumerate(values):
            own = labels[value_index]
            own_values = values[labels == own]
            intra = (
                np.abs(own_values - value).sum() / (len(own_values) - 1)
                if len(own_values) > 1
                else 0.0
            )
            nearest_other = min(
                np.abs(values[labels == other] - value).mean()
                for other in range(cluster_count)
                if other != own
            )
            silhouettes.append(
                (nearest_other - intra) / max(nearest_other, intra, 1e-9)
            )
        options.append(
            (float(np.mean(silhouettes)), labels.copy(), centers.copy())
        )

    if not options:
        return np.zeros(len(values), dtype=int), [47]
    score, labels, centers = max(options, key=lambda option: option[0])
    if score < 0.55:
        return np.zeros(len(values), dtype=int), [47]
    cluster_count = len(centers)
    pitch_order = [43, 50] if cluster_count == 2 else [43, 47, 50]
    center_order = np.argsort(centers)
    cluster_pitches = [0] * cluster_count
    for rank, cluster_index in enumerate(center_order):
        cluster_pitches[int(cluster_index)] = pitch_order[rank]
    return labels, cluster_pitches


def _assign_tom_pitches(
    values: np.ndarray,
    strong_mask: np.ndarray,
) -> list[int]:
    """Fit tom bands from strong hits, then assign marginal corroborated hits."""
    if not len(values):
        return []
    fit_values = values[strong_mask]
    if not len(fit_values):
        fit_values = values
    fit_labels, cluster_pitches = _cluster_tom_resonances(fit_values)
    centers = np.asarray(
        [
            fit_values[fit_labels == index].mean()
            for index in range(len(cluster_pitches))
        ]
    )
    labels = np.argmin(np.abs(values[:, None] - centers), axis=1)
    return [cluster_pitches[int(label)] for label in labels]


def _tom_pitch_map(
    candidates: list[DrumCandidate],
    tom_stem: Path,
) -> dict[DrumCandidate, int]:
    """Cluster an isolated tom stem by resonance into stable GM tom groups."""
    if not candidates:
        return {}
    audio, sample_rate = sf.read(str(tom_stem), always_2d=True)
    signal = audio.mean(axis=1)
    window_length = 8192
    window = np.hanning(window_length)
    frequencies = np.fft.rfftfreq(window_length, 1 / sample_rate)
    band = (frequencies >= 55) & (frequencies <= 450)
    band_frequencies = frequencies[band]
    features = []
    for candidate in candidates:
        start = max(0, round((candidate.time_s - 0.010) * sample_rate))
        segment = signal[start : start + window_length]
        segment = np.pad(segment, (0, max(0, window_length - len(segment))))
        magnitude = np.abs(np.fft.rfft(segment * window))[band]
        features.append(
            float(np.sum(band_frequencies * magnitude) / np.sum(magnitude))
        )
    pitches = _assign_tom_pitches(
        np.asarray(features),
        np.asarray([candidate.confidence >= 0 for candidate in candidates]),
    )
    return {
        candidate: pitch
        for candidate, pitch in zip(candidates, pitches, strict=True)
    }


def _write_classified_midi(
    adtof_mid: Path,
    separated: dict[str, Path],
    out: Path,
    drum_stem: Path | None = None,
) -> None:
    """Fuse ADTOF onset priors with six separated instrument identities."""
    separated_duration = min(
        sf.info(str(path)).duration for path in separated.values()
    )
    baseline = [
        hit
        for hit in _drum_hits_seconds(mido.MidiFile(str(adtof_mid)))
        if hit[0] <= separated_duration + 0.050
    ]
    whole_onsets = (
        sorted(
            candidate.time_s
            for candidate in _separated_onset_candidates(drum_stem, "whole")
            if candidate.confidence >= 0
        )
        if drum_stem is not None
        else []
    )
    separated_snares = _snap_to_prior_attacks(
        _separated_onset_candidates(separated["snare"], "snare"),
        [hit for hit in baseline if hit[1] == 38],
    )
    # A baseline snare is retained only when the separated snare stem has a
    # strong attack within the snap window. Independently strong separated
    # attacks recover snares that the baseline omitted. A marginal candidate
    # inside the normalized boundary hysteresis is retained only when both the
    # neural prior and the whole-drum onset detector corroborate it. Deeply
    # rejected bleed is never revived. This validates each hit from independent
    # audio evidence without imposing a backbeat or bar-position rule.
    snares = [
        candidate
        for candidate in separated_snares
        if _candidate_is_supported(candidate, whole_onsets)
    ]

    membranes = [
        candidate
        for instrument in ("kick", "toms")
        for candidate in _separated_onset_candidates(
            separated[instrument], instrument
        )
    ]
    membranes = _snap_to_prior_attacks(
        membranes,
        [hit for hit in baseline if hit[1] in (35, 47)],
    )
    membranes = [
        candidate
        for candidate in membranes
        if _candidate_is_supported(candidate, whole_onsets)
    ]

    # Ringing cymbal stems produce many tail/retrigger peaks and their separated
    # labels can flicker from hit to hit. Use the neural plate stream for both
    # attack time and coarse class, and require the independent whole-drum onset
    # detector to support it. ADTOF's pitch 49 means its combined CY+RD class;
    # serializing it as GM 49 does not claim crash-versus-ride identity. Never
    # create extra cymbal attacks from separated plate-stem peaks.
    plate_instruments = {42: "hh", 49: "crash", 51: "ride"}
    plates = [
        DrumCandidate(
            time_s=time_s,
            instrument=plate_instruments[pitch],
            confidence=1.0,
            velocity=velocity,
            prior_aligned=True,
        )
        for time_s, pitch, velocity in baseline
        if pitch in plate_instruments
        and (
            drum_stem is None
            or _has_nearby_onset(time_s, whole_onsets)
        )
    ]

    tom_candidates = [
        candidate for candidate in membranes if candidate.instrument == "toms"
    ]
    tom_pitches = _tom_pitch_map(tom_candidates, separated["toms"])
    fixed_pitches = {
        "kick": 35,
        "snare": 38,
        "hh": 42,
        "ride": 51,
        "crash": 49,
    }
    notes = []
    for candidate in snares + membranes + plates:
        pitch = (
            tom_pitches[candidate]
            if candidate.instrument == "toms"
            else fixed_pitches[candidate.instrument]
        )
        notes.append((candidate.time_s, pitch, candidate.velocity))

    # Collapse only identical same-drum attacks that snapped to one prior.
    unique = {}
    for time_s, pitch, velocity in notes:
        key = (round(time_s * 1000), pitch)
        unique[key] = (time_s, pitch, max(velocity, unique.get(key, (0, 0, 0))[2]))

    midi = mido.MidiFile(type=1, ticks_per_beat=480)
    meta = mido.MidiTrack()
    meta.append(
        mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(120), time=0)
    )
    midi.tracks.append(meta)
    drums = mido.MidiTrack()
    midi.tracks.append(drums)
    events = []
    for time_s, pitch, velocity in unique.values():
        tick = round(time_s * 2 * midi.ticks_per_beat)
        events.append(
            (
                tick,
                1,
                mido.Message(
                    "note_on", channel=9, note=pitch, velocity=velocity
                ),
            )
        )
        events.append(
            (
                tick + midi.ticks_per_beat // 8,
                0,
                mido.Message("note_off", channel=9, note=pitch, velocity=0),
            )
        )
    previous_tick = 0
    for tick, _, message in sorted(events, key=lambda event: (event[0], event[1])):
        drums.append(message.copy(time=tick - previous_tick))
        previous_tick = tick
    out.parent.mkdir(parents=True, exist_ok=True)
    midi.save(str(out))


def transcribe(stem: Path, out_dir: Path) -> Path:
    """Transcribe with ADTOF timing and six-stem instrument classification."""
    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="drums-to-gp-classify-") as work:
        work_path = Path(work)
        adtof_mid = _transcribe_adtof(stem, work_path / "adtof")
        separated = _separate_drum_stems(stem, work_path / "stems")
        dst = out_dir / f"{stem.stem}.mid"
        _write_classified_midi(adtof_mid, separated, dst, drum_stem=stem)
    return dst


def _duration_for_slots_per_quarter(slots_per_quarter: int) -> gp.Duration:
    if slots_per_quarter == 2:
        return gp.Duration(value=8)
    if slots_per_quarter == 3:
        return gp.Duration(value=8, tuplet=gp.Tuplet(enters=3, times=2))
    if slots_per_quarter == 4:
        return gp.Duration(value=16)
    if slots_per_quarter == 6:
        return gp.Duration(value=16, tuplet=gp.Tuplet(enters=3, times=2))
    if slots_per_quarter == 8:
        return gp.Duration(value=32)
    if slots_per_quarter == 12:
        return gp.Duration(value=32, tuplet=gp.Tuplet(enters=3, times=2))
    if slots_per_quarter == 16:
        return gp.Duration(value=64)
    raise PipelineError(f"unsupported slots per quarter: {slots_per_quarter}")


def _write_verified_gp5(
    song: gp.Song,
    out: Path,
    expected_note_grid: list[tuple[tuple[tuple[int, int], ...], ...]],
) -> None:
    """Write GP5 and verify serialized pitches, dynamics, and rhythmic slots."""
    out.parent.mkdir(parents=True, exist_ok=True)
    try:
        guitarpro.write(song, str(out), version=(5, 1, 0))
        parsed = guitarpro.parse(str(out))
    except Exception as error:
        raise PipelineError(f"Guitar Pro 5 export failed: {error}") from error
    if not parsed.tracks or not parsed.tracks[0].isPercussionTrack:
        raise PipelineError("Guitar Pro 5 verification found no percussion track")

    actual_note_grid = [
        tuple(
            tuple(sorted((note.value, note.velocity) for note in beat.notes))
            for beat in measure.voices[0].beats
        )
        for measure in parsed.tracks[0].measures
    ]
    if actual_note_grid == expected_note_grid:
        return

    if len(actual_note_grid) != len(expected_note_grid):
        detail = (
            f"expected {len(expected_note_grid)} measures, serialized "
            f"{len(actual_note_grid)}"
        )
    else:
        detail = "unknown grid mismatch"
        for measure_index, (expected, actual) in enumerate(
            zip(expected_note_grid, actual_note_grid, strict=True), start=1
        ):
            if expected == actual:
                continue
            if len(expected) != len(actual):
                detail = (
                    f"measure {measure_index}: expected {len(expected)} slots, "
                    f"serialized {len(actual)}"
                )
                break
            for slot_index, (expected_notes, actual_notes) in enumerate(
                zip(expected, actual, strict=True)
            ):
                if expected_notes != actual_notes:
                    detail = (
                        f"measure {measure_index}, slot {slot_index}: expected "
                        f"{expected_notes}, serialized {actual_notes}"
                    )
                    break
            break
    raise PipelineError(f"Guitar Pro 5 semantic verification failed: {detail}")


def _gp5_velocity(velocity: int) -> int:
    """Return the velocity represented by GP5's eight dynamic levels."""
    dynamic = max(1, min(8, int((velocity + 1) / 16)))
    return 16 * dynamic - 1


def gp5_to_midi(gp5_path: Path, out: Path) -> None:
    """Convert a GP5 percussion score to tempo-tagged GM drum MIDI."""
    try:
        song = guitarpro.parse(str(gp5_path))
    except Exception as error:
        raise PipelineError(f"cannot parse Guitar Pro file: {error}") from error
    if not song.tracks or not song.tracks[0].isPercussionTrack:
        raise PipelineError("Guitar Pro file contains no percussion track")

    quarter_time = gp.Duration.quarterTime
    midi = mido.MidiFile(type=1, ticks_per_beat=quarter_time)
    meta = mido.MidiTrack()
    midi.tracks.append(meta)

    tempo_events = [
        (0, mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(song.tempo)))
    ]
    meter_events = []
    previous_meter = None
    note_events = []
    for measure in song.tracks[0].measures:
        measure_tick = measure.header.start - quarter_time
        meter = (
            measure.header.timeSignature.numerator,
            measure.header.timeSignature.denominator.value,
        )
        if meter != previous_meter:
            meter_events.append(
                (
                    measure_tick,
                    mido.MetaMessage(
                        "time_signature",
                        numerator=meter[0],
                        denominator=meter[1],
                    ),
                )
            )
            previous_meter = meter
        for voice in measure.voices:
            for beat in voice.beats:
                tick = beat.start - quarter_time
                change = beat.effect.mixTableChange
                if change is not None and change.tempo is not None:
                    tempo_events.append(
                        (
                            tick,
                            mido.MetaMessage(
                                "set_tempo",
                                tempo=mido.bpm2tempo(change.tempo.value),
                            ),
                        )
                    )
                for note in beat.notes:
                    note_events.append(
                        (
                            tick,
                            1,
                            mido.Message(
                                "note_on",
                                channel=9,
                                note=note.value,
                                velocity=note.velocity,
                            ),
                        )
                    )
                    note_events.append(
                        (
                            tick + quarter_time // 8,
                            0,
                            mido.Message(
                                "note_off",
                                channel=9,
                                note=note.value,
                                velocity=0,
                            ),
                        )
                    )

    last_tick = 0
    for tick, message in sorted(
        tempo_events + meter_events, key=lambda event: event[0]
    ):
        meta.append(message.copy(time=tick - last_tick))
        last_tick = tick

    drums = mido.MidiTrack()
    midi.tracks.append(drums)
    last_tick = 0
    for tick, _, message in sorted(note_events, key=lambda event: (event[0], event[1])):
        drums.append(message.copy(time=tick - last_tick))
        last_tick = tick

    out.parent.mkdir(parents=True, exist_ok=True)
    midi.save(str(out))


def _midi_quarter_times(midi: mido.MidiFile, count: int) -> list[float]:
    tempo_events = []
    for track_index, track in enumerate(midi.tracks):
        absolute_tick = 0
        for message_index, message in enumerate(track):
            absolute_tick += message.time
            if message.type == "set_tempo":
                tempo_events.append(
                    (absolute_tick, track_index, message_index, message.tempo)
                )
    tempo_events.sort()

    result = []
    current_tick = 0
    current_seconds = 0.0
    tempo = mido.bpm2tempo(120)
    event_index = 0
    for quarter in range(count):
        target_tick = quarter * midi.ticks_per_beat
        while (
            event_index < len(tempo_events)
            and tempo_events[event_index][0] <= target_tick
        ):
            event_tick, _, _, next_tempo = tempo_events[event_index]
            current_seconds += mido.tick2second(
                event_tick - current_tick, midi.ticks_per_beat, tempo
            )
            current_tick = event_tick
            tempo = next_tempo
            event_index += 1
        current_seconds += mido.tick2second(
            target_tick - current_tick, midi.ticks_per_beat, tempo
        )
        current_tick = target_tick
        result.append(current_seconds)
    return result


def _explicit_measure_tempos(
    midi: mido.MidiFile, measure_starts: list[float]
) -> list[int] | None:
    """Return a MIDI's explicit tempo map, or None for a single global tempo."""
    events = []
    for track_index, track in enumerate(midi.tracks):
        absolute_tick = 0
        for message_index, message in enumerate(track):
            absolute_tick += message.time
            if message.type == "set_tempo":
                events.append(
                    (absolute_tick, track_index, message_index, message.tempo)
                )
    if len(events) <= 1:
        return None
    events.sort()

    result = []
    tempo = mido.bpm2tempo(120)
    event_index = 0
    for measure_start in measure_starts[:-1]:
        target_tick = round(measure_start * midi.ticks_per_beat)
        while event_index < len(events) and events[event_index][0] <= target_tick:
            tempo = events[event_index][3]
            event_index += 1
        result.append(round(mido.tempo2bpm(tempo)))
    return result


def _gp5_semantics(song: gp.Song) -> tuple:
    quarter_time = gp.Duration.quarterTime
    meters = tuple(
        (
            measure.header.start - quarter_time,
            measure.header.timeSignature.numerator,
            measure.header.timeSignature.denominator.value,
        )
        for measure in song.tracks[0].measures
    )

    tempo_events = [(0, song.tempo)]
    notes = []
    for measure in song.tracks[0].measures:
        for voice in measure.voices:
            for beat in voice.beats:
                tick = beat.start - quarter_time
                change = beat.effect.mixTableChange
                if change is not None and change.tempo is not None:
                    tempo_events.append((tick, change.tempo.value))
                notes.extend(
                    (tick, note.value, note.velocity) for note in beat.notes
                )

    normalized_tempos = []
    for tick, tempo in sorted(tempo_events):
        if normalized_tempos and normalized_tempos[-1][0] == tick:
            normalized_tempos[-1] = (tick, tempo)
        elif not normalized_tempos or normalized_tempos[-1][1] != tempo:
            normalized_tempos.append((tick, tempo))
    return meters, tuple(normalized_tempos), tuple(sorted(notes))


def _include_alternative(header: gp.MeasureHeader, pass_number: int) -> bool:
    return (
        header.repeatAlternative == 0
        or bool(header.repeatAlternative & (1 << (pass_number - 1)))
    )


def _expand_repeat_group(group: gp.RepeatGroup, passes: int) -> list[gp.MeasureHeader]:
    if not group.closings:
        return list(group.measureHeaders)
    if len(group.closings) != 1:
        raise PipelineError("reference GP5 has an unsupported nested repeat group")

    closing = group.closings[0]
    closing_index = group.measureHeaders.index(closing)
    repeated = group.measureHeaders[: closing_index + 1]
    ending = group.measureHeaders[closing_index + 1 :]
    expanded = []
    for pass_number in range(1, passes + 1):
        expanded.extend(
            header
            for header in repeated
            if _include_alternative(header, pass_number)
        )
    expanded.extend(
        header for header in ending if _include_alternative(header, passes)
    )
    return expanded


def _reference_measure_specs(
    path: Path, minimum_quarters: float
) -> list[tuple[int, int]]:
    """Unroll a GP5's meter/repeats, fitting ambiguous repeat counts to audio."""
    try:
        song = guitarpro.parse(str(path))
    except Exception as error:
        raise PipelineError(f"cannot parse reference Guitar Pro file: {error}") from error

    groups = []
    seen = set()
    for header in song.measureHeaders:
        identity = id(header.repeatGroup)
        if identity not in seen:
            seen.add(identity)
            groups.append(header.repeatGroup)

    options = []
    for group in groups:
        if not group.closings:
            options.append((1,))
            continue
        repeat_count = group.closings[0].repeatClose
        if repeat_count <= 1:
            options.append((2,))
        else:
            # GP files in the wild disagree on whether a displayed repeat
            # count includes the first pass. Audio length resolves it safely.
            options.append((repeat_count, repeat_count + 1))

    candidates = []
    for pass_counts in product(*options):
        expanded = []
        for group, passes in zip(groups, pass_counts, strict=True):
            expanded.extend(_expand_repeat_group(group, passes))
        quarters = sum(header.length / gp.Duration.quarterTime for header in expanded)
        candidates.append((quarters, expanded))

    long_enough = [candidate for candidate in candidates if candidate[0] >= minimum_quarters]
    if long_enough:
        _, selected = min(long_enough, key=lambda candidate: candidate[0])
    else:
        _, selected = max(candidates, key=lambda candidate: candidate[0])
    return [
        (header.timeSignature.numerator, header.timeSignature.denominator.value)
        for header in selected
    ]


def _adaptive_slots_per_quarter(
    hit_times: list[float],
    hit_beats: list[float],
    measure_start: float,
    beat_times: list[float],
) -> int:
    if not hit_beats:
        return 2
    beat_axis = np.arange(len(beat_times), dtype=float)
    event_times = np.asarray(hit_times)
    coordinates = np.asarray(hit_beats)
    for slots_per_quarter in ADAPTIVE_SLOTS_PER_QUARTER:
        quantized = (
            measure_start
            + np.round((coordinates - measure_start) * slots_per_quarter)
            / slots_per_quarter
        )
        quantized_times = np.interp(quantized, beat_axis, beat_times)
        errors = np.abs(quantized_times - event_times)
        if np.quantile(errors, 0.9) <= 0.045 and errors.max() <= 0.080:
            return slots_per_quarter
    return ADAPTIVE_SLOTS_PER_QUARTER[-1]


def _same_pitch_collision_count(
    events: list[tuple[float, float, int, int]],
    measure_start: float,
    slots_per_quarter: int,
) -> int:
    quantized = [
        (round((coordinate - measure_start) * slots_per_quarter), pitch)
        for _, coordinate, pitch, _ in events
    ]
    return len(quantized) - len(set(quantized))


def _has_exact_straight_32nd(
    events: list[tuple[float, float, int, int]],
    measure_start: float,
) -> bool:
    """Recognize serialized odd 32nd positions during a GP round trip."""
    for _, coordinate, _, _ in events:
        local = coordinate - measure_start
        fine_position = local * 8
        coarse_position = local * 4
        if (
            abs(fine_position - round(fine_position)) < 1e-6
            and abs(coarse_position - round(coarse_position)) > 1e-6
        ):
            return True
    return False


def _has_exact_straight_64th(
    events: list[tuple[float, float, int, int]],
    measure_start: float,
) -> bool:
    """Recognize serialized odd 64th positions during a GP round trip."""
    for _, coordinate, _, _ in events:
        local = coordinate - measure_start
        fine_position = local * 16
        coarse_position = local * 8
        if (
            abs(fine_position - round(fine_position)) < 1e-6
            and abs(coarse_position - round(coarse_position)) > 1e-6
        ):
            return True
    return False


def _phase_locked_integer_tempos(
    measure_starts: list[float],
    measure_times: list[float],
) -> list[int]:
    """Quantize tempo to integer BPM without accumulating phase drift."""
    origin = measure_times[0]
    elapsed = 0.0
    result = []
    for index, (start, end) in enumerate(
        zip(measure_starts[:-1], measure_starts[1:], strict=True)
    ):
        target_end = measure_times[index + 1] - origin
        required_duration = target_end - elapsed
        if required_duration <= 0:
            raise PipelineError("beat grid does not advance monotonically")
        quarter_count = end - start
        ideal_bpm = quarter_count * 60 / required_duration
        center_bpm = min(300, max(30, round(ideal_bpm)))
        candidates = range(max(30, center_bpm - 2), min(300, center_bpm + 2) + 1)
        tempo = min(
            candidates,
            key=lambda bpm: abs(
                elapsed + quarter_count * 60 / bpm - target_end
            ),
        )
        elapsed += quarter_count * 60 / tempo
        result.append(tempo)
    return result


def _export_gp5_beat_synced(
    midi: mido.MidiFile,
    mid_path: Path,
    out: Path,
    beat_times: list[float],
    subdivision: int | None,
    structure_gp5: Path | None,
) -> None:
    hits = _drum_hits_seconds(midi)
    if not hits:
        raise PipelineError("MIDI contains no channel-10 drum note-ons")
    if len(beat_times) < 2:
        raise PipelineError("beat-synced export needs at least two beat times")

    beat_axis = np.arange(len(beat_times), dtype=float)
    hit_seconds = np.asarray([hit[0] for hit in hits])
    hit_beats = np.interp(hit_seconds, beat_times, beat_axis)
    minimum_quarters = ceil(float(hit_beats.max()))
    if structure_gp5 is not None:
        measure_specs = _reference_measure_specs(structure_gp5, minimum_quarters)
    else:
        measure_specs = [(4, 4)] * ceil(minimum_quarters / 4)

    measure_starts = [0.0]
    for numerator, denominator in measure_specs:
        measure_starts.append(
            measure_starts[-1] + numerator * 4 / denominator
        )
    while measure_starts[-1] < minimum_quarters:
        measure_specs.append((4, 4))
        measure_starts.append(measure_starts[-1] + 4)

    measure_times = [
        float(np.interp(coordinate, beat_axis, beat_times))
        for coordinate in measure_starts
    ]
    for start, end in zip(measure_times[:-1], measure_times[1:], strict=True):
        if end <= start:
            raise PipelineError("beat grid does not advance through the measure structure")

    per_measure: list[list[tuple[float, float, int, int]]] = [
        [] for _ in measure_specs
    ]
    for (seconds, pitch, velocity), coordinate in zip(hits, hit_beats, strict=True):
        measure_index = min(
            bisect_right(measure_starts, float(coordinate)) - 1,
            len(measure_specs) - 1,
        )
        if (
            measure_index + 1 < len(measure_specs)
            and measure_starts[measure_index + 1] - coordinate < 0.15
        ):
            # Drum-transcription peaks commonly lead the broader onset used by
            # the beat tracker by 20-40 ms. Treat that as the following
            # downbeat instead of crushing it into the preceding bar's last
            # slot.
            measure_index += 1

        # GP5 can encode only one integer tempo for this measure. Map attacks
        # through the same linear measure-time model used for playback instead
        # of preserving short beat-tracker jitter that the score cannot play.
        measure_start = measure_starts[measure_index]
        measure_quarters = measure_starts[measure_index + 1] - measure_start
        measure_time_start = measure_times[measure_index]
        measure_duration = measure_times[measure_index + 1] - measure_time_start
        coordinate = measure_start + (
            (seconds - measure_time_start) / measure_duration * measure_quarters
        )
        coordinate = max(
            measure_start,
            min(
                float(coordinate),
                float(np.nextafter(measure_starts[measure_index + 1], measure_start)),
            ),
        )
        per_measure[measure_index].append(
            (seconds, float(coordinate), pitch, velocity)
        )

    explicit_tempos = _explicit_measure_tempos(midi, measure_starts)
    if subdivision is None:
        measure_grids = [
            _adaptive_slots_per_quarter(
                [event[0] for event in events],
                [event[1] for event in events],
                measure_starts[index],
                beat_times,
            )
            for index, events in enumerate(per_measure)
        ]
    elif subdivision == 16:
        # Preserve the readable straight-sixteenth default, escalating only
        # affected measures far enough to retain every distinct same-drum hit.
        measure_grids = []
        for index, events in enumerate(per_measure):
            if _has_exact_straight_64th(events, measure_starts[index]):
                start_grid = 16
            elif _has_exact_straight_32nd(events, measure_starts[index]):
                start_grid = 8
            else:
                start_grid = 4
            candidates = [
                grid for grid in (4, 8, 16) if grid >= start_grid
            ]
            best_grid = min(
                candidates,
                key=lambda grid: (
                    _same_pitch_collision_count(
                        events, measure_starts[index], grid
                    ),
                    grid,
                ),
            )
            measure_grids.append(best_grid)
    else:
        measure_grids = [subdivision // 4] * len(measure_specs)

    for start, end in zip(measure_starts[:-1], measure_starts[1:], strict=True):
        if end <= start:
            raise PipelineError("measure structure does not advance")
    if explicit_tempos is not None:
        measure_tempos = explicit_tempos
    else:
        measure_tempos = _phase_locked_integer_tempos(
            measure_starts, measure_times
        )

    song = gp.Song()
    song.title = mid_path.stem.removesuffix(".tempo")
    song.tempo = measure_tempos[0]
    song.tempoName = f"{song.tempo} BPM (audio-tracked)"
    track = song.tracks[0]
    track.name = "Drums"
    track.isPercussionTrack = True
    track.channel = gp.MidiChannel(channel=9, effectChannel=9, instrument=0)
    track.strings = [gp.GuitarString(number=i, value=0) for i in range(1, 8)]
    song.measureHeaders.clear()
    track.measures.clear()

    header_start = gp.Duration.quarterTime
    previous_tempo = song.tempo
    expected_note_grid: list[
        tuple[tuple[tuple[int, int], ...], ...]
    ] = []
    for measure_index, ((numerator, denominator), slots_per_quarter) in enumerate(
        zip(measure_specs, measure_grids, strict=True)
    ):
        measure_start = measure_starts[measure_index]
        measure_quarters = measure_starts[measure_index + 1] - measure_start
        slot_count = round(measure_quarters * slots_per_quarter)
        collisions = _same_pitch_collision_count(
            per_measure[measure_index],
            measure_start,
            slots_per_quarter,
        )
        if collisions:
            raise PipelineError(
                f"quantization would collapse {collisions} same-drum hit(s) "
                f"in measure {measure_index + 1} even on a "
                f"{slots_per_quarter * 4}th-note grid"
            )
        quantized: dict[int, dict[int, int]] = defaultdict(dict)
        for seconds, coordinate, pitch, velocity in per_measure[measure_index]:
            slot = max(
                0,
                min(
                    round((coordinate - measure_start) * slots_per_quarter),
                    slot_count - 1,
                ),
            )
            quantized[slot][pitch] = max(velocity, quantized[slot].get(pitch, 0))

        expected_note_grid.append(
            tuple(
                tuple(
                    sorted(
                        (pitch, _gp5_velocity(velocity))
                        for pitch, velocity in quantized.get(
                            local_slot, {}
                        ).items()
                    )
                )
                for local_slot in range(slot_count)
            )
        )
        header = gp.MeasureHeader(
            number=measure_index + 1,
            start=header_start,
            timeSignature=gp.TimeSignature(
                numerator=numerator,
                denominator=gp.Duration(value=denominator),
            ),
        )
        song.measureHeaders.append(header)
        measure = gp.Measure(track, header)
        track.measures.append(measure)
        voice = measure.voices[0]
        duration = _duration_for_slots_per_quarter(slots_per_quarter)
        measure_tempo = measure_tempos[measure_index]

        for local_slot in range(slot_count):
            slot_hits = quantized.get(local_slot, {})
            if len(slot_hits) > 7:
                raise PipelineError(
                    f"more than seven simultaneous drum voices in measure "
                    f"{measure_index + 1}, slot {local_slot}"
                )
            beat = gp.Beat(
                voice,
                duration=duration,
                status=(gp.BeatStatus.normal if slot_hits else gp.BeatStatus.rest),
            )
            if local_slot == 0 and measure_tempo != previous_tempo:
                beat.effect.mixTableChange = gp.MixTableChange(
                    tempo=gp.MixTableItem(value=measure_tempo, allTracks=True),
                    hideTempo=True,
                )
                previous_tempo = measure_tempo
            voice.beats.append(beat)
            for string, (pitch, velocity) in enumerate(
                sorted(slot_hits.items()), start=1
            ):
                beat.notes.append(
                    gp.Note(
                        beat,
                        value=pitch,
                        velocity=velocity,
                        string=string,
                        type=gp.NoteType.normal,
                    )
                )
        header_start += header.length

    _write_verified_gp5(song, out, expected_note_grid)


def verify_gp5_idempotent(path: Path, subdivision: int | None = 16) -> None:
    """Require GP -> MIDI -> GP to preserve score semantics exactly."""
    try:
        original = guitarpro.parse(str(path))
    except Exception as error:
        raise PipelineError(f"cannot parse Guitar Pro file: {error}") from error
    if not original.tracks or not original.tracks[0].isPercussionTrack:
        raise PipelineError("Guitar Pro file contains no percussion track")

    total_quarters = ceil(
        sum(
            measure.header.length / gp.Duration.quarterTime
            for measure in original.tracks[0].measures
        )
    )
    with tempfile.TemporaryDirectory(prefix="drums-to-gp-roundtrip-") as work:
        midi_path = Path(work) / "score.mid"
        roundtrip_path = Path(work) / "score.gp5"
        gp5_to_midi(path, midi_path)
        midi = mido.MidiFile(str(midi_path))
        beat_times = _midi_quarter_times(midi, total_quarters + 2)
        _export_gp5_beat_synced(
            midi,
            midi_path,
            roundtrip_path,
            beat_times,
            subdivision,
            path,
        )
        roundtrip = guitarpro.parse(str(roundtrip_path))

    if _gp5_semantics(original) != _gp5_semantics(roundtrip):
        raise PipelineError(
            "Guitar Pro 5 idempotence verification failed: GP -> MIDI -> GP "
            "changed meter, tempo, note position, pitch, or velocity"
        )


def export_gp5(
    mid_path: Path,
    out: Path,
    subdivision: int | None = 16,
    *,
    beat_times: list[float] | None = None,
    structure_gp5: Path | None = None,
) -> None:
    """Write a readable, quantized Guitar Pro 5 percussion score."""
    if subdivision is not None and subdivision not in SUPPORTED_SUBDIVISIONS:
        raise PipelineError(
            f"unsupported subdivision {subdivision}; choose one of "
            f"{SUPPORTED_SUBDIVISIONS}"
        )

    midi = mido.MidiFile(str(mid_path))
    if beat_times is not None:
        _export_gp5_beat_synced(
            midi,
            mid_path,
            out,
            beat_times,
            subdivision,
            structure_gp5,
        )
        verify_gp5_idempotent(out, subdivision)
        return

    if subdivision is None:
        subdivision = 16
    hits = _drum_hits(midi)
    if not hits:
        raise PipelineError("MIDI contains no channel-10 drum note-ons")

    tempos = [
        message.tempo
        for track in midi.tracks
        for message in track
        if message.type == "set_tempo"
    ]
    source_bpm = mido.tempo2bpm(tempos[0]) if tempos else 120.0
    gp_bpm = round(source_bpm)

    ticks_per_slot = midi.ticks_per_beat * 4 / subdivision
    # GP5 stores integer BPM. Rescale the musical positions to that integer
    # grid so rounding the tempo does not accumulate wall-clock drift.
    tick_scale = gp_bpm / source_bpm
    slots_per_measure = subdivision
    quantized: dict[int, dict[int, int]] = defaultdict(dict)
    for tick, pitch, velocity in hits:
        slot = round(tick * tick_scale / ticks_per_slot)
        quantized[slot][pitch] = max(velocity, quantized[slot].get(pitch, 0))

    last_slot = max(quantized)
    measure_count = last_slot // slots_per_measure + 1
    song = gp.Song()
    song.title = mid_path.stem.removesuffix(".tempo")
    song.tempo = gp_bpm
    song.tempoName = f"{gp_bpm} BPM"

    track = song.tracks[0]
    track.name = "Drums"
    track.isPercussionTrack = True
    track.channel = gp.MidiChannel(channel=9, effectChannel=9, instrument=0)
    track.strings = [gp.GuitarString(number=i, value=0) for i in range(1, 8)]
    song.measureHeaders.clear()
    track.measures.clear()

    measure_length = 4 * gp.Duration.quarterTime
    expected_note_grid = [
        tuple(
            tuple(
                sorted(
                    (pitch, _gp5_velocity(velocity))
                    for pitch, velocity in quantized.get(
                        measure_index * slots_per_measure + local_slot, {}
                    ).items()
                )
            )
            for local_slot in range(slots_per_measure)
        )
        for measure_index in range(measure_count)
    ]

    def beat_duration() -> gp.Duration:
        if subdivision == 12:
            return gp.Duration(value=8, tuplet=gp.Tuplet(enters=3, times=2))
        if subdivision == 24:
            return gp.Duration(value=16, tuplet=gp.Tuplet(enters=3, times=2))
        return gp.Duration(value=subdivision)

    for measure_index in range(measure_count):
        header = gp.MeasureHeader(
            number=measure_index + 1,
            start=gp.Duration.quarterTime + measure_index * measure_length,
        )
        song.measureHeaders.append(header)
        measure = gp.Measure(track, header)
        track.measures.append(measure)
        voice = measure.voices[0]

        for local_slot in range(slots_per_measure):
            global_slot = measure_index * slots_per_measure + local_slot
            slot_hits = quantized.get(global_slot, {})
            if len(slot_hits) > 7:
                raise PipelineError(
                    f"more than seven simultaneous drum voices at slot {global_slot}"
                )
            beat = gp.Beat(
                voice,
                duration=beat_duration(),
                status=(gp.BeatStatus.normal if slot_hits else gp.BeatStatus.rest),
            )
            voice.beats.append(beat)
            for string, (pitch, velocity) in enumerate(
                sorted(slot_hits.items()), start=1
            ):
                beat.notes.append(
                    gp.Note(
                        beat,
                        value=pitch,
                        velocity=velocity,
                        string=string,
                        type=gp.NoteType.normal,
                    )
                )

    _write_verified_gp5(song, out, expected_note_grid)
    verify_gp5_idempotent(out, subdivision)
