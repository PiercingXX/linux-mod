#!/bin/bash

set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
    echo "Please run as root (sudo)."
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

WIFI_FW_DIR="/lib/firmware/brcm"
AUDIO_FW_DIR="/lib/firmware/intel"

install_deps() {
    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y \
            linux-firmware \
            firmware-brcm80211 \
            bluez \
            bluez-tools \
            iw \
            alsa-utils \
            firmware-sof-signed || \
        apt-get install -y \
            linux-firmware \
            firmware-brcm80211 \
            bluez \
            bluez-tools \
            iw \
            alsa-utils
    else
        echo "apt-get not found. This script targets Debian/Ubuntu." >&2
        exit 1
    fi
}

install_deps

# Apply WiFi/Bluetooth and audio firmware
install -d "$WIFI_FW_DIR" "$AUDIO_FW_DIR"
cp -f "$SCRIPT_DIR"/wifi-bluetooth-drivers/* "$WIFI_FW_DIR"/
if [ -d "$SCRIPT_DIR/audio-drivers" ]; then
    cp -f "$SCRIPT_DIR"/audio-drivers/* "$AUDIO_FW_DIR"/ || true
fi

# Reload WiFi kernel module
modprobe -r brcmfmac 2>/dev/null || true
modprobe brcmfmac 2>/dev/null || true

wifi_iface="$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')"
wifi_iface="${wifi_iface:-wlan0}"
ip link set "$wifi_iface" up 2>/dev/null || true
iw "$wifi_iface" scan >/dev/null 2>&1 || true

# Restart Bluetooth service
modprobe -r btusb 2>/dev/null || true
modprobe btusb 2>/dev/null || true
systemctl restart bluetooth 2>/dev/null || true

# WiFi auto-start (systemd service)
install -m 0755 "$SCRIPT_DIR/wifi-startup.sh" /usr/local/bin/wifi-startup.sh
if [ -f "$SCRIPT_DIR/wifi-startup.service" ]; then
    cp -f "$SCRIPT_DIR/wifi-startup.service" /etc/systemd/system/wifi-startup.service
    systemctl daemon-reload
    systemctl enable --now wifi-startup.service
fi

# Audio fix
audio_modules=(
    snd_sof_pci
    snd_sof_acpi_intel_byt
    snd_sof_acpi
    snd_sof_intel_atom
    snd_sof_xtensa_dsp
    snd_sof
    snd_intel_sst_acpi
    snd_intel_sst_core
    snd_soc_sst_atom_hifi2_platform
    snd_soc_core
    snd_pcm
)
for mod in "${audio_modules[@]}"; do
    modprobe -r "$mod" 2>/dev/null || true
done
modprobe snd_sof_pci 2>/dev/null || true

if systemctl list-unit-files 2>/dev/null | grep -q '^pipewire\.service'; then
    systemctl restart pipewire 2>/dev/null || true
fi

# Touchscreen calibration
cat >/etc/udev/hwdb.d/61-sensor-local.hwdb <<'EOF'
sensor:modalias:acpi:KIOX000A*
 ACCEL_MOUNT_MATRIX=0,1,0;1,0,0;0,0,-1
EOF
systemd-hwdb update
udevadm trigger /sys/bus/iio/devices/iio:device0 2>/dev/null || true

if systemctl list-unit-files 2>/dev/null | grep -q '^iio-sensor-proxy\.service'; then
    systemctl restart iio-sensor-proxy
fi