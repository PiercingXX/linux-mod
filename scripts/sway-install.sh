#!/bin/bash
# GitHub.com/PiercingXX

set -uo pipefail

XI="sudo xbps-install -y"

xi_install_safe() {
	local pkg

	for pkg in "$@"; do
		if ! xbps-query -Rs "^${pkg}$" >/dev/null 2>&1; then
			echo "Skipping unavailable package: $pkg"
			continue
		fi

		if ! $XI "$pkg"; then
			echo "Optional package install failed: $pkg"
		fi
	done
}

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

echo "Installing Sway core components..."
$XI sway
$XI swaybg
$XI swayidle
$XI swaylock
$XI xdg-desktop-portal
$XI xdg-desktop-portal-wlr

echo "Installing Wayland bar/launcher stack..."
$XI waybar
xi_install_safe nwg-drawer
$XI fuzzel
$XI wlogout
$XI dunst
$XI libnotify
xi_install_safe notification-daemon
xi_install_safe swaync

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
$XI alsa-pipewire
$XI alsa-utils
$XI wireplumber
$XI wireplumber-elogind
$XI pavucontrol
$XI pamixer
$XI playerctl
$XI easyeffects
$XI rtkit

echo "Installing network and bluetooth utilities..."
$XI NetworkManager
$XI network-manager-applet
$XI bluez
$XI bluetuith

echo "Installing customization utilities..."
$XI nwg-look
$XI dconf

configure_pipewire_session

echo -e "\nAll Sway packages installed successfully!"