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
    sway \
    swaylock \
    swayidle \
    swaybg \
    foot \
    xwayland \
    i3 \
    i3lock \
    i3status \
    rofi \
    xterm \
    xorg \
    xclip \
    xsel \
    python3-full \
    python3-pip \
    python3-dev \
    python3-i3ipc \
    python3-pynvim \
    automake \
    autoconf \
    build-essential \
    pkg-config \
    gcc \
    gcc-arm-none-eabi \
    libstdc++-arm-none-eabi-newlib \
    libnewlib-arm-none-eabi \
    cups \
    bash \
    strace \
    htop \
    tree \
    curl \
    wget \
    stow \
    xxd \
    inotify-tools \
    blueman \
    network-manager \
    gnupg2 \
    sshpass \
    sshfs \
    ssh-askpass \
    flatpak \
    pipx \
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
pipx uninstall-all
pipx install pre-commit
pipx install black
pipx install isort
pipx install mypy
pipx install ruff
pipx install rtcqs
pipx install conan
pipx install jupyterlab
