#!/bin/bash
# GitHub.com/PiercingXX

# shellcheck source=service-manager.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/service-manager.sh"

set -e

PKGMGR="paru -S --noconfirm"

echo "Installing GNOME desktop packages..."
${PKGMGR} gnome gnome-extra
${PKGMGR} nautilus
${PKGMGR} gnome-tweaks
${PKGMGR} dconf

echo "Installing session dependencies for Artix..."
${PKGMGR} elogind
${PKGMGR} dbus
${PKGMGR} networkmanager
${PKGMGR} ly

# Ly is the default login manager for this project, regardless of desktop choice.
if ! disable_and_stop_service gdm lightdm sddm lxdm xdm; then
    echo "Warning: Could not fully disable alternate display managers on this init system."
fi

if ! enable_and_start_service dbus; then
    echo "Warning: Could not start/enable dbus service on this init system."
fi

if ! enable_and_start_service elogind; then
    echo "Warning: Could not start/enable elogind service on this init system."
fi

if ! enable_and_start_service NetworkManager networkmanager; then
    echo "Warning: Could not start/enable NetworkManager service on this init system."
fi

if ! enable_and_start_service ly; then
    echo "Warning: Could not start/enable ly service on this init system."
else
    echo "ly enabled as the default login manager."
fi

echo -e "\nGNOME installation completed successfully!"
