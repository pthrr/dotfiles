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

	memtest86 = {
	  enable = true;
	};
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

  fileSystems = {
    "/" = {
      options = ["noatime" "nodiratime" "discard"];
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
      allowReboot = true;
      channel = "https://nixos.org/channels/nixos-21.05";
      dates = "04:30";
    };

    #activationScripts = {
    #  media = ''
    #  mkdir /home/pthrr/opt
    #  '';
    #};
  };

  # services.acpid.enable = true;

  environment = {
    homeBinInPath = true;
    #extraInit = "";
    #extraSetup = "";
    #interactiveShellInit = "";
    #loginShellInit = "";

#	etc."bashrc".text =
#      ''
#        # /etc/bashrc: DO NOT EDIT -- this file has been generated automatically.
#        # Only execute this file once per shell.
#        if [ -n "$__ETC_BASHRC_SOURCED" -o -n "$NOSYSBASHRC" ]; then return; fi
#        __ETC_BASHRC_SOURCED=1
#        # If the profile was not loaded in a parent process, source
#        # it.  But otherwise don't do it because we don't want to
#        # clobber overridden values of $PATH, etc.
#        if [ -z "$__ETC_PROFILE_DONE" ]; then
#            . /etc/profile
#        fi
#        # We are not always an interactive shell.
#        if [ -n "$PS1" ]; then
#          ${cfg.interactiveShellInit}
#        fi
#        # Read system-wide modifications.
#        if test -f /etc/bashrc.local; then
#          . /etc/bashrc.local
#        fi
#      '';

    #shellAliases = {
    #  g = "git";
    #};

    #shellInit = "";

    variables = {
      LC_ALL = "de_DE.UTF-8";
      LANG = "de_DE.UTF-8";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      GTK_THEME = "Adwaita:dark";
      QT_QPA_PLATFORMTHEME = "qt5ct";
      GNOME_ACCESSIBILITY = "0";
      QT_ACCESSIBILITY = "0";
      NO_AT_BRIDGE = "1";
      QT_LINUX_ACCESSIBILITY_ALWAYS_ON = "0";
    };

    #shells = [ pkgs.bash ];

    systemPackages = with pkgs; [
      perl # system
      man-pages
      gnome.gnome-themes-extra
      nmap
      rsync
      which
      whois
      wget
      curl
      feh
      libnotify
      lxqt.lxqt-notificationd
      killall
      gnum4
      qt5ct
      zip
      binutils
      tree
      unzip
      #sudo
      stow
      nettools
      microcodeIntel
      exa
      neofetch
      ripgrep
      unrar
      xfontsel
      xlsfonts
      xclip
      dejavu_fonts
      ubuntu_font_family
      inconsolata
      fira-mono
      fira-code
      x11_ssh_askpass
      networkmanager
      jq
      p7zip
      gnupg
      openssh
      slock
      universal-ctags # vi
      #neovim
      fzf # tools
      #bash
      xcircuit
      xlog
      xarchiver
      ipe
      #qutebrowser
      chromium
      surf
      tabbed
      nextcloud-client
      git
      xterm
      vlc
      wirelesstools
      pass
      #xpdf
      epdfview
      spotify
      #tmux
      #networkmanagerapplet
      htop
      silver-searcher
      gnome.nautilus
      blueman
      lsof # diag
      strace
      gnumake # dev
      cmake
      automake
      ninja
      clang_12
      gcc11
      python39
      cargo
      ocaml
      opam
      xorg.xbacklight # hw
      xorg.xrandr
      #xorg.xf86inputsynaptics
      xorg.xf86inputevdev
      xorg.xf86inputlibinput
      xorg.xf86videointel
      xorg.xf86videonouveau
      pciutils
      lm_sensors
      pavucontrol
      #pulseaudioFull
      psensor
      stalonetray # wm
      dmenu
      cabal-install
      #redshift
      haskellPackages.yeganesh
      haskellPackages.xmobar
      haskellPackages.xmonad
      haskellPackages.xmonad-contrib
      haskellPackages.xmonad-extras
      #lightdm
      #xorg.xinit
      #xorg.xorgserver
    ];
  };
