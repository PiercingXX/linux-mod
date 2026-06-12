#!/bin/bash
# GitHub.com/PiercingXX

set -uo pipefail

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

echo "Installing herbstluftwm core components..."
$XI herbstluftwm
$XI sxhkd
$XI polybar
$XI picom
$XI dmenu

echo "Installing X11 utilities used by herbstluftwm config..."
$XI xorg-server
$XI xrandr
$XI xinput
$XI xsetroot
$XI xrdb
$XI setxkbmap
$XI xev
$XI numlockx
$XI xclip
$XI xdotool
$XI feh

echo "Installing launcher, wallpaper, and screenshot tools..."
$XI rofi
$XI libnotify
$XI flameshot

echo "Installing terminal, editor, and font tools..."
$XI kitty
$XI neovim
$XI tmux
$XI font-jetbrains-mono-nerd

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
$XI brightnessctl
$XI rtkit

echo "Installing auth/session helpers..."
$XI NetworkManager
$XI network-manager-applet
$XI polkit-gnome
$XI gnome-keyring

configure_pipewire_session

echo -e "\nAll herbstluftwm packages installed successfully!"