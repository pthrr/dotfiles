(define-module (home modules x)
  #:use-module (gnu home services)
  #:use-module (gnu home services xdg))

(define x-packages
    (map specification->package
       (list "xbacklight"
             ;;"xlockmore"
             "xclip")))

(define-public x-services
               (list
               ;;  (service home-xdg-user-directories-service-type
               ;;           (home-xdg-user-directories-configuration
               ;;             (desktop     "$HOME/desktop")
               ;;             (documents   "$HOME/documents")
               ;;             (download    "$HOME/downloads")
               ;;             (music       "$HOME/music")
               ;;             (pictures    "$HOME/pictures")
               ;;             (publicshare "$HOME/public")
               ;;             (templates   "$HOME/templates")
               ;;             (videos      "$HOME/videos")))))
