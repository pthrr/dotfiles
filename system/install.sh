#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
    #libtool \
    build-essential \
    automake \
    autoconf \
    #perl \
    python3 \
    python3-pip \
    #python3-venv \
    #python3-mypy \
    #pulseaudio \
    #pulseaudio-utils \
    #xorg \
    #x11-apps \
    #x11-xserver-utils \
    #software-properties-common \
    #firmware-misc-nonfree \
    #intel-microcode \
    #laptop-mode-tools \
    #xserver-xorg-input-synaptics \
    #lm-sensors \
    #adwaita-icon-theme \
    #adwaita-qt \
    #qt5ct \
    #mtp-tools \
    #xcircuit
#source ~/.profile
pip3 install -r requirements.txt
