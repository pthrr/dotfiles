---
when: "*.nix */flake.lock"
commands: "nix nix-build nix-shell nix-instantiate nixos-rebuild nixos-enter"
---

# Nix

## Checks

- `pre` may enter `nix develop` and build one component; a full build, or a check of every output, belongs in `ci` or
  `nightly`.

## Evaluation

- A path Nix reads during evaluation is a parameter: it points at the evaluating machine and comes from the
  environment under `--impure`. A path Nix writes into the output is a constant: it describes the booted system and is
  never overridable, or an evaluation from another machine or a rescue shell bakes that machine's paths into the store.
- From a rescue shell, override only the parameters, or chroot with `nixos-enter --root /mnt` so nothing needs
  overriding.
- `builtins.fetchGit` on a local checkout without `ref` includes uncommitted changes; `ref = "HEAD"` takes the
  committed tree only.
- Flake inputs are bumped together, with `nix flake update`, the project's `task update`, or an update bot's grouped
  change or lockfile maintenance, never with `nix flake update <input>` or one input per change: inputs released
  together, such as nixpkgs and home-manager, are only tested together.

## NixOS modules

- A `lib.mkIf` condition reads only cheap values: bools and strings set directly, or `nullOr` options with defaults.
  Forcing an option that is itself merged from other modules (`users.users`, `environment.etc`, `virtualHosts`)
  recurses infinitely, because merging that option first discharges the `mkIf`.
- An option several modules share is declared in a module that is always imported, not in the one providing it, so
  its consumers still evaluate when the provider is removed. A consumer wraps its use in `lib.mkIf` on the provider's
  flag and does not re-enable the provider through an upstream default.
- Upstream NixOS units keep their own sandbox: merging a second `SystemCallFilter` into theirs can widen it.

## State and switching

- A directory a service owns is declared in `systemd.tmpfiles.rules`. `systemd-tmpfiles-setup` applies the rules at
  boot before ordinary services start. On a switch that changed them, `systemd-tmpfiles-resetup` (pulled in by
  `sysinit-reactivation.target`) applies them after the activation script and before any unit starts or restarts, so
  a service added by the same switch finds its directory.
- Exception: a path below a filesystem the same switch adds. New mounts start after tmpfiles ran, so the directory
  would be created on the disk underneath and hidden by the mount. Give `systemd-tmpfiles-resetup` a
  `RequiresMountsFor` on the mount, and create the mount's source in an activation script, the one job left for one,
  with the reason next to it.
- Never repeat a tmpfiles rule in an activation script: a copy whose mode or owner drifts and the rule reset each other
  on every switch.
- NixOS assigns user and group IDs the first time it sees a name and remembers them in `/var/lib/nixos` on the root
  partition; a reinstall assigns new numbers. Every user and group that owns persistent files pins `uid`/`gid`, those
  with a static ID in `ids.nix` included: the pin turns an upstream change of that ID into an evaluation error instead
  of a silent remap.
- A switch restarts a unit only when its definition changed. A file the unit reads at run time (a secret, a value
  another unit renders) changes no definition, so its consumers need an explicit restart.

## Scripts in modules

- Unit scripts are inline TypeScript on the nixbits prelude (`nixbitsLib.ts`, `nixbitsLib.tsWithEnv`), not shell.
  Shell stays for one-liners and `exec` launchers. A helper any NixOS repo could use and several scripts need belongs
  in the nixbits prelude.
- Inside a Nix `''` string: no JavaScript template literals (`${` is Nix interpolation) and no `''`; interpolate
  values through `builtins.toJSON`; run an async body through `main()`, never a bare async IIFE.
