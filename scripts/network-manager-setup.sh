#!/bin/bash
# GitHub.com/PiercingXX

set -euo pipefail

# shellcheck source=service-manager.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/service-manager.sh"

enforce_networkmanager_multi_init() {
    echo "Standardizing network stack to NetworkManager (Artix init abstraction)..."

    disable_and_stop_service iwd >/dev/null 2>&1 || true
    disable_and_stop_service connman connmand >/dev/null 2>&1 || true
    disable_and_stop_service dhcpcd >/dev/null 2>&1 || true
    disable_and_stop_service wpa_supplicant >/dev/null 2>&1 || true

    sudo mkdir -p /etc/NetworkManager/conf.d
    sudo tee /etc/NetworkManager/conf.d/10-wifi-powersave-off.conf >/dev/null <<'EOF'
[connection]
wifi.powersave=2
EOF

    if ! enable_and_start_service NetworkManager networkmanager; then
        echo "Warning: Could not start/enable NetworkManager service on this init system."
    fi
}

enforce_networkmanager_multi_init