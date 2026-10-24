{
  pkgs,
  ...
}:

# Low-battery notifications via UPower's DisplayDevice, which combines the
# charge of all batteries. Unlike poweralertd, this intentionally ignores
# routine charging and AC events.
#
# A systemd timer + oneshot replaces the old sleep-loop daemon: the timer
# wakes the service every minute, so the script itself just runs once and
# exits. The last notified level lives in XDG_STATE_HOME, and a
# $XDG_RUNTIME_DIR marker (fresh every boot) preserves the old behavior of
# seeding state silently on session start instead of showing a stale
# warning.
let
  batteryAlertd = pkgs.writeShellApplication {
    name = "battery-alertd";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libnotify
      pkgs.systemd
    ];
    text = ''
      display_device=/org/freedesktop/UPower/devices/DisplayDevice
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/battery-alertd"
      state_file=$state_dir/last-level
      marker=''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/battery-alertd.run

      mkdir -p "$state_dir"
      if [[ -f $state_file ]]; then
        last_level=$(<"$state_file")
      else
        last_level=normal
      fi
      initialized=false
      [[ -e $marker ]] && initialized=true

      # busctl answers raw typed values ("d 22.145901", "u 2"): no locale
      # decimal separators and no scraping of textual upower -i output.
      #
      # UPower lives on the system bus. Asking the user bus failed on every run,
      # and exiting 0 on that failure meant no warning ever fired while the unit
      # reported success every minute. A query that fails is a failed unit, so it
      # shows in `systemctl --user --failed`; the timer keeps firing regardless.
      if ! percentage_line=$(
        busctl --system get-property org.freedesktop.UPower "$display_device" \
          org.freedesktop.UPower.Device Percentage
      ); then
        echo "battery-alertd: cannot read Percentage from UPower" >&2
        exit 1
      fi
      percentage=''${percentage_line#* }

      if ! state_line=$(
        busctl --system get-property org.freedesktop.UPower "$display_device" \
          org.freedesktop.UPower.Device State
      ); then
        echo "battery-alertd: cannot read State from UPower" >&2
        exit 1
      fi
      state=''${state_line#* }

      # UPower may report a fractional percentage (for example, 22.1459%).
      # Bash arithmetic needs the whole-number part.
      if [[ $percentage =~ ^([0-9]+)([.][0-9]+)?$ ]]; then
        percentage=''${BASH_REMATCH[1]}
      else
        exit 0
      fi

      # UPDeviceState enum: 2 = discharging.
      level=normal
      if [[ $state == 2 ]] && (( percentage <= 10 )); then
        level=critical
      elif [[ $state == 2 ]] && (( percentage <= 20 )); then
        level=low
      fi

      if [[ $initialized == true && $level != "$last_level" ]]; then
        case $level in
          low)
            notify-send --app-name=battery-alertd --urgency=normal \
              "Battery low" "Combined battery charge is $percentage%." || true
            ;;
          critical)
            notify-send --app-name=battery-alertd --urgency=critical \
              "Battery critical" "Combined battery charge is $percentage%. Connect power now." || true
            ;;
        esac
      fi

      printf '%s\n' "$level" > "$state_file"
      touch "$marker"
    '';
  };
in
{
  systemd.user = {
    services.battery-alertd = {
      Unit.Description = "One-shot low-battery check via UPower";
      Service = {
        Type = "oneshot";
        ExecStart = "${batteryAlertd}/bin/battery-alertd";
      };
    };

    timers.battery-alertd = {
      Unit.Description = "Periodic low-battery checks via UPower";
      Timer = {
        OnBootSec = "2min";
        OnUnitActiveSec = "60";
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
