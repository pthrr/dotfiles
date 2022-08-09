#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
    build-essential \
    automake \
    autoconf \
    python3 \
    python3-pip \
    firmware-misc-nonfree \
    intel-microcode \
    adwaita-icon-theme \
    adwaita-qt \
    qt5ct
python3 -m pip install \
    i3ipc \
    mypy
