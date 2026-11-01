/**
 * The client for TinyCI on the server: canonical source trees from local
 * files, uploads of what the server lacks, runs, and their outputs. Node
 * built-ins only. The server describes its HTTP API itself, at
 * <server>/openapi.json.
 */
import { createHash } from "node:crypto";
import {
    chmodSync,
    existsSync,
    lstatSync,
    mkdirSync,
    mkdtempSync,
    readdirSync,
    readFileSync,
    readlinkSync,
    rmSync,
    statSync,
    symlinkSync,
    writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { setTimeout as sleep } from "node:timers/promises";

export type TreeEntry =
    | { type: "file"; path: string; digest: string; mode: number; size: number }
    | { type: "directory"; path: string; mode: number }
    | { type: "symlink"; path: string; target: string };

export interface Tree {
    version: 1;
    entries: TreeEntry[];
}

/** One job as a job file declares it; the server fills in what is left out. */
export interface Job {
    image: string;
    script: string[];
    inputs: string[];
    outputs: string[];
    needs?: string[];
    network?: boolean;
    cache?: boolean;
    resume?: boolean;
    timeout?: number;
    cpu?: number;
    memory?: number;
}

export interface JobFile {
    version: 1;
    jobs: Record<string, Job>;
}

/** A job of a run, as the server reports it. */
export interface JobRecord {
    state: string;
    output_tree?: string;
    cache_hit?: boolean;
    error?: string;
    log?: string;
}

export interface Run {
    id: string;
    label: string;
    jobs: Record<string, JobRecord>;
}

/** A job without its definition or log, as the run summary reports it. */
export interface JobSummary {
    state: string;
    cache_hit?: boolean;
    error?: string;
    output_tree?: string;
}

/** Job states after which nothing more happens until someone retries. */
const finishedStates = new Set(["succeeded", "failed", "cancelled"]);

/** The server's largest blob: one input or output file, in bytes. */
export const maxBlobSize = 1024 * 1024 * 1024;

export function sha256(bytes: Buffer | string): string {
    return createHash("sha256").update(bytes).digest("hex");
}

// Path rules, the same the server's runner applies: plain relative names,
// and symlinks that stay inside the tree.

function components(value: string): string[] {
    const result = value.startsWith("/") ? ["/"] : [];

    value.split("/").forEach((part, index) => {
        if (part === "" || (part === "." && index > 0)) return;

        result.push(part);
    });

    return result;
}

export function validateRelativePath(value: string): void {
    if (value === "") throw new Error("empty path");

    if (value.startsWith("/")) throw new Error(`absolute path is not allowed: ${value}`);

    for (const component of components(value)) {
        if (component === "." || component === "..") {
            throw new Error(`path may contain only plain names: ${value}`);
        }
    }
}

export function validateSymlink(path: string, target: string): void {
    if (target.startsWith("/")) throw new Error(`absolute symlink is not allowed: ${path}`);

    let depth = Math.max(components(path).length - 1, 0);

    for (const component of components(target)) {
        if (component === ".") continue;

        if (component === "..") {
            if (depth === 0) throw new Error(`symlink escapes the tree: ${path} -> ${target}`);

            depth -= 1;
        } else {
            depth += 1;
        }
    }
}

/** Throws when `path` below `root` runs through, or ends at, an existing symlink. */
function refuseSymlinkOnPath(root: string, path: string): void {
    let current = root;

    for (const component of components(path)) {
        if (component === ".") continue;

        current = join(current, component);

        if (lstatSync(current, { throwIfNoEntry: false })?.isSymbolicLink()) {
            throw new Error(`refusing to go through a symlink: ${path}`);
        }
    }
}

/** Byte order of the UTF-8 encodings, the order tree entries are kept in. */
function compareUtf8(left: string, right: string): number {
    return Buffer.compare(Buffer.from(left, "utf8"), Buffer.from(right, "utf8"));
}

/**
 * A tree's manifest bytes, which address it. The field order is the one the
 * server's runner writes, so the same files give the same digest everywhere.
 */
export function encodeTree(tree: Tree): string {
    return JSON.stringify({
        version: tree.version,
        entries: tree.entries.map((entry) => {
            switch (entry.type) {
                case "file":
                    return {
                        type: "file",
                        path: entry.path,
                        digest: entry.digest,
                        mode: entry.mode,
                        size: entry.size,
                    };
                case "directory":
                    return { type: "directory", path: entry.path, mode: entry.mode };
                case "symlink":
                    return { type: "symlink", path: entry.path, target: entry.target };
            }
        }),
    });
}

/** A tree manifest from the server, with every entry checked. */
function decodeTree(bytes: Buffer): Tree {
    const tree = JSON.parse(bytes.toString("utf8")) as Tree;

    if (tree?.version !== 1 || !Array.isArray(tree.entries)) throw new Error("invalid tree");

    for (const entry of tree.entries) {
        validateRelativePath(entry.path);

        if (entry.type === "file") {
            if (entry.mode !== 0o644 && entry.mode !== 0o755) throw new Error(`invalid file mode: ${entry.path}`);
        } else if (entry.type === "directory") {
            if (entry.mode !== 0o755) throw new Error(`invalid directory mode: ${entry.path}`);
        } else if (entry.type === "symlink") {
            validateSymlink(entry.path, entry.target);
        } else {
            throw new Error(`invalid tree entry: ${entry.path}`);
        }
    }

    return tree;
}

/**
 * A temporary content-addressed store. Each input file is read once into it,
 * so the bytes uploaded are the bytes that were hashed even if the file
 * changes meanwhile.
 */
export class Store {
    readonly root = mkdtempSync(join(tmpdir(), "offload-"));
    readonly digests = new Set<string>();

    put(bytes: Buffer): string {
        const digest = sha256(bytes);
        writeFileSync(join(this.root, digest), bytes);
        this.digests.add(digest);
        return digest;
    }

    get(digest: string): Buffer {
        return readFileSync(join(this.root, digest));
    }

    size(digest: string): number {
        return statSync(join(this.root, digest)).size;
    }

    remove(): void {
        rmSync(this.root, { recursive: true, force: true });
    }
}

/**
 * The canonical tree of `inputs` below `base`, its files read into `store`,
 * merged with the entries of `stored` trees already on the server. As in the
 * runner, a path may appear twice only as the same entry.
 */
export function buildTree(
    base: string,
    inputs: string[],
    store: Store,
    stored: Tree[] = [],
): { digest: string; bytes: Buffer; tree: Tree } {
    const entries = new Map<string, TreeEntry>();

    const add = (name: string): void => {
        const path = join(base, name);
        const metadata = lstatSync(path);

        if (metadata.isSymbolicLink()) {
            const target = readlinkSync(path);
            validateSymlink(name, target);
            entries.set(name, { type: "symlink", path: name, target });
        } else if (metadata.isDirectory()) {
            entries.set(name, { type: "directory", path: name, mode: 0o755 });

            for (const child of readdirSync(path)) add(`${name}/${child}`);
        } else if (metadata.isFile()) {
            if (metadata.size > maxBlobSize) {
                throw new Error(`${name} is larger than the server's 1 GiB file limit; split it into smaller files`);
            }

            const bytes = readFileSync(path);
            const mode = (metadata.mode & 0o111) !== 0 ? 0o755 : 0o644;
            entries.set(name, { type: "file", path: name, digest: store.put(bytes), mode, size: bytes.length });
        } else {
            throw new Error(`not a file, directory or symlink: ${name}`);
        }
    };

    for (const input of inputs) {
        validateRelativePath(input);
        const name = components(input).join("/");
        refuseSymlinkOnPath(base, dirname(name));

        if (lstatSync(join(base, name), { throwIfNoEntry: false }) === undefined) {
            throw new Error(`missing input: ${input}`);
        }

        add(name);
    }

    for (const entry of stored.flatMap((tree) => tree.entries)) {
        const existing = entries.get(entry.path);

        if (existing && JSON.stringify(existing) !== JSON.stringify(entry)) {
            throw new Error(`two inputs put different entries at ${entry.path}`);
        }

        entries.set(entry.path, entry);
    }

    const tree: Tree = {
        version: 1,
        entries: [...entries.values()].sort((left, right) => compareUtf8(left.path, right.path)),
    };
    const bytes = Buffer.from(encodeTree(tree));
    return { digest: sha256(bytes), bytes, tree };
}

/** TinyCI's HTTP API. */
export class Server {
    readonly url: string;

    constructor(url: string) {
        this.url = url.replace(/\/+$/, "");
    }

    private async request(method: string, path: string, body?: unknown): Promise<Response> {
        const raw = Buffer.isBuffer(body);

        const response = await fetch(this.url + path, {
            method,
            headers: body === undefined || raw ? {} : { "content-type": "application/json" },
            body: body === undefined ? undefined : raw ? new Uint8Array(body) : JSON.stringify(body),
        });

        if (!response.ok) {
            const detail = await response.text().catch(() => "");
            throw new Error(`${method} ${path}: HTTP ${response.status}${detail ? ` ${detail}` : ""}`);
        }

        return response;
    }

    async json<T>(method: string, path: string, body?: unknown): Promise<T> {
        return (await (await this.request(method, path, body)).json()) as T;
    }

    async object(kind: "blobs" | "trees", digest: string): Promise<Buffer> {
        const bytes = Buffer.from(await (await this.request("GET", `/v1/${kind}/sha256/${digest}`)).arrayBuffer());

        if (sha256(bytes) !== digest) throw new Error(`${kind} object ${digest} does not match its digest`);

        return bytes;
    }

    async putObject(kind: "blobs" | "trees", digest: string, bytes: Buffer): Promise<void> {
        await this.request("PUT", `/v1/${kind}/sha256/${digest}`, bytes);
    }

    /** Which of `digests` the server lacks, asked in batches its body limit allows. */
    async missingBlobs(digests: string[]): Promise<string[]> {
        const missing: string[] = [];

        for (let start = 0; start < digests.length; start += 10_000) {
            const batch = digests.slice(start, start + 10_000);
            const answer = await this.json<{ missing: string[] }>("POST", "/v1/blobs/missing", { digests: batch });
            missing.push(...answer.missing);
        }

        return missing;
    }
}

const runPath = (run: string) => `/v1/runs/${encodeURIComponent(run)}`;

function parseJobFile(text: string): JobFile {
    const file = JSON.parse(text) as JobFile;

    if (file?.version !== 1) throw new Error("the job file must have version 1");

    if (!file.jobs || typeof file.jobs !== "object") throw new Error("the job file has no jobs");

    for (const [name, job] of Object.entries(file.jobs)) {
        if (!Array.isArray(job?.inputs)) throw new Error(`job ${name} has no inputs list`);
    }

    return file;
}

/** An input that names outputs already on the server: `run:<run>/<job>` or `tree:<digest>`. */
const isStoredInput = (input: string) => input.startsWith("run:") || input.startsWith("tree:");

/** The stored tree a `run:` or `tree:` input names. */
async function storedInput(server: Server, input: string): Promise<{ input: string; digest: string; tree: Tree }> {
    let digest: string;

    if (input.startsWith("tree:")) {
        digest = input.slice("tree:".length);
    } else {
        const [run, job, ...rest] = input.slice("run:".length).split("/");

        if (!run || !job || rest.length > 0) throw new Error(`input ${input} must be run:<run-id>/<job>`);

        const record = await jobRecord(server, run, job, false);

        if (!record.output_tree) throw new Error(`input ${input}: the job has no outputs (state: ${record.state})`);

        digest = record.output_tree;
    }

    if (!/^[0-9a-f]{64}$/.test(digest)) throw new Error(`input ${input} names no tree digest`);

    return { input, digest, tree: decodeTree(await server.object("trees", digest)) };
}

const mib = (bytes: number) => (bytes / (1024 * 1024)).toFixed(1);

/**
 * Submits a job file. Inputs are relative to the file's directory, or name
 * outputs already on the server; each job gets a tree of its own inputs, so an
 * unrelated change keeps its cache. The server checks the run before any input
 * is hashed or uploaded. Progress goes to `report`, stderr by default.
 */
export async function submit(
    server: Server,
    jobFile: string,
    label = "",
    report = (line: string) => process.stderr.write(`${line}\n`),
): Promise<{ run_id: string; dashboard: string }> {
    const file = parseJobFile(readFileSync(jobFile, "utf8"));
    const base = dirname(resolve(jobFile));
    const store = new Store();

    try {
        // Check fields, dependencies and limits before hashing local inputs.
        const drafts = Object.fromEntries(
            Object.entries(file.jobs).map(([name, job]) => [name, { ...job, needs: job.needs ?? [] }]),
        );
        await server.json("POST", "/v1/runs", { jobs: drafts, dry_run: true });

        const jobs: Record<string, unknown> = {};
        const trees = new Map<string, Buffer>();
        const reused: { input: string; tree: Tree }[] = [];

        for (const [name, job] of Object.entries(file.jobs)) {
            const local = job.inputs.filter((input) => !isStoredInput(input));
            const stored = await Promise.all(job.inputs.filter(isStoredInput).map((input) => storedInput(server, input)));
            const { digest, bytes } = buildTree(base, local, store, stored.map((input) => input.tree));
            trees.set(digest, bytes);
            reused.push(...stored);
            // A stored input is sent by its digest: the job's key follows content, not a run ID.
            jobs[name] = {
                ...job,
                inputs: [...local, ...stored.map((input) => `tree:${input.digest}`)],
                needs: job.needs ?? [],
                source_tree: digest,
            };
        }

        for (const { input, tree } of reused) {
            const files = tree.entries.flatMap((entry) => (entry.type === "file" ? [entry.digest] : []));
            const gone = await server.missingBlobs(files);

            if (gone.length > 0) {
                throw new Error(`input ${input}: ${gone.length} of its files are gone from the store; run the job that made them again`);
            }
        }

        const missing = await server.missingBlobs([...store.digests]);
        const total = missing.reduce((sum, digest) => sum + store.size(digest), 0);
        let sent = 0;
        let sentBytes = 0;
        let reportedAt = Date.now();
        report(`uploading ${missing.length} files (${mib(total)} MiB) the server lacks`);

        for (const digest of missing) {
            await server.putObject("blobs", digest, store.get(digest));
            sent += 1;
            sentBytes += store.size(digest);

            if (Date.now() - reportedAt >= 5000) {
                report(`uploaded ${sent} of ${missing.length} files (${mib(sentBytes)} of ${mib(total)} MiB)`);
                reportedAt = Date.now();
            }
        }

        report(`uploaded ${missing.length} files (${mib(total)} MiB)`);

        for (const [digest, bytes] of trees) await server.putObject("trees", digest, bytes);

        const { run_id } = await server.json<{ run_id: string }>("POST", "/v1/runs", { jobs, label });
        return { run_id, dashboard: `${server.url}/` };
    } finally {
        store.remove();
    }
}

/** Polls until every job of `run` has finished; it succeeded if they all did. */
export async function wait(
    server: Server,
    run: string,
    intervalMs = 5000,
): Promise<{ run: Run; succeeded: boolean }> {
    for (;;) {
        const current = await server.json<Run>("GET", `${runPath(run)}/summary`);
        const states = Object.values(current.jobs).map((job) => job.state);

        if (states.every((state) => finishedStates.has(state))) {
            return { run: current, succeeded: states.every((state) => state === "succeeded") };
        }

        await sleep(intervalMs);
    }
}

/** Polls one job until it finishes; it succeeded if it did. */
export async function waitForJob(
    server: Server,
    run: string,
    job: string,
    intervalMs = 5000,
): Promise<{ job: JobRecord; succeeded: boolean }> {
    for (;;) {
        const record = await jobRecord(server, run, job, false);

        if (finishedStates.has(record.state)) {
            return { job: record, succeeded: record.state === "succeeded" };
        }

        await sleep(intervalMs);
    }
}

/** A job without its definition or log, for the CLI's `wait` output. */
export function jobSummary(job: JobRecord): JobSummary {
    return {
        state: job.state,
        ...(job.cache_hit === undefined ? {} : { cache_hit: job.cache_hit }),
        ...(job.error === undefined ? {} : { error: job.error }),
        ...(job.output_tree === undefined ? {} : { output_tree: job.output_tree }),
    };
}

/** A run without its jobs' logs and definitions, for the CLI's `wait` output. */
export function runSummary(run: Run): { id: string; label: string; jobs: Record<string, JobSummary> } {
    return {
        id: run.id,
        label: run.label,
        jobs: Object.fromEntries(
            Object.entries(run.jobs).map(([name, job]) => [name, jobSummary(job)]),
        ),
    };
}

async function jobRecord(server: Server, run: string, job: string, logs = true): Promise<JobRecord> {
    if (!logs) {
        const record = (await server.json<Run>("GET", `${runPath(run)}/summary`)).jobs[job];

        if (record === undefined) throw new Error(`run ${run} has no job ${job}`);

        return record;
    }

    const record = await server.json<JobRecord>("GET", `${runPath(run)}/jobs/${encodeURIComponent(job)}`);

    if (record === undefined) throw new Error(`run ${run} has no job ${job}`);

    return record;
}

/** How many of the previous lines must recur to mark where the new ones start. */
const anchorLines = 20;

/**
 * The lines of `current` not yet seen in `previous`. A running job's log is a
 * tail window and its final log the whole log, so the new lines are those after
 * the last place the end of `previous` recurs in `current`; without such a
 * place, all of `current` is new.
 */
export function newLines(previous: string[], current: string[]): string[] {
    const anchor = previous.slice(-anchorLines);

    if (anchor.length === 0) return current;

    for (let start = current.length - anchor.length; start >= 0; start -= 1) {
        if (anchor.every((line, index) => current[start + index] === line)) {
            return current.slice(start + anchor.length);
        }
    }

    return current;
}

/** A log's complete lines: a trailing newline ends the last one. */
function logLines(log = ""): string[] {
    const lines = log.split("\n");

    if (lines.at(-1) === "") lines.pop();

    return lines;
}

/** The most live log lines `follow` prints before it stops streaming. */
const maxFollowLines = 30;
/** The final lines a failed or cancelled job adds after the live cap. */
const maxFailureLines = 30;
/** The final lines a successful job adds after the live cap. */
const maxSuccessLines = 8;
/** The longest log line `follow` keeps, in characters. */
const maxLineLength = 400;
const ansi = /\x1b\[[0-?]*[ -/]*[@-~]/g;

/** One log line without ANSI, the last carriage-return redraw, or excess length. */
function compactLine(line: string): string {
    const frame = line.split("\r").filter((part) => part.trim() !== "").at(-1) ?? "";
    const plain = frame.replace(ansi, "").trimEnd();

    return plain.length > maxLineLength ? `${plain.slice(0, maxLineLength)}…` : plain;
}

/** Log lines worth showing an LLM: no redraws, ANSI, blanks or adjacent repeats. */
export function compactLines(lines: string[]): string[] {
    const result: string[] = [];

    for (const line of lines) {
        const compact = compactLine(line);

        if (compact === "" || compact === result.at(-1)) continue;

        result.push(compact);
    }

    return result;
}

/**
 * Prints a compact log stream until the job ends: state changes, filtered new
 * lines, and a bounded final tail. The full log stays on the dashboard and at
 * `GET /v1/runs/{run}/jobs/{job}`.
 */
export async function follow(
    server: Server,
    run: string,
    job: string,
    intervalMs = 5000,
    write = (text: string) => process.stdout.write(text),
): Promise<boolean> {
    let previous: string[] = [];
    let lastState = "";
    let printed = new Set<string>();
    let printedCount = 0;
    let capReported = false;
    let polled = false;

    const emit = (line: string) => write(`${line}\n`);

    const emitLog = (lines: string[]) => {
        for (const line of lines) {
            if (printedCount >= maxFollowLines) return;

            emit(line);
            printed.add(line);
            printedCount += 1;
        }
    };

    for (;;) {
        const record = await jobRecord(server, run, job);
        const lines = logLines(record.log);
        const compact = compactLines(lines);
        const finished = finishedStates.has(record.state);

        if (record.state !== lastState) {
            emit(`# ${job}: ${record.state}`);
            lastState = record.state;
        }

        if (!polled && finished) {
            const shown = compact.slice(-maxFollowLines);
            emitLog(shown);

            if (compact.length > shown.length) emit(`# showing the last ${shown.length} log lines`);
        } else {
            emitLog(compactLines(newLines(previous, lines)));

            if (printedCount >= maxFollowLines && !capReported) {
                emit(`# log capped at ${maxFollowLines} lines; use the dashboard or curl for the rest`);
                capReported = true;
            }
        }

        previous = lines;
        polled = true;

        if (finished) {
            if (record.error) emit(`# error: ${compactLine(record.error.replace(/\n/g, " "))}`);

            const finalLines = record.state === "succeeded" ? maxSuccessLines : maxFailureLines;
            const unseen = compact.slice(-finalLines).filter((line) => !printed.has(line));

            if (unseen.length > 0) {
                emit("# recent log:");

                for (const line of unseen) emit(line);
            }

            return record.state === "succeeded";
        }

        await sleep(intervalMs);
    }
}

/** Creates `path` and its missing parents as directories with mode 0755. */
function makeDirectory(path: string): void {
    const metadata = lstatSync(path, { throwIfNoEntry: false });

    if (metadata !== undefined) {
        if (!metadata.isDirectory()) throw new Error(`${path} is not a directory`);

        chmodSync(path, 0o755);
        return;
    }

    const parent = dirname(path);

    if (parent !== path) makeDirectory(parent);

    mkdirSync(path, { mode: 0o755 });
    chmodSync(path, 0o755);
}

/**
 * Writes the outputs `job` ended with into `dest`, which must not exist yet:
 * all of them, or only those equal to or below one of `paths`.
 */
export async function fetchOutputs(
    server: Server,
    run: string,
    job: string,
    dest: string,
    paths: string[] = [],
): Promise<{ dest: string; files: number }> {
    if (existsSync(dest)) throw new Error(`${dest} exists already`);

    for (const path of paths) validateRelativePath(path);

    const selected = paths.map((path) => components(path).join("/"));
    const record = await jobRecord(server, run, job, false);

    if (!record.output_tree) throw new Error(`job ${job} has no outputs (state: ${record.state})`);

    const tree = decodeTree(await server.object("trees", record.output_tree));
    const within = (entry: TreeEntry, path: string) => entry.path === path || entry.path.startsWith(`${path}/`);

    for (const path of selected) {
        if (!tree.entries.some((entry) => within(entry, path))) throw new Error(`job ${job} has no output ${path}`);
    }

    const entries =
        selected.length === 0 ? tree.entries : tree.entries.filter((entry) => selected.some((path) => within(entry, path)));
    let files = 0;
    mkdirSync(dirname(dest), { recursive: true, mode: 0o755 });
    // Claim the destination exclusively before entering cleanup handling.
    mkdirSync(dest, { mode: 0o755 });

    try {
        chmodSync(dest, 0o755);

        for (const entry of entries) {
            refuseSymlinkOnPath(dest, entry.path);
            const target = join(dest, entry.path);
            makeDirectory(dirname(target));

            if (entry.type === "directory") {
                makeDirectory(target);
            } else if (entry.type === "file") {
                const bytes = await server.object("blobs", entry.digest);
                // "wx": never through, or over, something already there.
                writeFileSync(target, bytes, { mode: entry.mode, flag: "wx" });
                chmodSync(target, entry.mode);
                files += 1;
            } else {
                symlinkSync(entry.target, target);
            }
        }
    } catch (error) {
        rmSync(dest, { recursive: true, force: true });
        throw error;
    }

    return { dest, files };
}
