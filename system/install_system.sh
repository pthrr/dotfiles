#!/usr/bin/env bash
set -euo pipefail

sudo dnf update -y
sudo dnf group remove -y \
	libreoffice
sudo dnf group install -y --skip-unavailable \
	admin-tools \
	c-development \
	container-management \
	desktop-accessibility \
	development-tools \
	office \
	sound-and-video \
	system-tools \
	virtualization
# sudo dnf group install -y --skip-unavailable \
# 	gnome-desktop \
# 	kde-desktop \
# 	swaywm \
# 	swaywm-extended
# TODO remove whats in groups already
sudo dnf install -y \
	kde-connect krdc \
	sway-systemd rofi sway-contrib \
	kdenlive \
	qemu \
	syslinux \
	pipx flatpak \
	bash foot \
	wget curl \
	sshpass sshfs openssh-askpass gnupg2 rclone \
	cloud-utils \
	dejavu-fonts-all fira-code-fonts jetbrains-mono-fonts \
	clang llvm llvm-devel clang-tools-extra clang-analyzer clang-devel \
	gcc-c++ libstdc++-static glibc-static libasan libubsan libtsan \
	arm-none-eabi-binutils-cs arm-none-eabi-gcc-cs-c++ arm-none-eabi-gcc-cs arm-none-eabi-newlib \
	libxcrypt-compat ncurses-compat-libs \
	stlink stlink-gui \
	minicom picocom openocd \
	gdb \
	libxkbcommon libX11 \
	stow inotify-tools \
	nodejs npm \
	strace xxd \
	mock
sudo dnf remove -y \
	thunderbird firefox
# Remove dunst after swaywm group installed (use mako instead)
sudo dnf remove -y \
	dunst
# Disable offline updates - only allow manual online updates
sudo systemctl mask \
	packagekit-offline-update.service \
	system-update.target \
	dnf5-offline-transaction.service \
	dnf-system-upgrade.service
# Boot to console login, start DE manually
sudo systemctl set-default multi-user.target
sudo flatpak remote-add --if-not-exists \
	flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install -y \
	org.libreoffice.LibreOffice \
	it.fabiodistasio.AntaresSQL \
	com.bitwig.BitwigStudio \
	net.lutris.Lutris \
	org.mozilla.firefox \
	io.github.gtkwave.GTKWave \
	dev.zed.Zed \
	io.github.ra3xdh.qucs_s \
	org.inkscape.Inkscape \
	org.gnucash.GnuCash \
	com.usebottles.bottles \
	org.otfried.Ipe \
	com.jgraph.drawio.desktop \
	org.mozilla.Thunderbird \
	org.torproject.torbrowser-launcher \
	md.obsidian.Obsidian \
	org.zotero.Zotero \
	org.jdownloader.JDownloader \
	org.kde.labplot \
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
	org.gnome.meld \
	org.zealdocs.Zeal \
	com.prusa3d.PrusaSlicer \
	org.freecad.FreeCAD \
	org.openscad.OpenSCAD \
	org.kicad.KiCad \
	org.gimp.GIMP \
	org.sqlitebrowser.sqlitebrowser
sudo npm i @informalsystems/quint -g
sudo npm i @informalsystems/quint-language-server -g
sudo npm i bash-language-server -g
pipx install pre-commit
pipx install black
pipx install isort
pipx install ty
pipx install ruff
pipx install uv
pipx install jupyterlab
pipx install cppman
pipx install grip
