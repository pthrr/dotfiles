{ config, lib, pkgs, ... }:

let
  defaultUserName = "pthrr";
  defaultUserEmail = "pthrr@posteo.de";
  gitUserNameFile = "${config.home.homeDirectory}/.config/git/name.txt";
  gitUserEmailFile = "${config.home.homeDirectory}/.config/git/email.txt";
  gitUserName = if builtins.pathExists gitUserNameFile then
    let
      content = builtins.readFile gitUserNameFile;
    in
      builtins.trace "gitUserNameFile exists: ${content}" content
    else
      builtins.trace "gitUserNameFile does not exist, using default" defaultUserName;
  gitUserEmail = if builtins.pathExists gitUserEmailFile then
    let
      content = builtins.readFile gitUserEmailFile;
    in
      builtins.trace "gitUserEmailFile exists: ${content}" content
    else
      builtins.trace "gitUserEmailFile does not exist, using default" defaultUserEmail;
in
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
            # langs
            cue cuelsp cuetools
            zig zls
            tectonic
            typst typst-fmt typst-lsp
            scala_3 sbt-with-scala-native scalafmt scalafix scala-cli metals
            ansible ansible-lint ansible-language-server
            yamlfmt yamllint
            ghc cabal-install cabal2nix stack hlint haskell-language-server
            compcert mold cling rr openocd valgrind gdb gdbgui sccache ddd
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
            #bluespec yosys-bluespec
            # dev tools
            git-lfs git-filter-repo git-imerge difftastic jujutsu
            scons meson ninja bazelisk bmake go-task
            hotspot
            #
            yosys verilator gtkwave symbiyosys icestorm nextpnrWithGui
            picotool
            qemu ripes crun
            winetricks wineWow64Packages.stagingFull
            ngspice qucs-s xyce openems
            svdtools svd2rust
            # sw
            thunderbird firefox
            pcb2gcode candle
            tlaplus tlaplusToolbox nuXmv alloy6
            coq coqPackages.coqide
            # tools
            vifm
            sent age mc tmuxp tmux picocom minicom tio tldr
            unrar
            jq fzf fq pdfgrep ugrep expect dos2unix universal-ctags fdupes
            eza fd sd bat ripgrep glow broot tree htop nvtopPackages.full
            wl-clipboard wlr-randr
            waybar mako kanshi rofi
            poppler_utils graphviz drawio ipe pandoc libwebp
            drumgizmo x42-avldrums x42-plugins wolf-shaper distrho calf
            # os
            nsxiv farbfeld
            zathura
        ];

        # files in ~/
        file.".bashrc".source = ../../../bash/.bashrc;
        file.".bash_profile".source = ../../../bash/.bash_profile;
        file."key-bindings.bash".source = ../../../bash/key-bindings.bash;
        file."z.sh".source = ../../../bash/z.sh;
        file."git-prompt.sh".source = ../../../bash/git-prompt.sh;

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

        file.".local/share/applications/Zed.desktop".source = ../../../zed/.local/share/applications/Zed.desktop;

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

    programs.git = {
      enable = true;
      userName = gitUserName;
      userEmail = gitUserEmail;
      extraConfig = ''
        [core]
            editor = nvim
            autocrlf = false
            whitespace = fix,-indent-with-non-tab,trailing-space,cr-at-eol
            pager = less -+$LESS -FRX
            excludesfile = ~/.config/git/.gitignore_global
            attributesfile = ~/.config/git/.gitattributes_global
        [diff "zip"]
            textconv = unzip -c -a
        [merge]
            conflictstyle = diff3
        [rerere]
            enabled = true
        [filter "zippey"]
            smudge = zippey d
            clean = zippey e
        [credential]
            helper = store
        [safe]
            directory = *
        [gpg]
            program = gpg2
        [http]
            sslVerify = false
        [submodule]
            recurse = true
        [pull]
            rebase = false
        [push]
            autoSetupRemote = true
            default = simple
            recurseSubmodules = on-demand
        [commit]
            template = ~/.config/git/git-commit-template.txt
        [clean]
            requireForce = false
        [status]
            submoduleSummary = true
        [diff]
            tool = difftastic
        [difftool]
            prompt = false
        [merge]
            tool = meld
        [mergetool]
            keepBackup = false
        [pager]
            difftool = true
        [difftool "difftastic"]
            cmd = difft "$LOCAL" "$REMOTE"
        [difftool "meld"]
            cmd = meld \"$LOCAL\" \"$REMOTE\"
            trustExitCode = false
        [mergetool "meld"]
            cmd = meld --auto-merge \"$LOCAL\" \"$BASE\" \"$REMOTE\" --output \"$MERGED\" --label=Local --label=Base --label=Remote --diff \"$BASE\" \"$LOCAL\" --diff \"$BASE\" \"$REMOTE\"
            trustExitCode = false
        [difftool "kdiff3"]
            cmd = kdiff3 \"$LOCAL\" \"$REMOTE\"
            trustExitCode = false
        [mergetool "kdiff3"]
            cmd = kdiff3 \"$LOCAL\" \"$BASE\" \"$REMOTE\" \"$MERGED\"
            trustExitCode = false
        [difftool "bcomp4"]
            cmd = \"/mnt/c/Program Files/Beyond Compare 4/BComp.exe\" "$(wslpath -w $LOCAL)" "$(wslpath -w $REMOTE)"
            trustExitCode = true
        [mergetool "bcomp4"]
            cmd = \"/mnt/c/Program Files/Beyond Compare 4/BComp.exe\" "$(wslpath -w $LOCAL)" "$(wslpath -w $REMOTE)" "$(wslpath -w $BASE)" "$(wslpath -w $MERGED)"
            trustExitCode = true
        [filter "lfs"]
            required = true
            clean = git-lfs clean -- %f
            smudge = git-lfs smudge -- %f
            process = git-lfs filter-process
        [alias]
            a = add
            aa = add --all
            b = branch
            c = commit
            d = diff
            dt = difftool
            f = fetch
            g = grep
            l = log
            m = merge
            o = checkout
            p = pull
            r = remote
            s = status
            w = whatchanged
            lg = log --graph
            lo = log --oneline
            lp = log --patch
            lfp = log --first-parent
            # log with items appearing in topological order, i.e. descendant commits are shown before their parents.
            lt = log --topo-order
            # log like - we like this summarization our key performance indicators. Also aliased as `log-like`.
            ll = log --graph --topo-order --date=short --abbrev-commit --decorate --all --boundary --pretty=format:'%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %Cblue%G?%Creset'
            # log like long  - we like this summarization our key performance indicators. Also aliased as `log-like-long`.
            lll = log --graph --topo-order --date=iso8601-strict --no-abbrev-commit --abbrev=40 --decorate --all --boundary --pretty=format:'%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn <%ce>]%Creset %Cblue%G?%Creset'
      '';
    };

    programs.neovim = {
        enable = true;
        plugins = with pkgs.vimPlugins; [
            nvim-treesitter.withAllGrammars
            nvim-treesitter-textobjects
            plenary-nvim
            telescope-nvim
            nvim-dap
            nvim-dap-ui

        ];
    };

    xdg = {
        # files in ~/.config/
        configFile."zed" = {
            source = ../../../zed/.config/zed;
            recursive = true;
        };

        configFile."plasma-workspace/env" = {
            source = ../../../nix/.config/plasma-workspace/env;
            recursive = true;
        };

        configFile."gdb" = {
            source = ../../../gdb/.config/gdb;
            recursive = true;
        };

        configFile."hikari" = {
            source = ../../../hikari/.config/hikari;
            recursive = true;
        };

        configFile."foot" = {
            source = ../../../foot/.config/foot;
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
        configFile."swaync" = {
            source = ../../../sway/.config/swaync;
            recursive = true;
        };
        configFile."swayr" = {
            source = ../../../sway/.config/swayr;
            recursive = true;
        };
        configFile."kanshi" = {
            source = ../../../sway/.config/kanshi;
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
