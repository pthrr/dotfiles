#!/usr/bin/env bash
set -euo pipefail

sudo install -d -m755 -o $(id -u) -g $(id -g) /nix
curl -L https://nixos.org/nix/install | sh
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
nix-env -i hello
which hello
hello
nix profile add -L github:garnix-io/garn
