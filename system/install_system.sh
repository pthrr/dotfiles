#!/usr/bin/env bash
set -euo pipefail

# wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg
# [[ ! $(grep "virtualbox" /etc/dnf/sources.list) ]] && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian bookworm contrib" | sudo tee -a /etc/dnf/sources.list
sudo dnf update -y
sudo dnf install -y \
    @kde-desktop kde-connect \
    pipx flatpak \
    bash foot \
    sshpass sshfs openssh-askpass gnupg2 \
    dejavu-fonts-all fira-code-fonts jetbrains-mono-fonts \
    clang llvm llvm-devel clang-tools-extra clang-analyzer clang-devel \
    gcc-c++ libstdc++-static glibc-static \
    arm-none-eabi-binutils-cs arm-none-eabi-gcc-cs arm-none-eabi-newlib \
    stlink stlink-gui arm-none-eabi-gcc-cs-c++ \
    libxkbcommon libX11 \
    stow inotify-tools \
    nodejs npm \
    strace xxd
sudo dnf remove -y \
    thunderbird firefox
sudo flatpak remote-add --if-not-exists \
    flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install \
    org.jdownloader.JDownloader \
    org.kde.labplot2 \
    fm.reaper.Reaper \
    net.ankiweb.Anki \
    engineer.atlas.Nyxt \
    org.videolan.VLC \
    net.cozic.joplin_desktop \
    com.valvesoftware.Steam \
    org.telegram.desktop \
    com.discordapp.Discord \
    com.spotify.Client \
    im.riot.Riot \
    org.freecadweb.FreeCAD \
    org.keepassxc.KeePassXC \
    io.github.shiftey.Desktop \
    org.openmw.OpenMW \
    org.gnome.meld \
    org.olivevideoeditor.Olive \
    org.kde.yakuake \
    com.prusa3d.PrusaSlicer \
    org.zealdocs.Zeal \
    org.openscad.OpenSCAD \
    org.kicad.KiCad \
    org.gnucash.GnuCash
sudo npm i @informalsystems/quint -g
sudo npm i @informalsystems/quint-language-server -g
pipx uninstall-all
pipx install pre-commit
pipx install black
pipx install isort
pipx install mypy
pipx install ruff
pipx install conan
pipx install cmake
pipx install jupyterlab
pipx install cppman
