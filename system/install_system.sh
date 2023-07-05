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
    task-desktop \
    task-german \
    task-laptop \
    task-kde-desktop \
    firmware-misc-nonfree \
    intel-microcode \
    fonts-firacode \
    fonts-dejavu \
    fonts-font-awesome \
    fonts-ubuntu \
    i3 \
    i3lock \
    i3status \
    python3-i3ipc \
    rofi \
    bash \
    xterm \
    tmux \
    xorg \
    automake \
    autoconf \
    build-essential \
    pkg-config \
    strace \
    htop \
    tree \
    curl \
    wget \
    stow \
    xclip \
    xsel \
    sshpass \
    sshfs \
    ssh-askpass \
    cups \
    gnupg2 \
    xxd \
    nvidia-detect \
    inotify-tools \
    xdotool \
    virtualbox-7.0 \
    chromium \
    flatpak \
    kdenlive \
    labplot \
    spacefm \
    qemu \
    lilv-utils \
    lv2-dev \
    jackd2 \
    qjackctl \
    a2jmidid \
    pulseaudio-module-jack \
    alsa-utils \
    python3-full \
    python3-pip \
    python3-dev \
    pipx \
    python3-pynvim \
    cppman \
    openjdk-17-jdk-headless \
    openjdk-17-jre-headless \
    cargo \
    npm \
    golang-go \
    leiningen \
    clojure \
    gdb \
    gcc \
    gcc-arm-none-eabi \
    libnewlib-arm-none-eabi \
    clang \
    clangd \
    clang-tidy \
    clang-tools \
    valgrind \
    libxmu-dev \
    libcairomm-1.0-dev \
    libcairo2-dev \
    libopenblas-dev \
    libsndfile1-dev \
    libx11-dev \
    libcairo2-dev
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
pipx install --force pre-commit
pipx install --force black
pipx install --force isort
pipx install --force mypy
pipx install --force ruff
pipx install --force rofi-tmuxp
pipx install --force rtcqs
pipx upgrade-all
sudo npm install -g npm n
sudo n stable
sudo npm install \
    fixjson
