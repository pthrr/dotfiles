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
    xxd
    yakuake \
    xclip \
    virtualbox-7.0 \
    libxmu-dev \
    openjdk-17-jdk-headless \
    openjdk-17-jre-headless \
    libcairomm-1.0-dev \
    libcairo2-dev \
    libopenblas-dev \
    nvidia-detect \
    firmware-misc-nonfree \
    exfat-utils \
    qemu \
    chromium \
    sshpass \
    sshfs \
    ssh-askpass \
    task-kde-desktop \
    kdenlive \
    labplot \
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
    gcc \
    gcc-arm-none-eabi \
    libnewlib-arm-none-eabi \
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
    flatpak
sudo apt remove -y \
    firefox-esr \
    firefox
sudo apt purge -y \
    kdegames
sudo apt autoremove -y
sudo flatpak remote-add --if-not-exists \
    flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install \
    jdownloader
python3 -m pip install --upgrade pip
python3 -m pip install --upgrade --force-reinstall \
    cppman \
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
