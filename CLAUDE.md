# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository using Nix and Home Manager for declarative system configuration management. The setup is primarily designed for Fedora Linux with KDE Plasma desktop environment.

## Key Commands

### Installation and Setup
- `./install.sh` - Full system installation (runs system setup, Nix installation, and dotfiles linking)
- `task install` - Alternative installation using go-task
- `task switch` - Apply Home Manager configuration changes
- `home-manager switch --flake .` - Direct Home Manager switch

### System Management
- `./system/install_system.sh` - Install system packages via DNF and Flatpak
- `./system/install_nix_single.sh` - Install Nix package manager (single-user)
- `./system/install_nix_home_manager.sh` - Install Home Manager
- `./dotfiles/install.sh [target]` - Link dotfiles using stow (optionally specify single target)

### Development
- `task --list-all` - Show all available tasks
- Most development tools are managed through Nix packages in `dotfiles/nix/.config/home-manager/home.nix`

## Architecture

### Directory Structure
- `/dotfiles/` - Configuration files organized by application/tool
  - Each subdirectory represents a stow package (bash, git, nvim, etc.)
  - Files are symlinked to `$HOME` using GNU stow
- `/system/` - System-level installation scripts
- `flake.nix` - Nix flake configuration for Home Manager
- `Taskfile.yml` - Task runner configuration

### Configuration Management
The repository uses a hybrid approach:
1. **System packages**: Managed via DNF (system/install_system.sh) and Flatpak
2. **User packages**: Managed via Nix/Home Manager (dotfiles/nix/.config/home-manager/home.nix)
3. **Dotfiles**: Linked via GNU stow from dotfiles/ subdirectories

### Key Components
- **Home Manager**: Declarative user environment management via `home.nix`
- **Stow**: Symlink farm manager for dotfiles organization
- **Flake**: Nix flake provides reproducible Home Manager configurations
- **Git configuration**: Dynamic user name/email from `~/.config/git/{name,email}.txt` files

### Development Tools Integration
- Language servers and development tools installed via Nix
- Build tools: Bazel, CMake, Meson, Ninja, Make variants
- Compilers: GCC, Clang, Rust, Zig, Node.js, Deno, Bun
- Debugging: GDB, Valgrind, RR, hotspot
- Hardware development: ARM toolchain, OpenOCD, Yosys, Verilator

### Service Management
- sccache daemon configured as systemd user service with Redis backend
- Environment variables and PATH managed through Home Manager

## Important Notes

- Git user configuration is dynamically loaded from separate files for flexibility
- The setup assumes Fedora Linux but may work on other distributions with modifications
- Some Flatpak applications are installed system-wide vs user-space Nix packages
- WSL-specific configurations exist but may not be actively maintained