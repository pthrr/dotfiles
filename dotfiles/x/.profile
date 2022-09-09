# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
    fi
fi

# set PATH so it includes bin if it exists
if [ -d "/usr/sbin" ] ; then
    export PATH="/usr/sbin:$PATH"
fi

# set PATH so it includes bin if it exists
if [ -d "/sbin" ] && [ ! -L "/sbin" ] ; then
    export PATH="/sbin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    export PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# include Rust environment
if [ -f "$HOME/.cargo/env" ] ; then
    . "$HOME/.cargo/env"
fi

# include Haskell environment
if [ -d "$HOME/.cabal/bin" ] ; then
    export PATH="$HOME/.cabal/bin:$PATH"
fi

# include OCaml environment
if [ -f "$(which opam)" ] ; then
    eval $(opam config env)
fi

# include LV2 plugins
if [ -d "$HOME/.lv2" ] ; then
    export LV2_PATH="$HOME/.lv2:$LV2_PATH"
fi

# include Guix environment
if [ -f "$HOME/.guix-profile/etc/profile" ] ; then
    #export GUIX_LOCPATH="$HOME/.guix-profile/lib/locale"
    #export GUIX_PROFILE="$HOME/.guix-profile"
    #. "$GUIX_PROFILE/etc/profile"
    export XDG_DATA_DIRS="$XDG_DATA_DIRS:/usr/share/gnome:/usr/local/share:/usr/share"
fi

# include Nix environment
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ] ; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
fi

if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ] ; then
    # shell is not managed by home manager
    . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi

# create standard dirs
if [ ! -d  "$HOME/tmp" ] ; then
    mkdir "$HOME/tmp"
fi

if [ ! -d  "$HOME/bin" ] ; then
    mkdir "$HOME/bin"
fi

if [ ! -d  "$HOME/opt" ] ; then
    mkdir "$HOME/opt"
fi

if [ ! -d  "$HOME/mail/personal" ] ; then
    mkdir -p "$HOME/mail/personal"
fi

if [ ! -d  "$HOME/mail/public" ] ; then
    mkdir -p "$HOME/mail/public"
fi

export LANG=de_DE.UTF-8
export LC_ALL=de_DE.UTF-8
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_DESKTOP_DIR="$HOME/Schreibtisch"
export XDG_DOCUMENTS_DIR="$HOME/Dokumente"
export XDG_DOWNLOAD_DIR="$HOME/Downloads"
export XDG_MUSIC_DIR="$HOME/Musik"
export XDG_AUDIO_DIR="$HOME/Audio"
export XDG_PICTURES_DIR="$HOME/Bilder"
export XDG_PUBLICSHARE_DIR="$HOME/Öffentlich"
export XDG_TEMPLATES_DIR="$HOME/Vorlagen"
export XDG_VIDEOS_DIR="$HOME/Video"
export SHELL='bash'
export EDITOR='nvim'
export BROWSER='librewolf'
export TERMINAL='xterm'
export PDFVIEWER='zathura'
export MEDIAPLAYER='vlc'
export MAILPATH="$HOME/mail/personal/Inbox:$HOME/mail/public/Inbox"
export MAILCHECK=300
export FZF_DEFAULT_COMMAND='rg --files'
export FZF_DEFAULT_OPTS='-m --height 50% --border'
export LESS='-r'
export GNOME_ACCESSIBILITY=0
export QT_ACCESSIBILITY=0
export NO_AT_BRIDGE=1
export QT_LINUX_ACCESSIBILITY_ALWAYS_ON=0
export _JAVA_AWT_WM_NONREPARENTING=1
export AWT_TOOLKIT=XToolkit
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export ANDROID_HOME=/usr/lib/android-sdk
export ANDROID_SDK=/usr/lib/android-sdk
export ANDROID_NDK_HOME=/usr/lib/android-ndk
export ANDROID_NDK=/usr/lib/android-ndk
export GTK_THEME=Adwaita:dark
export GTK2_RC_FILES="/usr/share/themes/Adwaita-dark/gtk-2.0/gtkrc"
export QT_QPA_PLATFORMTHEME=qt5ct
