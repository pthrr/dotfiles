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
  (gnu home services shells)

  #:use-module (home modules base)
  #:use-module (home modules xfce)
  #:use-module (home modules i3)
  #:use-module (home modules x)
  #:use-module (home modules system)
  #:use-module (home modules dev)
  #:use-module (home modules tools))

(home-environment
  (packages
    `(,@base-packages
       ,@xfce-packages
       ,@i3-packages
       ,@x-packages
       ,@system-packages
       ,@dev-packages
       ,@tools-packages))

  (services
    `(,@base-services
       ,@xfce-services
       ,@i3-services
       ,@x-services
       ,@system-services
       ,@dev-services
       ,@tools-services)))
