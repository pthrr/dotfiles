/** The offload-compute client against a stand-in for TinyCI's HTTP API. */
import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { once } from "node:events";
import {
    closeSync,
    existsSync,
    ftruncateSync,
    mkdirSync,
    mkdtempSync,
    openSync,
    readFileSync,
    readlinkSync,
    statSync,
    symlinkSync,
    writeFileSync,
} from "node:fs";
import { createServer } from "node:http";
import type { AddressInfo } from "node:net";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import {
    buildTree,
    compactLines,
    encodeTree,
    fetchOutputs,
    follow,
    maxBlobSize,
    newLines,
    runSummary,
    type Run,
    Server,
    sha256,
    Store,
    submit,
    wait,
    waitForJob,
} from "./tinyci.ts";

const scratch = () => mkdtempSync(join(tmpdir(), "offload-test-"));

interface Call {
    method: string;
    path: string;
    body?: { [field: string]: unknown };
}

interface Fake {
    url: string;
    objects: Map<string, Buffer>;
    calls: Call[];
    runs: Map<string, Run>;
    /** Set `message` to refuse every dry run with it, as the server refuses a bad setting. */
    refusal: { message?: string };
    close(): Promise<void>;
}

/** Keeps objects and runs in memory and records every request. */
async function fakeServer(): Promise<Fake> {
    const objects = new Map<string, Buffer>();
    const calls: Call[] = [];
    const runs = new Map<string, Run>();
    const refusal: { message?: string } = {};

    const server = createServer(async (request, response) => {
        const chunks: Buffer[] = [];

        for await (const chunk of request) chunks.push(chunk as Buffer);

        const bytes = Buffer.concat(chunks);
        const method = request.method ?? "GET";
        const path = request.url ?? "/";
        const object = /^\/v1\/(blobs|trees)\/sha256\/([0-9a-f]{64})$/.exec(path);
        const send = (status: number, value: unknown) =>
            response.writeHead(status, { "content-type": "application/json" }).end(JSON.stringify(value));

        if (object) {
            calls.push({ method, path });
            const key = `${object[1]}/${object[2]}`;

            if (method === "PUT") {
                objects.set(key, bytes);
                response.writeHead(204).end();
            } else {
                const stored = objects.get(key);
                response.writeHead(stored ? 200 : 404).end(stored);
            }

            return;
        }

        const body = bytes.length > 0 ? JSON.parse(bytes.toString("utf8")) : undefined;
        const pathname = path.split("?")[0];
        calls.push({ method, path, body });
        const run = /^\/v1\/runs\/([^/]+)$/.exec(pathname);
        const summary = /^\/v1\/runs\/([^/]+)\/summary$/.exec(pathname);
        const job = /^\/v1\/runs\/([^/]+)\/jobs\/([^/]+)$/.exec(pathname);
        const summarize = (value: Run) => ({
            id: value.id,
            label: value.label,
            paused: false,
            cancelled: false,
            jobs: Object.fromEntries(
                Object.entries(value.jobs).map(([name, record]) => [
                    name,
                    {
                        state: record.state,
                        ...(record.cache_hit === undefined ? {} : { cache_hit: record.cache_hit }),
                        ...(record.error === undefined ? {} : { error: record.error }),
                        ...(record.output_tree === undefined ? {} : { output_tree: record.output_tree }),
                    },
                ]),
            ),
        });

        if (method === "POST" && pathname === "/v1/blobs/missing") {
            send(200, { missing: body.digests.filter((digest: string) => !objects.has(`blobs/${digest}`)) });
        } else if (method === "POST" && pathname === "/v1/runs" && body.dry_run === true) {
            if (refusal.message) {
                send(400, { error: refusal.message });
            } else {
                send(200, { ok: true });
            }
        } else if (method === "POST" && pathname === "/v1/runs") {
            const jobs = Object.fromEntries(Object.keys(body.jobs).map((name) => [name, { state: "queued" }]));
            runs.set("run-1", { id: "run-1", label: body.label, jobs });
            send(202, { run_id: "run-1" });
        } else if (method === "GET" && pathname === "/v1/runs") {
            send(200, { runs: [...runs.values()] });
        } else if (method === "GET" && summary) {
            const found = runs.get(summary[1]);
            send(found ? 200 : 404, found ? summarize(found) : { error: "run not found" });
        } else if (method === "GET" && job) {
            const found = runs.get(job[1])?.jobs[job[2]];

            if (!found) {
                send(404, { error: "job not found" });
            } else if (path.endsWith("?logs=0")) {
                const { log, ...record } = found;
                send(200, record);
            } else {
                send(200, found);
            }
        } else if (method === "GET" && run) {
            const found = runs.get(run[1]);
            send(found ? 200 : 404, found ?? { error: "run not found" });
        } else if (method === "POST" && /\/(cancel|retry)$/.test(pathname)) {
            send(200, { ok: true });
        } else {
            send(404, { error: "not found" });
        }
    });

    await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
    const { port } = server.address() as AddressInfo;
    return {
        url: `http://127.0.0.1:${port}`,
        objects,
        calls,
        runs,
        refusal,
        close: () =>
            new Promise<void>((resolve) => {
                server.closeAllConnections();
                server.close(() => resolve());
            }),
    };
}

