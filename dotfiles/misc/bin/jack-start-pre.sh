#!/bin/bash

SINK='alsa_output.usb-ESI_Audiotechnik_GmbH_U22_XT_USB-01.analog-stereo'
SOURCE='alsa_input.usb-ESI_Audiotechnik_GmbH_U22_XT_USB-01.analog-stereo'

pacmd suspend-sink $SINK true
pacmd suspend-sink $SOURCE true
