#!/bin/bash
# GitHub.com/PiercingXX

set -euo pipefail

XI="sudo xbps-install -y"

# Ensure build dependencies are available
echo "Ensuring build dependencies are available..."
$XI base-devel
$XI git
$XI cmake
$XI meson
$XI pkg-config

# Install core Hyprland components
# NOTE: Hyprland and its ecosystem are available in the void-packages repo.
echo "Installing Hyprland core components..."
$XI hyprland
$XI hyprpaper
$XI hyprlock
$XI hypridle
$XI hyprcursor
$XI polkit-gnome

# Install additional utilities
$XI wlsunset
$XI wl-clipboard

# Set up Waybar and menus
$XI waybar
$XI fuzzel
$XI wlogout
$XI libnotify
$XI dunst
$XI brightnessctl

# Install file manager and customization tools
$XI thunar
$XI thunar-volman

# Add screenshot and clipboard utilities
$XI grim
$XI slurp
$XI cliphist

# Install audio tools
 $XI pipewire
 $XI pipewire-pulse
 $XI alsa-utils
$XI pamixer
$XI cava
$XI wireplumber
$XI playerctl
$XI pavucontrol

# Network and Bluetooth utilities
$XI NetworkManager
$XI network-manager-applet
$XI bluez
$XI bluetuith

# GUI customization tools
$XI nwg-look
$XI dconf

# Hyprland plugins via hyprpm (if hyprpm is available)
if command -v hyprpm &>/dev/null; then
    echo "Updating and loading Hyprland plugin manager..."
    hyprpm update
    hyprpm reload

    echo "Adding Hyprland plugins..."
    hyprpm add https://github.com/hyprwm/hyprland-plugins || echo "Warning: Failed to add hyprland-plugins"
    hyprpm add https://github.com/virtcode/hypr-dynamic-cursors || echo "Warning: Failed to add hypr-dynamic-cursors"
    hyprpm enable dynamic-cursors || echo "Warning: Failed to enable dynamic-cursors"
    hyprpm add https://github.com/horriblename/hyprgrass || echo "Warning: Failed to add hyprgrass"
    hyprpm enable hyprgrass || echo "Warning: Failed to enable hyprgrass"
else
    echo "hyprpm not found, skipping plugin install."
fi

# Success message
echo -e "\nAll Hyprland packages and plugins installed successfully!"
