---
when: "*.ts *.tsx *.mts *.cts"
---

# TypeScript

Node runs the `.ts` files directly (type stripping) and checks no types, so `tsc` from the project's `typescript`
package is the lint, and `tsconfig.json` enforces what Node needs:

- Only erasable syntax: no `enum`, `namespace` or parameter properties (`erasableSyntaxOnly`). Use unions instead of
  enums.
- Relative imports carry the `.ts` extension (`allowImportingTsExtensions`); no barrel file.
- Type-only imports use `import type` (`verbatimModuleSyntax`); Node fails on a plain import of a type.
- Built-ins come through `node:` specifiers.

```json
{
  "compilerOptions": {
    "module": "nodenext",
    "strict": true,
    "noEmit": true,
    "allowImportingTsExtensions": true,
    "erasableSyntaxOnly": true,
    "verbatimModuleSyntax": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "types": ["node"]
  }
}
```

- pnpm is the only package manager: `pnpm add` (`-D` for tooling), `pnpm install`, `pnpm exec` for the project's own
  binaries, `pnpm dlx` for one-off ones. Never npm, npx, yarn or bun; `npx tsc` fetches an unrelated package named
  `tsc` instead of running the project's TypeScript.
- Dependencies go into `package.json` with `"type": "module"`; the generated `pnpm-lock.yaml` is committed and
  `/node_modules` is ignored. `package.json` also declares `devEngines`, so npm refuses to work in the project and
  pnpm refuses a Node outside the range:

  ```json
  "devEngines": {
    "packageManager": { "name": "pnpm", "onFail": "error" },
    "runtime": { "name": "node", "version": ">=<major>", "onFail": "error" }
  }
  ```

- `@types/node` is installed as `@types/node@<major>`, where `<major>` is the major version of `node --version`, so
  the types match the runtime; the same `<major>` goes into `devEngines.runtime.version`.
- TypeScript runs with `node` only: `node <file>.ts`, tests with `node --test`. Never tsx, ts-node, bun or deno.
- Tests use `node:test` and `node:assert/strict`.
