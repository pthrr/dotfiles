(define-module (home modules tools)
  #:use-module (gnu home services)
  #:use-module (gnu home services xdg))

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

