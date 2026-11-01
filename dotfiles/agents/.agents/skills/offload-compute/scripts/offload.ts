/** The command line of the offload-compute skill; see SKILL.md next to it. */
import { parseArgs } from "node:util";
import {
    fetchOutputs,
    follow,
    jobSummary,
    runSummary,
    Server,
    submit,
    wait,
    waitForJob,
} from "./tinyci.ts";

const usage = `usage: offload.ts <command> ...
  submit <jobs.json> [--label text]     check the run, upload the inputs, start it
  wait <run> [job]                      until the run or one job finished; print a summary; exit 1 unless all succeeded
  follow <run> <job>                    compact state/log stream until it ends; exit 1 unless it succeeded
  fetch <run> <job> <dest> [path ...]   write the job's outputs, or only these paths, into a new directory
The server is $TINYCI_URL, http://nullwave.de:8020 by default.`;

class UsageError extends Error {}

/** The positional arguments of a command, at least `min` and at most `max` of them. */
function argumentsOf(values: string[], min: number, max = min): string[] {
    if (values.length < min || values.length > max) throw new UsageError(usage);

    return values;
}

/** Parses the command line, reporting a malformed option as a usage error. */
function parseCommandLine(argv: string[]) {
    try {
        return parseArgs({
            args: argv,
            options: { label: { type: "string" } },
            allowPositionals: true,
        });
    } catch (error) {
        throw new UsageError(`${error instanceof Error ? error.message : String(error)}\n${usage}`);
    }
}

async function main(argv: string[]): Promise<number> {
    const { values, positionals } = parseCommandLine(argv);
    const [command, ...rest] = positionals;
    const server = new Server(process.env.TINYCI_URL ?? "http://nullwave.de:8020");
    const print = (value: unknown) => console.log(JSON.stringify(value, null, 2));

    switch (command) {
        case "submit": {
            const [jobFile] = argumentsOf(rest, 1);
            print(await submit(server, jobFile, values.label));
            return 0;
        }
        case "wait": {
            const [run, job] = argumentsOf(rest, 1, 2);

            if (job === undefined) {
                const result = await wait(server, run);
                print(runSummary(result.run));
                return result.succeeded ? 0 : 1;
            }

            const result = await waitForJob(server, run, job);
            print({ run_id: run, job, ...jobSummary(result.job) });
            return result.succeeded ? 0 : 1;
        }
        case "follow": {
            const [run, job] = argumentsOf(rest, 2);
            return (await follow(server, run, job)) ? 0 : 1;
        }
        case "fetch": {
            const [run, job, dest, ...paths] = argumentsOf(rest, 3, Number.POSITIVE_INFINITY);
            print(await fetchOutputs(server, run, job, dest, paths));
            return 0;
        }
        default:
            throw new UsageError(usage);
    }
}

main(process.argv.slice(2)).then(
    (code) => {
        process.exitCode = code;
    },
    (error: unknown) => {
        console.error(error instanceof Error ? error.message : String(error));
        process.exitCode = error instanceof UsageError ? 2 : 1;
    },
);
