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

if [ -d "$HOME/.cargo/bin" ] ; then
    export PATH="$HOME/.cargo/bin:$PATH"
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

if [ -d "$HOME/.nix-profile/lib/lv2" ] ; then
    export LV2_PATH="$HOME/.nix-profile/lib/lv2:$LV2_PATH"
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
    # export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
    export NIX_PATH="$HOME/.nix-defexpr/channels:$NIX_PATH"
    export XDG_DATA_DIRS="$HOME/.nix-profile/share:$XDG_DATA_DIRS"
fi

if [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ] ; then
    . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi

# include pyenv
if [ ! -f "$(which pyenv)" ] ; then
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
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

if [ ! -d  "$HOME/fun" ] ; then
    mkdir "$HOME/fun"
fi

if [ ! -d  "$HOME/analysis" ] ; then
    mkdir "$HOME/analysis"
fi

if [ ! -d  "$HOME/business" ] ; then
    mkdir "$HOME/business"
fi

if [ ! -d  "$HOME/job" ] ; then
    mkdir "$HOME/job"
fi

if [ ! -d  "$HOME/Drive" ] ; then
    mkdir "$HOME/Drive"
fi

if [ ! -d  "$HOME/Dokumente/notes" ] ; then
    mkdir -p "$HOME/Dokumente/notes"
fi

if [ ! -d  "$HOME/Dokumente/notebooks" ] ; then
    mkdir -p "$HOME/Dokumente/notebooks"
fi

if [ ! -d  "$HOME/Dokumente/letters" ] ; then
    mkdir -p "$HOME/Dokumente/letters"
fi

if [ ! -d  "$HOME/Vorlagen/slides" ] ; then
    mkdir -p "$HOME/Vorlagen/slides"
fi

if [ ! -d  "$HOME/Vorlagen/snippets" ] ; then
    mkdir -p "$HOME/Vorlagen/snippets"
fi

if [ ! -d  "$HOME/Audio" ] ; then
    mkdir -p "$HOME/Audio"
fi

export LANG=de_DE.UTF-8
export LC_ALL=C.UTF-8
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
export BROWSER='firefox'
export MAILCLIENT='thunderbird'
export TERMINAL='xterm'
export PDFVIEWER='zathura'
export IMAGEVIEWER='nsxiv'
export MEDIAPLAYER='vlc'
export FILEMANAGER='spacefm'
export FZF_DEFAULT_COMMAND='rg --files'
export FZF_DEFAULT_OPTS='-m --height 50% --border'
export LESS='-r'
export NO_AT_BRIDGE=1
export DO_NOT_TRACK=1
export _JAVA_AWT_WM_NONREPARENTING=1
export MC_XDG_OPEN="$HOME/bin/xdg"
export MC_SKIN="$HOME/.config/mc/solarized.ini"
