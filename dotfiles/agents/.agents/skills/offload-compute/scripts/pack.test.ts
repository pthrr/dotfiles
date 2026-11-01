import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import {
    chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync,
    readlinkSync, rmSync, statSync, symlinkSync, utimesSync, writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";
import { chunkBytes, packInputs } from "./pack.ts";

test("archives round-trip across chunks with writable modes, executables and symlinks", async (context) => {
    const root = mkdtempSync(join(tmpdir(), "offload-pack-"));
    const source = join(root, "source");
    const nested = join(source, "read-only");
    mkdirSync(nested, { recursive: true });

    context.after(() => {
        chmodSync(nested, 0o755);
        rmSync(root, { recursive: true, force: true });
    });

    const content = randomBytes(chunkBytes + 65536);
    writeFileSync(join(nested, "data"), content, { mode: 0o444 });
    writeFileSync(join(nested, "run"), "#!/bin/sh\necho ready\n", { mode: 0o555 });
    symlinkSync("read-only/data", join(source, "link"));
    chmodSync(nested, 0o555);
    const first = await packInputs(source, join(root, "first"));
    const names = readdirSync(first.directory).sort();
    assert.equal(first.chunks, 2);
    assert.equal(statSync(join(first.directory, names[0])).size, chunkBytes);
    assert.ok(statSync(join(first.directory, names[1])).size <= chunkBytes);
    const archive = Buffer.concat(names.map((name) => readFileSync(join(first.directory, name))));
    assert.equal(first.bytes, archive.length);
    utimesSync(join(nested, "data"), new Date(), new Date());
    const second = await packInputs(source, join(root, "second"));

    for (const name of names) {
        assert.deepEqual(readFileSync(join(second.directory, name)), readFileSync(join(first.directory, name)));
    }

    const extracted = join(root, "extracted");
    mkdirSync(extracted);
    const result = spawnSync("tar", ["--extract", "--gzip", "--no-same-owner", "--directory", extracted], {
        input: archive,
        encoding: "utf8",
    });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(readFileSync(join(extracted, "read-only/data")), content);
    assert.equal(readlinkSync(join(extracted, "link")), "read-only/data");
    assert.equal(statSync(join(extracted, "read-only")).mode & 0o777, 0o755);
    assert.equal(statSync(join(extracted, "read-only/run")).mode & 0o777, 0o755);
    assert.equal(statSync(join(extracted, "read-only/data")).mode & 0o777, 0o644);
    assert.equal(statSync(nested).mode & 0o777, 0o555);
    assert.equal(statSync(join(nested, "run")).mode & 0o777, 0o555);
});

test("an existing destination is preserved", async (context) => {
    const root = mkdtempSync(join(tmpdir(), "offload-pack-"));
    context.after(() => rmSync(root, { recursive: true, force: true }));
    mkdirSync(join(root, "source"));
    mkdirSync(join(root, "chunks"));
    writeFileSync(join(root, "chunks/keep"), "keep");
    await assert.rejects(packInputs(join(root, "source"), join(root, "chunks")), /EEXIST/);
    assert.equal(readFileSync(join(root, "chunks/keep"), "utf8"), "keep");
});

test("destinations inside the source, including through a parent symlink, are refused", async (context) => {
    const root = mkdtempSync(join(tmpdir(), "offload-pack-"));
    context.after(() => rmSync(root, { recursive: true, force: true }));
    mkdirSync(join(root, "source"));
    symlinkSync("source", join(root, "alias"));
    await assert.rejects(packInputs(join(root, "source"), join(root, "alias/chunks")), /outside/);
    await assert.rejects(packInputs("/", join(root, "chunks")), /outside/);
    assert.deepEqual(readdirSync(join(root, "source")), []);
});

test("a failed archiver removes its own partial destination", (context) => {
    const root = mkdtempSync(join(tmpdir(), "offload-pack-"));
    context.after(() => rmSync(root, { recursive: true, force: true }));
    mkdirSync(join(root, "source"));
    const result = spawnSync(process.execPath, [
        "--experimental-strip-types", fileURLToPath(new URL("pack.ts", import.meta.url)),
        join(root, "source"), join(root, "chunks"),
    ], { env: { ...process.env, PATH: "/nonexistent" }, encoding: "utf8" });
    assert.equal(result.status, 1, result.stderr);
    assert.match(result.stderr, /ENOENT/);
    assert.equal(existsSync(join(root, "chunks")), false);
});
