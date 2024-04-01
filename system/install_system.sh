#!/usr/bin/env bash
set -euo pipefail

# wget -O- https://www.virtualbox.org/download/oracle_vbox_2016.asc | sudo gpg --dearmor --yes --output /usr/share/keyrings/oracle-virtualbox-2016.gpg
# [[ ! $(grep "virtualbox" /etc/dnf/sources.list) ]] && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian bookworm contrib" | sudo tee -a /etc/dnf/sources.list
sudo dnf update -y
sudo dnf install -y \
    @kde-desktop \
    tlp tlp-rdw \
    pipx \
    flatpak \
    bash foot \
    sshpass sshfs openssh-askpass gnupg2 \
    kde-connect \
    dejavu-fonts-all fira-code-fonts jetbrains-mono-fonts \
    clang llvm clang-tools-extra clang-analyzer clang-devel \
    arm-none-eabi-binutils-cs arm-none-eabi-gcc-cs arm-none-eabi-newlib \
    stow inotify-tools \
    nodejs npm \
    strace xxd
sudo dnf remove -y \
    thunderbird firefox
sudo flatpak remote-add --if-not-exists \
    flathub https://flathub.org/repo/flathub.flatpakrepo
sudo flatpak install \
    jdownloader \
    com.github.d4nj1.tlpui
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
