#!/usr/bin/env bash
set -euo pipefail

# On atomic: /nix is bind-mounted from /var/nix via systemd (see Containerfile)
# On non-atomic: create /nix manually
if [ ! -d /nix ]; then
  sudo install -d -m755 -o "$(id -u)" -g "$(id -g)" /nix
fi
sudo chown "$(id -u):$(id -g)" /nix
curl -L https://nixos.org/nix/install | sh -s -- --no-daemon
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
nix-env -i hello
which hello
hello
