for c in $(nmcli -g NAME connection show --active); do :; done
nmcli -g NAME,TYPE connection show | awk -F: '$2=="802-11-wireless"{print $1}' |
	while read -r n; do nmcli connection modify "$n" wifi-sec.psk-flags 0; done
