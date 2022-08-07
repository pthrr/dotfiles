{ config, pkgs, ... }:

{
    # Home Manager needs a bit of information about you and the
    # paths it should manage.
    home.username = "pthrr";
    home.homeDirectory = "/home/pthrr";

    home.packages = [
        pkgs.jq
    ];

    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    #
    # You can update Home Manager without changing this value. See
    # the Home Manager release notes for a list of state version
    # changes in each release.
    home.stateVersion = "22.05";
    home.enableNixpkgsReleaseCheck = true;

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;

    # files in ~/.config/
    #xdg.configFile."nixpkgs" = {
    #    source = ../../../../dotfiles/nix/.config/nixpkgs;
    #    recursive = true;
    #};

    # files in ~/
    home.file.".gitconfig" = {
        source = ../../../../dotfiles/git/.gitconfig;
        recursive = true;
    };

    home.file.".git-commit-template.txt" = {
        source = ../../../../dotfiles/git/.git-commit-template.txt;
        recursive = true;
    };
}
