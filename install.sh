sudo apt-get update
sudo apt-get install -y \
    strace \
    perl \
    tree \
    curl \
    wget \
    git \
    git-lfs \
    neovim \
    chromium \
    vlc \
    nautilus \
    universal-ctags \
    stow \
    fonts-firacode \
    fonts-dejavu \
    fonts-ubuntu \
    fonts-font-awesome \
    gnome-themes-standard \
    adwaita-icon-theme \
    adwaita-qt \
    qt5ct \
    mtp-tools \
    net-tools \
    build-essential \
    cmake \
    libtool \
    libstdc++-arm-none-eabi-newlib \
    gcc-arm-none-eabi \
    bzip2 \
    ninja-build \
    automake \
    autoconf \
    g++-10 \
    gcc-10 \
    clang \
    xserver-xorg-input-synaptics \
    laptop-mode-tools \
    firmware-misc-nonfree \
    intel-microcode \
    libx11-dev \
    libxinerama-dev \
    libxext-dev \
    libxrandr-dev \
    libxss-dev \
    libxft-dev \
    xterm \
    suckless-tools \
    x11-xserver-utils \
    xorg \
    xarchiver \
    xpdf \
    xcircuit \
    xlog \
    xfig \
    xbacklight \
    xfe \
    x11-apps
    tmux \
    ssh-askpass \
    network-manager-gnome \
    libssl-dev \
    libicu-dev \
    libgraphite2-dev \
    libfreetype6-dev \
    libfontconfig1-dev \
    exa \
    ripgrep \
    silversearcher-ag \
    htop \
    fzf \
    opam \
    lm-sensors \
    stalonetray \
    pulseaudio-utils \
    pavucontrol \
    redshift
    python3-pip \
    python3

cabal-install && cabal update
cabal install xmonad xmonad-contrib xmobar yeganesh
curl https://sh.rustup.rs -sSf | sh
