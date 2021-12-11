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
  };

  boot.kernel.sysctl = { "vm.swappiness" = 95;};

  swapDevices = [
    { device = "/dev/disk/by-uuid/e08a2b6f-dfe1-4641-b823-d5cbdb156eba"; }
  ];

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
        mkdir -p ~/bin/
        mkdir -p ~/.config/nvim/undo/
        mkdir -p ~/.config/nvim/tags/
        mkdir -p ~/.config/nvim/after/
        mkdir -p ~/.config/nvim/syntax/
        mkdir -p ~/.config/zathura/
      '';
    };
  };

  environment = {
    homeBinInPath = true;
    #extraSetup = "";
    #interactiveShellInit = "";
    #loginShellInit = "";

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
      QT_QPA_PLATFORMTHEME = "qt5ct";
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
    };

    shells = [ pkgs.bash ];

    systemPackages = with pkgs; [
      perl # system
      binutils
      coreutils-full
      nomacs
      util-linux
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
      silver-searcher
      feh
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
      tree
      unzip
      stow
      libwebp
      nettools
      microcodeIntel
      exa
      bat
      neofetch
      ripgrep
      unrar
      xfontsel
      xlsfonts
      xclip
      x11_ssh_askpass
      gnupg
      jq
      p7zip
      universal-ctags # vi
      qtpass
      pinentry-curses
      xcircuit
      ngspice
      keepassxc
      xlog
      xarchiver
      ipe
      zathura
      ungoogled-chromium
      firefox
      #tor-browser-bundle-bin
      nextcloud-client
      git
      delta
      xterm
      wine
      winetricks
      vlc
      wirelesstools
      #brightnessctl
      nodePackages.npm
      pass
      spotify
      gnome.geary
      tectonic
      obsidian
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
      #blueman
      #networkmanager
      lsof # diag
      strace
      pprof
      gnumake # dev
      gnuplot
      cmake
      automake
      autoconf
      ninja
      cabal-install
      clang_12
      gcc11
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
      ocaml
      ocamlPackages.owl
      ocamlPackages.owl-base
      ocamlPackages.core
      ocamlPackages.opam-core
      ocamlPackages.base
      ocamlPackages.findlib
      opam
      xorg.xbacklight # hw
      xorg.xrandr
      xorg.xf86inputevdev
      xorg.xf86inputlibinput
      xorg.xf86videointel
      xorg.xf86videonouveau
      pciutils
      lm_sensors
      pavucontrol
      psensor
      stalonetray # wm
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
        pinentryFlavor = "curses";
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
            set background=dark
            set termguicolors
            colorscheme NeoSolarized
            " just be a text editor
            let g:loaded_python_provider = 0 " disable py2
            let g:python3_host_prog = '/run/current-system/sw/bin/python'
            " generic
            syntax on
            filetype plugin indent on
            set encoding=utf-8
            set fileencodings=ucs-bom,utf-8,utf-16,cp1252,default,latin1
            set nobomb
            set nobackup
            set noswapfile
            set nowritebackup
            set undodir=~/.config/nvim/undo
            set undofile
            set splitbelow
            set splitright
            set number
            set relativenumber
            set nowrap
            set autoread
            set hlsearch
            set ignorecase
            set incsearch
            set title
            set hidden
            set noshowmode
            set novisualbell
            set noerrorbells
            set statusline=
            set statusline +=\ %n\             "buffer number
            set statusline +=%{&ff}            "file format
            set statusline +=%y                "file type
            set statusline +=\ %{&fenc}        "file encoding
            set statusline +=\ %<%F            "full path
            set statusline +=%m                "modified flag
            set statusline +=%=%5l             "current line
            set statusline +=/%L               "total lines
            set statusline +=%4v\              "virtual column number
            set statusline +=0x%04B\           "character under cursor
            set path=$PWD/**
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
            set list listchars=tab:\›\ ,trail:-,extends:>,precedes:<
            set tabstop=4
            set softtabstop=4
            set shiftwidth=4
            set expandtab
            set foldmethod=indent
            set foldnestmax=2
            set foldlevelstart=10
            " map folding
            nnoremap <space> za
            vnoremap <space> zf
            " map ESC
            inoremap jk <ESC>
            tnoremap jk <C-\><C-n>
            " change leader key
            let mapleader = "'"
            " automatically save view, load with :loadview
            autocmd BufWinLeave *.* mkview
            " paste multiple times
            xnoremap p pgvy
            " show matching brackets
            set showmatch
            highlight MatchParen guibg=none guifg=white gui=bold ctermbg=none ctermfg=white cterm=bold
            set matchtime=0
            " highlight cursorline in insert mode
            highlight cursorline guibg=none guifg=none gui=underline ctermbg=none ctermfg=none cterm=underline
            autocmd InsertEnter * set cursorline
            autocmd InsertLeave * set nocursorline
            " fzf
            set grepprg=rg\ --vimgrep\ --smart-case\ --follow
            nnoremap <silent> <C-f> :Files<CR>
            nnoremap <silent> <Leader>f :Ag<CR>
            nnoremap <silent> <Leader>b :Buffers<CR>
            nnoremap <silent> <Leader>/ :BLines<CR>
            nnoremap <silent> <Leader>' :Marks<CR>
            nnoremap <silent> <Leader>g :Commits<CR>
            nnoremap <silent> <Leader>H :Helptags<CR>
            nnoremap <silent> <Leader>hh :History<CR>
            nnoremap <silent> <Leader>h: :History:<CR>
            nnoremap <silent> <Leader>h/ :History/<CR> 
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
            " magit
            let g:magit_default_fold_level = 0
            nmap <F7> :MagitOnly<CR>
            " c/cpp syntax highlighting options
            let g:cpp_member_highlight = 1
            let g:cpp_attributes_highlight = 1
            " gutentags
            map oo <C-]>
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
        '';

        packages.nix = with pkgs.vimPlugins; {
          start = [
            NeoSolarized
            tagbar
            vim-nix
            fzf-vim
            vim-gutentags
            vimagit
            ultisnips
          ];
        };
      };
    };

    slock = {
      enable = true;
    };

    bash = {
      enableCompletion = true;
      enableLsColors = true;

      shellInit = ''
        HISTCONTROL=ignoreboth
        HISTSIZE=1000
        HISTFILESIZE=2000
      '';

      interactiveShellInit = ''
        function cht() {
            curl -m 10 "https://cht.sh/$@"
        }
        function gmv() { # move submodule
            mv $1 $2
            git rm $1
            git add $2
            git submodule sync
        }
        function fmp() {
            isort --profile black --atomic --line-length 79 "$@"
            black --verbose --line-length 79 "$@"
            pylint "$@"
        }
        function op() {
            dune init proj $@ --libs base,stdio,owl,owl-top,owl-base,owl-plplot,owl-zoo
        }
        source "$HOME/z.sh"
        source "$HOME/key-bindings.bash"
        eval $(opam config env)
      '';

      #loginShellInit = "";

      promptInit = ''
        PROMPT_DIRTRIM=2
        PS1='\[\e[33m\]\w\[\e[0m\] \u$(if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then echo " @ \h"; else echo ""; fi) % '
      '';

      shellAliases = {
        top = "htop";
        ack = "ag";
        ls = "exa";
        cat = "bat";
        grep = "rg";
        cp = "cp -iv";
        mv = "mv -iv";
        mkdir = "mkdir -pv";
        rm = "rm -Iv";
        untar = "tar vxf";
        lla = "ls -la";
        ll = "ls -l";
        lsd = "tree -d -L 6 | less";
        lsf = "tree -a -L 6 -I '.git' | less";
        h = "history | less";
        cl = "clear";
        ".." = "cd ../";
        "..." = "cd ../../";
        "...." = "cd ../../../";
        "....." = "cd ../../../../";
        g = "git";
        s = "g ssb";
        l = "g ld";
        fmc = "clang-format -verbose -i -style=google";
        fmo = "dune build @fmt --auto-promote --enable-outside-detected-project";
        fmm = "cmake-format -i";
        vp = "vi src/*.py";
        vc = "vi src/*.c src/*.cc";
        vo = "vi src/*.ml";
        oc = "dune build && dune exec";
        ot = "dune runtest";
        py = "python3";
        xdg = "xdg-open";
        mirror="wget --mirror --convert-links --adjust-extension --page-requisites --no-parent";
        pc="picocom -b 115200 --echo --omap=crcrlf";
        ports="lsof -i -P -n | grep LISTEN";
        pwgen="python -c 'import secrets,pyperclip;pw=secrets.token_urlsafe(32);pyperclip.copy(pw);print(pw)'";
      };
    };

    nm-applet = {
      enable = true;
    };

    tmux = {
      enable = true;

      extraConfig = ''
        set -g status-position bottom
        set -g status-bg colour234
        set -g status-fg colour137
        set -g status-left ""
        set -g status-right ""
        set -g status-right-length 50
        set -g status-left-length 20
        set-option -g status-interval 5
        set-option -g automatic-rename on
        set-option -g automatic-rename-format '#{b:pane_current_path}'
        setw -g window-status-current-format " #I#[fg=colour250]:#[fg=colour255]#W#[fg=colour50]#F "
        setw -g window-status-format " #I#[fg=colour237]:#[fg=colour250]#W#[fg=colour244]#F "
        setw -g mode-keys vi
        set-option -g history-limit 5000
        set -g base-index 1
        setw -g pane-base-index 1
        set-option -ga terminal-overrides ",xterm-256color:Tc"
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

    fontDir = {
      enable = true;
    };

    fonts = with pkgs; [
      corefonts
      dejavu_fonts
      inconsolata
      fira-mono
      fira-code
      ubuntu_font_family
    ];
  };

  i18n = {
    defaultLocale = "de_DE.UTF-8";
  };

  console = {
    font = "Lat2-Terminus16"; #"${pkgs.terminus_font}/share/consolefonts/ter-v16n.psf.gz";
    keyMap = "de";
    #useXkbConfig = true;
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
        "0.ch.pool.ntp.org"
        "1.ch.pool.ntp.org"
        "2.ch.pool.ntp.org"
        "3.ch.pool.ntp.org"
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
          enable = false;
        };

        session = [
          { name = "custom";
            start = ''
              /run/current-system/sw/bin/xrdb -merge ~/.xresources
              /run/current-system/sw/bin/xsetroot -solid black &
              /run/current-system/sw/bin/stalonetray &
              /run/current-system/sw/bin/blueman-applet &
              #/run/current-system/sw/bin/nm-applet &
              /run/current-system/sw/bin/nextcloud &
            '';
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
            rev = "f8c63eb135f39a8afb78474a563506c0fa673a20";
            sha256 = "093yfhk6lm758hahb79r36248gyx3j1dkbkf33iqvqywxwjfc3h1";
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

            import Control.Monad (when)
            import Text.Printf (printf)
            import System.Posix.Process (executeFile)
            import System.Info (arch,os)
            import System.Environment (getArgs)
            import System.FilePath ((</>))

            main = do
            xmproc <- spawnPipe "xmobar"
            xmonad $ def
              { terminal = "xterm"
              , manageHook = manageDocks <+> manageHook def
              , layoutHook = avoidStruts $ layoutHook def
              , focusFollowsMouse = False
              , handleEventHook = handleEventHook def <+> docksEventHook
              , logHook = dynamicLogWithPP $ def
                { ppOutput = hPutStrLn xmproc
                , ppOrder = \(ws:_:t:_) -> [ws,t]
                }
              , borderWidth = 2
              }
              `additionalKeys`
              [ ((mod1Mask, xK_p), spawn "exe=`dmenu_path | yeganesh -- -b -fn \"xft:DejaVu Sans Mono:size=10\"` && eval \"exec $exe\"")
              , ((mod1Mask, xK_s), spawn "slock")
              , ((0, xF86XK_MonBrightnessUp), spawn "xbacklight +10")
              , ((0, xF86XK_MonBrightnessDown), spawn "xbacklight -10")
              , ((0, xF86XK_AudioMute), spawn "pactl set-sink-mute @DEFAULT_SINK@ toggle")
              , ((0, xF86XK_AudioMicMute), spawn "pactl set-source-mute @DEFAULT_SOURCE@ toggle")
              , ((0, xF86XK_AudioLowerVolume), spawn "pactl set-sink-volume @DEFAULT_SINK@ -10%")
              , ((0, xF86XK_AudioRaiseVolume), spawn "pactl set-sink-volume @DEFAULT_SINK@ +10%")
              , ((mod1Mask, xK_Right), nextWS)
              , ((mod1Mask, xK_Left), prevWS)
              , ((mod1Mask .|. shiftMask, xK_Right), shiftToNext)
              , ((mod1Mask .|. shiftMask, xK_Left), shiftToPrev)
              , ((mod1Mask, xK_Up), nextScreen)
              , ((mod1Mask, xK_Down), prevScreen)
              , ((mod1Mask .|. shiftMask, xK_Up), shiftNextScreen)
              , ((mod1Mask .|. shiftMask, xK_Down), shiftPrevScreen)
              , ((mod1Mask, xK_z), toggleWS)
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
    enableRedistributableFirmware = true;

    bluetooth = {
      enable = true;
    };

    pulseaudio = {
      enable = true;
      extraModules = [ pkgs.pulseaudio-modules-bt ];
      package = pkgs.pulseaudioFull;
    };

    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    cpu = {
      intel = {
        updateMicrocode = true;
      };
    };
  };

  users = {
    mutableUsers = true;

    extraUsers = {
      pthrr = {
        description = "pthrr";
        isNormalUser = true;
        uid = 1000;
        extraGroups = [ "wheel" "networkmanager" ];
      };

      hacknmake = {
        description = "hacknmake";
        isNormalUser = true;
        extraGroups = [ "networkmanager" ];
      };
    };
  };
}
