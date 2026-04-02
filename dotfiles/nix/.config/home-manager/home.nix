{
  config,
  lib,
  pkgs,
  ...
}:

let
  ghcup = pkgs.stdenv.mkDerivation {
    pname = "ghcup";
    version = "latest";
    src = pkgs.fetchurl {
      url = "https://downloads.haskell.org/~ghcup/x86_64-linux-ghcup";
      hash = "sha256-/2KI35dYIRNy2CQv6DDY5r5qg2XZQG8cm94US350QUM=";
    };
    dontUnpack = true;
    installPhase = ''
      install -Dm755 $src $out/bin/ghcup
    '';
  };

  mcrl2-patched = pkgs.mcrl2.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace libraries/atermpp/include/mcrl2/atermpp/detail/aterm_list_iterator.h \
        --replace-fail 'other.position' 'other.m_position'
    '';
  });

  defaultUserName = "pthrr";
  defaultUserEmail = "pthrr@posteo.de";
  gitUserNameFile = "${config.home.homeDirectory}/.config/git/name.txt";
  gitUserEmailFile = "${config.home.homeDirectory}/.config/git/email.txt";
  gitUserName =
    if builtins.pathExists gitUserNameFile then
      let
        content = builtins.readFile gitUserNameFile;
      in
      builtins.trace "gitUserNameFile exists: ${content}" content
    else
      builtins.trace "gitUserNameFile does not exist, using default" defaultUserName;
  gitUserEmail =
    if builtins.pathExists gitUserEmailFile then
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
  imports = [
    (fetchTarball "https://github.com/gmodena/nix-flatpak/archive/latest.tar.gz")
  ];

  home = {
    username = builtins.getEnv "USER";
    homeDirectory = builtins.getEnv "HOME";
    stateVersion = "22.05";
    enableNixpkgsReleaseCheck = false;

    packages =
      with pkgs;
      # Core utilities
      [
        coreutils
        findutils
        usbutils
        pciutils
        openssl
        unrar
        unzip
        p7zip
        wget
        curl
        gnupg
        unixtools.xxd
        inotify-tools
      ]
      ++

        # Shell & terminal tools
        [
          vifm
          tmux
          tmuxp
          tree
          htop
          fzf
          ripgrep
          fd
        ]
      ++

        # WM
        [
          wl-clipboard
          wlr-randr
          udiskie
        ]
      ++

        # Network & remote
        [
          sshpass
          rclone
        ]
      ++

        # Fonts
        [
          dejavu_fonts
          fira-code
          jetbrains-mono
        ]
      ++

        # Build systems
        [
          scons
          meson
          ninja
          bazelisk
          bmake
          bear
          buck2
          git-repo
          conan
          cmake
        ]
      ++

        # Compilers & toolchains
        [
          zig
          zls
          ocaml
          opam
          lean4
          rustup
          (agda.withPackages (p: [
            p.cubical
            p.standard-library
          ]))
          # haskellPackages.agda-language-server  # unmaintained: needs lsp<1.7 and Agda<2.6.4
          ghcup
        ]
      ++

        # JavaScript/TypeScript
        [
          deno
          bun
          nodejs_24
          eslint
          nodePackages.typescript-language-server
          nodePackages.bash-language-server
        ]
      ++

        # Python tooling
        [
          pyright
          pre-commit
          ruff
          uv
          ty
          jupyterlab
          cppman
          python3Packages.grip
        ]
      ++

        # Java tooling
        [
          jdk
          maven
          gradle
        ]
      ++

        # Nix tooling
        [
          nixd
          nixfmt
        ]
      ++

        # Containers & Kubernetes
        # [ kind minikube helm k3s k3d crun envsubst ] ++

        # Build caching & debugging
        [
          mold
          sccache
          redis
          gdbgui
          rr
          hotspot
        ]
      ++

        # Hardware development
        [
          yosys
          verilator
          verible
          # bluespec yosys-bluespec
          icestorm
          svdtools
          svd2rust
          candle
          ngspice
          # pcb2gcode
          # sby
          nextpnrWithGui
          xyce-parallel
          minicom
          picocom
        ]
      ++

        # WebAssembly
        [
          emscripten
          wasmtime
          wabt
        ]
      ++

        # Document tools
        [
          typst
          tinymist
          typstyle
          pandoc
          poppler-utils
          graphviz
          tectonic
        ]
      ++

        # Formatters & linters
        [
          marksman
          tlafmt
          yamlfmt
          yamllint
          shfmt
          stylua
          lua-language-server
          cmake-format
          nodePackages.prettier
        ]
      ++

        # Protocol buffers
        [
          protobuf
          protobufc
        ]
      ++

        # Data tools
        [
          jq
          fq
        ]
      ++

        # Formal verification
        [
          cue
          cuelsp
          cuetools
          mcrl2-patched
          nuXmv
          z3
          tlaplus
        ]
      ++

        # Image tools
        [
          nsxiv
          farbfeld
          libwebp
          netpbm
          potrace
        ]
      ++

        # Media/Audio
        [
          drumgizmo
          x42-avldrums
          x42-plugins
          wolf-shaper
          calf
        ]
      ++

        # Viewers & diff tools
        [
          difftastic
          sent
          zathura
        ]
      ++

        # Web browsers
        [ ladybird ]
      ++

        # Editors
        [ vscode ]
      ++

        # Other
        [
          claude-code
          go-task
          wineWow64Packages.waylandFull
          openpomodoro-cli
          # ripes # temporarily disabled due to cmake build issue
        ];

    file = {
      ".bashrc".source = ../../../bash/.bashrc;
      ".bash_profile".source = ../../../bash/.bash_profile;
      "z.sh".source = ../../../bash/z.sh;
      "git-prompt.sh".source = ../../../bash/git-prompt.sh;
      "jj-prompt.sh".source = ../../../bash/jj-prompt.sh;

      ".clang-tidy".source = ../../../lang/.clang-tidy;
      ".clang-format".source = ../../../lang/.clang-format;
      ".cmake-format.yaml".source = ../../../lang/.cmake-format.yaml;
      ".config/stylua/stylua.toml".source = ../../../lang/stylua.toml;
      ".bazelrc".source = ../../../lang/.bazelrc;
      ".prettierrc".source = ../../../lang/.prettierrc;

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
      ".claude" = {
        source = ../../../claude/.config/claude;
        recursive = true;
      };
    };
  };

  # Unmount SSHFS mounts before sleep to prevent freeze
  systemd.user.services.sshfs-sleep-handler = {
    Unit = {
      Description = "Unmount SSHFS before sleep";
    };
    Service = {
      Type = "simple";
      ExecStart = pkgs.writeShellScript "sshfs-sleep-handler" ''
        /usr/bin/gdbus monitor --system \
          --dest org.freedesktop.login1 \
          --object-path /org/freedesktop/login1 |
        while read -r line; do
          if echo "$line" | grep -q "PrepareForSleep (true)"; then
            if /usr/bin/mount | grep -q " $HOME/Drive "; then
              /usr/bin/fusermount -uz "$HOME/Drive" 2>/dev/null || true
            fi
          fi
        done
      '';
      Restart = "always";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
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

      # Revset aliases for powerful commit filtering
      revset-aliases = {
        "mine()" = ''author(email_substring("pthrr")) | committer(email_substring("pthrr"))'';
        "trunk()" = "main@origin | master@origin";
        "stack()" = "ancestors(@, mutable())";
      };

      aliases = {
        # Git-equivalent aliases
        co = [ "checkout" ];
        br = [
          "branch"
          "list"
        ];
        cm = [ "new" ];
        df = [ "diff" ];
        lg = [
          "log"
          "--graph"
        ];
        rb = [ "rebase" ];
        mt = [ "resolve" ];

        # Workflow shortcuts
        st = [ "status" ];
        l = [
          "log"
          "-r"
          "trunk()..@"
          "--limit"
          "20"
        ];
        ll = [
          "log"
          "--limit"
          "50"
        ];
        s = [ "show" ];
        n = [ "new" ];
        e = [ "edit" ];

        # Advanced workflows
        amend = [ "squash" ];
        fixup = [ "squash" ];
        uncommit = [
          "edit"
          "@-"
        ];

        # Git integration
        fetch = [
          "git"
          "fetch"
        ];
        pull = [
          "git"
          "fetch"
        ];
        push = [
          "git"
          "push"
        ];

        # Git command aliases
        git-fetch = [
          "git"
          "fetch"
          "--prune"
        ];
        git-push = [
          "git"
          "push"
          "--follow-tags"
        ];
        git-status = [
          "git"
          "status"
        ];
        git-log = [
          "git"
          "log"
          "--oneline"
          "--graph"
          "--decorate"
        ];
        git-diff = [
          "git"
          "diff"
        ];
        git-commit = [
          "git"
          "commit"
          "-v"
        ];
        git-branch = [
          "git"
          "branch"
        ];
        git-rebase = [
          "git"
          "rebase"
        ];
        git-merge = [
          "git"
          "merge"
        ];
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
        diff-editor = ":builtin";
        merge-editor = "meld";
        paginate = "auto";
        log-synthetic-elided-nodes = true;
      };

      # Template customizations
      template-aliases = {
        "format_short_change_id(id)" = "id.shortest(8)";
        "format_short_commit_id(id)" = "id.shortest(8)";
      };
    };
  };

  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    lfs.enable = true;
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
        ff = "only";
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

      alias = {
        a = "add";
        aa = "add --all";
        b = "branch";
        p = "push";
        pf = "push --force-with-lease";
        c = "commit";
        ca = "commit --amend";
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
        ll = "log --graph --topo-order --date=short --abbrev-commit --decorate --boundary --pretty=format:'%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %Cblue%G?%Creset'";
        lla = "log --graph --topo-order --date=short --abbrev-commit --decorate --all --boundary --pretty=format:'%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %Cblue%G?%Creset'";
        lll = "log --graph --topo-order --date=iso8601-strict --no-abbrev-commit --abbrev=40 --decorate --all --boundary --pretty=format:'%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn <%ce>]%Creset %Cblue%G?%Creset'";
        subm-reinit = "!git submodule deinit --all --force && git submodule update --init --recursive";
      };
    };
  };

  programs.neovim = {
    enable = true;
    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
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
    lib.genAttrs [
      "sway"
      "gdb"
      "foot"
      "zathura"
      "git"
      "tmux"
      "vifm"
      "nvim"
    ] mkConfigDir
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
    };

  services.flatpak = {
    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
    ];
    packages = [
      "org.libreoffice.LibreOffice"
      "it.fabiodistasio.AntaresSQL"
      "net.lutris.Lutris"
      "org.mozilla.firefox"
      "io.github.gtkwave.GTKWave"
      "io.github.ra3xdh.qucs_s"
      "org.inkscape.Inkscape"
      "org.gnucash.GnuCash"
      "com.usebottles.bottles"
      "org.otfried.Ipe"
      "com.jgraph.drawio.desktop"
      "org.mozilla.Thunderbird"
      "org.torproject.torbrowser-launcher"
      "md.obsidian.Obsidian"
      "org.zotero.Zotero"
      "org.jdownloader.JDownloader"
      "org.kde.labplot"
      "fm.reaper.Reaper"
      "net.ankiweb.Anki"
      "engineer.atlas.Nyxt"
      "org.videolan.VLC"
      "net.cozic.joplin_desktop"
      "com.valvesoftware.Steam"
      "org.telegram.desktop"
      "com.discordapp.Discord"
      "com.spotify.Client"
      "im.riot.Riot"
      "org.signal.Signal"
      "org.keepassxc.KeePassXC"
      "org.gnome.meld"
      "com.prusa3d.PrusaSlicer"
      "org.freecad.FreeCAD"
      "org.openscad.OpenSCAD"
      "org.kicad.KiCad"
      "org.gimp.GIMP"
      "org.sqlitebrowser.sqlitebrowser"
      "org.kde.kdenlive"
    ];
  };

  home.activation.runMyScript = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    sudo -n $HOME/bin/patchnixapps $HOME/.nix-profile/share/applications
  '';

  home.activation.ensureHaskellTools = lib.hm.dag.entryAfter [ "installPackages" ] ''
    export PATH="$HOME/.ghcup/bin:$HOME/.cabal/bin:$HOME/.nix-profile/bin:/usr/local/bin:/usr/bin:$PATH"
    ghcup install ghc 9.8.4 --set
    ghcup install cabal 3.16.1.0 --set
    cabal update
  '';
}
