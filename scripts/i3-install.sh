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

echo "Installing i3 core components..."
$XI i3
$XI i3blocks
$XI i3lock
$XI i3status
$XI picom

echo "Installing X11 utilities used by i3 config..."
$XI xorg-server
$XI xrandr
$XI xinput
$XI xsetroot
$XI xrdb
$XI setxkbmap
$XI xev
$XI numlockx
$XI feh

echo "Installing launcher/menu and screenshot tools..."
$XI fuzzel
$XI grim
$XI slurp
$XI wl-clipboard
$XI cliphist
$XI i3lock

echo "Installing audio and brightness controls..."
$XI pipewire
$XI pipewire-pulse
$XI alsa-utils
$XI wireplumber
$XI pavucontrol
$XI pamixer
$XI playerctl
$XI easyeffects
$XI brightnessctl

echo "Installing auth/session helpers..."
$XI polkit-gnome
$XI gnome-keyring

echo "Installing terminal and file tools..."
$XI kitty
$XI tmux
$XI thunar
$XI thunar-volman

echo "Installing system utilities used by blocks/scripts..."
$XI NetworkManager
$XI network-manager-applet
$XI acpi
$XI upower

echo -e "\nAll i3 packages installed successfully!"