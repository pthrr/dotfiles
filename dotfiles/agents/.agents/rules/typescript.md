---
when: "*.ts *.tsx *.mts *.cts */package.json */tsconfig.json */biome.json */.prettierrc */pnpm-workspace.yaml"
commands: "npm npx pnpm yarn bun tsc tsx ts-node"
---

# TypeScript

tsx runs the `.ts` files directly (esbuild emits to memory) and checks no types, so `pnpm exec tsc`, the project's
own TypeScript, is the type check, and `tsconfig.json` enforces what tsx needs:

- Relative imports carry the `.ts` extension (`allowImportingTsExtensions`); no barrel file.
- Type-only imports use `import type` (`verbatimModuleSyntax`); the loader fails on a plain import of a type.
- Built-ins come through `node:` specifiers.
- Full TypeScript capabilities are on the table (`enum`, parameter properties, namespaces) — `verbatimModuleSyntax`
  and `import type` stay as the contract for which names are types.

```json
{
  "compilerOptions": {
    "module": "nodenext",
    "strict": true,
    "noEmit": true,
    "allowImportingTsExtensions": true,
    "verbatimModuleSyntax": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "types": ["node"]
  }
}
```

- pnpm is the only package manager: `pnpm add` (`-D` for tooling), `pnpm install`, `pnpm exec` for the project's own
  binaries, `pnpm dlx <package>@<version>` with an exact version for one-off ones. Never npm, npx, yarn or bun;
  `npx tsc` fetches an unrelated package named `tsc` instead of running the project's TypeScript. A package of the same
  repository is added with `pnpm add link:<path>`, a symlink, never `file:<path>`, a copy pnpm re-syncs and swaps on
  every install and before every `pnpm exec`. A package of another repository comes from the registry, never through a
  path.
- Dependencies go into `package.json` with `"type": "module"`; the generated `pnpm-lock.yaml` is committed and pins
  them, and `/node_modules` is ignored. `package.json` also declares `devEngines`, so npm refuses to work in the
  project. It names no version: the flake pins pnpm and Node, and a second copy would drift.

  ```json
  "devEngines": {
    "packageManager": { "name": "pnpm", "onFail": "error" }
  }
  ```

- pnpm fails an install on a dependency build script nobody has reviewed. Each one gets a ruling under `allowBuilds` in
  the committed `pnpm-workspace.yaml`, `false` unless the package needs its script; esbuild, which tsx brings, does not.
- `pnpm-workspace.yaml` also sets the 7-day cool-off, `minimumReleaseAge: 10080` (minutes). pnpm applies it to every
  resolution, transitive dependencies included, and fails rather than take a younger version.
- Node comes from the flake as `pkgs.nodejs-slim_<major>`, where `<major>` is the major of nixpkgs' `nodejs-slim_latest`
  when the project starts, its newest stable Node; a higher `nodejs-slim_<n>` can be a pre-release. `@types/node` is
  installed as `@types/node@<major>`, so the types match the runtime. `task update`, and an update bot's config, keep
  `@types/node` within that major; moving to a new major changes both together.
- TypeScript runs with tsx: `pnpm exec tsx <file>.ts`, tests with `pnpm exec tsx --test`. Never ts-node, bun or deno.
  tsx runs the code, so it is a dependency (`pnpm add tsx`); `typescript` and `@types/node` only check it, so they
  are dev dependencies (`pnpm add -D`).
- A `.ts` script outside a pnpm project (no `package.json`) runs with `node` directly, which only strips types, so it
  keeps to erasable syntax: no `enum`, `namespace` or parameter properties.
- Tests use `node:test` and `node:assert/strict`.
- Biome formats TypeScript, JavaScript, JSON and YAML with the repository's `biome.json`, in the standard style: 4
  spaces for code and 2 for JSON and YAML, 120 columns, double quotes, semicolons, trailing commas `all`. prettier
  formats only Vue and Markdown. Neovim formats each file on save, so no task writes formatting; `task pre` holds the
  format checks: `biome format .`, and `prettier --check` for Vue.
- Biome lints: `biome lint --error-on-warnings`, or `biome ci --formatter-enabled=false`, so lint checks no
  formatting. Fix a finding rather than silencing it.
- Every repository commits its own `biome.json`, with the formatter settings above, the 2-space overrides
  `"json": { "formatter": { "indentWidth": 2 } }` and `"yaml": { "formatter": { "indentWidth": 2 } }`,
  `"linter": { "rules": { "preset": "recommended" } }` and, because prettier owns Markdown,
  `"markdown": { "formatter": { "enabled": false }, "linter": { "enabled": false } }`. When it has Vue files, it also
  commits its own `.prettierrc` in the same style: `"printWidth": 120`, `"tabWidth": 4`, `"semi": true`,
  `"singleQuote": false`, `"trailingComma": "all"`, `"proseWrap": "always"`, and a Markdown override,
  `"overrides": [{ "files": "*.md", "options": { "embeddedLanguageFormatting": "off" } }]`, so prettier leaves code
  blocks to the formatter of their language.
- In a pnpm project, Biome, and prettier when the repository has Vue files, are dev dependencies
  (`pnpm add -D @biomejs/biome prettier`), pinned by `pnpm-lock.yaml`, never dev shell packages: Neovim runs the
  project's own `node_modules/.bin/biome` and `prettier`, so a save and the check agree. A repository without
  `package.json` takes them from its flake.
