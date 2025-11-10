#!/bin/bash
# Move all workspaces to the external monitor (DP-2) when docking

sleep 1  # Give Sway time to configure outputs

# Get all workspace numbers
workspaces=$(swaymsg -t get_workspaces | jq -r '.[].name')

# Move each workspace to the external monitor
for ws in $workspaces; do
    swaymsg "workspace $ws, move workspace to output DP-2"
done

# Focus the external monitor
swaymsg "focus output DP-2"
