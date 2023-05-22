#!/usr/bin/env bash
set -euo pipefail

wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg
[[ ! $(grep "virtualbox" /etc/apt/sources.list) ]] && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian bullseye contrib" | sudo tee -a /etc/apt/sources.list
sudo apt update -y
sudo apt remove -y \
    task-lxqt-desktop \
    task-gnome-flashback-desktop \
    task-xfce-desktop \
    task-mate-desktop \
    task-cinnamon-desktop \
    task-lxde-desktop
sudo apt install -y \
    virtualbox-7.0 \
    libxmu-dev \
    # gnome-themes-standard \
    openjdk-17-jdk-headless \
    openjdk-17-jre-headless \
    libcairomm-1.0-dev \
    libcairo2-dev \
    libopenblas-dev \
    hicolor-icon-theme \
    nvidia-detect \
    firmware-misc-nonfree \
    exfat-utils \
    qemu \
    chromium \
    # gnome-shell-extensions \
    # gnome-tweaks \
    sshpass \
    sshfs \
    ssh-askpass \
    # gnome-software-plugin-flatpak \
    task-kde-desktop \
    # task-gnome-desktop \
    task-desktop \
    task-german \
    task-laptop \
    cpufrequtils \
    cups \
    exfat-fuse \
    lilv-utils \
    gnupg2 \
    xdotool \
    inotify-tools \
    xsel \
    jackd2 \
    qjackctl \
    a2jmidid \
    pulseaudio-module-jack \
    alsa-utils \
    cargo \
    npm \
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
    clangd \
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
    python3-dev \
    intel-microcode \
    adwaita-icon-theme \
    adwaita-qt \
    # qt5ct \
    flatpak
sudo apt remove -y \
    firefox-esr \
    firefox
sudo apt purge -y \
    gnome-games
sudo apt autoremove -y
sudo flatpak remote-add --if-not-exists \
    flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install \
    kdenlive \
    labplot \
    jdownloader
python3 -m pip install --upgrade pip
python3 -m pip install --upgrade --force-reinstall \
    i3ipc \
    mypy \
    ruff \
    isort \
    black \
    conan \
    rofi-tmuxp \
    rtcqs
sudo npm install -g npm n
sudo n stable
sudo npm install \
    fixjson
