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

echo "Installing bspwm core components..."
$XI bspwm
$XI sxhkd
$XI polybar
$XI picom

echo "Installing X11 utilities used by bspwm config..."
$XI xorg-server
$XI xrandr
$XI xsetroot
$XI setxkbmap
$XI xrdb
$XI xev
$XI xinput

echo "Installing launcher/background/screenshot tools..."
$XI fuzzel
$XI hsetroot
$XI flameshot
$XI sxiv
$XI zathura

echo "Installing terminal, drag/drop and input tools..."
$XI kitty
$XI xdragon
$XI fcitx5

echo "Installing audio stack..."
$XI pipewire
$XI pipewire-pulse
$XI alsa-utils
$XI wireplumber
$XI pavucontrol
$XI pamixer
$XI playerctl
$XI easyeffects

echo "Installing network and auth helpers..."
$XI NetworkManager
$XI network-manager-applet
$XI bluez
$XI bluetuith
$XI polkit-gnome
$XI gnome-keyring

echo "Installing optional swallow helpers..."
$XI xdo

echo -e "\nAll bspwm packages installed successfully!"