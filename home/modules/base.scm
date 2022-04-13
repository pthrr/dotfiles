(define-module (home modules base)
  #:use-module (gnu home services)
  #:use-module (gnu home services xdg))

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

(define-public zsh-services
  (list
   (service home-zsh-service-type
            (home-zsh-configuration
             (xdg-flavor? #t)
             (environment-variables
              '(("EDITOR" . "\"emacsclient -a ''\"")
                ("XCURSOR_THEME" . "Nordzy-cursors")
                ("GUIX_LOCPATH" . "$HOME/.guix-profile/lib/locale")
                ("GUIX_EXTRA_PROFILES" . "$HOME/.guix-extra-profiles")
                ("SSL_CERT_DIR" . "$HOME/.guix-home/profile/etc/ssl/certs")
                ("SSL_CERT_FILE" . "$HOME/.guix-home/profile/etc/ssl/certs/ca-certificates.crt")
                ("GIT_SSL_CAINFO" . "$SSL_CERT_FILE")
                ("GEM_PATH" . "$HOME/.local/share/gem")
                ("_JAVA_AWT_WM_NONREPARENTING" . "1")))
             (zshrc
              (list
               (local-file "../files/zshrc")))))
   (simple-service 'direnvrc
                   home-files-service-type
                   `(("config/direnv/direnvrc"
                      ,(local-file "../files/direnvrc"))))
   (simple-service 'login-variables
                   home-environment-variables-service-type
                   `(;; ("XDG_DATA_DIRS" . "$XDG_DATA_DIRS:/usr/local/share/:/usr/share/")
                     ;; ("XDG_CONFIG_DIRS" . "$XDG_CONFIG_DIRS:/etc/xdg/")
                     ;; ("XDG_CONFIG_DIRS" . "$HOME/.guix-home/profile/etc/xdg:$XDG_CONFIG_DIRS")
                     ;; ("GUILE_LOAD_PATH" . "$XDG_CONFIG_HOME/guix/current/share/guile/site/3.0:$GUILE_LOAD_PATH")
                     ;; ("GUILE_LOAD_COMPILED_PATH" . "$XDG_CONFIG_HOME/guix/current/lib/guile/3.0/site-ccache:$GUILE_LOAD_COMPILED_PATH")
                     ("PATH" . "$HOME/.local/bin/:$PATH")))))
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