#  boot.initrd.availableKernelModules =
#    [ "xhci_pci" "ehci_pci" "ahci" "sd_mod" "sdhci_pci" ];
#  boot.initrd.kernelModules = [ "dm-snapshot" ];
#  boot.kernelModules = [ "kvm-intel" ];
#  boot.extraModulePackages = [ ];

#  nix.maxJobs = lib.mkDefault 4;
#  powerManagement.cpuFreqGovernor = lib.mkDefault "conservative";
  # Firmware updates
#  services.fwupd.enable = true;

  #powerManagement = {
  #  scsiLinkPolicy = "max_performance";
  #};

  programs = {
    bash = {
      enableCompletion = true;
      enableLsColors = true;

      interactiveShellInit = ''
        export LV2_PATH="$HOME/.lv2:$LV2_PATH";
        eval $(opam config env)
      '';

      #loginShellInit = "";
      #promptInit = "";

      shellAliases = {
        top = "htop";
	#ssp = "surf https://www.startpage.com/do/mypage.pl?prfe=f242a59967ba7e9847b309593d1abbe034e2efc8b5780ff7c4ae592d21a509f36cfafb368bbb7f41735c3dd65a9654f7df5fe776bbb81d6597c38455b668278e14d6357f58f2a5ad196bfae683c791";
      };

      #shellInit = ''
      #'';
    };

    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };

    nm-applet = {
      enable = true;
    };

    tmux = {
      enable = true;
    };
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      #permittedInsecurePackages = [ "xpdf-4.03" ];
    };
  };

  security = {
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
      dates = "4:30";
      options = "--delete-older-than 30d";
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
      #packages = [ pkgs.networkmanager_openvpn ];
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
    services = {
      upower = {
        enable = true;
      };
    };
  };

  xdg = {
    mime.enable = true;
  };

  services = {
    dbus = {
      enable = true;
    };

    avahi = {
      enable = false;
      nssmdns = false;
    };

    tlp = {
      enable = true;

      settings = {
        SATA_LINKPWR_ON_AC = true;
        SATA_LINKPWR_ON_BAT = true;
      };
    };

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
      extraConfig = "SystemMaxUse=500M";
    };

    upower = {
      enable = true;
    };

    redshift = {
      enable = true;

      temperature = {
        day = 5500;
        night = 2300;
      };
    };

    gnome = {
      gnome-keyring = {
        enable = true;
      };
    };

    xserver = {
      enable = true;
      autorun = true;
      exportConfiguration = false;
      layout = "de";
      xkbOptions = "eurosign:e";

      #synaptics = {
      #  enable = true;
#	twoFingerScroll = true;
#	palmDetect = true;
#	horizontalScroll = true;
#      };

      libinput = {
        enable = true;
      };

      desktopManager = {
        gnome = {
          enable = false;
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
            /run/current-system/sw/bin/nm-applet &
            /run/current-system/sw/bin/nextcloud &
	    '';
	  }
	];
      };

      displayManager = {
        defaultSession = "custom+xmonad";

        startx = {
          enable = false;
        };

        gdm = {
          enable = false;
        };

        lightdm = {
          enable = true;

	  #greeters = {
          #  mini = {
          #    enable = true;
          #    user = "pthrr";
	  #    extraConfig = ''
	  #      [greeter]
	#	show-password-label = false
         #       show-sys-info = true
	#	[greeter-theme]
	#	background-color = "#000000"
	#	background-image = ""
	 #     '';
	  #  };
	 # };
        };
      };

      windowManager = {
        xmonad = {
          enable = true;
          enableContribAndExtras = true;
          extraPackages = hpkgs: [ hpkgs.xmonad hpkgs.xmonad-contrib hpkgs.xmonad-extras ];
        };
      };
    };
  };

  location = {
    latitude = 39.0;
    longitude = -77.0;
  };

  sound = {
    enable = true;

    mediaKeys = {
      enable = true;
    };
  };

  hardware = {
    enableRedistributableFirmware = true;

    pulseaudio = {
      enable = true;
      package = pkgs.pulseaudioFull;
    };

    bluetooth = {
      enable = true;
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
    defaultUserShell = "/run/current-system/sw/bin/bash";

    extraUsers = {
      pthrr = {
        description = "pthrr";
        isNormalUser = true;
	uid = 1000;
        extraGroups = [ "wheel" "networkmanager" ]; # Enable ‘sudo’ for the user.
      };
    };
  };
}
