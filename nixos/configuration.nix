# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  boot = {
    cleanTmpDir = true;
    supportedFilesystems = [ "ext2" "ext3" "ext4" "fat16" "fat32" "exfat" "ntfs" ];
    kernelParams = [ "efivars.pstore_disable=y" ];

    loader = {
      timeout = 1;

      systemd-boot = {
        enable = false;
      };

      grub = {
        enable = true;
        version = 2;
        splashImage = null;
        device = "nodev";
        efiSupport = true;
        enableCryptodisk = true;
      };

      efi = {
        canTouchEfiVariables = true;
      };
    };

    initrd.luks.devices = {
      root = {
        device = "/dev/disk/by-uuid/74f4fca2-9eb4-44e5-b1aa-33ebb254b109";
        preLVM = true;
      };
    };

    kernel = {
      sysctl = {
        "vm.swappiness" = 95;
      };
    };
  };

  fileSystems = {
    "/" = {
      options = [ "noatime" ];
    };
  };

  system = {
    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    stateVersion = "21.05"; # Did you read the comment?

    autoUpgrade = {
      enable = true;
      allowReboot = false;
      channel = "https://nixos.org/channels/nixos-21.05";
      dates = "weekly";
    };

    userActivationScripts = {
      dirs.text = ''
        mkdir -p ~/opt/
        mkdir -p ~/tmp/
        mkdir -p ~/mnt/
        mkdir -p ~/bin/
        mkdir -p ~/.config/nvim/undo/
        mkdir -p ~/.config/nvim/tags/
        mkdir -p ~/.config/nvim/after/
        mkdir -p ~/.config/nvim/syntax/
        mkdir -p ~/.config/nvim/indent/
        mkdir -p ~/.config/zathura/
      '';
    };
  };

  environment = {
    homeBinInPath = true;

    extraInit = ''
      export XDG_CONFIG_HOME=$HOME/.config
      export XDG_DATA_HOME=$HOME/.local/share
      export XDG_CACHE_HOME=$HOME/.cache
    '';

    gnome = {
      excludePackages = [ pkgs.gnome.file-roller pkgs.gnome.gnome-terminal pkgs.gnome.seahorse ];
    };

    variables = {
      LC_ALL = config.i18n.defaultLocale;
      LANG = config.i18n.defaultLocale;
      _JAVA_AWT_WM_NONREPARENTING = "1";
      GTK_THEME = "Adwaita:dark";
      QT_QPA_PLATFORMTHEME = pkgs.lib.mkForce "qt5ct";
      GNOME_ACCESSIBILITY = "0";
      QT_ACCESSIBILITY = "0";
      NO_AT_BRIDGE = "1";
      QT_LINUX_ACCESSIBILITY_ALWAYS_ON = "0";
      LV2_PATH = "$HOME/.lv2:$LV2_PATH";
      TERMINAL = "xterm-256color";
      TERM = "xterm-256color";
      BROWSER = "chromium";
      FZF_DEFAULT_COMMAND = "rg --files";
      FZF_DEFAULT_OPTS = "-m --height 50% --border";
      LESS = "-r";
    };

    shells = [ pkgs.bash ];

    systemPackages = with pkgs; [
      perl
      binutils
      usbutils
      coreutils-full
      util-linux
      nomacs
      man-pages
      nmap
      fzf
      rsync
      which
      wget
      file
      jre8
      curl
      htop
      alacritty
      kitty
      gdb
      rr
      appimage-run
      steam-run
      libnotify
      lxqt.lxqt-notificationd
      killall
      gnum4
      qt5ct
      zip
      unzip
      stow
      libwebp
      nettools
      microcodeIntel
      exa
      bat
      openscad
      neofetch
      gnumeric
      ripgrep
      unrar
      xfontsel
      xlsfonts
      xclip
      x11_ssh_askpass
      gnupg
      jq
      p7zip
      universal-ctags
      xcircuit
      ngspice
      keepassxc
      xlog
      xlife
      xlockmore
      xarchiver
      ipe
      zathura
      hexchat
      ungoogled-chromium
      evolution
      tor-browser-bundle-bin
      nextcloud-client
      git
      delta
      xterm
      wine
      winetricks
      android-file-transfer
      go-mtpfs
      vlc
      wirelesstools
      nodejs
      nodePackages.npm
      nodePackages.node2nix
      ghidra-bin
      spotify
      deadbeef
      tdesktop
      #element-desktop
      weechat
      tectonic
      zotero
      obsidian
      lv2
      kicad
      qucs
      flatcam
      avrdude
      verilator
      ngspice
      gnuradio
      gnucap
      picocom
      imagemagick
      gnome.nautilus
      lsof
      strace
      pprof
      gnumake
      gnuplot
      cmake
      automake
      autoconf
      ninja
      cabal-install
      clang_12
      clang-tools
      valgrind
      docker
      (python38.withPackages(ps: with ps; [
        pyqt4
        sip
        qtpy
        pyserial
        numpy
        scipy
        pyperclip
        pynvim
        pip
        setuptools
        wheel
        isort
        black
        mypy
        pylint
      ]))
      qt4
      cargo
      ocamlformat
      opam
      acpilight
      xorg.xrandr
      xorg.xf86inputevdev
      xorg.xf86inputlibinput
      xorg.xf86videointel
      xorg.xf86videonouveau
      pciutils
      lm_sensors
      pavucontrol
      psensor
      stalonetray
      dmenu
      haskellPackages.yeganesh
      haskellPackages.xmobar
      xorg.xorgserver
    ];
  };

  powerManagement = {
    enable = true;
  };

  programs = {
    gnupg = {
      agent = {
        enable = true;
      };
    };

    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;

      configure = {
        customRC = ''
          " OS dependent
          set termguicolors
          set background=dark
          colorscheme NeoSolarized
          let g:python3_host_prog = '/run/current-system/sw/bin/python'
          " generic
          syntax on
          filetype plugin indent on
          set encoding=utf-8
          set fileencodings=ucs-bom,utf-8,latin1,cp1252,default
          set nobomb
          set nobackup
          set noswapfile
          set nowritebackup
          set noshowmode
          set novisualbell
          set noerrorbells
          set undodir=~/.config/nvim/undo
          set undofile
          set undolevels=1000
          set undoreload=10000
          set complete=.,w,b,u,t
          set scrolloff=1
          set sidescrolloff=5
          set list
          set listchars=tab:\›\ ,trail:-,extends:>,precedes:<,nbsp:+
          set shell=/usr/bin/env\ bash
          set history=1000
          set splitbelow
          set splitright
          set number
          set relativenumber
          set nowrap
          set hlsearch
          set incsearch
          set autoread
          set lazyredraw
          set title
          set hidden
          set path+=**
          set wildmenu
          set wildmode=list:longest,full
          set wildignore +=.git,.hg,.svn
          set wildignore +=*.aux,*.out,*.toc
          set wildignore +=*.o,*.obj,*.exe,*.dll,*.manifest,*.rbc,*.class
          set wildignore +=*.ai,*.bmp,*.gif,*.ico,*.jpg,*.jpeg,*.png,*.psd,*.webp
          set wildignore +=*.avi,*.divx,*.mp4,*.webm,*.mov,*.m2ts,*.mkv,*.vob,*.mpg,*.mpeg
          set wildignore +=*.mp3,*.oga,*.ogg,*.wav,*.flac
          set wildignore +=*.eot,*.otf,*.ttf,*.woff
          set wildignore +=*.doc,*.pdf,*.cbr,*.cbz
          set wildignore +=*.zip,*.tar.gz,*.tar.bz2,*.rar,*.tar.xz,*.kgb
          set wildignore +=*.swp,.lock,.DS_Store,._*
          set colorcolumn=80
          set clipboard=unnamedplus
          set tabstop=4
          set softtabstop=4
          set shiftwidth=4
          set expandtab
          set foldmethod=indent
          set foldnestmax=2
          set foldlevelstart=10
          " automatically save view, load with :loadview
          autocmd BufWinLeave *.* mkview
          " show matching brackets
          set showmatch
          set matchtime=0
          highlight MatchParen guibg=none guifg=white gui=bold ctermbg=none ctermfg=white cterm=bold
          " highlight cursorline
          autocmd BufEnter * setlocal cursorline
          autocmd BufLeave * setlocal nocursorline
          autocmd InsertEnter * highlight cursorline guibg=none guifg=none gui=underline ctermbg=none ctermfg=none cterm=underline
          autocmd InsertLeave * highlight cursorline guibg=#073642 guifg=none gui=none ctermbg=none ctermfg=none cterm=none
          " c/cpp syntax highlighting options
          let g:cpp_member_highlight = 1
          let g:cpp_attributes_highlight = 1
          " change leader key
          let mapleader = "'"
          " map ESC
          inoremap jk <ESC>
          tnoremap jk <C-\><C-n>
          " move among buffers with CTRL
          map <C-J> :bnext<CR>
          map <C-K> :bprev<CR>
          " map folding
          vnoremap <space> zf
          nnoremap <space> za
          " paste multiple times
          xnoremap <leader>p "0p
          nnoremap <leader>p "0p
          " delete without yanking
          vnoremap <leader>d "_d
          nnoremap <leader>d "_d
          " replace currently selected text without yanking it
          vnoremap <leader>p "_dP
          " todo-comments
          nmap <F5> :TodoQuickFix cwd=.<CR>
          lua << EOF
            require("todo-comments").setup {
              highlight = {
                  before = "", -- "fg" or "bg" or empty
                  keyword = "fg", -- "fg", "bg", "wide" or empty
                  after = "", -- "fg" or "bg" or empty
                  pattern = [[.*<(KEYWORDS)\s*:]],
                  comments_only = true,
                  max_line_len = 400,
                  exclude = {},
              },
              keywords = {
                  FIXME = { icon = "! ", color = "error" },
                  TODO = { icon = "+ ", color = "info" },
                  HACK = { icon = "* ", color = "warning" },
                  WARN = { icon = "# ", color = "warning" },
                  PERF = { icon = "$ ", color = "default" },
                  NOTE = { icon = "> ", color = "hint" },
              },
              merge_keywords = false,
              pattern = [[\b(KEYWORDS):]],
            }
          EOF
          " ultisnips
          let g:UltiSnipsExpandTrigger = '<tab>'
          let g:UltiSnipsJumpForwardTrigger = '<tab>'
          let g:UltiSnipsJumpBackwardTrigger = '<s-tab>'
          let g:UltiSnipsSnippetDirectories = [$HOME.'/Documents/snippets']
          let g:ultisnips_python_style = 'sphinx'
          " tagbar
          nmap <F8> :TagbarToggle<CR>
          let g:tagbar_compact = 1
          let g:tagbar_sort = 1
          let g:tagbar_foldlevel = 1
          let g:tagbar_show_linenumbers = 1
          let g:tagbar_width = max([80, winwidth(0) / 4])
          " gutentags
          map oo <C-]>
          map OO <C-T>
          map <C-O> g]
          set tags=~/.config/nvim/tags
          let g:gutentags_modules = ['ctags']
          let g:gutentags_add_default_project_roots = 0
          let g:gutentags_project_root = ['requirements.txt', '.git', 'README.md']
          let g:gutentags_cache_dir='~/.config/nvim/tags'
          let g:gutentags_generate_on_new = 1
          let g:gutentags_generate_on_missing = 1
          let g:gutentags_generate_on_write = 1
          let g:gutentags_generate_on_empty_buffer = 0
          let g:gutentags_ctags_extra_args = [
                \ '--tag-relative=yes',
                \ '--fields=+ailmnS',
                \ ]
          let g:gutentags_ctags_exclude = [
                \ '*.git', '*.svg', '*.hg',
                \ '*/tests/*',
                \ 'build',
                \ 'dist',
                \ '*/venv/*', '*/.venv/*',
                \ '*sites/*/files/*',
                \ 'bin',
                \ 'node_modules',
                \ 'bower_components',
                \ 'cache',
                \ 'compiled',
                \ 'docs',
                \ 'example',
                \ 'bundle',
                \ 'vendor',
                \ '*.md',
                \ '*-lock.json',
                \ '*.lock',
                \ '*bundle*.js',
                \ '*build*.js',
                \ '.*rc*',
                \ '*.json',
                \ '*.min.*',
                \ '*.map',
                \ '*.bak',
                \ '*.zip',
                \ '*.pyc',
                \ '*.class',
                \ '*.sln',
                \ '*.Master',
                \ '*.csproj',
                \ '*.tmp',
                \ '*.csproj.user',
                \ '*.cache',
                \ '*.pdb',
                \ 'tags*',
                \ 'cscope.*',
                \ '*.css',
                \ '*.less',
                \ '*.scss',
                \ '*.exe', '*.dll',
                \ '*.mp3', '*.ogg', '*.flac',
                \ '*.swp', '*.swo',
                \ '*.bmp', '*.gif', '*.ico', '*.jpg', '*.png',
                \ '*.rar', '*.zip', '*.tar', '*.tar.gz', '*.tar.xz', '*.tar.bz2',
                \ '*.pdf', '*.doc', '*.docx', '*.ppt', '*.pptx',
                \ ]
          " ale
          nmap <F6> :ALEFix<CR>
          let g:ale_linters = {
              \ 'python': ['pylint'],
              \ 'cpp': ['clangtidy'],
              \ 'c': ['clangtidy'],
              \}
          let g:ale_fixers = {
              \ 'python': ['black', 'isort'],
              \ 'cpp': ['clang-format'],
              \ 'c': ['clang-format'],
              \ '*': ['remove_trailing_lines', 'trim_whitespace'],
              \}
          let g:ale_python_black_options = '--line-length 79'
          let g:ale_python_isort_options = '--profile black --atomic --line-length 79'
          let g:ale_cpp_clangformat_style_option = 'chromium'
          let g:ale_c_clangformat_style_option = 'webkit'
          let g:ale_cpp_clangtidy_checks = [
              \ 'bugprone-*',
              \ 'cppcoreguidelines-*',
              \ 'google-*',
              \ 'modernize-*',
              \ 'misc-*',
              \ 'performance-*',
              \ 'readability-*',
              \]
          let g:ale_fix_on_save = 0
          let g:ale_lint_on_enter = 1
          let g:ale_lint_on_filetype_changed = 0
          let g:ale_lint_on_insert_leave = 0
          let g:ale_lint_on_text_changed = 0
          let g:ale_lint_on_save = 1
        '';

        packages.nix = with pkgs.vimPlugins; {
          start = [
            vim-nix
            vim-ocaml
            NeoSolarized
            ultisnips
            tagbar
            vim-gutentags
            todo-comments-nvim
            ale
          ];
        };
      };
    };

    bash = {
      enableCompletion = true;
      enableLsColors = true;

      interactiveShellInit = ''
        HISTCONTROL=ignorespace:erasedups
        HISTSIZE=1000
        HISTFILESIZE=2000
        function cht() {
            curl -m 10 "https://cht.sh/$@"
        }
        function gmv() { # move submodule
            mv $1 $2
            git rm $1
            git add $2
            git submodule sync
        }
        function fpy() {
            isort --profile black --atomic --line-length 79 "$@"
            black --verbose --line-length 79 "$@"
            pylint "$@"
        }
        function fcc() {
            clang-format -verbose -i -style=google "$@"
            clang-tidy "$@"
        }
        function fcm() {
            cmake-format -i "$@"
        }
        function foc() {
            ocamlformat --inplace --enable-outside-detected-project "$@"
        }
        function ioc() {
            dune init proj "$@" --libs "base,stdio,owl,owl-top,owl-base,owl-plplot"
        }
        function roc() {
            dune build && dune exec "$@"
        }
        function toc() {
            dune test "$@"
        }
        function lla() {
            exa -la --git --color=always "$@" | less
        }
        function ll() {
            exa -l --git --color=always "$@" | less
        }
        function lsd() {
            exa --tree --long --git --color=always --level 6 -D -I ".git|venv|__pycache__" "$@" | less
        }
        function lsf() {
            exa --tree --long --git --color=always --level 6 -a -I ".git|venv|__pycache__" "$@" | less
        }
        function vp() {
            shopt -s nullglob
            nvim src/*.py "$@"
            shopt -u nullglob
        }
        function vc() {
            shopt -s nullglob
            nvim src/*.c src/*.cc "$@"
            shopt -u nullglob
        }
        function vo() {
            shopt -s nullglob
            nvim bin/*.ml lib/*.ml test/*.ml "$@"
            shopt -u nullglob
        }
        source "$HOME/z.sh"
        source "$HOME/key-bindings.bash"
        eval $(opam config env)
      '';

      promptInit = ''
        PROMPT_DIRTRIM=2
        PS1='\[\e[33m\]\w\[\e[0m\] \u$(if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then echo " @ \h"; else echo ""; fi) % '
      '';

      shellAliases = {
        g = "git";
        top = "htop";
        ls = "exa";
        cat = "bat";
        grep = "rg";
        cp = "cp -iv";
        mv = "mv -iv";
        mkdir = "mkdir -pv";
        rm = "rm -Iv";
        untar = "tar vxf";
        un7z = "7z x";
        cl = "clear";
        ".." = "cd ../";
        "..." = "cd ../../";
        "...." = "cd ../../../";
        "....." = "cd ../../../../";
        py = "python3";
        xdg = "xdg-open";
        mirror="wget --mirror --convert-links --adjust-extension --page-requisites --no-parent";
        com="picocom -b 115200 --echo --omap=crcrlf";
        ports="sudo netstat -pln";
        pwgen="python -c 'import secrets,pyperclip;pw=secrets.token_urlsafe(32);pyperclip.copy(pw);print(pw)'";
      };
    };

    nm-applet = {
      enable = true;
    };

    tmux = {
      enable = true;

      extraConfig = ''
        set -g status-bg colour234
        set -g status-fg colour137
        set -g status-right "[#S]"
        set -g status-left ""
        set -g status-interval 5
        set -g renumber-windows on
        set -g automatic-rename on
        set -g automatic-rename-format '#{b:pane_current_path}'
        set -g base-index 1
        set -g escape-time 1
        set -g focus-events on
        set -g history-limit 5000
        set -ga terminal-overrides ",xterm-256color:Tc"
        setw -g mode-keys vi
        setw -g pane-base-index 1
        setw -g window-status-current-format " #I#[fg=colour250]:#[fg=colour255]#W#[fg=colour50]#F "
        setw -g window-status-format " #I#[fg=colour237]:#[fg=colour250]#W#[fg=colour244]#F "
      '';
    };
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  security = {
    #polkit = {
    #  enable = false;
    #};

    #rngd = {
    #  enable = false;
    #};

    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
  };

  nix = {
    optimise = {
      automatic = true;
    };

    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };

  time = {
    timeZone = "Europe/Berlin";
  };

  networking = {
    hostName = "X250";
    useDHCP = false; # disable globally as this flag is deprecated
    enableIPv6 = false;

    firewall = {
      enable = false;
    };

    wireless = {
      enable = false;  # Enables wireless support via wpa_supplicant.
    };

    networkmanager = {
      enable = true;
      packages = [ pkgs.networkmanager-openvpn ];
    };

    interfaces = {
      enp0s25 = {
        useDHCP = true;
      };

      wlp3s0 = {
        useDHCP = true;
      };
    };
  };

  fonts = {
    enableGhostscriptFonts = true;

    fontconfig = {
      enable = true;
    };

    fontDir = {
      enable = true;
    };

    fonts = with pkgs; [
      lmodern
      font-awesome
      font-awesome_4
      corefonts
      dejavu_fonts
      inconsolata
      fira-mono
      fira-code
      fira-code-symbols
      ubuntu_font_family
    ];
  };

  i18n = {
    defaultLocale = "de_DE.UTF-8";
  };

  console = {
    font = "Lat2-Terminus16";
    keyMap = "de";
  };

  systemd = {
    targets = {
      sleep = {
        enable = false;
      };

      suspend = {
        enable = false;
      };

      hibernate = {
        enable = false;
      };

      hybrid-sleep = {
        enable = false;
      };
    };
  #  services = {
     # upower = {
     #   enable = true;
      #};
  #  };
  };

  xdg = {
    mime = {
      enable = true;
    };
  };

  services = {
    udev = {
      packages = [ pkgs.android-udev-rules ];
      extraRules = ''
        ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video %S%p/brightness", RUN+="${pkgs.coreutils}/bin/chmod g+w %S%p/brightness"
      '';
    };

    fstrim = {
      enable = true;
    };

    gvfs = {
      enable = true;
    };

    cron = {
      enable = true;
    };

    openssh = {
      enable = true;
      permitRootLogin = "no";
    };

    fwupd = {
      enable = true;
    };

    acpid = {
      enable = true;
    };

    dbus = {
      enable = true;
    };

    avahi = {
      enable = false;
    };

    blueman = {
      enable = true;
    };

    #tlp = {
    #  enable = true;

    #  settings = {
    #    SATA_LINKPWR_ON_AC = true;
    #    SATA_LINKPWR_ON_BAT = true;
    #  };
    #};

    timesyncd = {
      enable = true;
      servers = [
        "0.pool.ntp.org"
        "1.pool.ntp.org"
        "2.pool.ntp.org"
        "3.pool.ntp.org"
      ];
    };

    journald = {
      extraConfig = "SystemMaxUse=100M";
    };

    #upower = {
    #  enable = true;
    #};

    redshift = {
      enable = true;

      temperature = {
        day = 5500;
        night = 2300;
      };
    };

    gnome = {
      core-utilities = {
        enable = false;
      };

      core-developer-tools = {
        enable = false;
      };

      core-os-services = {
        enable = true;
      };

      core-shell = {
        enable = true;
      };

      games = {
        enable = false;
      };
    };

    xserver = {
      enable = true;
      autorun = true;
      exportConfiguration = true;
      layout = "de";
      xkbOptions = "eurosign:e";

      desktopManager = {
        gnome = {
          enable = true;
        };

        xterm = {
          enable = false; # login manager
        };

        session = [
          { name = "custom";
            start = ''
              /run/current-system/sw/bin/xrdb -merge ~/.xresources
              /run/current-system/sw/bin/xsetroot -solid black &
              /run/current-system/sw/bin/stalonetray &
              /run/current-system/sw/bin/blueman-applet &
              /run/current-system/sw/bin/nm-applet &
              /run/current-system/sw/bin/nextcloud &
            '';
            #/run/current-system/sw/bin/telegram-desktop -startintray &
          }
        ];
      };

      displayManager = {
        defaultSession = "custom+xmonad";

        sddm = {
          enable = true;
          theme = "${(pkgs.fetchFromGitHub {
            owner = "pthrr";
            repo = "minimal-sddm-theme";
            rev = "cdeefa8cefd8d216d1836a7a94ccc6cfa843c2cd";
            sha256 = "01n5zaa6a87scq190lmq3bb476ip6xgxl2iqqlldkjm0v134z684";
            })}";
        };
      };

      windowManager = {
        xmonad = {
          enable = true;
          enableContribAndExtras = true;
          extraPackages = haskellPackages: [ haskellPackages.yeganesh haskellPackages.xmobar ];

          config = ''
            import XMonad
            import XMonad.Hooks.ManageDocks
            import XMonad.Util.Run
            import XMonad.Hooks.DynamicLog
            import XMonad.Util.CustomKeys
            import XMonad.Util.EZConfig
            import Graphics.X11.ExtraTypes.XF86
            import XMonad.Actions.CycleWS
            import XMonad.Layout.NoBorders
            import XMonad.Hooks.ManageDocks

            import Control.Monad (when)
            import Text.Printf (printf)
            import System.Posix.Process (executeFile)
            import System.Info (arch,os)
            import System.Environment (getArgs)
            import System.FilePath ((</>))

            main = do
            xmproc <- spawnPipe "xmobar"
            xmonad $ docks $ def
              { terminal = "xterm"
              , manageHook = manageDocks <+> manageHook def
              , layoutHook = avoidStruts $ smartBorders $ layoutHook def
              , focusFollowsMouse = False
              , logHook = dynamicLogWithPP $ def
                { ppOutput = hPutStrLn xmproc
                , ppOrder = \(ws:_:t:_) -> [ws,t]
                }
              , borderWidth = 2
              }
              `additionalKeys`
              [ ((0, xF86XK_MonBrightnessUp), spawn "xbacklight +10")
              , ((0, xF86XK_MonBrightnessDown), spawn "xbacklight -10")
              , ((0, xF86XK_AudioLowerVolume), spawn "pactl set-sink-volume @DEFAULT_SINK@ -10%")
              , ((0, xF86XK_AudioRaiseVolume), spawn "pactl set-sink-volume @DEFAULT_SINK@ +10%")
              , ((0, xF86XK_AudioMute), spawn "pactl set-sink-mute @DEFAULT_SINK@ toggle")
              , ((0, xF86XK_AudioMicMute), spawn "pactl set-source-mute @DEFAULT_SOURCE@ toggle")
              , ((mod1Mask, xK_z), toggleWS)
              , ((mod1Mask, xK_j), nextWS)
              , ((mod1Mask, xK_k), prevWS)
              , ((mod1Mask, xK_h), nextScreen)
              , ((mod1Mask, xK_l), prevScreen)
              , ((mod1Mask .|. shiftMask, xK_Right), shiftToNext)
              , ((mod1Mask .|. shiftMask, xK_Left), shiftToPrev)
              , ((mod1Mask .|. shiftMask, xK_Up), shiftNextScreen)
              , ((mod1Mask .|. shiftMask, xK_Down), shiftPrevScreen)
              , ((mod1Mask, xK_s), spawn "xlock")
              , ((mod1Mask, xK_p), spawn "exe=`dmenu_path | yeganesh -- -b -fn \"xft:DejaVu Sans Mono:size=10\"` && eval \"exec $exe\"")
              , ((mod1Mask, xK_q), restart "/run/current-system/sw/bin/xmonad" True)
              ]
          '';
        };
      };
    };
  };

  location = {
    latitude = 48.1;
    longitude = 11.5;
  };

  sound = {
    enable = true;

    mediaKeys = {
      enable = true;
    };
  };

  hardware = {
    enableAllFirmware = true;

    trackpoint = {
      enable = true;
      emulateWheel = true;
    };

    bluetooth = {
      enable = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
        };
      };
    };

    pulseaudio = {
      enable = true;
      extraModules = [ pkgs.pulseaudio-modules-bt ];
      #extraConfig = "
      #  load-module module-switch-on-connect
      #";
      package = pkgs.pulseaudioFull;
    };

    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
      extraPackages = with pkgs; [
          vaapiIntel
          vaapiVdpau
          libvdpau-va-gl
          intel-media-driver
        ];
    };

    cpu = {
      intel = {
        updateMicrocode = true;
      };
    };
  };

  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;

  #users.extraGroups.vboxusers.members = [ "user-with-access-to-virtualbox" ];

  users = {
    mutableUsers = true;

    extraUsers = {
      pthrr = {
        description = "pthrr";
        isNormalUser = true;
        uid = 1000;
        extraGroups = [ "wheel" "video" "networkmanager" "vboxusers" ];
      };

      hacknmake = {
        description = "hacknmake";
        isNormalUser = true;
        extraGroups = [ "video" "networkmanager" ];
      };
    };
  };
}
