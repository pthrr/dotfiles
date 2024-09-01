#!/usr/bin/env bash
set -euo pipefail

sudo dnf update -y
sudo dnf install -y \
    @virtualization \
    @kde-desktop kde-connect \
    syslinux \
    qemu \
    pipx flatpak \
    bash foot \
    wget curl \
    sshpass sshfs openssh-askpass gnupg2 \
    cloud-utils \
    dejavu-fonts-all fira-code-fonts jetbrains-mono-fonts \
    clang llvm llvm-devel clang-tools-extra clang-analyzer clang-devel \
    gcc-c++ libstdc++-static glibc-static libasan libubsan libtsan \
    arm-none-eabi-binutils-cs arm-none-eabi-gcc-cs-c++ arm-none-eabi-gcc-cs arm-none-eabi-newlib \
    libxcrypt-compat ncurses-compat-libs \
    stlink stlink-gui \
    minicom picocom openocd \
    gdb rust-gdb \
    libxkbcommon libX11 \
    stow inotify-tools \
    nodejs npm \
    strace xxd \
    mock
sudo dnf remove -y \
    thunderbird firefox
sudo flatpak remote-add --if-not-exists \
    flathub https://flathub.org/repo/flathub.flatpakrepo
    # org.mozilla.firefox \
    # org.mozilla.Thunderbird \
sudo flatpak install \
    org.torproject.torbrowser-launcher \
    md.obsidian.Obsidian \
    org.zotero.Zotero \
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
    org.keepassxc.KeePassXC \
    io.github.shiftey.Desktop \
    org.openmw.OpenMW \
    org.olivevideoeditor.Olive \
    org.gnome.meld \
    org.zealdocs.Zeal \
    com.prusa3d.PrusaSlicer \
    org.freecadweb.FreeCAD \
    org.openscad.OpenSCAD \
    org.kicad.KiCad \
    org.gimp.GIMP \
    net.lutris.Lutris \
    org.sqlitebrowser.sqlitebrowser \
    net.runelite.RuneLite \
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
pipx install grip
