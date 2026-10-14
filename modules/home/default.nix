{
  config,
  pkgs,
  ...
}:

let
  defaultUserName = "pthrr";
  defaultUserEmail = "pthrr@posteo.de";
  gitUserNameFile = "${config.home.homeDirectory}/.config/git/name.txt";
  gitUserEmailFile = "${config.home.homeDirectory}/.config/git/email.txt";
  gitUserName =
    if builtins.pathExists gitUserNameFile then
      let
        content = builtins.readFile gitUserNameFile;
      in
      builtins.trace "gitUserNameFile exists: ${content}" content
    else
      builtins.trace "gitUserNameFile does not exist, using default" defaultUserName;
  gitUserEmail =
    if builtins.pathExists gitUserEmailFile then
      let
        content = builtins.readFile gitUserEmailFile;
      in
      builtins.trace "gitUserEmailFile exists: ${content}" content
    else
      builtins.trace "gitUserEmailFile does not exist, using default" defaultUserEmail;

  commonUser = {
    name = gitUserName;
    email = gitUserEmail;
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
    # the config file. sccache is deliberately absent here: ~/bin/sccache-wrapper
    # owns SCCACHE_* setup (remote S3 on nwv-srv:8333 when reachable, else
    # local ~/.cache/sccache capped at 5G), and it starts a clean env, so any
    # SCCACHE_CACHE_SIZE set here would be discarded anyway.
    sessionVariables = {
      CCACHE_MAXSIZE = "5G";
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
