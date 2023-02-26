#!/usr/bin/env bash
set -euo pipefail

sudo apt update -y
sudo apt remove -y \
    task-lxqt-desktop \
    task-gnome-desktop \
    task-gnome-flashback-desktop \
    task-kde-desktop \
    task-mate-desktop \
    task-cinnamon-desktop \
    task-lxde-desktop
sudo apt install -y \
    gnome-software-plugin-flatpak \
    nvidia-detect \
    qemu \
    task-xfce-desktop \
    task-desktop \
    task-german \
    task-laptop \
    cpufrequtils \
    cups \
    exfat-fuse \
    exfat-utils \
    lilv-utils \
    gnupg2 \
    chromium \
    xdotool \
    inotify-tools \
    xsel \
    jackd2 \
    qjackctl \
    pulseaudio-module-jack \
    alsa-utils \
    cargo \
    npm \
    kicad \
    golang-go \
    leiningen \
    clojure \
    python-is-python3 \
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
    flatpak
sudo apt remove -y \
    firefox-esr \
    firefox
sudo apt autoremove -y
sudo flatpak remote-add --if-not-exists \
    flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install \
    kdenlive \
    labplot \
    joplin \
    jdownloader
python3 -m pip install --upgrade pip
python3 -m pip install --upgrade --force-reinstall \
    i3ipc \
    pyright \
    isort \
    black \
    pylint \
    conan \
    rtcqs
sudo npm install -g npm n
sudo n stable
sudo npm install \
    fixjson
