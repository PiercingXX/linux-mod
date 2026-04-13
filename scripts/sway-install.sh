#!/bin/bash
# GitHub.com/PiercingXX

set -euo pipefail

XI="sudo xbps-install -y"

echo "Ensuring build dependencies are available..."
$XI base-devel
$XI git
$XI cmake
$XI meson
$XI pkg-config

echo "Installing Sway core components..."
$XI sway
$XI swaybg
$XI swayidle
$XI swaylock
$XI xdg-desktop-portal
$XI xdg-desktop-portal-wlr

echo "Installing Wayland bar/launcher stack..."
$XI waybar
$XI fuzzel
$XI wlogout
$XI dunst
$XI libnotify

echo "Installing clipboard and screenshot tools..."
$XI wl-clipboard
$XI cliphist
$XI grim
$XI slurp
$XI brightnessctl

echo "Installing auth/session helpers..."
$XI polkit-gnome
$XI gnome-keyring

echo "Installing terminal and file tools..."
$XI kitty
$XI tmux
$XI thunar
$XI thunar-volman

echo "Installing audio stack..."
$XI pipewire
$XI pipewire-pulse
$XI alsa-utils
$XI wireplumber
$XI pavucontrol
$XI pamixer
$XI playerctl
$XI easyeffects

echo "Installing network and bluetooth utilities..."
$XI NetworkManager
$XI network-manager-applet
$XI bluez
$XI bluetuith

echo "Installing customization utilities..."
$XI nwg-look
$XI dconf

echo -e "\nAll Sway packages installed successfully!"