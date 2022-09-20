#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Bug: Stow cant properly use --dotfiles option on folders right now

if [ -z "${1+n}" ] ; then
    for d in */ ; do
        [ -L "${d%/}" ] && continue
        echo "Stowing $d .."
        stow --no-folding --target="$HOME" "${@:2}" "$d"
    done
else
    echo "Stowing $1 .."
    stow --no-folding --target="$HOME" "${@:2}" "$1"
fi
