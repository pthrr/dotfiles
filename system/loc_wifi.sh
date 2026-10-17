#!/usr/bin/env bash
set -euo pipefail

# Re-arm agent-owned secret storage for all Wi-Fi connections (1 = not saved,
# 2 = always ask). Use 1 or 2 instead of 0 to keep passphrases out of
# /etc/NetworkManager/system-connections in plaintext.
nmcli -g NAME,TYPE connection show | awk -F: '$2=="802-11-wireless"{print $1}' |
	while read -r n; do nmcli connection modify "$n" wifi-sec.psk-flags 1; done
