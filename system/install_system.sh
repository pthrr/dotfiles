#!/usr/bin/env bash
set -euo pipefail

sudo dnf update -y
sudo dnf group install -y --skip-unavailable \
	c-development \
	container-management \
	development-tools \
	system-tools \
	virtualization
sudo dnf group install -y --skip-broken \
	swaywm \
	swaywm-extended
# KDE Plasma as fallback desktop
sudo dnf group install -y --skip-unavailable \
	kde-desktop
sudo dnf install -y \
	kde-connect \
	rofi-wayland sway-contrib kanshi blueman \
	sway-systemd swaylock swayidle waybar mako foot \
	syslinux \
	flatpak \
	clang llvm llvm-devel clang-tools-extra clang-analyzer clang-devel \
	libstdc++-static glibc-static libasan libubsan libtsan \
	arm-none-eabi-binutils-cs arm-none-eabi-gcc-cs-c++ arm-none-eabi-gcc-cs arm-none-eabi-newlib \
	sshfs openocd dfu-util \
	libxcrypt-compat ncurses-compat-libs \
	mock
# Remove dropped groups and packages from previous installs
sudo dnf group remove -y \
	admin-tools \
	desktop-accessibility \
	office \
	sound-and-video \
	libreoffice
sudo dnf remove -y \
	krdc qemu \
	stlink stlink-gui \
	cloud-utils \
	openssh-askpass \
	timeshift \
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

# System hardening (idempotent)
sudo mkdir -p /etc/systemd/journald.conf.d
sudo tee /etc/systemd/journald.conf.d/size.conf <<<$'[Journal]\nSystemMaxUse=500M'
sudo tee /etc/sysctl.d/99-swappiness.conf <<<"vm.swappiness=10"
sudo tee /etc/sysctl.d/99-panic.conf <<<"kernel.panic=10"
sudo sysctl --system

# Ensure rescue kernel exists for recovery
sudo dnf install -y kernel-core

# DNF safety settings (idempotent - updates or adds)
sudo sed -i '/^installonly_limit=/d; /^clean_requirements_on_remove=/d; /^protect_running_kernel=/d; /^keepcache=/d' /etc/dnf/dnf.conf
cat <<'EOF' | sudo tee -a /etc/dnf/dnf.conf
installonly_limit=3
clean_requirements_on_remove=True
protect_running_kernel=True
keepcache=False
EOF
