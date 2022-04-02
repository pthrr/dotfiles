#!/usr/bin/env bash
set -eu -o pipefail
cd "$(dirname "$0")"

# Bug: Stow cant properly use --dotfiles option on folders right now

# install only first argument
if [ -d "${1+null}" ] ; then
    echo "Stowing $1 .."
    stow --no-folding --dotfiles --target="$HOME" "$1"
fi

# giving no argument will install all in current folder
if [ -z "${1+null}" ] ; then
    for d in */ ; do
        [ -L "${d%/}" ] && continue
        echo "Stowing $d .."
        stow --no-folding --dotfiles --target="$HOME" "$d"
    done
fi
