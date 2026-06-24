#!/bin/bash

# Get battery info
bat0_capacity=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo 0)
bat1_capacity=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 0)

bat0_status=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "Unknown")
bat1_status=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo "Unknown")

bat0_energy=$(cat /sys/class/power_supply/BAT0/energy_now 2>/dev/null || echo 0)
bat1_energy=$(cat /sys/class/power_supply/BAT1/energy_now 2>/dev/null || echo 0)

bat0_power=$(cat /sys/class/power_supply/BAT0/power_now 2>/dev/null || echo 0)
bat1_power=$(cat /sys/class/power_supply/BAT1/power_now 2>/dev/null || echo 0)

# Calculate combined values
total_capacity=$(( (bat0_capacity + bat1_capacity) / 2 ))
total_energy=$(( bat0_energy + bat1_energy ))
total_power=$(( bat0_power + bat1_power ))

# Calculate time remaining
if [ "$total_power" -gt 0 ]; then
    hours=$(( total_energy / total_power ))
    minutes=$(( (total_energy * 60 / total_power) % 60 ))
    time_str=$(printf "%d:%02d" "$hours" "$minutes")
else
    time_str="--:--"
fi

# Determine status and display format
# Check if fully charged (either "Full" or "Not charging" with high capacity)
if ([ "$bat0_status" = "Full" ] || [ "$bat0_status" = "Not charging" ]) && \
   ([ "$bat1_status" = "Full" ] || [ "$bat1_status" = "Not charging" ]) && \
   [ "$total_capacity" -ge 95 ]; then
    # Full: show FULL
    echo "BAT: FULL"
elif [ "$bat0_status" = "Charging" ] || [ "$bat1_status" = "Charging" ]; then
    # Charging: show percentage
    echo "BAT: ${total_capacity}%"
else
    # Discharging: show time remaining
    echo "BAT: $time_str"
fi
