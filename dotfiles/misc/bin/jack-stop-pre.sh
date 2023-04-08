#!/bin/bash
pactl unload-module module-jack-sink
pactl unload-module module-jack-source
sleep 3
