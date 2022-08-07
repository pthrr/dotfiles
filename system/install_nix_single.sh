sudo install -d -m755 -o $(id -u) -g $(id -g) /nix
curl -L https://nixos.org/nix/install | sh
nix-env -i hello
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
which hello
hello
