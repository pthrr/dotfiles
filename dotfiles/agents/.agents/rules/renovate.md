---
when: "*/renovate.json */renovate.json5 */.renovaterc */.renovaterc.json */.renovaterc.json5"
commands: "renovate renovate-config-validator"
---

# Renovate

Renovate opens as few merge requests as it can: one with every update, and one for lockfile maintenance, which Renovate
never groups with other updates.

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended", "group:all"],
  "minimumReleaseAge": "7 days",
  "minimumReleaseAgeBehaviour": "timestamp-optional",
  "lockFileMaintenance": { "enabled": true },
  "nix": { "enabled": true },
  "packageRules": [{ "matchPackageNames": ["@types/node"], "matchUpdateTypes": ["major"], "enabled": false }]
}
```

- `config:recommended` is Renovate's baseline: the dependency dashboard, workarounds for known registry quirks,
  replacements for deprecated packages, and skipping test fixtures. `group:all` comes after it, so its one group
  overrides the baseline's groups.
- `group:all` puts every update of every layer, majors included, into one merge request.
- `minimumReleaseAge` holds back what Renovate proposes until it is 7 days old; the default
  `internalChecksFilter: "strict"` then proposes the newest release that is.
- `minimumReleaseAgeBehaviour: "timestamp-optional"` lets through updates without a release timestamp, which includes
  lockfile maintenance and flake inputs; the default would hold them back forever. pnpm's and Cargo's own cool-off still
  applies to what lockfile maintenance resolves.
- `lockFileMaintenance` is off by default. It regenerates every lockfile, transitive dependencies and `flake.lock`
  included, in a merge request of its own.
- The `nix` manager is in beta and off by default; without it no flake input moves.
- `packageRules` keeps `@types/node` on the Node major the flake provides, so a TypeScript project needs no second copy
  of the number; other projects leave the entry out.
