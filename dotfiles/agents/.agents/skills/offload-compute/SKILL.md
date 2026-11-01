---
name: offload-compute
description: Offload builds, test suites, benchmarks, simulations, renders, fuzzing, data processing or any other long or heavy computation from this machine to the LAN server's TinyCI sandbox, then fetch the results. Use when a command would run for many minutes or hours, needs more CPU or memory than this machine should spend, or should keep running while this machine sleeps.
---

# Offload compute to TinyCI

TinyCI on the LAN server runs each job in a fresh sandboxed container (a
Kubernetes Pod) and stores its outputs. The client in `scripts/` submits a job
file, follows the run, and fetches the outputs. Use `curl` for run and job
controls.

## The model

- A job is a container image pinned by digest, a shell script, declared
  inputs (files from here) and declared outputs (paths under `/work`). The
  script runs as one `/bin/sh -eu` program in `/work`, as the image's user,
  with no capabilities. Everything outside `/work` is lost when the job ends.
- Jobs are offline. `network: true` gives public internet access, but never
  the LAN, the server or the cluster.
- The job is the unit of caching, stopping and resuming:
  - `cache` (default `true`): a successful job's outputs are reused by an
    identical job, which then does not run. Identity covers the canonical
    job except `cache`, `resume`, `timeout`, `cpu` and `memory` — including
    image, script, inputs, outputs, `needs` and `network` — plus the source
    tree and needed output trees. With caching on, changing only resources
    or timeout does not rerun; changing network, outputs, script or inputs
    does. Set `false` for anything that should run every time: benchmarks,
    fuzzers, downloads that are not pinned.
  - `resume` (default `false`): when the job executes, it starts from the
    latest outputs its key ended with, whatever the last end (including a
    successful `cache: false` run). The script runs again and must read
    those outputs to continue. A changed script or input is a new key and
    starts fresh; saved outputs that have expired start from the inputs.
    `cache: false` alone does not force a clean start: set `resume: false`
    for benchmarks.
- Outputs are captured however a job ends: success, failure, timeout or
  stop. A failed fuzzer keeps its crashes and corpus, and the job stays
  failed with its exit status. A successful exit with a missing declared
  output fails the job; on failure, only the outputs that exist are kept.
  Only a success is cached and lets the jobs that `needs` it run.
- `needs` makes a graph: a job gets the outputs of the jobs it needs, at the
  same paths, once they all succeeded. Without `needs`, jobs are
  independent. A path may appear only once across inputs and needed outputs
  unless every entry is identical. A job can also take the outputs of an
  earlier run; see "Reusing outputs".
- The server checks a run before any input is hashed or uploaded: `submit`
  asks it first. A field the server does not know, `cpu` above 2, `memory`
  above 8 or a `needs` cycle is refused at once.
- The server runs four jobs at once, each at most 2 CPU and 8 GiB; the
  others queue.
- Runs live in the server's memory for up to 30 days, and a server restart
  clears them. Stored inputs and outputs expire 30 days after they were
  written.

## Job file

JSON. Input paths are relative to the job file's directory, so put it next to
the inputs. They are literal (no globs) and land at the same relative paths
under `/work`.

| Field | Default | Meaning |
|---|---|---|
| `image` | required | `name:tag@sha256:<digest>`; the server pulls it |
| `script` | required | POSIX shell lines, run as one `/bin/sh -eu` program in `/work` |
| `inputs` | required | literal relative paths uploaded into `/work`, or stored outputs (`run:<run>/<job>`, `tree:<digest>`) |
| `outputs` | required | paths under `/work` kept when the job ends; they must exist on success |
| `needs` | `[]` | jobs whose outputs this one receives; they must all succeed |
| `network` | `false` | public internet access; never the LAN |
| `cache` | `true` | reuse a success of an identical job; see "The model" |
| `resume` | `false` | start from the latest outputs of this key when it executes |
| `timeout` | `7200` | whole seconds until the job is stopped; at least 1 |
| `cpu` | `1` | whole cores, 1–2; more is refused at submission |
| `memory` | `1` | whole GiB, 1–8; more is refused, and using more gets the job killed (OOMKilled) |

