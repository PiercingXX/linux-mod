#!/bin/bash
# GitHub.com/PiercingXX

set -euo pipefail

XI="sudo xbps-install -y"

install_hyprland_pkg() {
    echo "Refreshing xbps repository index..."
    sudo xbps-install -S || true

    if ! xbps-query -Rs hyprland >/dev/null 2>&1; then
        echo "Error: 'hyprland' package not found in enabled xbps repositories." >&2
        echo "Enable the appropriate repo/mirror and retry installer." >&2
        exit 1
    fi

    $XI hyprland
}

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
install_hyprland_pkg
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
