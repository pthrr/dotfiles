#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

./system/install_system.sh
./system/install_nix_single.sh
./system/install_nix_home_manager.sh
./dotfiles/install.sh nix/

rm ~/.bashrc ~/.profile
home-manager switch
