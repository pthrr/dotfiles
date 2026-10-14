{
  lib,
  pkgs,
  ...
}:

{
  home.file = {
    ".bashrc".source = ../../dotfiles/bash/.bashrc;
    ".bash_profile".source = ../../dotfiles/bash/.bash_profile;
    "z.sh".source = ../../dotfiles/bash/z.sh;
    "git-prompt.sh".source = ../../dotfiles/bash/git-prompt.sh;
    "jj-prompt.sh".source = ../../dotfiles/bash/jj-prompt.sh;

    ".clang-tidy".source = ../../dotfiles/lang/.clang-tidy;
    ".clang-format".source = ../../dotfiles/lang/.clang-format;
    ".cmake-format.yaml".source = ../../dotfiles/lang/.cmake-format.yaml;
    ".config/stylua/stylua.toml".source = ../../dotfiles/lang/stylua.toml;
    ".bazelrc".source = ../../dotfiles/lang/.bazelrc;
    ".prettierrc".source = ../../dotfiles/lang/.prettierrc;

    ".cargo" = {
      source = ../../dotfiles/lang/.cargo;
      recursive = true;
    };
    ".ssh" = {
      source = ../../dotfiles/ssh/.ssh;
      recursive = true;
    };
    "bin" = {
      source = ../../dotfiles/misc/bin;
      recursive = true;
    };
    "Vorlagen/slides" = {
      source = ../../dotfiles/sent/Vorlagen/slides;
      recursive = true;
    };

    # ncurses on Fedora searches ~/.terminfo unconditionally, so symlinking
    # the entry there works regardless of TERMINFO_DIRS or a stale
    # __HM_SESS_VARS_SOURCED guard inherited from an older session.
    ".terminfo/x/xterm-ghostty".source = "${pkgs.ghostty.terminfo}/share/terminfo/x/xterm-ghostty";
  };

  xdg.configFile =
    let
      mkConfigDir = name: {
        source = ../../dotfiles/${name}/.config/${name};
        recursive = true;
      };
    in
    lib.genAttrs [
      "sway"
      "gdb"
      "foot"
      "monstar"
      "zathura"
      "git"
      "zellij"
      "vifm"
      "nvim"
      "calcurse"
      "meli"
    ] mkConfigDir
    // {
      "plasma-workspace/env" = {
        source = ../../dotfiles/nix/.config/plasma-workspace/env;
        recursive = true;
      };
      # waybar config is now part of sway package
      "waybar" = {
        source = ../../dotfiles/sway/.config/waybar;
        recursive = true;
      };
      "kanshi" = {
        source = ../../dotfiles/sway/.config/kanshi;
        recursive = true;
      };
      "swaylock" = {
        source = ../../dotfiles/sway/.config/swaylock;
        recursive = true;
      };
      "rofi" = {
        source = ../../dotfiles/sway/.config/rofi;
        recursive = true;
      };
      "mako" = {
        source = ../../dotfiles/sway/.config/mako;
        recursive = true;
      };
      # Bridge the host-side obsidian CLI to the Flatpak-confined socket.
      # %t expands to $XDG_RUNTIME_DIR; recreated each user session by
      # systemd-tmpfiles-setup.service since /run/user/UID is tmpfs.
      "user-tmpfiles.d/obsidian-cli-socket.conf".text = ''
        L+ %t/.obsidian-cli.sock - - - - %t/.flatpak/md.obsidian.Obsidian/xdg-run/.obsidian-cli.sock
      '';

      # ccache reads $XDG_CONFIG_HOME/ccache/ccache.conf before ~/.ccache.
      # Env var CCACHE_MAXSIZE (see default.nix) is a belt-and-braces fallback.
      "ccache/ccache.conf".text = ''
        max_size = 5G
      '';
    };
}
