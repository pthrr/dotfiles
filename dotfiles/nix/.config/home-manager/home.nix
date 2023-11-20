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
            systemc
            jetbrains.clion
            jetbrains.webstorm
            jetbrains.pycharm-professional micromamba
            jetbrains.jdk jetbrains.idea-ultimate
            kotlin kotlin-native kotlin-language-server detekt ktlint
            typescript nodejs_20 nodePackages_latest.eslint deno bun esbuild
            nodePackages_latest.fixjson
            typst typst-fmt typst-lsp
            scala_3 sbt-with-scala-native scalafmt scalafix scala-cli metals
            yosys verilator gtkwave symbiyosys icestorm nextpnrWithGui
            bluespec yosys-bluespec
            shfmt
            rustup cargo-rr
            yamlfmt yamllint
            ansible ansible-lint ansible-language-server
            elixir elixir-ls
            ghc cabal-install cabal2nix stack hlint haskell-language-server
            clojure leiningen clojure-lsp
            zig zls
            compcert mold cling rr openocd valgrind gdb gdbgui clang-tools
            nasm
            wasmer emscripten wasmtime
            scons meson buck ninja bazelisk cmake-format cmake bmake
            go
            crun podman podman-desktop podman-compose
            qemu ripes
            winetricks wineWowPackages.full
            ngspice qucs-s xyce
            thunderbird firefox tor-browser-bundle-bin librewolf nyxt
            darcs gitFull git-lfs git-filter-repo meld gitui
            sent go-task age mc tmuxp tmux picocom minicom tio neofetch
            unrar
            jq fzf fq pdfgrep expect dos2unix
            eza fd bat ripgrep
            openscad kicad horizon-eda prusa-slicer pcb2gcode candle
            tlaplus tlaplusToolbox nuXmv nusmv alloy6
            coq coqPackages.coqide
            discord element-desktop signal-desktop whatsapp-for-linux tdesktop
            wl-clipboard wlogout wdisplays gammastep bemenu rofi wlr-randr
            waybar mako kanshi
            olive-editor spotify vlc yt-dlp
            obsidian zotero
            poppler_utils graphviz tectonic drawio ipe pandoc
            nsxiv farbfeld zathura
            keepassxc
            zeal
            steam
            anki
            gnucash
            drumgizmo x42-avldrums x42-plugins wolf-shaper distrho calf
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

    programs.vscode = {
        enable = true;
        package = pkgs.vscode;
        extensions = with pkgs.vscode-extensions; [
            alygin.vscode-tlaplus
            vscodevim.vim
        ];
    };

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

        configFile."i3status" = {
            source = ../../../sway/.config/i3status;
            recursive = true;
        };
        configFile."sway" = {
            source = ../../../sway/.config/sway;
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

        configFile."mc" = {
            source = ../../../mc/.config/mc;
            recursive = true;
        };

        configFile."nvim" = {
            source = ../../../nvim/.config/nvim;
            recursive = true;
        };

        configFile."Code" = {
            source = ../../../vscode/.config/Code;
            recursive = true;
        };
    };
}