No other field is allowed: the server refuses a job file with one, so a
misspelling never passes silently.

```json
{
  "version": 1,
  "jobs": {
    "deps": {
      "image": "docker.io/library/python:3.13-slim@sha256:<digest>",
      "network": true,
      "script": ["pip download -r requirements.txt -d wheels"],
      "inputs": ["requirements.txt"],
      "outputs": ["wheels/"]
    },
    "simulate": {
      "image": "docker.io/library/python:3.13-slim@sha256:<digest>",
      "needs": ["deps"],
      "cache": false,
      "resume": true,
      "timeout": 86400,
      "cpu": 2,
      "memory": 8,
      "script": [
        "pip install --no-index --find-links wheels --target /tmp/site -r requirements.txt",
        "PYTHONPATH=/tmp/site python sim.py --checkpoint state/ --out results/"
      ],
      "inputs": ["sim.py", "requirements.txt"],
      "outputs": ["state/", "results/"]
    }
  }
}
```

Rules:

- Pin every image by digest:
  `skopeo inspect --format '{{.Digest}}' docker://docker.io/library/alpine:3.24.3`
  or `docker buildx imagetools inspect docker.io/library/alpine:3.24.3`.
- Everything a job needs comes from its image, its inputs, or a job it
  `needs`. Fetch dependencies in a networked job, pinned by a lockfile with
  hashes so the job stays cacheable.
- Declare the smallest set of inputs the job reads: a directory input
  includes everything beneath it, including dotfiles and caches, and all of
  it becomes part of the job's tree.
- A binary built here only runs in an image with a matching libc. Prefer
  building inside a job.
- Write progress into the outputs as it happens (checkpoints, corpus), so a
  stop keeps it, and set `resume` to continue from it.
- Declare only outputs the script creates: a missing declared output fails
  a successful job.
- Inputs, logs and outputs are visible to everyone on the LAN through the
  dashboard. Never put secrets in them.

## Limits and pitfalls

- One blob is at most 1 GiB. This applies to each input file and each
  captured output file; split larger files. The client stages inputs under
  `$TMPDIR`, so that filesystem needs room for them. The current client also
  buffers individual files during hashing and upload; use bounded chunks
  for large payloads rather than approaching the protocol limit.
- A job's log is its last 1 MiB; while it runs, the server refreshes a tail
  every 10 s. `follow` prints a compact, filtered stream: state changes, at
  most 30 live lines, and a short final tail. It can miss earlier lines; the
  full log is on the dashboard and at `GET /v1/runs/{run}/jobs/{job}`. Write
  important logs to a declared output file.
- `cpu`, `memory` and `timeout` are whole numbers of at least 1. Memory is
  GiB, timeout seconds. The defaults are 1 core, 1 GiB and 7200 s; a job
  that uses more memory than its limit is killed.
- Scripts run as one POSIX `/bin/sh -eu` program, not necessarily bash. The
  image must provide `/bin/sh`; do not rely on `[[`, arrays, process
  substitution or `pipefail`.
- Input and output paths are literal relative names: `src`, not `./src`.
  `.`, `..` and absolute paths are refused, and there is no glob expansion.
  A directory input includes everything beneath it, including dotfiles.
- Job names must match `[A-Za-z0-9][A-Za-z0-9_.-]{0,127}`.
- Symlinks are uploaded and captured as links, not followed. Declare a
  link's target too (or let it come from the image or `needs`), or it
  dangles.
- Inputs are materialized by the runner and owned by the runner's user. A
  job that runs as a non-root image user can read them but cannot write
  inside input directories; write outputs to new paths, or copy the tree
  first.

## Packaging inputs

Pass source and build outputs as ordinary files or directories in `inputs`.
The client snapshots them, preserves executable bits and relative symlinks
within the input tree, and uploads only file contents the server lacks.
Directory inputs retain reuse of unchanged files when source changes.

