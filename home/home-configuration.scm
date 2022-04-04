;; This "home-environment" file can be passed to 'guix home reconfigure'
;; to reproduce the content of your profile.  This is "symbolic": it only
;; specifies package names.  To reproduce the exact same profile, you also
;; need to capture the channels being used, as returned by "guix describe".
;; See the "Replicating Guix" section in the manual.

(use-modules
  (gnu home)
  (gnu packages)
  (gnu services)
  (guix gexp)
  (gnu home services shells))

(define base-packages
  (map specification->package
       (list "exa"
             "dos2unix"
             "ripgrep"
             "stow"
             "jq"
             "netcat-openbsd"
             "openssl"
             "openssh"
             "p7zip"
             "bzip2"
             "unzip"
             "curl"
             "bat"
             "htop"
             "xxd"
             "tmux"
             "fzf"
             "rsync"
             "curl"
             "wget"
             "tree"
             "unrar"
             "bsdtar"
             "strace"
             "dtrace"
             "fontconfig"
             "font-fira-code"
             "font-dejavu"
             "font-ubuntu"
             "font-awesome"
             "glibc-locales"
             "glibc-utf8-locales"
             "nss-certs")))

(define xfce-packages
  (map specification->package
       (list "xfce"
             "xfce4-session"
             "xfconf"
             "xfce4-battery-plugin"
             "xfce4-volumed-pulse"
             "xfce4-notifyd")))

(define awesome-packages
  (map specification->package
       (list "awesome")))

(define x-packages
  (map specification->package
       (list "xbacklight"
             "xlockmore"
             "xclip")))

(define system-packages
  (map specification->package
       (list "pavucontrol"
             "xarchiver"
             "neofetch"
             "net-tools"
             "network-manager"
             "network-manager-applet"
             "blueman"
             "bluez"
             "alsa-utils"
             "redshift")))

(define dev-packages
  (map specification->package
       (list "scons"
             "valgrind"
             "gdb"
             "clang-toolchain"
             "avr-toolchain"
             "arm-none-eabi-toolchain"
             "rust"
             "ninja"
             "universal-ctags"
             "lv2"
             "git"
             "git-lfs"
             "neovim"
             "cmake")))

(define tools-packages
  (map specification->package
       (list "vlc"
             "xfig"
             "keepassxc"
             "ardour"
             "zathura"
             "zathura-djvu"
             "zathura-pdf-poppler"
             "zathura-ps"
             "tectonic"
             "weechat"
             "xnec2c")))

(home-environment
  (packages
    `(,@base-packages
       ,@system-packages
       ,@dev-packages
       ;;,@xfce-packages
       ,@x-packages
       ,@cwm-packages
       ,@tools-packages))

  (services
    (list (service
            home-bash-service-type
            (home-bash-configuration
              (aliases
                '((".." . "cd ../")
                  ("..." . "cd ../../")
                  ("...." . "cd ../../../")
                  ("....." . "cd ../../../../")
                  ("cat" . "bat")
                  ("cl" . "clear")
                  ("com"
                   .
                   "picocom -b 115200 --echo --omap=crcrlf")
                  ("cp" . "cp -iv")
                  ("g" . "git")
                  ("grep" . "rg")
                  ("jupnote"
                   .
                   "chromium http://localhost:8888/; jupyter-notebook --no-browser --notebook-dir=~/Documents/notebooks")
                  ("ls" . "exa")
                  ("mirror"
                   .
                   "wget --mirror --convert-links --adjust-extension --page-requisites --no-parent")
                  ("mkdir" . "mkdir -pv")
                  ("mv" . "mv -iv")
                  ("ports" . "sudo netstat -pln")
                  ("procs" . "ps -aux")
                  ("pwgen"
                   .
                   "python -c '\\''import secrets,pyperclip;pw=secrets.token_urlsafe(32);pyperclip.copy(pw);print(pw)'\\''")
                  ("py" . "python3")
                  ("rm" . "rm -Iv")
                  ("top" . "htop")
                  ("un7z" . "7z x")
                  ("untar" . "tar vxf")
                  ("vi" . "nvim")
                  ("xdg" . "xdg-open")
                  ("z" . "_z 2>&1")))
              (bashrc
                (list (local-file
                        "/home/pthrr/src/guix-config/.bashrc"
                        "bashrc")))
              (bash-profile
                (list (local-file
                        "/home/crab/src/guix-config/.bash_profile"
                        "bash_profile")))))))

    (simple-service 'application-configs
      home-files-service-type
        (list `("ssh/id_rsa"
		,(local-file
		   "/home/crab/src/guix-config/.ssh/id_rsa"
		   "id_rsa"))
	      `("ssh/id_rsa.pub"
		,(local-file
		   "/home/crab/src/guix-config/.ssh/id_rsa.pub"
		   "id_rsa.pub"))
	      `("config/git/config"
		,(local-file
		   "/home/crab/src/guix-config/config/git/config"
		   "config"))
	      `("cwmrc"
		,(local-file
		   "/home/crab/src/guix-config/config/cwm/cwmrc"
		   "cwmrc"))
	      `("config/hikari/hikari.conf"
                ,(local-file
                   "/home/crab/src/guix-config/config/hikari/hikari.conf"
                   "hikari.conf"))
	      `("config/alacritty/alacritty.yml"
		,(local-file
		   "/home/crab/src/guix-config/config/alacritty/alacritty.yml"
		   "alacritty.yml"))))

  )
