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
            pkgs.rustfmt
            pkgs.rust-analyzer
            pkgs.yamllint
            pkgs.ansible
            pkgs.ansible-lint
            pkgs.ansible-language-server
            pkgs.elixir-ls
            pkgs.elixir
            pkgs.haskell-language-server
            pkgs.hlint
            pkgs.clojure-lsp
            pkgs.zls
            pkgs.compcert
            pkgs.cling
            pkgs.shfmt
            pkgs.cabal-install
            pkgs.cabal2nix
            pkgs.stack
            pkgs.ghc
            pkgs.nasm
            pkgs.wasmer
            pkgs.emscripten
            pkgs.pipx
            pkgs.cmake-format
            pkgs.cmakeWithGui
            pkgs.maven
            pkgs.scons
            pkgs.meson
            pkgs.buck
            pkgs.ninja
            pkgs.bazelisk
            pkgs.podman
            pkgs.podman-compose
            pkgs.zeal
            pkgs.picocom
            pkgs.yosys-bluespec
            pkgs.icestorm
            pkgs.nextpnrWithGui
            pkgs.yosys
            pkgs.verilator
            pkgs.gtkwave
            pkgs.bluespec
            pkgs.dotnet-sdk
            pkgs.slack
            pkgs.ngspice
            pkgs.xyce
            pkgs.qucs-s
            pkgs.go-task
            pkgs.ripes
            pkgs.thunderbird
            pkgs.librewolf
            pkgs.firefox
            pkgs.tor-browser-bundle-bin
            pkgs.rr
            pkgs.openocd
            pkgs.age
            pkgs.youtube-dl
            pkgs.gitui
            pkgs.git
            pkgs.git-lfs
            pkgs.git-filter-repo
            pkgs.poppler_utils
            pkgs.graphviz
            pkgs.nsxiv
            pkgs.farbfeld
            pkgs.tmuxp
            pkgs.sent
            pkgs.mc
            pkgs.fd
            pkgs.jq
            pkgs.fzf
            pkgs.exa
            pkgs.pdfgrep
            pkgs.ripgrep
            pkgs.crun
            pkgs.fq
            pkgs.redshift
            pkgs.prusa-slicer
            pkgs.lynx
            pkgs.openscad
            pkgs.freecad
            pkgs.kicad
            pkgs.horizon-eda
            pkgs.jetbrains.pycharm-community
            pkgs.pcb2gcode
            pkgs.candle
            pkgs.tlaplus
            pkgs.tlaplusToolbox
            pkgs.nuXmv
            pkgs.nusmv
            pkgs.alloy6
            pkgs.coq
            pkgs.coqPackages.coqide
            pkgs.ghidra
            pkgs.gnucash
            pkgs.winetricks
            pkgs.wineWowPackages.full
            pkgs.drawio
            pkgs.vlc
            pkgs.meld
            pkgs.tectonic
            pkgs.spotify
            pkgs.discord
            pkgs.element-desktop
            pkgs.signal-desktop
            pkgs.whatsapp-for-linux
            pkgs.tdesktop
            pkgs.anki
            pkgs.reaper
            pkgs.steam
            pkgs.zathura
            pkgs.ipe
            pkgs.keepassxc
            pkgs.obsidian
            pkgs.zotero
            pkgs.drumgizmo
            pkgs.carla
            pkgs.guitarix
            pkgs.swh_lv2
            pkgs.ladspaPlugins
            pkgs.wolf-shaper
            pkgs.distrho
            pkgs.x42-plugins
            pkgs.x42-avldrums
            pkgs.lv2lint
            pkgs.lv2bm
            pkgs.jalv
            pkgs.statix
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
        file.".xresources".source = ../../../x/.xresources;
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
            source = ../../../i3/.config/i3;
            recursive = true;
        };
        configFile."i3status" = {
            source = ../../../i3/.config/i3status;
            recursive = true;
        };
        configFile."rofi" = {
            source = ../../../i3/.config/rofi;
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
