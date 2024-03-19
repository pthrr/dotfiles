#!/usr/bin/env bash
set -euo pipefail

wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg
[[ ! $(grep "virtualbox" /etc/apt/sources.list) ]] && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian bookworm contrib" | sudo tee -a /etc/apt/sources.list
sudo apt update -y
sudo apt purge -y \
    task-lxqt-desktop \
    task-gnome-desktop \
    task-gnome-flashback-desktop \
    task-xfce-desktop \
    task-mate-desktop \
    task-cinnamon-desktop \
    task-lxde-desktop
sudo apt install -y \
    task-desktop task-kde-desktop task-german task-laptop \
    firmware-misc-nonfree intel-microcode \
    fonts-firacode fonts-dejavu fonts-font-awesome fonts-ubuntu fonts-jetbrains-mono \
    libwlroots-dev wayland-utils wayland-protocols xwayland \
    python3-full python3-pip python3-dev python3-pynvim python3-i3ipc pipx \
    automake autoconf libtool pkg-config \
    build-essential \
    clang clang-tools clangd clang-format clang-tidy \
    gcc-arm-none-eabi libstdc++-arm-none-eabi-newlib libnewlib-arm-none-eabi \
    nodejs npm \
    acpi acpi-support acpid lm-sensors sysstat linux-cpupower \
    printer-driver-all cups hp-ppd openprinting-ppds system-config-printer \
    sway swaylock swayidle swaybg sway-notification-center \
    i3status \
    thermald tlp \
    bash foot \
    strace curl wget stow xxd \
    gnupg2 \
    inotify-tools \
    uidmap \
    pipewire pipewire-pulse wireplumber \
    playerctl brightnessctl \
    kdeconnect network-manager \
    sshpass sshfs ssh-askpass \
    flatpak \
    cppman \
    spacefm \
    virtualbox-7.0 \
    blueman libspa-0.2-bluetooth
sudo apt remove -y \
    firefox-esr thunderbird firefox
sudo apt purge -y \
    kdegames
sudo apt autoremove -y
sudo flatpak remote-add --if-not-exists \
    flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install \
    jdownloader
sudo npm i @informalsystems/quint -g
sudo npm i @informalsystems/quint-language-server -g
pipx uninstall-all
pipx install pre-commit
pipx install black
pipx install isort
pipx install mypy
pipx install ruff
pipx install rtcqs
pipx install conan
pipx install cmake
pipx install jupyterlab
pipx install tlp-ui
