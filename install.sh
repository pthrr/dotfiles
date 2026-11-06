#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# The home configuration and the Taskfile read the nixbits checkout.
git submodule update --init

./system/install_system.sh
./system/install_nix_single.sh
./system/install_nix_home_manager.sh
./dotfiles/install.sh nix/

rm -f ~/.bashrc ~/.profile
nix develop -c home-manager switch --flake .#pthrr@x86_64-linux
