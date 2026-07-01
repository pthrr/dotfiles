#!/usr/bin/env bash
set -euo pipefail

printer_name=TR4700_series
printer_uri=ipp://192.168.178.54:631/ipp/print

if ! command -v lpadmin >/dev/null 2>&1; then
	echo "lpadmin is unavailable; install CUPS before configuring the printer" >&2
	exit 1
fi

# Canon advertises IPPS too, but its TLS handshake fails with the local CUPS
# stack. Keep the driverless queue on the working IPP endpoint instead.
if ! sudo lpadmin \
	-p "$printer_name" \
	-E \
	-v "$printer_uri" \
	-m everywhere \
	-o ColorModel=Gray \
	-o print-color-mode=monochrome; then
	echo "Could not configure $printer_name. Make sure the printer is powered on and reachable." >&2
	exit 1
fi

echo "Configured $printer_name at $printer_uri"
