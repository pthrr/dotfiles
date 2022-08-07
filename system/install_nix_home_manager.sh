#!/usr/bin/env bash
set -euo pipefail

nix-channel --add https://github.com/nix-community/home-manager/archive/release-22.05.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install