test("a tree follows the source tree rules and the runner's byte layout", () => {
    const base = scratch();
    mkdirSync(join(base, "in/sub"), { recursive: true });
    writeFileSync(join(base, "in/a.txt"), "a");
    writeFileSync(join(base, "in/run.sh"), "#!/bin/sh\n", { mode: 0o700 });
    symlinkSync("a.txt", join(base, "in/link"));
    const store = new Store();

    try {
        const { digest, bytes } = buildTree(base, ["in/"], store);
        const expected =
            `{"version":1,"entries":[` +
            `{"type":"directory","path":"in","mode":493},` +
            `{"type":"file","path":"in/a.txt","digest":"${sha256("a")}","mode":420,"size":1},` +
            `{"type":"symlink","path":"in/link","target":"a.txt"},` +
            `{"type":"file","path":"in/run.sh","digest":"${sha256("#!/bin/sh\n")}","mode":493,"size":10},` +
            `{"type":"directory","path":"in/sub","mode":493}]}`;
        assert.equal(bytes.toString("utf8"), expected);
        assert.equal(digest, sha256(expected));
        assert.deepEqual([...store.digests].sort(), [sha256("a"), sha256("#!/bin/sh\n")].sort());
    } finally {
        store.remove();
    }
});

test("inputs outside the source tree rules are refused", () => {
    const base = scratch();
    mkdirSync(join(base, "in"));
    symlinkSync("../../outside", join(base, "in/escape"));
    mkdirSync(join(base, "real"));
    writeFileSync(join(base, "real/x"), "x");
    symlinkSync("real", join(base, "linked"));
    assert.equal(spawnSync("mkfifo", [join(base, "pipe")]).status, 0);
    const cases: [string[], RegExp][] = [
        [["/etc"], /absolute/],
        [["../x"], /plain names/],
        [["nope"], /missing input/],
        [["in"], /escapes the tree/],
        [["pipe"], /not a file, directory or symlink/],
        [["linked/x"], /through a symlink/],
    ];

    for (const [inputs, message] of cases) {
        const store = new Store();

        try {
            assert.throws(() => buildTree(base, inputs, store), message);
        } finally {
            store.remove();
        }
    }
});

test("an input file above the server's 1 GiB limit is refused", () => {
    const base = scratch();
    const store = new Store();
    const fd = openSync(join(base, "huge"), "w");

    try {
        ftruncateSync(fd, maxBlobSize + 1);
        assert.throws(() => buildTree(base, ["huge"], store), /huge.*1 GiB/);
    } finally {
        closeSync(fd);
        store.remove();
    }
});

