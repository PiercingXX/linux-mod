#!/bin/bash
# Standalone Ly installer/enabler for Artix init variants.

# shellcheck source=service-manager.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/service-manager.sh"

set -e

echo "Installing ly..."
sudo pacman -S --needed --noconfirm ly

echo "Disabling alternate display managers (if present)..."
if ! disable_and_stop_service gdm lightdm sddm lxdm xdm; then
    echo "Warning: Could not fully disable alternate display managers on this init system."
fi

echo "Enabling ly..."
if ! enable_and_start_service ly; then
    echo "Error: Could not enable/start ly service on this init system."
    exit 1
fi

echo "ly is now installed and set as the active display manager."
