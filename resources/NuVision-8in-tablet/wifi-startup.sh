#!/bin/bash

set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
    echo "Please run as root (sudo)." >&2
    exit 1
fi

# Run at startup to force WiFi on.
modprobe -r brcmfmac 2>/dev/null || true
modprobe brcmfmac 2>/dev/null || true

wifi_iface="$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')"
wifi_iface="${wifi_iface:-wlan0}"
ip link set "$wifi_iface" up 2>/dev/null || true
iw "$wifi_iface" scan >/dev/null 2>&1 || true