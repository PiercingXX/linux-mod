#!/bin/bash
# GitHub.com/PiercingXX

set -euo pipefail

XI="sudo xbps-install -y"

configure_pipewire_session() {
	sudo rm -f /etc/pipewire/pipewire.conf.d/10-wireplumber.conf \
		/etc/pipewire/pipewire.conf.d/20-pipewire-pulse.conf \
		/etc/alsa/conf.d/50-pipewire.conf \
		/etc/alsa/conf.d/99-pipewire-default.conf

	sudo mkdir -p /etc/xdg/autostart

	if [ -f /usr/share/applications/pipewire.desktop ]; then
		sudo ln -snf /usr/share/applications/pipewire.desktop \
			/etc/xdg/autostart/pipewire.desktop
	fi

	if [ -f /usr/share/applications/pipewire-pulse.desktop ]; then
		sudo ln -snf /usr/share/applications/pipewire-pulse.desktop \
			/etc/xdg/autostart/pipewire-pulse.desktop
	fi

	if [ -f /usr/share/applications/wireplumber.desktop ]; then
		sudo ln -snf /usr/share/applications/wireplumber.desktop \
			/etc/xdg/autostart/wireplumber.desktop
	fi
}

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
$XI alsa-pipewire
$XI alsa-utils
$XI wireplumber
$XI wireplumber-elogind
$XI pavucontrol
$XI pamixer
$XI playerctl
$XI easyeffects
$XI rtkit
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

configure_pipewire_session

echo -e "\nAll i3 packages installed successfully!"