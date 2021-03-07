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

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    export PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    export PATH="$HOME/.local/bin:$PATH"
fi

# include Cabal
if [ -d "$HOME/.cabal/bin" ] ; then
    export PATH="$HOME/.cabal/bin:$PATH"
fi

export PATH="/home/ps/.pyenv/bin:$PATH"
export WORKON_HOME=~/.venvs
export PIPENV_VENV_IN_PROJECT=1
export LC_ALL='en_US.UTF-8'
export LANG='de_DE.UTF-8'
export EDITOR='nvim'
export SUDO_ASKPASS='/usr/bin/ssh-askpass'
export _JAVA_AWT_WM_NONREPARENTING=1
source "$HOME/.cargo/env"
