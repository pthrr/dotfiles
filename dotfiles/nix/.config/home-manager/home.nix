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
            # hare harec haredo haredoc
            # dotenv-linter
            # swift
            cue cuelsp cuetools
            # zig zls
            # tectonic
            typst typst-fmt typst-lsp
            # scala_3 sbt-with-scala-native scalafmt scalafix scala-cli metals
            # ansible ansible-lint ansible-language-server
            yamlfmt yamllint
            # ghc cabal-install cabal2nix stack hlint haskell-language-server
            # cling gdbgui ddd cbmc
            mold rr valgrind sccache
            # tinycc
            shfmt
            # nasm
            pyright
            emscripten wasmtime wabt
            rustup cargo-rr
            # elixir elixir-ls
            # clojure leiningen clojure-lsp
            # go
            cmake-format
            nodePackages_latest.fixjson
            protobuf protobufc
            # bluespec yosys-bluespec
            # bun
            # dev tools
            git-lfs git-filter-repo git-imerge difftastic
            scons meson ninja bazelisk bmake bear
            # hotspot
            unifdef
            kind minikube kubernetes helm
            netpbm
            #
            # yosys verilator gtkwave symbiyosys icestorm nextpnrWithGui
            picotool
            # ripes crun
            winetricks wineWow64Packages.stagingFull
            # ngspice qucs-s xyce openems
            svdtools svd2rust
            # sw
            firefox
            # pcb2gcode
            candle
            nuXmv alloy6
            # coq coqPackages.coqide
            lean4
            # tigerbeetle
            gnuradio
            # tools
            # sent age tio tldr
            sent mc tmuxp tmux
            unrar
            jq fzf fq pdfgrep ugrep expect dos2unix universal-ctags fdupes pdftk
            eza fd sd bat ripgrep glow broot tree htop nvtopPackages.full
            wl-clipboard wlr-randr
            poppler_utils graphviz pandoc libwebp
            drumgizmo x42-avldrums x42-plugins wolf-shaper calf
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
        file.".cmake-format.yaml".source = ../../../lang/.cmake-format.yaml;

        file.".ssh" = {
            source = ../../../ssh/.ssh;
            recursive = true;
        };

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

    programs.jujutsu = {
      enable = true;
      settings = {
        user = {
          name = gitUserName;
          email = gitUserEmail;
        };

        core = {
          editor = "nvim";
          pager = "less -+$LESS -FRX";
        };

        git = {
          auto-local-branch = true;
          push-branch-prefix = "";
          fetch-tags = true;
          track-branches = true;
        };

        operation = {
          allow-empty = true;

          rebase = {
            auto-squash = true;
            update-refs = true;
          };
        };

        aliases = {
          # Git-equivalent aliases
          co = "checkout";
          br = "branch list";
          cm = "new";
          df = "diff";
          lg = "log --graph";
          rb = "rebase";
          mt = "resolve";
          st = "status";

          # Git command aliases
          git-fetch = "git fetch --prune";
          git-push = "git push --follow-tags";
          git-status = "git status";
          git-log = "git log --oneline --graph --decorate";
          git-diff = "git diff";
          git-commit = "git commit -v";
          git-branch = "git branch";
          git-rebase = "git rebase";
          git-merge = "git merge";
        };

        diff = {
          tool = "difftastic";
        };

        merge = {
          tool = "meld";
        };

        fetch = {
          all = true;
        };

        push = {
          auto-setup-remote = true;
        };

        pager = {
          enabled = true;
        };

        ui = {
          default-command = "status";
          color = "auto";
        };
      };
    };

    programs.git = {
      enable = true;
      userName = gitUserName;
      userEmail = gitUserEmail;
      package = pkgs.gitAndTools.gitFull;
      extraConfig = {
        core = {
          editor = "nvim";
          autocrlf = false;
          pager = "less -+$LESS -FRX";
          excludesfile = "~/.config/git/.gitignore_global";
          attributesfile = "~/.config/git/.gitattributes_global";
        };

        branch = {
          sort = "-committerdate";
        };

        tag = {
          sort = "version:refname";
        };

        init = {
          defaultBranch = "main";
        };

        merge = {
          conflictstyle = "zdiff3";
          tool = "meld";
        };

        diff = {
          algorithm = "histogram";
          colorMoved = "plain";
          mnemonicPrefix = true;
          renames = true;
          tool = "difftastic";
        };

        credential = {
          helper = "cache --timeout=3600";
        };

        safe = {
          directory = "*";
        };

        gpg = {
          program = "gpg2";
        };

        submodule = {
          recurse = true;
        };

        fetch = {
          prune = true;
          pruneTags = true;
          all = true;
        };

        pull = {
          rebase = true;
        };

        push = {
          recurseSubmodules = "on-demand";
          default = "simple";
          autoSetupRemote = true;
          followTags = true;
        };

        commit = {
          verbose = true;
          template = "~/.config/git/git-commit-template.txt";
        };

        rerere = {
          enabled = true;
          autoupdate = true;
        };

        rebase = {
          autoSquash = true;
          autoStash = true;
          updateRefs = true;
        };

        status = {
          submoduleSummary = true;
        };

        difftool = {
          prompt = false;
          "difftastic" = {
            cmd = "difft \"$LOCAL\" \"$REMOTE\"";
            trustExitCode = true;
          };

          "meld" = {
            cmd = "meld \"$LOCAL\" \"$REMOTE\"";
            trustExitCode = false;
          };

          "kdiff3" = {
            cmd = "kdiff3 \"$LOCAL\" \"$REMOTE\"";
            trustExitCode = false;
          };

          "bcomp4" = {
            cmd = "\"/mnt/c/Program Files/Beyond Compare 4/BComp.exe\" \"$(wslpath -w $LOCAL)\" \"$(wslpath -w $REMOTE)\"";
            trustExitCode = true;
          };
        };

        mergetool = {
          keepBackup = false;
          "meld" = {
            cmd = "meld --auto-merge \"$LOCAL\" \"$BASE\" \"$REMOTE\" --output \"$MERGED\" --label=Local --label=Base --label=Remote --diff \"$BASE\" \"$LOCAL\" --diff \"$BASE\" \"$REMOTE\"";
            trustExitCode = false;
          };

          "kdiff3" = {
            cmd = "kdiff3 \"$LOCAL\" \"$BASE\" \"$REMOTE\" \"$MERGED\"";
            trustExitCode = false;
          };

          "bcomp4" = {
            cmd = "\"/mnt/c/Program Files/Beyond Compare 4/BComp.exe\" \"$(wslpath -w $LOCAL)\" \"$(wslpath -w $REMOTE)\" \"$(wslpath -w $BASE)\" \"$(wslpath -w $MERGED)\"";
            trustExitCode = true;
          };
        };

        pager = {
          difftool = true;
        };

        filter = {
          "lfs" = {
            required = true;
            clean = "git-lfs clean -- %f";
            smudge = "git-lfs smudge -- %f";
            process = "git-lfs filter-process";
          };
        };

        alias = {
          a = "add";
          aa = "add --all";
          b = "branch";
          p = "push";
          c = "commit";
          co = "checkout";
          s = "status";
          d = "diff";
          dt = "difftool";
          m = "merge";
          mt = "mergetool";
          l = "log";
          lg = "log --graph";
          lo = "log --oneline";
          lp = "log --patch";
          lfp = "log --first-parent";
          lt = "log --topo-order";
          ll = "log --graph --topo-order --date=short --abbrev-commit --decorate --all --boundary --pretty=format:'%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %Cblue%G?%Creset'";
          lll = "log --graph --topo-order --date=iso8601-strict --no-abbrev-commit --abbrev=40 --decorate --all --boundary --pretty=format:'%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn <%ce>]%Creset %Cblue%G?%Creset'";
        };
      };
    };

    programs.neovim = {
        enable = true;
        plugins = with pkgs.vimPlugins; [
            nvim-treesitter.withAllGrammars
            nvim-treesitter-textobjects
            plenary-nvim
            telescope-nvim
            nvim-lspconfig
        ];
    };

    xdg = {
        # files in ~/.config/
        configFile."plasma-workspace/env" = {
            source = ../../../nix/.config/plasma-workspace/env;
            recursive = true;
        };

        configFile."gdb" = {
            source = ../../../gdb/.config/gdb;
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

        configFile."git" = {
            source = ../../../git/.config/git;
            recursive = true;
        };

        configFile."tmux" = {
            source = ../../../tmux/.config/tmux;
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

  home.activation.runMyScript = lib.hm.dag.entryAfter ["writeBoundary"] ''
    sudo -n $HOME/bin/patchnixapps $HOME/.nix-profile/share/applications
  '';
}
