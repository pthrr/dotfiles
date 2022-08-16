#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
    build-essential \
    automake \
    autoconf \
    strace \
    tree \
    curl \
    wget \
    git \
    git-lfs \
    stow \
    fonts-firacode \
    fonts-dejavu \
    fonts-font-awesome \
    fonts-ubuntu \
    hicolor-icon-theme \
    spacefm \
    make \
    clang \
    clang-tools \
    g++-10 \
    gcc-10 \
    xterm \
    tmux \
    htop \
    xorg \
    i3 \
    i3status \
    rofi \
    python3 \
    python3-pip \
    firmware-misc-nonfree \
    intel-microcode \
    adwaita-icon-theme \
    adwaita-qt \
    qt5ct
python3 -m pip install pip --upgrade
python3 -m pip install --upgrade --force-reinstall \
    i3ipc
