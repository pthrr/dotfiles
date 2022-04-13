(define-module (home modules i3)
  #:use-module (gnu home services)
  #:use-module (gnu home services xdg))

(define i3-packages
  (map specification->package
       (list "i3-wm"
             "i3lock"
             "yeganesh"
             "i3status")))

(define-public desktop-services
               (list
                 (service home-bspwm-service-type
                          (home-bspwm-configuration
                            (bspwmrc (list
                                       (local-file "../files/bspwmrc")))))
                 (simple-service 'gtk-config
                                 home-files-service-type
                                 `(("config/gtk-3.0/settings.ini"
                                    ,(local-file "../files/gtk3.ini"))
                                   ("config/gtk-3.0/gtk.css"
                                    ,(local-file "../files/gtk3.css"))))))
