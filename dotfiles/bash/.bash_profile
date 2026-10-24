# .bash_profile
# shellcheck shell=bash

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    # shellcheck disable=SC1090
    . ~/.bashrc
fi

# Keyboard config — only once per session
if [[ -z "$__LOGIN_DONE" ]]; then
    if command -v kwriteconfig6 &> /dev/null; then
        kwriteconfig6 --file kcminputrc --group Keyboard --key RepeatDelay 300
        kwriteconfig6 --file kcminputrc --group Keyboard --key RepeatRate 50
        kwriteconfig6 --file kxkbrc --group Layout --key Options "caps:none"
    elif command -v kwriteconfig5 &> /dev/null; then
        kwriteconfig5 --file kcminputrc --group Keyboard --key RepeatDelay 300
        kwriteconfig5 --file kcminputrc --group Keyboard --key RepeatRate 50
        kwriteconfig5 --file kxkbrc --group Layout --key Options "caps:none"
    fi
    export __LOGIN_DONE=1
fi
