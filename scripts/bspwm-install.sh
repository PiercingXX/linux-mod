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
$XI alsa-pipewire
$XI alsa-utils
$XI wireplumber
$XI wireplumber-elogind
$XI pavucontrol
$XI pamixer
$XI playerctl
$XI easyeffects
$XI rtkit

echo "Installing network and auth helpers..."
$XI NetworkManager
$XI network-manager-applet
$XI bluez
$XI bluetuith
$XI polkit-gnome
$XI gnome-keyring

echo "Installing optional swallow helpers..."
$XI xdo

configure_pipewire_session

echo -e "\nAll bspwm packages installed successfully!"