test("submit uploads only what the server lacks and posts each job with its tree", async () => {
    const fake = await fakeServer();

    try {
        const base = scratch();
        mkdirSync(join(base, "src"));
        writeFileSync(join(base, "src/kept.txt"), "already there");
        writeFileSync(join(base, "src/new.txt"), "new");
        fake.objects.set(`blobs/${sha256("already there")}`, Buffer.from("already there"));
        const job = { image: `alpine@sha256:${"a".repeat(64)}`, script: ["true"], inputs: ["src"], outputs: ["out"] };
        writeFileSync(join(base, "jobs.json"), JSON.stringify({ version: 1, jobs: { build: job } }));

        const progress: string[] = [];
        const result = await submit(new Server(fake.url), join(base, "jobs.json"), "try", (line) => progress.push(line));
        assert.deepEqual(result, { run_id: "run-1", dashboard: `${fake.url}/` });
        assert.deepEqual(progress, ["uploading 1 files (0.0 MiB) the server lacks", "uploaded 1 files (0.0 MiB)"]);

        const dryRun = fake.calls.find((call) => call.body?.dry_run === true)?.body;
        assert.ok(dryRun);
        const draft = (dryRun.jobs as { build: { [field: string]: unknown } }).build;
        assert.equal("source_tree" in draft, false, "the dry run happens before trees are built");

        const puts = fake.calls.filter((call) => call.method === "PUT").map((call) => call.path);
        assert.deepEqual(
            puts.filter((path) => path.startsWith("/v1/blobs/")),
            [`/v1/blobs/sha256/${sha256("new")}`],
        );
        assert.equal(puts.filter((path) => path.startsWith("/v1/trees/")).length, 1);

        const posted = fake.calls.find(
            (call) => call.method === "POST" && call.path === "/v1/runs" && call.body?.dry_run !== true,
        )?.body;
        assert.ok(posted);
        const sent = (posted.jobs as { build: { [field: string]: unknown } }).build;
        assert.ok(fake.objects.has(`trees/${sent.source_tree}`), "the tree went up before the run");
        assert.deepEqual(sent.needs, []);
        assert.equal(posted.label, "try");
        assert.equal("version" in posted, false);
    } finally {
        await fake.close();
    }
});

test("fetch writes a job's outputs into a new directory, and nothing through a symlink", async () => {
    const fake = await fakeServer();
    const server = new Server(fake.url);

    try {
        // Outputs as the runner stores them: a tree and its blobs.
        const source = scratch();
        mkdirSync(join(source, "out"));
        writeFileSync(join(source, "out/result.txt"), "done\n");
        writeFileSync(join(source, "out/run.sh"), "#!/bin/sh\n", { mode: 0o755 });
        symlinkSync("result.txt", join(source, "out/latest"));
        const store = new Store();
        const { digest, bytes } = buildTree(source, ["out"], store);

        for (const blob of store.digests) fake.objects.set(`blobs/${blob}`, store.get(blob));

        store.remove();
        fake.objects.set(`trees/${digest}`, bytes);
        fake.runs.set("run-1", { id: "run-1", label: "", jobs: { build: { state: "cancelled", output_tree: digest } } });

        const dest = join(scratch(), "fetched");
        const previousUmask = process.umask(0o077);

        try {
            assert.deepEqual(await fetchOutputs(server, "run-1", "build", dest), { dest, files: 2 });
            assert.equal(readFileSync(join(dest, "out/result.txt"), "utf8"), "done\n");
            assert.equal(readlinkSync(join(dest, "out/latest")), "result.txt");
            assert.equal(statSync(dest).mode & 0o777, 0o755);
            assert.equal(statSync(join(dest, "out")).mode & 0o777, 0o755);
            assert.equal(statSync(join(dest, "out/result.txt")).mode & 0o777, 0o644);
            assert.equal(statSync(join(dest, "out/run.sh")).mode & 0o777, 0o755);
        } finally {
            process.umask(previousUmask);
        }

        await assert.rejects(fetchOutputs(server, "run-1", "build", dest), /exists already/);
        assert.equal(readFileSync(join(dest, "out/result.txt"), "utf8"), "done\n");

        // A missing blob leaves no half-fetched directory.
        fake.objects.delete(`blobs/${sha256("done\n")}`);
        const partial = join(scratch(), "fetched");
        await assert.rejects(fetchOutputs(server, "run-1", "build", partial), /HTTP 404/);
        assert.equal(existsSync(partial), false);

        // A tree with a file beneath one of its own symlinks.
        const sneaky = encodeTree({
            version: 1,
            entries: [
                { type: "symlink", path: "out/link", target: "sub" },
                { type: "file", path: "out/link/x", digest: sha256("x"), mode: 0o644, size: 1 },
                { type: "directory", path: "out/sub", mode: 0o755 },
            ],
        });
        fake.objects.set(`trees/${sha256(sneaky)}`, Buffer.from(sneaky));
        fake.objects.set(`blobs/${sha256("x")}`, Buffer.from("x"));
        fake.runs.set("run-2", { id: "run-2", label: "", jobs: { build: { state: "failed", output_tree: sha256(sneaky) } } });
        await assert.rejects(fetchOutputs(server, "run-2", "build", join(scratch(), "fetched")), /through a symlink/);
    } finally {
        await fake.close();
    }
});

