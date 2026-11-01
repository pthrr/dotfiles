/** Deterministic, owner-writable GNU tar archives split into bounded input files. */
import { spawn } from "node:child_process";
import { closeSync, mkdirSync, openSync, realpathSync, rmSync, statSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

export const chunkBytes = 32 * 1024 * 1024;

/** Creates a new destination; existing directories and the source are never changed. */
export async function packInputs(sourcePath: string, destinationPath: string) {
    const source = realpathSync(sourcePath);
    const requested = resolve(destinationPath);
    const destination = join(realpathSync(dirname(requested)), basename(requested));
    const sourcePrefix = source === sep ? sep : `${source}${sep}`;

    if (!statSync(source).isDirectory()) {
        throw new Error("source must be a directory");
    }

    if (destination === source || destination.startsWith(sourcePrefix)) {
        throw new Error("destination must be outside the source directory");
    }

    mkdirSync(destination);
    let descriptor: number | undefined;
    let partSize = 0;
    let chunks = 0;
    let bytes = 0;
    const archive = spawn("tar", [
        "--create", "--sort=name", "--mtime=@0", "--owner=0", "--group=0",
        "--numeric-owner", "--format=gnu", "--mode=u+w",
        "--use-compress-program=gzip -1 -n", "--file=-", "--directory", source, "--", ".",
    ], {
        stdio: ["ignore", "pipe", "pipe"],
        env: { ...process.env, LC_ALL: "C", TZ: "UTC", TAR_OPTIONS: "", GZIP: "" },
    });
    let failure: Error | undefined;
    let diagnostics = "";

    archive.on("error", (error) => {
        failure = error;
    });

    archive.stderr.on("data", (chunk: Buffer) => {
        diagnostics = (diagnostics + chunk.toString()).slice(-8192);
    });

    const completed = new Promise<number | null>((done) => archive.once("close", done));

    try {
        for await (const chunk of archive.stdout) {
            let offset = 0;

            while (offset < chunk.length) {
                if (descriptor === undefined) {
                    const name = `part-${String(chunks).padStart(6, "0")}`;
                    descriptor = openSync(join(destination, name), "wx", 0o644);
                    chunks += 1;
                    partSize = 0;
                }

                const length = Math.min(chunk.length - offset, chunkBytes - partSize);
                writeFileSync(descriptor, chunk.subarray(offset, offset + length));
                offset += length;
                partSize += length;
                bytes += length;

                if (partSize === chunkBytes) {
                    closeSync(descriptor);
                    descriptor = undefined;
                }
            }
        }

        const status = await completed;

        if (failure) {
            throw failure;
        }

        if (status !== 0) {
            throw new Error(`tar failed (${status}): ${diagnostics.trim()}`);
        }

        if (descriptor !== undefined) {
            closeSync(descriptor);
            descriptor = undefined;
        }

        return { directory: destination, chunks, bytes };
    } catch (error) {
        archive.kill("SIGKILL");
        await completed;

        if (descriptor !== undefined) {
            closeSync(descriptor);
        }

        rmSync(destination, { recursive: true, force: true });
        throw error;
    }
}

if (fileURLToPath(import.meta.url) === resolve(process.argv[1] ?? "")) {
    try {
        if (process.argv.length !== 4) {
            throw new Error("usage: pack.ts <source-directory> <new-chunks-directory>");
        }

        console.log(JSON.stringify(await packInputs(process.argv[2], process.argv[3])));
    } catch (error) {
        console.error(error instanceof Error ? error.message : String(error));
        process.exitCode = 1;
    }
}
