#!/bin/sh

. "$HOME/.xsessionrc"

session=${1:-i3}

case $session in
gnome|gnome-session)
    exec gnome-session
    ;;
xfce|xfce4|startxfce4)
    exec startxfce4
    ;;
i3wm|i3)
    exec i3
    ;;
*)
    exec xwm
    ;;
esac
