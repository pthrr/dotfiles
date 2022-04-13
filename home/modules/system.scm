(define-module (home modules system)
  #:use-module (gnu home services)
  #:use-module (gnu home services xdg))

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