Keep dependency setup separate from changing source: use a cached setup job
with a pinned image and lockfile, declare its dependency directory as an
output, and consume it through `needs`. Reuse it across runs with `run:` or
`tree:` as described below.

Archives are optional for large dependency environments or toolchains. Keep
entry order, timestamps and ownership metadata stable when repacking unchanged
contents so their digest stays reusable. Preserve executable bits and relative
symlinks, and extract under `/work`. Prefer building native binaries inside a
job for the target image; uploaded binaries must match its architecture and libc.

### Large archives

Use the helper when an archive is useful; ordinary source trees should still
use directory inputs for reuse of unchanged files:

```sh
node --experimental-strip-types ~/.agents/skills/offload-compute/scripts/pack.ts environment chunks
```

`environment` must be a directory. `chunks` must not exist, its parent must
exist, and it must be outside the source tree. The helper needs GNU tar and
gzip. It streams a deterministic tar.gz into ordered `part-000000` files of
at most 32 MiB, preserves executables and symlinks, and adds owner-write
permission in the archive without changing the source. Failed packaging
removes its new destination and leaves existing destinations alone.

Declare `chunks` as an input. In the job, extract this trusted archive into
a new writable directory; the image must include tar and gzip:

```sh
mkdir environment
cat chunks/part-* | tar --extract --gzip --no-same-owner --file=- --directory=environment
```

The 2026-11-03 probe repeatedly lost the connection on 512 MiB uploads;
32 MiB chunks uploaded successfully. This is a measured workaround, not a
new API limit or an established diagnosis of the disconnect. Packaging and
client staging require disk space in addition to the source; a RAM-backed
`TMPDIR` also spends memory on the staged archive. The job needs room for
both its chunks and the extracted tree, plus its build outputs.

Read-only source directories can prevent extraction in capability-free jobs,
even with delayed directory-mode restoration. Adding owner writes to archived
modes fixed the observed extraction failure without changing the source.
`--no-same-owner` alone does not fix unwritable directories.

## Reusing outputs

An `inputs` entry can name outputs the server already stores, instead of
local files:

- `run:<run-id>/<job>`: the outputs that job of an earlier run ended with;
  the job need not have succeeded
- `tree:<digest>`: a stored tree, such as a job's `output_tree` in its run's status

The entries land at their own paths, as with `needs`; two inputs, or an
input and a needed output, may put something at the same path only if it
is the same entry. No file is downloaded or uploaded again, and the job is
cached by content, so reusing the same outputs again is a cache hit. `run:`
works while the server still holds the run (a restart clears runs);
`tree:` works as long as the files are stored (30 days). If they have
expired, `submit` says so: run the job that made them again. A failed or
cancelled job's outputs are reusable too, which is how a triage job can
consume a failed fuzzer's corpus.

```json
{
  "version": 1,
  "jobs": {
    "analyse": {
      "image": "docker.io/library/python:3.13-slim@sha256:<digest>",
      "script": ["python analyse.py results/ > report.txt"],
      "inputs": ["analyse.py", "run:0f1e2d3c-1111-4222-8333-444455556666/simulate"],
      "outputs": ["report.txt"]
    }
  }
}
```

## Commands

Use the client for file transfers, waiting, and following logs:

```sh
node --experimental-strip-types ~/.agents/skills/offload-compute/scripts/offload.ts submit jobs.json
```

| Command | Does |
|---|---|
| `submit <jobs.json> [--label text]` | has the server check the run, uploads the inputs it lacks, starts the run; prints the run ID and dashboard URL |
| `wait <run> [job]` | blocks until the run or one job finished; prints a compact JSON summary (states, cache hits, errors, output trees); exits 1 unless all succeeded |
| `follow <run> <job>` | prints a compact stream until the job ends: state changes as `# <job>: <state>`, filtered log lines, at most 30 live lines, and a short final tail; exits 1 unless it succeeded |
| `fetch <run> <job> <dest> [path ...]` | writes the job's outputs into `dest`, which must not exist; with paths, only the outputs at or below them; restores modes and removes `dest` if the fetch fails |