test("concurrent fetches preserve the successful download into a shared destination", async () => {
    const fake = await fakeServer();
    const server = new Server(fake.url);

    try {
        const output = storeOutputs(fake, { "out/result.txt": "complete", "out/details.txt": "details" });
        fake.runs.set("run-1", {
            id: "run-1",
            label: "",
            jobs: { build: { state: "succeeded", output_tree: output } },
        });
        const dest = join(scratch(), "parent/fetched");
        const results = await Promise.allSettled([
            fetchOutputs(server, "run-1", "build", dest),
            fetchOutputs(server, "run-1", "build", dest),
        ]);
        assert.equal(results.filter((result) => result.status === "fulfilled").length, 1);
        const rejected = results.find((result) => result.status === "rejected");
        assert.ok(rejected);
        assert.match(String(rejected.reason), /EEXIST|exists already/);
        assert.equal(readFileSync(join(dest, "out/result.txt"), "utf8"), "complete");
        assert.equal(readFileSync(join(dest, "out/details.txt"), "utf8"), "details");
    } finally {
        await fake.close();
    }
});

/** A job file of one job with the given inputs, next to `src/new.txt`. */
function jobFile(inputs: string[], fields: { [field: string]: unknown } = {}): string {
    const base = scratch();
    mkdirSync(join(base, "src"));
    writeFileSync(join(base, "src/new.txt"), "new");
    const job = { image: `alpine@sha256:${"a".repeat(64)}`, script: ["true"], inputs, outputs: ["out"], ...fields };
    writeFileSync(join(base, "jobs.json"), JSON.stringify({ version: 1, jobs: { build: job } }));
    return join(base, "jobs.json");
}

/** Stores the tree of `files` with its blobs on the fake server; its digest. */
function storeOutputs(fake: Fake, files: Record<string, string>): string {
    const source = scratch();

    for (const [path, content] of Object.entries(files)) {
        mkdirSync(join(source, path, ".."), { recursive: true });
        writeFileSync(join(source, path), content);
    }

    const store = new Store();
    const { digest, bytes } = buildTree(source, Object.keys(files), store);

    for (const blob of store.digests) fake.objects.set(`blobs/${blob}`, store.get(blob));

    store.remove();
    fake.objects.set(`trees/${digest}`, bytes);
    return digest;
}

const ignoreProgress = () => {};

test("submit has the run checked before it uploads, and uploads nothing when refused", async () => {
    const fake = await fakeServer();
    const server = new Server(fake.url);

    try {
        await submit(server, jobFile(["src"]), "", ignoreProgress);
        const dryRun = fake.calls.findIndex((call) => call.body?.dry_run === true);
        const firstUpload = fake.calls.findIndex((call) => call.method === "PUT");
        assert.ok(dryRun >= 0 && dryRun < firstUpload, "the dry run comes before any upload");

        fake.calls.length = 0;
        fake.refusal.message = "job build declares cpu 9; the most is 8";
        await assert.rejects(submit(server, jobFile(["src"], { cpu: 9 }), "", ignoreProgress), /cpu 9; the most is 8/);
        assert.deepEqual(
            fake.calls.filter((call) => call.method === "PUT" || (call.path === "/v1/runs" && !call.body?.dry_run)),
            [],
        );
    } finally {
        await fake.close();
    }
});

test("a run: input reuses stored outputs by digest without moving their files", async () => {
    const fake = await fakeServer();
    const server = new Server(fake.url);

    try {
        const outputs = storeOutputs(fake, { "out/app": "built binary" });
        fake.runs.set("run-0", { id: "run-0", label: "", jobs: { build: { state: "succeeded", output_tree: outputs } } });

        await submit(server, jobFile(["src", "run:run-0/build"]), "", ignoreProgress);
        const posted = fake.calls.find((call) => call.path === "/v1/runs" && call.body?.dry_run !== true)?.body;
        const sent = (posted?.jobs as { build: { inputs: string[]; source_tree: string } }).build;
        assert.deepEqual(sent.inputs, ["src", `tree:${outputs}`]);

        const tree = JSON.parse(fake.objects.get(`trees/${sent.source_tree}`)?.toString() ?? "{}");
        assert.deepEqual(
            tree.entries.map((entry: { path: string }) => entry.path),
            ["out/app", "src", "src/new.txt"],
        );
        assert.equal(
            fake.calls.some((call) => call.method === "PUT" && call.path.endsWith(sha256("built binary"))),
            false,
            "the reused file is not uploaded again",
        );

        // A local input with other content at the same path.
        const clashing = jobFile(["out", `tree:${outputs}`]);
        mkdirSync(join(clashing, "../out"));
        writeFileSync(join(clashing, "../out/app"), "a different binary");
        await assert.rejects(submit(server, clashing, "", ignoreProgress), /different entries at out\/app/);

        fake.objects.delete(`blobs/${sha256("built binary")}`);
        await assert.rejects(submit(server, jobFile(["run:run-0/build"]), "", ignoreProgress), /files are gone from the store/);
    } finally {
        await fake.close();
    }
});

