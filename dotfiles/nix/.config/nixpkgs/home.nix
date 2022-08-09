{ config, pkgs, ... }:

{
    home = {
        # Home Manager needs a bit of information about you and the
        # paths it should manage.
        username = builtins.getEnv "USER";
        homeDirectory = builtins.getEnv "HOME";

        # This value determines the Home Manager release that your
        # configuration is compatible with. This helps avoid breakage
        # when a new Home Manager release introduces backwards
        # incompatible changes.
        #
        # You can update Home Manager without changing this value. See
        # the Home Manager release notes for a list of state version
        # changes in each release.
        stateVersion = "22.05";
        enableNixpkgsReleaseCheck = true;

        packages = [
            pkgs.jq
            pkgs.neovim
            pkgs.obsidian
            pkgs.zotero
            pkgs.nextcloud-client
            pkgs.joplin-desktop
        ];

        # files in ~/
        file.".bashrc".source = ../../../bash/.bashrc;
        file.".tmux.conf".source = ../../../bash/.tmux.conf;
        file."key-bindings.bash".source = ../../../bash/key-bindings.bash;
        file."z.sh".source = ../../../bash/z.sh;

        file.".gitconfig".source = ../../../git/.gitconfig;
        file.".git-commit-template.txt".source = ../../../git/.git-commit-template.txt;

        file.".clang-format".source = ../../../lang/.clang-format;
        file.".clang-tidy".source = ../../../lang/.clang-tidy;
        file.".pylintrc".source = ../../../lang/.pylintrc;

        file.".ssh" = {
            source = ../../../misc/.ssh;
            recursive = true;
        };

        file.".weechat" = {
            source = ../../../misc/.weechat;
            recursive = true;
        };

        file."bin" = {
            source = ../../../misc/bin;
            recursive = true;
        };

        file."mail" = {
            source = ../../../misc/mail;
            recursive = true;
        };

        file."Dokumente/snippets" = {
            source = ../../../nvim/Dokumente/snippets;
            recursive = true;
        };

        file.".profile".source = ../../../x/.profile;
        file.".xinitrc".source = ../../../x/.xinitrc;
        file.".xresources".source = ../../../x/.xresources;
        file.".xsessionrc".source = ../../../x/.xsessionrc;
    };

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;

    xdg = {
        # files in ~/.config/
        configFile."i3" = {
            source = ../../../../dotfiles/i3/.config/i3;
            recursive = true;
        };
        configFile."i3status" = {
            source = ../../../../dotfiles/i3/.config/i3status;
            recursive = true;
        };
        configFile."rofi" = {
            source = ../../../../dotfiles/i3/.config/rofi;
            recursive = true;
        };

        configFile."zathura" = {
            source = ../../../../dotfiles/misc/.config/zathura;
            recursive = true;
        };

        configFile."nvim" = {
            source = ../../../../dotfiles/nvim/.config/nvim;
            recursive = true;
        };
    };
}
