/** A conservative convenience allowlist, not a shell interpreter or sandbox. */
import { homedir } from "node:os";
import { resolve } from "node:path";

export function shellCommands(command: string): string[][] | null {
    // Expansions can execute code inside an otherwise read-only command.
    // A backslash is not an expansion — it is checked in the scan below, where
    // the quoting context is known, because rejecting it outright turned every
    // regex escape (\., \b, \d) into a write and sent plain greps to consent.
    if (/[$`\0]/.test(command)) return null;
    const commands: string[][] = [];
    let words: string[] = [],
        word = "",
        quote = "";
    const flushWord = () => {
        if (word) words.push(word);
        word = "";
    };
    const flushCommand = () => {
        flushWord();
        if (words.length) commands.push(words);
        words = [];
    };
    for (let i = 0; i < command.length; i++) {
        const char = command[i];
        if (quote) {
            // Single quotes give a backslash no meaning in POSIX sh, so it is
            // literal text that cannot desync this scan — which is exactly
            // where a regex escape belongs. Inside double quotes it still
            // escapes, the closing quote included, so it stays rejected there.
            if (char === "\\" && quote === '"') return null;
            if (char === quote) quote = "";
            else word += char;
        } else if (char === "\\") {
            return null;
        } else if (char === "'" || char === '"') {
            quote = char;
        } else if ("<>()".includes(char)) {
            return null;
        } else if (char === "#" && !word) {
            while (i < command.length && command[i] !== "\n") i++;
            flushCommand();
        } else if (";&|\n".includes(char)) {
            if (char === "&" && command[i + 1] !== "&") return null;
            if ((char === "&" || char === "|") && command[i + 1] === char) i++;
            flushCommand();
        } else if (/\s/.test(char)) {
            flushWord();
        } else {
            word += char;
        }
    }
    if (quote) return null;
    flushCommand();
    return commands;
}

function readonlyCommand([name, ...args]: string[]): boolean {
    // Bare executable names only: ./cat is an arbitrary local program.
    // Nothing here writes without a redirection, and redirections are rejected
    // by the scan above. Deliberately absent: find (-delete, -exec), awk and
    // xargs (execute), env (runs its argument), uniq (takes an output-file
    // positional), tee and dd.
    if (
        [
            "pwd",
            "ls",
            "cat",
            "head",
            "tail",
            "wc",
            "stat",
            "readlink",
            "realpath",
            "grep",
            "jq",
            "true",
            "false",
            "echo",
            "printf",
            "dirname",
            "basename",
            "diff",
            "cmp",
            "file",
            "which",
            "test",
            "md5sum",
            "sha256sum",
            "du",
            "df",
            "tr",
            "cut",
            "nl",
            "rev",
        ].includes(name)
    )
        return true;
    // sort writes when told to: -o/--output names a destination. -o takes an
    // argument, so inside a short cluster it can only be last (-no out), and
    // the long form abbreviates down to --o.
    if (name === "sort") return !args.some((arg) => /^--o/.test(arg) || /^-[a-zA-Z]*o/.test(arg));
    if (name === "rg") return !args.some((arg) => /^(--pre|--hostname-bin)/.test(arg));
    if (name === "sed") {
        if (args[0] !== "-n" || !/^\d+(?:,[\d$]+)?p$/.test(args[1] ?? "")) return false;
        // sed accepts options after the script and filenames. Before "--",
        // allow only literal paths: glob/brace expansion can introduce options.
        for (const arg of args.slice(2)) {
            if (arg === "--") return true;
            if (arg.startsWith("-") || /[*?\[\]{}]/.test(arg)) return false;
        }
        return true;
    }
    if (name === "command") return ["-v", "-V"].includes(args[0]);
    if (name === "git") {
        while (["-C", "--no-optional-locks", "--no-pager"].includes(args[0])) {
            const count = args[0] === "-C" ? 2 : 1;
            if (args.length < count) return false;
            args = args.slice(count);
        }
        if (args.some((arg) => /^(--output|--ext-diff|--textconv|--config-env)/.test(arg))) return false;
        return (
            ["status", "diff", "log", "show", "ls-files", "ls-tree", "rev-parse", "check-ignore"].includes(args[0]) ||
            (args.length === 2 && args[0] === "branch" && args[1] === "--show-current")
        );
    }
    return false;
}

export function expandHome(path: string): string {
    return path === "~" ? homedir() : path.startsWith("~/") ? homedir() + path.slice(1) : path;
}

export function shellEffect(
    command: string,
    cwd: string,
): { readonly: boolean; directories: string[]; reads: string[] } {
    const commands = shellCommands(command);
    if (!commands) return { readonly: false, directories: [cwd], reads: [] };
    let directory = cwd,
        readonly = true;
    const directories = new Set([cwd]),
        reads: string[] = [];
    for (const words of commands) {
        if (words[0] === "cd" && words.length === 2 && !words[1].startsWith("-")) {
            directory = resolve(directory, expandHome(words[1]));
            directories.add(directory);
            continue;
        }
        const safe = readonlyCommand(words);
        readonly &&= safe;
        if (safe && ["cat", "head", "tail", "sed"].includes(words[0])) {
            for (const arg of words.slice(1)) {
                if (!arg.startsWith("-")) reads.push(resolve(directory, expandHome(arg)));
            }
        }
    }
    return { readonly, directories: [...directories].sort(), reads };
}
