#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.nix-profile/bin:$PATH"

# Home-manager comes from the dotfiles flake (see the home dev-shell package);
# no channel, no `nix-shell '<home-manager>' -A install` anymore.
nix profile add github:nix-community/nixGL#nixGLIntel
