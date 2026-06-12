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

install_or_build_suckless() {
	local package="$1"
	local repo_url="$2"
	local build_dir="/tmp/${package}-build"

	if xbps-query -Rs "^${package}$" >/dev/null 2>&1; then
		$XI "$package"
		return 0
	fi

	echo "Package ${package} not found in XBPS, building from source..."
	rm -rf "$build_dir"
	git clone --depth 1 "$repo_url" "$build_dir"
	pushd "$build_dir" >/dev/null || return 1
	sudo make clean install
	popd >/dev/null || return 1
	rm -rf "$build_dir"
}

echo "Ensuring build dependencies are available..."
$XI base-devel
$XI git
$XI cmake
$XI meson
$XI pkg-config

echo "Installing DWM core components..."
install_or_build_suckless dwm https://git.suckless.org/dwm
install_or_build_suckless dmenu https://git.suckless.org/dmenu
install_or_build_suckless st https://git.suckless.org/st
xi_install_safe slstatus sxhkd picom

echo "Installing X11 utilities used by DWM config..."
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
xi_install_safe rofi libnotify
$XI flameshot

echo "Installing terminal, editor, and font tools..."
$XI kitty
$XI neovim
$XI tmux
xi_install_safe font-jetbrains-mono-nerd

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
xi_install_safe easyeffects brightnessctl
$XI rtkit

echo "Installing auth/session helpers..."
$XI NetworkManager
$XI network-manager-applet
$XI polkit-gnome
$XI gnome-keyring

configure_pipewire_session

echo -e "\nAll DWM packages installed successfully!"