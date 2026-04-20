#!/bin/bash
# surface-kernel-setup.sh
# Automated setup script for Microsoft Surface kernel on Artix Linux
# This script must be run as root or with sudo

set -uo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# Import linux-surface signing key
echo "Importing linux-surface signing key..."
curl -s https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc | pacman-key --add -

# Verify fingerprint
echo "Verifying key fingerprint:"
pacman-key --finger 56C464BAAC421453

# Locally sign the imported key
echo "Locally signing the key..."
pacman-key --lsign-key 56C464BAAC421453

# Add linux-surface repository if not already present
if ! grep -q '\[linux-surface\]' /etc/pacman.conf; then
    echo "Adding linux-surface repository to /etc/pacman.conf..."
    echo -e '\n[linux-surface]\nServer = https://pkg.surfacelinux.com/arch/' | sudo tee -a /etc/pacman.conf
else
    echo "linux-surface repository already present in /etc/pacman.conf."
fi

# Update package lists
echo "Updating package lists..."
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm linux-surface linux-surface-headers iptsd
# do not put --noconfirm on libwacom-surface
paru -S libwacom-surface
sudo pacman -S --noconfirm linux-firmware-marvell
sudo pacman -S --noconfirm linux-firmware-intel
sudo pacman -S --noconfirm linux-surface-secureboot-mok


# Update GRUB configuration
echo "\nUpdating GRUB configuration..."
if command -v grub-mkconfig &> /dev/null; then
    sudo grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "\nIf you use rEFInd/other bootloaders, ensure linux-surface is selected as default manually."

echo "\nSetup complete! Please reboot your system. After reboot, check your kernel with:"
echo "uname -a | grep surface"