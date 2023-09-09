#!/usr/bin/env bash
set -euo pipefail

wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg
[[ ! $(grep "virtualbox" /etc/apt/sources.list) ]] && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian bullseye contrib" | sudo tee -a /etc/apt/sources.list
sudo apt update -y
sudo apt purge -y \
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
    fonts-jetbrains-mono \
    sway
    swaylock
    swayidle
    swaybg
    rofi
    i3
    i3lock
    i3status
    python3-i3ipc \
    xterm \
    xorg \
    foot \
    xwayland \
    cups \
    bash \
    tmux \
    gcc \
    npm \
    python3-full \
    python3-pip \
    python3-dev \
    python3-pynvim \
    automake \
    autoconf \
    build-essential \
    pkg-config \
    gcc-arm-none-eabi \
    libstdc++-arm-none-eabi-newlib \
    libnewlib-arm-none-eabi \
    strace \
    htop \
    tree \
    curl \
    wget \
    stow \
    xxd \
    xclip \
    xsel \
    inotify-tools \
    gnupg2 \
    sshpass \
    sshfs \
    ssh-askpass \
    flatpak \
    chromium \
    spacefm \
    cppman \
    libcairomm-1.0-dev \
    libx11-dev \
    libcairo2-dev \
    virtualbox-7.0
sudo apt remove -y \
    firefox-esr \
    thunderbird \
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
pipx install --force conan
sudo npm install -g npm n
sudo n stable
sudo npm install \
    fixjson