test("fetch writes only the asked-for paths, and refuses one the job has not", async () => {
    const fake = await fakeServer();
    const server = new Server(fake.url);

    try {
        const outputs = storeOutputs(fake, { "out/report.html": "<p>ok</p>", "crashes/c1": "boom" });
        fake.runs.set("run-1", { id: "run-1", label: "", jobs: { fuzz: { state: "failed", output_tree: outputs } } });

        const dest = join(scratch(), "fetched");
        assert.deepEqual(await fetchOutputs(server, "run-1", "fuzz", dest, ["crashes/"]), { dest, files: 1 });
        assert.equal(readFileSync(join(dest, "crashes/c1"), "utf8"), "boom");
        assert.equal(existsSync(join(dest, "out")), false);

        const missing = join(scratch(), "fetched");
        await assert.rejects(fetchOutputs(server, "run-1", "fuzz", missing, ["nope"]), /has no output nope/);
        assert.equal(existsSync(missing), false);
    } finally {
        await fake.close();
    }
});

test("newLines gives what follows the last window: grown, moved, the final log, or no overlap", () => {
    const lines = (from: number, to: number) => Array.from({ length: to - from + 1 }, (_, index) => `line ${from + index}`);

    assert.deepEqual(newLines([], lines(1, 3)), lines(1, 3));
    assert.deepEqual(newLines(lines(1, 3), lines(1, 5)), lines(4, 5));
    assert.deepEqual(newLines(lines(1, 30), lines(11, 40)), lines(31, 40));
    assert.deepEqual(newLines(lines(3001, 4000), lines(1, 4010)), lines(4001, 4010));
    assert.deepEqual(newLines(lines(1, 30), lines(1, 30)), []);
    assert.deepEqual(newLines(["something else"], lines(1, 2)), lines(1, 2));
});

test("wait returns once every job finished, and whether they all succeeded", async () => {
    const fake = await fakeServer();
    const server = new Server(fake.url);

    try {
        const run: Run = { id: "run-1", label: "", jobs: { a: { state: "running" }, b: { state: "succeeded" } } };
        fake.runs.set("run-1", run);

        setTimeout(() => {
            run.jobs.a.state = "succeeded";
        }, 50);

        assert.equal((await wait(server, "run-1", 10)).succeeded, true);

        run.jobs.b.state = "failed";
        assert.equal((await wait(server, "run-1", 10)).succeeded, false);
    } finally {
        await fake.close();
    }
});

test("waitForJob returns one job's record and whether it succeeded", async () => {
    const fake = await fakeServer();
    const server = new Server(fake.url);

    try {
        fake.runs.set("run-1", {
            id: "run-1",
            label: "",
            jobs: { build: { state: "running" }, test: { state: "succeeded" } },
        });

        setTimeout(() => {
            fake.runs.get("run-1")!.jobs.build.state = "succeeded";
        }, 20);

        const result = await waitForJob(server, "run-1", "build", 10);
        assert.equal(result.succeeded, true);
        assert.equal(result.job.state, "succeeded");
    } finally {
        await fake.close();
    }
});

