#!/bin/bash
# GitHub.com/PiercingXX

set -euo pipefail

service_dir() {
    if [ -e /var/service ]; then
        printf '/var/service\n'
        return 0
    fi

    if [ -d /etc/runit/runsvdir/current ]; then
        printf '/etc/runit/runsvdir/current\n'
        return 0
    fi

    if [ -d /etc/runit/runsvdir/default ]; then
        printf '/etc/runit/runsvdir/default\n'
        return 0
    fi

    return 1
}

disable_service_link() {
    local svc="$1"
    local svdir

    svdir="$(service_dir)" || return 0
    sudo sv down "$svc" >/dev/null 2>&1 || true
    sudo rm -f "$svdir/$svc"
}

enforce_networkmanager_runit() {
    local svdir

    echo "Standardizing network stack to NetworkManager (runit)..."
    svdir="$(service_dir)" || {
        echo "Could not detect runit service directory; skipping NetworkManager service link changes."
        return 0
    }

    disable_service_link dhcpcd
    disable_service_link wpa_supplicant
    disable_service_link iwd
    disable_service_link connmand

    if [ -d /etc/sv/NetworkManager ]; then
        sudo ln -sfn /etc/sv/NetworkManager "$svdir/NetworkManager"
        sudo sv up NetworkManager >/dev/null 2>&1 || true
    fi

    sudo mkdir -p /etc/NetworkManager/conf.d
    sudo tee /etc/NetworkManager/conf.d/10-wifi-powersave-off.conf >/dev/null <<'EOF'
[connection]
wifi.powersave=2
EOF
}

enforce_networkmanager_runit