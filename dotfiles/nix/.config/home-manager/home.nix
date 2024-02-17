{ config, lib, pkgs, ... }:

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
            # ide
            jetbrains.clion
            jetbrains.webstorm deno bun
            jetbrains.pycharm-professional micromamba
            jetbrains.jdk jetbrains.idea-ultimate
            # langs
            koka
            cue cuelsp cuetools
            zig zls
            tectonic
            typst typst-fmt typst-lsp
            scala_3 sbt-with-scala-native scalafmt scalafix scala-cli metals
            ansible ansible-lint ansible-language-server
            yamlfmt yamllint
            ghc cabal-install cabal2nix stack hlint haskell-language-server
            compcert mold cling rr openocd valgrind gdb gdbgui
            shfmt
            nasm
            wasmer emscripten wasmtime
            rustup cargo-rr
            elixir elixir-ls
            clojure leiningen clojure-lsp
            go
            cmake-format
            nodePackages_latest.fixjson
            protobuf protobufc
            bluespec yosys-bluespec
            # dev tools
            gitFull git-lfs git-filter-repo meld
            scons meson buck ninja bazelisk bmake
            go-task
            crun podman podman-desktop podman-compose
            #
            yosys verilator gtkwave symbiyosys icestorm nextpnrWithGui
            picotool
            qemu ripes
            winetricks wineWowPackages.full
            ngspice qucs-s xyce
            # sw
            thunderbird firefox tor-browser-bundle-bin nyxt w3m
            discord element-desktop signal-desktop whatsapp-for-linux tdesktop
            olive-editor
            spotify
            vlc
            obsidian zotero
            keepassxc
            zeal
            openscad kicad horizon-eda prusa-slicer pcb2gcode candle
            anki
            steam higan
            gnucash
            # tools
            vifm
            sent age mc tmuxp tmux picocom minicom tio tldr
            unrar
            jq fzf fq pdfgrep ugrep expect dos2unix universal-ctags fdupes
            eza fd sd bat ripgrep glow broot tree htop
            tlaplus tlaplusToolbox nuXmv nusmv alloy6
            coq coqPackages.coqide
            wl-clipboard wlogout wdisplays gammastep bemenu rofi wlr-randr
            waybar mako kanshi hikari
            poppler_utils graphviz drawio ipe pandoc
            yt-dlp
            drumgizmo x42-avldrums x42-plugins wolf-shaper distrho calf
            # os
            nsxiv farbfeld
            zathura
        ];

        # files in ~/
        file.".bashrc".source = ../../../bash/.bashrc;
        file.".profile".source = ../../../bash/.profile;
        file."key-bindings.bash".source = ../../../bash/key-bindings.bash;
        file."z.sh".source = ../../../bash/z.sh;
        file."git-prompt.sh".source = ../../../bash/git-prompt.sh;

        file.".gitignore".source = ../../../git/.gitignore;

        file.".clang-tidy".source = ../../../lang/.clang-tidy;
        file.".clang-format".source = ../../../lang/.clang-format;
        file.".cmake-format.yml".source = ../../../lang/.cmake-format.yml;

        file.".gdbinit.d" = {
            source = ../../../gdb/.gdbinit.d;
            recursive = true;
        };

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
    };

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;

    programs.neovim = {
        enable = true;
        plugins = with pkgs.vimPlugins; [
            nvim-treesitter.withAllGrammars
            nvim-treesitter-textobjects
            plenary-nvim
            telescope-nvim
        ];
    };

    xdg = {
        # files in ~/.config/
        configFile."gdb" = {
            source = ../../../gdb/.config/gdb;
            recursive = true;
        };

        configFile."hikari" = {
            source = ../../../hikari/.config/hikari;
            recursive = true;
        };
        configFile."kanshi" = {
            source = ../../../hikari/.config/kanshi;
            recursive = true;
        };

        configFile."foot" = {
            source = ../../../foot/.config/foot;
            recursive = true;
        };

        configFile."cpugovernor" = {
            source = ../../../cpugovernor/.config/cpugovernor;
            recursive = true;
        };

        configFile."zathura" = {
            source = ../../../zathura/.config/zathura;
            recursive = true;
        };

        configFile."git" = {
            source = ../../../git/.config/git;
            recursive = true;
        };

        configFile."tmux" = {
            source = ../../../tmux/.config/tmux;
            recursive = true;
        };
        configFile."tmuxp" = {
            source = ../../../tmux/.config/tmuxp;
            recursive = true;
        };

        configFile."vifm" = {
            source = ../../../vifm/.config/vifm;
            recursive = true;
        };

        configFile."nvim" = {
            source = ../../../nvim/.config/nvim;
            recursive = true;
        };
    };

  home.activation.runMyScript = lib.hm.dag.entryAfter ["writeBoundary"] ''
    sudo -n $HOME/bin/patchnixapps $HOME/.nix-profile/share/applications
  '';
}
