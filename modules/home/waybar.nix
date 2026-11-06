{ ... }:

# Waybar as a user service instead of sway's `bar { swaybar_command waybar }`:
# sway never respawns a bar that died, and waybar's tray crashes inside
# libdbusmenu when an app rebuilds its menu while a property reply is still
# pending. sway-systemd's session.sh starts graphical-session.target after
# importing WAYLAND_DISPLAY and SWAYSOCK, so the bar finds the compositor.
# Fedora's binary, the one sway ran before, keeps the host GTK stack.
{
  systemd.user.services.waybar = {
    Unit = {
      Description = "Waybar status bar for sway";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      Requisite = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "/usr/bin/waybar";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
