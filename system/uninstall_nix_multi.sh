#!/usr/bin/env bash
set -uo pipefail

sudo systemctl disable nix-daemon.socket
sudo systemctl disable nix-daemon.service
sudo systemctl stop|kill nix-daemon.socket
sudo systemctl stop|kill  nix-daemon.service

rm -rf ~/.nix-*
sudo rm /etc/profile.d/nix.sh

i=0
while [ $i -ne 32 ]
do
  i=$(($i+1))
  sudo userdel "nixbld${i}"
done 

sudo rm -rf /nix
sudo rm -rf /etc/nix
sudo groupdel nixbld
