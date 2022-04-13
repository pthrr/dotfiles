(define-module (home modules dev)
  #:use-module (gnu home services)
  #:use-module (gnu home services xdg))

(define dev-packages
  (map specification->package
       (list "scons"
             "valgrind"
             ;;"gdb"
             ;;"clang-toolchain"
             ;;"avr-toolchain"
             ;;"arm-none-eabi-toolchain"
             ;;"gfortran-toolchain"
             ;;"gcc-toolchain"
             ;;"rust"
             "ninja"
             "universal-ctags"
             "lv2"
             "git"
             "git-lfs"
             "neovim"
             "cmake")))

(define-public emacs-services
  (list
   (simple-service 'emacs-init
                   home-files-service-type
                   `(("config/emacs/early-init.el"
                      ,(local-file "../files/early-init.el"))
                     ("config/emacs/init.el"
                      ,(local-file "../files/init.el"))))
