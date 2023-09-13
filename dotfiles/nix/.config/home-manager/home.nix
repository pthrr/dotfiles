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
        enableNixpkgsReleaseCheck = false;

        packages = [
            pkgs.yt-dlp
            pkgs.expect
            pkgs.pipx
            pkgs.shfmt
            pkgs.rustup pkgs.cargo-rr
            pkgs.yamlfmt pkgs.yamllint
            pkgs.ansible pkgs.ansible-lint pkgs.ansible-language-server
            pkgs.elixir pkgs.elixir-ls
            pkgs.ghc pkgs.cabal-install pkgs.cabal2nix pkgs.stack
            pkgs.hlint pkgs.haskell-language-server
            pkgs.clojure pkgs.leiningen pkgs.clojure-lsp
            pkgs.zls pkgs.zig
            pkgs.compcert pkgs.mold pkgs.cling
            pkgs.rr pkgs.openocd pkgs.valgrind pkgs.gdb pkgs.gdbgui
            pkgs.olive-editor
            pkgs.clang-tools
            pkgs.nasm
            pkgs.wasmer
            pkgs.emscripten
            pkgs.scons pkgs.meson pkgs.buck pkgs.ninja pkgs.bazelisk
            pkgs.cmake-format pkgs.cmake
            pkgs.go
            pkgs.crun pkgs.podman pkgs.podman-compose
            pkgs.qemu pkgs.ripes
            pkgs.winetricks pkgs.wineWowPackages.full
            pkgs.verilator pkgs.gtkwave pkgs.icestorm pkgs.nextpnrWithGui
            pkgs.bluespec pkgs.yosys pkgs.yosys-bluespec
            pkgs.ngspice pkgs.qucs-s pkgs.xyce
            pkgs.thunderbird pkgs.firefox pkgs.tor-browser-bundle-bin pkgs.librewolf
            pkgs.gitFull pkgs.git-lfs pkgs.git-filter-repo pkgs.meld pkgs.gitui
            pkgs.poppler_utils pkgs.graphviz
            pkgs.nsxiv pkgs.farbfeld
            pkgs.tmuxp
            pkgs.sent
            pkgs.go-task
            pkgs.mc
            pkgs.jq
            pkgs.fzf
            pkgs.pdfgrep
            pkgs.eza pkgs.fd pkgs.bat pkgs.ripgrep
            pkgs.fq
            pkgs.zeal
            pkgs.picocom pkgs.tio
            pkgs.age
            pkgs.redshift
            pkgs.openscad pkgs.freecad pkgs.kicad pkgs.horizon-eda
            pkgs.prusa-slicer pkgs.pcb2gcode pkgs.candle
            pkgs.tlaplus pkgs.tlaplusToolbox pkgs.nuXmv pkgs.nusmv pkgs.alloy6
            pkgs.coq pkgs.coqPackages.coqide
            pkgs.drawio pkgs.ipe
            pkgs.discord pkgs.element-desktop
            pkgs.signal-desktop pkgs.whatsapp-for-linux pkgs.tdesktop
            pkgs.vlc
            pkgs.river
            pkgs.steam
            pkgs.spotify
            pkgs.zathura
            pkgs.keepassxc
            pkgs.obsidian
            pkgs.zotero
            pkgs.tectonic
            pkgs.anki
            pkgs.gnucash
            pkgs.reaper pkgs.carla
            pkgs.drumgizmo pkgs.x42-avldrums
            pkgs.x42-plugins pkgs.wolf-shaper pkgs.distrho
        ];

        # files in ~/
        file.".bashrc".source = ../../../bash/.bashrc;
        file.".profile".source = ../../../bash/.profile;
        file."key-bindings.bash".source = ../../../bash/key-bindings.bash;
        file."z.sh".source = ../../../bash/z.sh;
        file."git-prompt.sh".source = ../../../bash/git-prompt.sh;

        file.".tmux.conf".source = ../../../tmux/.tmux.conf;
        file.".tmuxp" = {
            source = ../../../tmux/.tmuxp;
            recursive = true;
        };

        file.".gitconfig".source = ../../../git/.gitconfig;
        file.".git-commit-template.txt".source = ../../../git/.git-commit-template.txt;

        file.".clang-tidy".source = ../../../lang/.clang-tidy;
        file.".clang-format".source = ../../../lang/.clang-format;

        file.".ssh" = {
            source = ../../../ssh/.ssh;
            recursive = true;
        };

        file.".local/share/applications/Joplin.desktop".source = ../../../misc/.local/share/applications/Joplin.desktop;
        file."bin" = {
            source = ../../../misc/bin;
            recursive = true;
        };

        file."Vorlagen/snippets" = {
            source = ../../../nvim/Vorlagen/snippets;
            recursive = true;
        };
        file."Vorlagen/slides" = {
            source = ../../../sent/Vorlagen/slides;
            recursive = true;
        };

        file.".xinitrc".source = ../../../x/.xinitrc;
        file.".Xresources".source = ../../../x/.Xresources;
        file.".Xdefaults".source = ../../../x/.Xdefaults;
        file.".xsessionrc".source = ../../../x/.xsessionrc;
        file.".xprofile".source = ../../../x/.xprofile;
    };

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;

    programs.neovim = {
        enable = true;
        plugins = [
            pkgs.vimPlugins.nvim-treesitter.withAllGrammars
            pkgs.vimPlugins.nvim-treesitter-textobjects
            pkgs.vimPlugins.plenary-nvim
            pkgs.vimPlugins.telescope-nvim
        ];
    };

    xdg = {
        # files in ~/.config/
        configFile."i3" = {
            source = ../../../wm/.config/i3;
            recursive = true;
        };
        configFile."i3status" = {
            source = ../../../wm/.config/i3status;
            recursive = true;
        };
        configFile."rofi" = {
            source = ../../../wm/.config/rofi;
            recursive = true;
        };
        configFile."sway" = {
            source = ../../../wm/.config/sway;
            recursive = true;
        };

        configFile."foot" = {
            source = ../../../foot/.config/foot;
            recursive = true;
        };

        configFile."zathura" = {
            source = ../../../zathura/.config/zathura;
            recursive = true;
        };

        configFile."mc" = {
            source = ../../../mc/.config/mc;
            recursive = true;
        };

        configFile."nvim" = {
            source = ../../../nvim/.config/nvim;
            recursive = true;
        };
    };
}