Output is JSON, except `follow`. `submit` reports its upload progress on stderr:
the size first, then a line at most every 5 s. A wrong command line exits 2.
The server is `$TINYCI_URL`, `http://nullwave.de:8020` by default.

`wait` with a job prints that job's record (`run_id`, `job`, state, cache hit,
error, output tree). `follow` prefixes state changes with `# <job>: <state>`
and errors with `# error:`; use the dashboard or
`GET /v1/runs/{run}/jobs/{job}` for the unfiltered log.

The usual flow: write the job file, `submit`, give the user the dashboard
URL, then `wait`. `wait` prints a summary without logs; read each job's
`error` there. For a compact log, `follow` the job; for full status, use
the summary `curl` below; for the full log, the dashboard or the job
endpoint. For jobs of hours, run `follow` in the background. Finally,
`fetch` the outputs, or only the ones you need
(`fetch <run> fuzz dest crashes/`).

The dashboard lists the runs by day, with filters and search. For each job
it shows what it needs and what needs it, its definition, its log, and its
output and input files, each a download. A job without outputs says why.

## Job controls

Use `curl` for status and run/job controls:

```sh
tinyci_url="${TINYCI_URL:-http://nullwave.de:8020}"
run_id="<run-id>"
curl --fail-with-body --silent --show-error "$tinyci_url/v1/runs/$run_id/summary"
```

Send a control request with POST, for example to pause a run:

```sh
curl --fail-with-body --silent --show-error --request POST "$tinyci_url/v1/runs/$run_id/pause"
```

| Method | Path | Does |
|---|---|---|
| GET | `/v1/runs` | lists runs without logs |
| GET | `/v1/runs/{run}` | returns the run, its jobs' states and logs |
| GET | `/v1/runs/{run}/summary` | returns the run without job definitions or logs |
| GET | `/v1/runs/{run}/jobs/{job}` | returns one job; add `?logs=0` to omit its log |
| POST | `/v1/runs/{run}/pause` | prevents new jobs of this run from starting; already assigned jobs continue |
| POST | `/v1/runs/{run}/resume` | makes the paused run's queued jobs eligible again |
| POST | `/v1/runs/{run}/cancel` | cancels queued jobs and stops active jobs; terminal, and keeps the outputs produced |
| POST | `/v1/runs/{run}/jobs/{job}/cancel` | stops one job and keeps its outputs |
| POST | `/v1/runs/{run}/jobs/{job}/retry` | reruns a finished job; deletes its cached result and requeues its failed or cancelled dependants |

Run pause/resume controls scheduling. The job file's `resume: true` controls
restoring saved outputs when a job executes; `retry` deletes the cached
result, so a retried job runs. Pause and cancel are refused once every job
has finished, and a cancelled run refuses retries. After a failure or
cancellation, use `fetch` to retrieve the outputs the job produced,
including a fuzzer's failing cases.

## When a job fails

`wait`'s summary carries each job's `error`; the log is separate and can be
empty, for example when the image cannot be pulled. Common cases:

- `exit 137` (often OOMKilled): the job hit its memory limit; raise
  `memory`.
- `DeadlineExceeded`: the job hit `timeout`; raise it, and add
  `resume: true` plus checkpoints for work that takes longer.
- `missing output: ...`: a declared output did not exist on success;
  create it or stop declaring it.
- `job pod cannot start` or an image pull error: check the image digest and
  that the image contains `/bin/sh`.
- `dependency failed` or `dependency cancelled`: fix and retry the
  producer; retry requeues its failed or cancelled dependants.
- `... gone from the store`: an input or output expired (30 days); rerun
  the job that made it, or submit the run again.
- A `run:` input no longer resolves after a server restart: the run is
  gone; use `tree:` while the files are stored, or rerun the producer.
- An unexpected cache hit: set `cache: false`, change the key, or use
  `retry`, which deletes the cached result. A job with `resume` continues
  from its latest outputs.

After a failure or cancellation, `fetch` still retrieves the outputs the
job produced.

## HTTP API

The server describes its API at `$TINYCI_URL/openapi.json`.
