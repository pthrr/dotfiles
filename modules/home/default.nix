{
  pkgs,
  ...
}:

let
  # Pinned rather than read from ~/.config/git/name.txt / email.txt at eval
  # time: an eval-time read of an absolute home path forced `--impure`, and
  # pinning keeps the flake a pure function of its inputs.
  commonUser = {
    name = "pthrr";
    email = "pthrr@posteo.de";
  };
in
{
  _module.args.commonUser = commonUser;

  imports = [
    ./packages.nix
    ./files.nix
    ./agents.nix
    ./vcs.nix
    ./editor.nix
    ./battery.nix
    ./sccache.nix
    ./activation.nix
    ./flatpak.nix
  ];

  home = {
    # Explicit strings instead of builtins.getEnv: evaluation is flake-based
    # now, and pinned values keep the setup deterministic across machines.
    username = "pthrr";
    homeDirectory = "/home/pthrr";
    stateVersion = "22.05";
    enableNixpkgsReleaseCheck = false;

    # ccache reads XDG config (see xdg.configFile in files.nix); the env var is a
    # belt-and-braces fallback for tools that spawn ccache without inheriting
    # the config file. sccache needs none: the sccache-daemon user service
    # (sccache.nix) owns the remote-vs-local decision, and ~/bin/sccache-wrapper
    # only points clients at its socket — which is what lets sandboxed builds
    # (nix sandboxes, agent harnesses) reach the remote S3 without any network.
    sessionVariables = {
      CCACHE_MAXSIZE = "5G";
      # sccache refuses to cache any unit compiled with -C incremental, so stop
      # cargo from requesting incremental compilation at all (upstream sccache
      # guidance; cargo reads this from the real environment, config [env]
      # doesn't reach its own decision). Trade-off: edit-rebuild iteration
      # within a session is slightly slower; clean/rebuild-heavy flows are much
      # faster. Per-project override: CARGO_INCREMENTAL=1 in .envrc.
      CARGO_INCREMENTAL = "0";
      # OpenCode enables its built-in LSP servers from opencode.json; this keeps
      # it to the servers home-manager installs instead of downloading its own.
      OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
    };
  };

  nixpkgs.config.allowUnfree = true;

  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
