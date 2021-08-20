sudo apt-get install -y sudo perl curl wget git neovim chromium nautilus exuberant-ctags stow
sudo apt-get install -y build-essential cmake automake g++-10 gcc-10 clang
sudo apt-get install -y libx11-dev libxinerama-dev libxext-dev
sudo apt-get install -y libxrandr-dev libxss-dev libxft-dev
sudo apt-get install -y xterm suckless-tools x11-xserver-utils
sudo apt-get install -y xarchiver xpdf xcircuit xlog xfig xbacklight xfe x11-apps
sudo apt-get install -y tmux ssh-askpass network-manager-gnome libssl-dev libicu-dev libgraphite2-dev libfreetype6-dev libfontconfig1-dev
sudo apt-get install -y exa ripgrep silversearcher-ag htop fzf opam lm-sensors
sudo apt-get install -y stalonetray pulseaudio-utils pavucontrol redshift
sudo apt-get install -y cabal-install && cabal update
cabal install xmonad xmonad-contrib xmobar yeganesh
curl https://sh.rustup.rs -sSf | sh
