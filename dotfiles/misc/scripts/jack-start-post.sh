#!/bin/bash
pactl load-module module-jack-sink channels=2
pactl load-module module-jack-source channels=2
pacmd set-default-sink jack_out
pacmd set-default-source jack_in

# Since Jack2 has no own MIDI support, so we need this bridge
a2jmidid -e &
