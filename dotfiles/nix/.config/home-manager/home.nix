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

        packages = with pkgs; [
            typescript nodejs_20 nodePackages_latest.eslint nodePackages_latest.fixjson
            sbt-with-scala-native scala scalafmt scalafix scala-cli
            verilator gtkwave yosys symbiyosys icestorm nextpnrWithGui
            bluespec yosys-bluespec
            shfmt
            rustup cargo-rr
            yamlfmt yamllint
            ansible ansible-lint ansible-language-server
            elixir elixir-ls
            ghc cabal-install cabal2nix stack hlint haskell-language-server
            clojure leiningen clojure-lsp
            zls zig
            compcert mold cling rr openocd valgrind gdb gdbgui clang-tools
            nasm
            wasmer emscripten
            scons meson buck ninja bazelisk cmake-format cmake
            go
            crun podman podman-compose
            qemu ripes
            winetricks wineWowPackages.full
            ngspice qucs-s xyce
            thunderbird firefox tor-browser-bundle-bin librewolf
            gitFull git-lfs git-filter-repo meld gitui
            sent go-task age mc tmuxp pipx picocom tio
            jq fzf fq pdfgrep expect
            eza fd bat ripgrep
            openscad freecad kicad horizon-eda prusa-slicer pcb2gcode candle
            tlaplus tlaplusToolbox nuXmv nusmv alloy6
            coq coqPackages.coqide
            discord element-desktop signal-desktop whatsapp-for-linux tdesktop
            redshift
            olive-editor spotify vlc yt-dlp
            obsidian zotero
            poppler_utils graphviz tectonic drawio ipe
            nsxiv farbfeld zathura
            keepassxc
            zeal
            steam
            anki
            gnucash
            reaper carla
            drumgizmo x42-avldrums x42-plugins wolf-shaper distrho
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
