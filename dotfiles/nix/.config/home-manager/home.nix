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
      hash = "sha256-ntXaVEm0gEOg0X52fAXS71heJaY5u5NDKUlsbS+tnPg=";
    };
    dontUnpack = true;
    installPhase = ''
      install -Dm755 $src $out/bin/ghcup
    '';
  };

  xyceParallelNoCheck = pkgs.xyce-parallel.override {
    enableDocs = false;
    enableTests = false;
  };

  # Not in nixpkgs; consumed straight from upstream's own flake package output.
  # Pinned by rev — bump manually when you want a newer monstar.
  monstar = (builtins.getFlake "github:rockorager/monstar/c41132f5570f6b6347ec15c9de5e9417d79f2f50").packages.${pkgs.stdenv.hostPlatform.system}.default;

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
    "${fetchTarball "https://github.com/gmodena/nix-flatpak/archive/latest.tar.gz"}/modules/home-manager.nix"
  ];

  home = {
    username = builtins.getEnv "USER";
    homeDirectory = builtins.getEnv "HOME";
    stateVersion = "22.05";
    enableNixpkgsReleaseCheck = false;

    # ncurses on Fedora searches ~/.terminfo unconditionally, so symlinking
    # the entry there works regardless of TERMINFO_DIRS or a stale
    # __HM_SESS_VARS_SOURCED guard inherited from an older session.
    file.".terminfo/x/xterm-ghostty".source = "${pkgs.ghostty.terminfo}/share/terminfo/x/xterm-ghostty";

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
          zellij
          tree
          htop
          fzf
          ripgrep
          fd
          calcurse
          meli
        ]
      ++

        # WM
        [
          wl-clipboard
          wlr-randr
          udiskie
          monstar
          # monstar (like ghostty itself) sets TERM=xterm-ghostty for its child;
          # neither Fedora's ncurses-term nor nixpkgs' ncurses register that name
          # (only the unrelated "ghostty" alias), so pull just the terminfo entry
          # rather than the ~1GB full ghostty package.
          ghostty.terminfo
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
          # deno
          # bun
          nodejs_24
          tsx
          eslint
          vscode-langservers-extracted
          typescript-language-server
          bash-language-server
          tree-sitter
        ]
      ++

        # Python tooling
        [
          pre-commit
          ruff
          uv
          ty
          # python3Packages.jupyterlab
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

        # AI tooling
        [
          claude-code
          codex
        ]
      ++

        # Containers & Kubernetes
        # [ kind minikube helm k3s k3d crun envsubst ] ++

        # Build caching & debugging
        [
          mold
          sccache
          # redis
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
          xyceParallelNoCheck
          minicom
          picocom
        ]
      ++

        # WebAssembly
        [
          # emscripten
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
          prettier
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
          mcrl2
          nuxmv
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
        [
          # ladybird
        ]
      ++

        # Other
        [
          go-task
          # wineWow64Packages.waylandFull
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
      "Vorlagen/slides" = {
        source = ../../../sent/Vorlagen/slides;
        recursive = true;
      };
      ".agents" = {
        source = ../../../agents/.agents;
        recursive = true;
      };
      ".claude/settings.json".source = ../../../claude/.config/claude/settings.json;
      ".claude/statusline.sh".source = ../../../claude/.config/claude/statusline.sh;

      # Keep Claude Code pointed at the cross-client rules and skills until it
      # discovers ~/.agents natively.
      ".claude/CLAUDE.md".source = ../../../agents/.agents/AGENTS.md;
      ".claude/skills" = {
        source = ../../../agents/.agents/skills;
        recursive = true;
      };
    };
  };

  # Unmount SSHFS mounts before sleep to prevent freeze.
  # Ordered Before=sleep.target so systemd waits for completion before suspending.
  # fusermount -uz (lazy unmount) detaches immediately via MNT_DETACH even if the
  # FUSE daemon is unresponsive (e.g. SSH tunnel dropped mid-transit).
  # TimeoutStartSec caps the worst case so sleep is never blocked indefinitely.
  # UPower's DisplayDevice reports the combined charge of all batteries.  Unlike
  # poweralertd, this intentionally ignores routine charging and AC events.
  systemd.user.services.battery-alertd = {
    Unit = {
      Description = "Low combined-battery notifications via UPower";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart =
        let
          batteryAlertd = pkgs.writeShellApplication {
            name = "battery-alertd";
            runtimeInputs = [
              pkgs.upower
              pkgs.libnotify
              pkgs.gnused
            ];
            text = ''
              display_device=/org/freedesktop/UPower/devices/DisplayDevice
              last_level=normal
              initialized=false

              while true; do
                # LC_ALL=C: upower renders "percentage" with the locale's
                # decimal separator (e.g. "12,96%" under de_DE), which the
                # numeric regex below rejects.
                status=$(LC_ALL=C upower -i "$display_device" 2>/dev/null || true)
                state=$(sed -n 's/^[[:space:]]*state:[[:space:]]*//p' <<<"$status")
                percentage=$(sed -n 's/^[[:space:]]*percentage:[[:space:]]*//p' <<<"$status")
                percentage=''${percentage%\%}

                # UPower may report a fractional percentage (for example,
                # 22.1459%).  Bash arithmetic needs the whole-number part.
                if [[ $percentage =~ ^([0-9]+)([.][0-9]+)?$ ]]; then
                  percentage=''${BASH_REMATCH[1]}
                else
                  sleep 60
                  continue
                fi

                level=normal
                if [[ $state == discharging ]]; then
                  if (( percentage <= 10 )); then
                    level=critical
                  elif (( percentage <= 20 )); then
                    level=low
                  fi
                fi

                # Match the previous -s behavior: do not show a stale warning
                # merely because the graphical session has just started.
                if $initialized && [[ $level != "$last_level" ]]; then
                  case $level in
                    low)
                      notify-send --app-name=battery-alertd --urgency=normal \
                        "Battery low" "Combined battery charge is $percentage%." || true
                      ;;
                    critical)
                      notify-send --app-name=battery-alertd --urgency=critical \
                        "Battery critical" "Combined battery charge is $percentage%. Connect power now." || true
                      ;;
                  esac
                fi

                last_level=$level
                initialized=true
                sleep 60
              done
            '';
          };
        in
        "${batteryAlertd}/bin/battery-alertd";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.sshfs-sleep-handler = {
    Unit = {
      Description = "Unmount SSHFS before sleep";
      Before = [ "sleep.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "sshfs-sleep-handler" ''
        if /usr/bin/mount | grep -q " $HOME/Drive "; then
          /usr/bin/fusermount -uz "$HOME/Drive" 2>/dev/null || true
        fi
      '';
      TimeoutStartSec = 10;
    };
    Install = {
      WantedBy = [ "sleep.target" ];
    };
  };

  nixpkgs.config.allowUnfree = true;

  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

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
    signing.format = "openpgp";
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
        sw = "!git checkout $(git branch --sort=-committerdate | fzf | sed 's/^[* ] //')";
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
    sideloadInitLua = true;
    withRuby = true;
    withPython3 = true;
    withPerl = false;
    withNodeJs = false;
    # wrapRc=false skips provider --cmd; inject ruby/python hosts explicitly.
    extraWrapperArgs =
      let
        providerWrap = pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
          withPython3 = true;
          withRuby = true;
          withPerl = false;
          withNodeJs = false;
          plugins = [ ];
          wrapRc = false;
        };
      in
      [
        "--add-flags"
        ''--cmd "lua ${providerWrap.passthru.providerLuaRc}"''
      ];
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
      "monstar"
      "zathura"
      "git"
      "zellij"
      "vifm"
      "nvim"
      "calcurse"
      "meli"
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
      # Bridge the host-side obsidian CLI to the Flatpak-confined socket.
      # %t expands to $XDG_RUNTIME_DIR; recreated each user session by
      # systemd-tmpfiles-setup.service since /run/user/UID is tmpfs.
      "user-tmpfiles.d/obsidian-cli-socket.conf".text = ''
        L+ %t/.obsidian-cli.sock - - - - %t/.flatpak/md.obsidian.Obsidian/xdg-run/.obsidian-cli.sock
      '';
    };

  services.flatpak = {
    enable = false;
    uninstallUnmanaged = false;
    uninstallUnused = false;
    update.onActivation = false;
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
      "ar.com.tuxguitar.TuxGuitar"
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
