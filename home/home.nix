{ pkgs, ... }:

let
  homedir = builtins.getEnv "HOME";
in
{
  imports = [
  ];
  home = {
    sessionVariables.PATH = "/usr/local/opt/mysql@5.7/bin:${homedir}/bin:${homedir}/.cabal/bin:${homedir}/.local/bin:$PATH";
    packages = with pkgs; [
      muchsync
      (haskellPackages.ghcWithPackages (ps: with ps; [hledger]))
      coreutils
    ];
  };

  programs = {

    # Doesnt' work bc clang can't compile it??
    #qutebrowser = {
    #  enable = true;
    #  settings = {
    #    "colors.webpage.darkmode.enabled" = true;
    #  };
    #};

 };
}