test("follow caps live lines and adds the error and a failure tail", async () => {
    const fake = await fakeServer();
    const server = new Server(fake.url);
    const log = Array.from({ length: 100 }, (_, index) => `line ${index}`).join("\n") + "\n";
    const output: string[] = [];
    fake.runs.set("run-1", { id: "run-1", label: "", jobs: { build: { state: "running", log } } });

    try {
        const following = follow(server, "run-1", "build", 10, (text) => output.push(text));

        setTimeout(() => {
            const job = fake.runs.get("run-1")!.jobs.build;
            job.state = "failed";
            job.error = "boom";
        }, 100);

        assert.equal(await following, false);
        const text = output.join("");
        assert.match(text, /# build: running/);
        assert.match(text, /# log capped at 30 lines/);
        assert.match(text, /# error: boom/);
        assert.match(text, /# recent log:/);
        assert.match(text, /line 99/);
        assert.doesNotMatch(text, /# showing the last/);
    } finally {
        await fake.close();
    }
});

test("compactLines drops redraws, ANSI, blanks, repeats and excess length", () => {
    const long = "x".repeat(1000);

    assert.deepEqual(
        compactLines([
            "\u001b[31mred\u001b[0m",
            "",
            "progress 10%\rprogress 50%\rprogress 100%",
            "same",
            "same",
            long,
        ]),
        ["red", "progress 100%", "same", `${"x".repeat(400)}…`],
    );
});

test("runSummary leaves out logs and definitions", () => {
    const run: Run = {
        id: "run-1",
        label: "example",
        jobs: {
            build: { state: "succeeded", cache_hit: true, output_tree: "a".repeat(64), log: "noise" },
            test: { state: "failed", error: "boom", log: "noise" },
        },
    };

    assert.deepEqual(runSummary(run), {
        id: "run-1",
        label: "example",
        jobs: {
            build: { state: "succeeded", cache_hit: true, output_tree: "a".repeat(64) },
            test: { state: "failed", error: "boom" },
        },
    });
});

test("follow prints a job's log and returns its exit status", async () => {
    const fake = await fakeServer();
    const offload = fileURLToPath(new URL("./offload.ts", import.meta.url));

    try {
        for (const [state, exitStatus] of [["succeeded", 0], ["failed", 1], ["cancelled", 1]] as const) {
            fake.runs.set("run-1", {
                id: "run-1",
                label: "",
                jobs: { build: { state, log: "job output\n", ...(state === "failed" ? { error: "boom" } : {}) } },
            });
            const child = spawn(process.execPath, ["--experimental-strip-types", offload, "follow", "run-1", "build"], {
                env: { ...process.env, TINYCI_URL: fake.url },
                stdio: ["ignore", "pipe", "pipe"],
            });
            let standardOutput = "";
            let standardError = "";

            child.stdout.on("data", (chunk: Buffer) => {
                standardOutput += chunk.toString();
            });

            child.stderr.on("data", (chunk: Buffer) => {
                standardError += chunk.toString();
            });

            const [status] = await once(child, "close");
            const expected =
                state === "failed" ? `# build: failed\njob output\n# error: boom\n` : `# build: ${state}\njob output\n`;
            assert.equal(status, exitStatus, standardError);
            assert.equal(standardOutput, expected);
        }
    } finally {
        await fake.close();
    }
});

test("wait prints one job's compact summary", async () => {
    const fake = await fakeServer();
    const offload = fileURLToPath(new URL("./offload.ts", import.meta.url));
    fake.runs.set("run-1", {
        id: "run-1",
        label: "example",
        jobs: {
            build: { state: "succeeded", cache_hit: true, output_tree: "a".repeat(64), log: "noise" },
        },
    });

    try {
        const child = spawn(process.execPath, ["--experimental-strip-types", offload, "wait", "run-1", "build"], {
            env: { ...process.env, TINYCI_URL: fake.url },
            stdio: ["ignore", "pipe", "pipe"],
        });
        let standardOutput = "";
        let standardError = "";

        child.stdout.on("data", (chunk: Buffer) => {
            standardOutput += chunk.toString();
        });

        child.stderr.on("data", (chunk: Buffer) => {
            standardError += chunk.toString();
        });

        const [status] = await once(child, "close");
        assert.equal(status, 0, standardError);
        assert.deepEqual(JSON.parse(standardOutput), {
            run_id: "run-1",
            job: "build",
            state: "succeeded",
            cache_hit: true,
            output_tree: "a".repeat(64),
        });
    } finally {
        await fake.close();
    }
});

test("the command line rejects missing and removed commands", () => {
    const offload = fileURLToPath(new URL("./offload.ts", import.meta.url));

    for (const args of [[], ["status", "run-1"], ["stop", "run-1"], ["retry", "run-1", "build"], ["log", "run-1", "build"]]) {
        const result = spawnSync(process.execPath, ["--experimental-strip-types", offload, ...args], { encoding: "utf8" });
        assert.equal(result.status, 2);
        assert.match(result.stderr, /usage: offload\.ts/);
    }
});

test("the command line rejects malformed options as usage errors", () => {
    const offload = fileURLToPath(new URL("./offload.ts", import.meta.url));

    for (const args of [["submit", "jobs.json", "--bogus"], ["submit", "jobs.json", "--label"]]) {
        const result = spawnSync(process.execPath, ["--experimental-strip-types", offload, ...args], { encoding: "utf8" });
        assert.equal(result.status, 2, result.stderr);
        assert.match(result.stderr, /usage: offload\.ts/);
    }
});
