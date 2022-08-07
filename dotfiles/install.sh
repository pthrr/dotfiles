#!/usr/bin/env bash
set -eu -o pipefail
cd "$(dirname "$0")"

# Bug: Stow cant properly use --dotfiles option on folders right now

if [ -z "${1+n}" ] ; then
    for d in */ ; do
        [ -L "${d%/}" ] && continue
        echo "Stowing $d .."
        stow --no-folding --target="$HOME" "$d"
    done
else
    echo "Stowing $1 .."
    stow --no-folding --target="$HOME" "$1"
fi
