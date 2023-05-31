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
            pkgs.hlint
            pkgs.picocom
            pkgs.yosys-bluespec
            pkgs.icestorm
            pkgs.nextpnrWithGui
            pkgs.yosys
            pkgs.verilator
            pkgs.gtkwave
            pkgs.bluespec
            pkgs.elixir
            pkgs.elixir-ls
            pkgs.mozwire
            pkgs.mozillavpn
            pkgs.dotnet-sdk
            pkgs.slack
            pkgs.nuXmv
            pkgs.nusmv
            pkgs.discord
            pkgs.tmuxp
            pkgs.wasmer
            pkgs.emscripten
            pkgs.tlaplus
            pkgs.tlaplusToolbox
            pkgs.alloy6
            pkgs.swh_lv2
            pkgs.ladspaPlugins
            pkgs.wolf-shaper
            pkgs.distrho
            pkgs.x42-plugins
            pkgs.x42-avldrums
            pkgs.zig
            pkgs.cabal-install
            pkgs.cabal2nix
            pkgs.stack
            pkgs.ghc
            pkgs.haskell-language-server
            pkgs.element-desktop
            pkgs.kicad
            pkgs.horizon-eda
            pkgs.pcb2gcode
            pkgs.candle
            pkgs.maven
            pkgs.anki
            pkgs.reaper
            pkgs.steam
            pkgs.whatsapp-for-linux
            pkgs.tdesktop
            pkgs.neofetch
            pkgs.ngspice
            pkgs.xyce
            pkgs.qucs-s
            pkgs.shfmt
            pkgs.thunderbird
            pkgs.librewolf
            pkgs.go-task
            pkgs.ripes
            pkgs.firefox
            pkgs.drumgizmo
            pkgs.carla
            pkgs.guitarix
            pkgs.rr
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
            pkgs.sent
            pkgs.transmission-gtk
            pkgs.mc
            pkgs.prusa-slicer
            pkgs.lynx
            pkgs.openscad
            pkgs.coq
            pkgs.coqPackages.coqide
            pkgs.compcert
            pkgs.dwarf-fortress
            pkgs.texlive.combined.scheme-basic
            pkgs.cling
            pkgs.ghidra
            pkgs.rustfmt
            pkgs.rust-analyzer
            pkgs.gnucash
            pkgs.winetricks
            pkgs.wineWowPackages.full
            pkgs.lv2lint
            pkgs.lv2bm
            pkgs.jalv
            pkgs.statix
            pkgs.tor-browser-bundle-bin
            pkgs.drawio
            pkgs.meson
            pkgs.bazelisk
            pkgs.jq
            pkgs.vlc
            pkgs.meld
            pkgs.cmakeWithGui
            pkgs.cmake-format
            pkgs.tectonic
            pkgs.ninja
            pkgs.spotify
            pkgs.zathura
            pkgs.ipe
            pkgs.ripgrep
            pkgs.fd
            pkgs.fzf
            pkgs.exa
            pkgs.redshift
            pkgs.keepassxc
            pkgs.obsidian
            pkgs.buck
            pkgs.zotero
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
        file."scripts" = {
            source = ../../../misc/scripts;
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
            pkgs.vimPlugins.coc-nvim
            pkgs.vimPlugins.coc-cmake
            pkgs.vimPlugins.coc-clangd
            pkgs.vimPlugins.coc-pyright
            pkgs.vimPlugins.coc-rust-analyzer
            pkgs.vimPlugins.coc-toml
            pkgs.vimPlugins.coc-yaml
            pkgs.vimPlugins.coc-json
            pkgs.vimPlugins.coc-sh
            pkgs.vimPlugins.coc-docker
            pkgs.vimPlugins.coc-java
            pkgs.vimPlugins.coc-markdownlint
            pkgs.vimPlugins.coc-snippets
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
