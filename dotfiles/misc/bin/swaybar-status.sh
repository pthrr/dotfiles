#!/usr/bin/env bash

while true; do
	# CPU usage (percentage)
	cpu=$(top -bn2 -d0.5 | grep "Cpu(s)" | tail -n1 | awk '{print $2}' | cut -d'%' -f1)
	cpu=$(printf "%.0f" "$cpu")

	# Memory usage (percentage)
	mem=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')

	# Battery (remaining time in minutes)
	battery=""
	if [ -d "/sys/class/power_supply/BAT0" ]; then
		bat_percent=$(cat /sys/class/power_supply/BAT0/capacity)
		bat_status=$(cat /sys/class/power_supply/BAT0/status)

		# Calculate remaining time
		if [ -f "/sys/class/power_supply/BAT0/power_now" ] && [ -f "/sys/class/power_supply/BAT0/energy_now" ]; then
			power_now=$(cat /sys/class/power_supply/BAT0/power_now)
			energy_now=$(cat /sys/class/power_supply/BAT0/energy_now)
			if [ "$power_now" -gt 0 ]; then
				minutes=$((energy_now * 60 / power_now))
				if [ "$bat_status" = "Charging" ]; then
					battery="⚡${minutes}min (${bat_percent}%)"
				else
					battery="🔋${minutes}min (${bat_percent}%)"
				fi
			else
				battery="🔋${bat_percent}%"
			fi
		else
			battery="🔋${bat_percent}%"
		fi
	fi

	# Volume
	volume=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -n1)
	muted=$(pactl get-sink-mute @DEFAULT_SINK@ | grep -q yes && echo "🔇" || echo "🔊")

	# Date and time: CW, day name, hh:mm - dd.MM.yyyy
	datetime=$(date +'KW %V, %a, %H:%M - %d.%m.%Y')

	# Output
	echo "CPU: ${cpu}% | MEM: ${mem}% | ${battery} | ${muted}${volume} | ${datetime} |"

	sleep 3
done
