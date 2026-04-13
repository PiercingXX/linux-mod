#!/bin/bash
# GitHub.com/PiercingXX

set -euo pipefail

# Suppress dconf/gsettings "failed to commit changes" errors when running
# without a display (installer runs headless under sudo).
export DISPLAY="${DISPLAY:-:0}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-/dev/null}"

YELLOW='\033[1;33m'
NC='\033[0m'

username=$(id -u -n 1000)
builddir=$(pwd)

# xbps helper — install only (sync is handled by system update)
XI="sudo xbps-install -y"

enable_service() {
    local service_name="$1"
    if [ -d "/etc/sv/$service_name" ]; then
        sudo ln -sf "/etc/sv/$service_name" /var/service/
        sudo sv up "$service_name" || true
    else
        echo "# Skipping missing service: $service_name"
    fi
}

# Create Directories if needed
    echo -e "${YELLOW}Creating Necessary Directories...${NC}"
        # font directory
            if [ ! -d "$HOME/.fonts" ]; then
                mkdir -p "$HOME/.fonts"
            fi
            chown -R "$username":"$username" "$HOME"/.fonts
        # icons directory
            if [ ! -d "$HOME/.icons" ]; then
                mkdir -p /home/"$username"/.icons
            fi
            chown -R "$username":"$username" /home/"$username"/.icons
        # Background and Profile Image Directories
            if [ ! -d "$HOME/Pictures/backgrounds" ]; then
                mkdir -p /home/"$username"/Pictures/backgrounds
            fi
            chown -R "$username":"$username" /home/"$username"/Pictures/backgrounds
            if [ ! -d "$HOME/Pictures/profile-image" ]; then
                mkdir -p /home/"$username"/Pictures/profile-image
            fi
            chown -R "$username":"$username" /home/"$username"/Pictures/profile-image

# System Update
    sudo xbps-install -Su

# Install dependencies
    echo "# Installing dependencies..."
    $XI trash-cli
    $XI fastfetch
    $XI tree
    $XI zoxide
    $XI bash-completion
    $XI starship
    $XI eza
    $XI bat
    $XI fzf
    $XI chafa
    $XI w3m
    $XI zip unzip gzip tar make wget fontconfig
    $XI base-devel gcc
    $XI linux-firmware
    $XI bluez
    $XI iw
    $XI tmux
    $XI sshpass
    $XI htop
    $XI dbus
    $XI polkit

# Enable dbus (required by many desktop components)
    echo "# Enabling dbus..."
    enable_service dbus
    enable_service polkitd

# Flatpak
    echo -e "${YELLOW}Installing Flatpak & adding Flathub...${NC}"
    $XI flatpak
    [ -d /etc/sv/dbus ] && sudo ln -sf /etc/sv/dbus /var/service/ || true
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Installing more Depends
    echo "# Installing more dependencies..."
    $XI multitail
    $XI bluetuith
    $XI dconf
    $XI cmake meson cpio
    $XI fwupd
    $XI kitty
    $XI python3
    $XI wmctrl xdotool libinput
    $XI nodejs npm
    $XI lnav
    $XI ulauncher
    $XI nvtop
    $XI xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr
    flatpak install flathub net.waterfox.waterfox -y
    flatpak install flathub md.obsidian.Obsidian -y
    flatpak install flathub org.libreoffice.LibreOffice -y
    flatpak install flathub org.qbittorrent.qBittorrent -y
    flatpak install flathub io.missioncenter.MissionCenter -y
    flatpak install flathub io.github.shiftey.Desktop -y #Github Desktop

# GNOME & Depends
    echo "# Installing GNOME..."
    $XI xorg
    $XI xorg-server-xwayland
    $XI mesa-dri
    $XI gnome
    $XI gdm
    $XI gnome-disk-utility gnome-calculator
    $XI seahorse gnome-keyring
    $XI gnome-shell-extensions gnome-sushi
    $XI xdg-utils
    $XI elogind
    enable_service elogind
    enable_service gdm
    sudo sv status gdm || true
    echo "# If GDM still fails after reboot, check: sudo sv status gdm && sudo tail -n 100 /var/log/gdm/*"

# Wayland / Compositor utilities
    $XI wl-clipboard
    $XI waybar
    $XI fuzzel
    $XI wlogout
    $XI libnotify
    $XI dunst
    $XI brightnessctl
    $XI pamixer
    $XI cava
    $XI pipewire
    $XI pipewire-pulse
    $XI alsa-utils
    $XI wireplumber
    $XI playerctl
    $XI pavucontrol
    $XI NetworkManager
    $XI network-manager-applet
    $XI nwg-look

# Nvim & Depends
    sudo xbps-remove -Ry neovim 2>/dev/null || true
    $XI neovim
    $XI lua51
    $XI python3-pip
    $XI python3-neovim
    python3 -m pip install --user --upgrade pynvim
    command -v nvim >/dev/null 2>&1 || {
        echo "# Neovim install appears to have failed; check xbps output above."
        exit 1
    }

# VSCode (flatpak — no official xbps package)
    flatpak install flathub com.visualstudio.code -y

# Firewall
    $XI ufw
    sudo ufw allow OpenSSH
    enable_service ufw

# Yazi
    $XI yazi
    $XI ffmpeg
    $XI 7zip
    $XI jq
    $XI poppler
    $XI fd
    $XI ripgrep
    $XI fzf
    $XI zoxide
    $XI ImageMagick
    ya pkg add dedukun/bookmarks
    ya pkg add yazi-rs/plugins:mount
    ya pkg add dedukun/relative-motions
    ya pkg add yazi-rs/plugins:chmod
    ya pkg add yazi-rs/plugins:smart-enter
    ya pkg add AnirudhG07/rich-preview
    ya pkg add grappas/wl-clipboard
    ya pkg add Rolv-Apneseth/starship
    ya pkg add yazi-rs/plugins:full-border
    ya pkg add uhs-robert/recycle-bin
    ya pkg add yazi-rs/plugins:diff

# Apps to remove
    sudo xbps-remove -Ry firefox 2>/dev/null || true
    sudo xbps-remove -Ry epiphany 2>/dev/null || true

# Tailscale
    $XI tailscale
    enable_service tailscaled

# Theme stuffs
    $XI papirus-icon-theme

# Install fonts
    echo "Installing Fonts"
    cd "$builddir" || exit
    $XI font-firacode-nerd
    $XI font-jetbrains-mono-nerd
    $XI noto-fonts-emoji
    $XI terminus-font
    # Reload Font
    fc-cache -vf
    wait

# OpenSSH
    echo "# Enabling OpenSSH Service..."
    $XI openssh
    enable_service sshd

# System Control Services
    echo "# Enabling Audio, Bluetooth, WiFi and CUPS services..."
    # Enable Audio
        enable_service alsa
    # Enable Bluetooth
        enable_service bluetoothd
    # Enable WiFi / NetworkManager
        enable_service NetworkManager
    # Enable Printer
        $XI cups gutenprint cups-pk-helper nmap net-tools cmake meson cpio
        enable_service cupsd
    # Add dialout group for ZMK / VIA keyboards
        sudo usermod -aG uucp "$USER"