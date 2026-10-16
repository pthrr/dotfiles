{
  pkgs,
  inputs,
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

  # Not in nixpkgs; consumed from upstream's own flake package output. The
  # rev lives in the flake.nix input — bump it there to upgrade monstar.
  monstar = inputs.monstar.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  home.packages =
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
        m4
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
        # clangd for the C/C++ LSP, plus clang-format/clang-tidy matching
        # the .clang-format and .clang-tidy wired up below.
        clang-tools
        ocaml
        opam
        lean4
        rustup
        (agda.withPackages (p: [
          p.cubical
          p.standard-library
        ]))
        cornelis
        ghcup
      ]
    ++

      # JavaScript/TypeScript
      [
        # Shared harness hooks run TypeScript directly with Node.
        nodejs
        pnpm
        # bun
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

      # Go tooling
      # gotools carries goimports (the on-save formatter wired up in
      # nvim/init.lua); `go` itself only ships gofmt, which leaves imports alone.
      [
        go
        gopls
        gotools
        delve
        golangci-lint
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
        opencode
        # Shared harness hooks lock state with flock.
        util-linux
      ]
    ++

      # Containers & Kubernetes
      # [ kind minikube helm k3s k3d crun envsubst ] ++

      # Build caching & debugging
      [
        mold
        sccache
        cargo-sweep
        cargo-cache
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
        quint
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
        qutebrowser
      ]
    ++

      # Other
      [
        go-task
        # wineWow64Packages.waylandFull
        # ripes # temporarily disabled due to cmake build issue
      ];
}
