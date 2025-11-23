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

  commonUser = {
    name = gitUserName;
    email = gitUserEmail;
  };

  commonCore = {
    editor = "nvim";
    pager = "less -+$LESS -FRX";
  };
in
{
    home = {
        username = builtins.getEnv "USER";
        homeDirectory = builtins.getEnv "HOME";
        stateVersion = "22.05";
        enableNixpkgsReleaseCheck = false;

        packages = with pkgs;
          # Core utilities
          [ coreutils findutils usbutils pciutils openssl sqlite ] ++

          # Shell & terminal tools
          [ mc tmux tree htop fzf ripgrep fd wl-clipboard wlr-randr mako udiskie ] ++

          # Build systems
          [ scons meson ninja bazelisk bmake bear buck2 git-repo cmake-format ] ++

          # Compilers & toolchains
          [ zig zls rustup ] ++

          # JavaScript/TypeScript
          [ deno bun nodejs_24 eslint nodePackages.typescript-language-server ] ++

          # Python tooling
          [ pyright ] ++

          # Nix tooling
          [ nixd nil ] ++

          # Containers & Kubernetes
          # [ kind minikube helm k3s k3d crun envsubst ] ++

          # Build caching & debugging
          [ mold valgrind sccache redis gdbgui rr hotspot ] ++

          # Hardware development
          [ yosys verilator
            # bluespec yosys-bluespec
            icestorm
            svdtools svd2rust pcb2gcode candle ngspice
            # sby
            nextpnrWithGui
            # xyce-parallel
          ] ++

          # WebAssembly
          [ emscripten wasmtime wabt ] ++

          # Document tools
          [ typst tinymist typstyle pandoc poppler-utils graphviz ] ++

          # Formatters & linters
          [ yamlfmt yamllint shfmt stylua lua-language-server ] ++

          # Protocol buffers
          [ protobuf protobufc ] ++

          # Data tools
          [ jq fq ] ++

          # Formal verification
          [ lean4 tlafmt cue cuelsp cuetools nuXmv alloy6 ] ++

          # Image tools
          [ nsxiv farbfeld libwebp netpbm potrace ] ++

          # Media/Audio
          [ drumgizmo x42-avldrums x42-plugins wolf-shaper calf ] ++

          # Viewers
          [ zathura sent ] ++

          # Diff tools
          [ difftastic ] ++

          # Other
          [ claude-code ty go-task unrar wineWow64Packages.waylandFull
            # ripes # temporarily disabled due to cmake build issue
          ];

        file = {
          ".bashrc".source = ../../../bash/.bashrc;
          ".bash_profile".source = ../../../bash/.bash_profile;
          "z.sh".source = ../../../bash/z.sh;
          "git-prompt.sh".source = ../../../bash/git-prompt.sh;

          ".clang-tidy".source = ../../../lang/.clang-tidy;
          ".clang-format".source = ../../../lang/.clang-format;
          ".cmake-format.yaml".source = ../../../lang/.cmake-format.yaml;
          "stylua.toml".source = ../../../lang/stylua.toml;
          ".bazelrc".source = ../../../lang/.bazelrc;

          ".cargo" = {
            source = ../../../lang/.cargo;
            recursive = true;
          };
          ".ssh" = {
            source = ../../../ssh/.ssh;
            recursive = true;
          };
          "bin" = {
            source = ../../../misc/bin;
            recursive = true;
          };
          "Vorlagen/snippets" = {
            source = ../../../nvim/Vorlagen/snippets;
            recursive = true;
          };
          "Vorlagen/slides" = {
            source = ../../../sent/Vorlagen/slides;
            recursive = true;
          };
        };
    };

    systemd.user.services.sccache = {
      Unit.Description = "sccache daemon";
      Install.WantedBy = [ "default.target" ];
      Service = {
        Type = "forking";
        Environment = [
          "SCCACHE_REDIS=redis://nwv-srv:6380"
          "SCCACHE_REDIS_TTL=604800"
        ];
        ExecStart = "${pkgs.sccache}/bin/sccache --start-server";
        ExecStop = "${pkgs.sccache}/bin/sccache --stop-server";
        Restart = "on-failure";
      };
    };

    programs.home-manager.enable = true;

    programs.jujutsu = {
      enable = true;
      settings = {
        user = commonUser;
        core = commonCore;

        git = {
          auto-local-bookmark = true;
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
          diff-context = 8;
        };
      };
    };

    programs.git = {
      enable = true;
      package = pkgs.gitFull;
      settings = {
        user = {
          name = commonUser.name;
          email = commonUser.email;
        };
        core = commonCore // {
          autocrlf = false;
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
          tool = "meld";
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
          prompt = true;

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
          difftool = false;
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
          pf = "push --force-with-lease";
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
          subm-reinit = "!git submodule deinit --all --force && git submodule update --init --recursive";
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
        ];
    };

    xdg.configFile =
      let
        mkConfigDir = name: {
          source = ../../../${name}/.config/${name};
          recursive = true;
        };
      in
        lib.genAttrs [ "sway" "gdb" "foot" "zathura" "git" "tmux" "mc" "nvim" ] mkConfigDir
        // {
          "plasma-workspace/env" = {
            source = ../../../nix/.config/plasma-workspace/env;
            recursive = true;
          };
          # waybar config is now part of sway package
          "waybar" = {
            source = ../../../sway/.config/waybar;
            recursive = true;
          };
          "kanshi" = {
            source = ../../../sway/.config/kanshi;
            recursive = true;
          };
          "swaylock" = {
            source = ../../../sway/.config/swaylock;
            recursive = true;
          };
          "rofi" = {
            source = ../../../sway/.config/rofi;
            recursive = true;
          };
          "mako" = {
            source = ../../../sway/.config/mako;
            recursive = true;
          };
          "clippy" = {
            source = ../../../rust/.config/clippy;
            recursive = true;
          };
        };

  home.activation.runMyScript = lib.hm.dag.entryAfter ["writeBoundary"] ''
    sudo -n $HOME/bin/patchnixapps $HOME/.nix-profile/share/applications
  '';
}
