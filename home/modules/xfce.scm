(define-module (home modules xfce)
  #:use-module (gnu home services)
  #:use-module (gnu home services xdg))

(define xfce-packages
  (map specification->package
       '()))

