#!/usr/bin/env bash
set -euo pipefail

sudo apt update -y
sudo apt install -y \
    usrmerge \
    build-essential \
    gdb \
    valgrind \
    pkg-config \
    lv2-dev \
    libsndfile1-dev \
    libx11-dev \
    libcairo2-dev \
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
    spacefm \
    clang \
    clang-tidy \
    clang-tools \
    xterm \
    tmux \
    htop \
    xorg \
    i3 \
    i3lock \
    i3status \
    rofi \
    python3 \
    python3-pip \
    firmware-misc-nonfree \
    intel-microcode \
    adwaita-icon-theme \
    hicolor-icon-theme \
    adwaita-qt \
    qt5ct \
    steam
sudo apt autoremove -y
python3 -m pip install --upgrade pip
python3 -m pip install --upgrade --force-reinstall \
    i3ipc \
    mypy \
    isort \
    black \
    pylint
