#!/bin/bash
# GitHub.com/PiercingXX

set -euo pipefail

YELLOW='\033[1;33m'
BLUE='\033[1;34m'
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
    sudo xbps-install -Suv
    sudo xbps-install -Rs -y void-repo-nonfree

# Install core dependencies (deduped)
    echo "# Installing dependencies..."
    $XI curl wget git xz unzip zip nano vim gptfdisk xtools mtools mlocate ntfs-3g fuse-exfat
    $XI bash-completion linux-headers gtksourceview4 ffmpeg mesa mesa-dri mesa-vdpau mesa-vaapi
    $XI autoconf automake bison m4 make libtool flex meson ninja optipng sassc cmake cpio
    $XI trash-cli fastfetch tree zoxide starship eza bat fzf chafa w3m fontconfig
    $XI base-devel gcc linux-firmware iw tmux sshpass htop multitail bluetuith dconf fwupd kitty
    $XI python3 nodejs npm lnav ulauncher nvtop wmctrl xdotool libinput
    $XI xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr xdg-user-dirs xdg-user-dirs-gtk xdg-utils
    $XI dbus elogind polkit gnome-browser-connector

# GNOME stack
    echo "# Installing GNOME..."
    $XI xorg xorg-server-xwayland xinit
    $XI gnome gdm gnome-session gnome-shell gnome-disk-utility gnome-calculator seahorse gnome-keyring gnome-shell-extensions gnome-sushi

# Networking, audio, Bluetooth, power
    $XI NetworkManager NetworkManager-openvpn NetworkManager-openconnect NetworkManager-vpnc NetworkManager-l2tp network-manager-applet
    $XI pipewire alsa-utils wireplumber playerctl pavucontrol pamixer cava pulseaudio pulseaudio-utils pulsemixer alsa-plugins-pulseaudio
    $XI bluez cronie tlp tlp-rdw powertop

# Wayland / compositor utilities
    $XI wl-clipboard Waybar fuzzel wlogout libnotify dunst brightnessctl nwg-look

# Fonts and font config
    $XI noto-fonts-emoji noto-fonts-ttf noto-fonts-ttf-extra
    sudo ln -sf /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/
    sudo xbps-reconfigure -f fontconfig

# Enable core services
    echo "# Enabling desktop services..."
    enable_service dbus
    enable_service elogind
    enable_service polkitd
    enable_service NetworkManager
    enable_service bluetoothd
    enable_service cronie
    enable_service tlp
    enable_service gdm

    sudo usermod -aG bluetooth "$username" || true

# Desktop launch wrappers for consistent commands from TTY
    echo "# Creating desktop launch wrappers..."
    sudo tee /usr/local/bin/gnome-wayland >/dev/null <<'EOF'
#!/bin/sh
exec env XDG_SESSION_TYPE=wayland XDG_RUNTIME_DIR="/run/user/$(id -u)" dbus-run-session gnome-session "$@"
EOF
    sudo chmod +x /usr/local/bin/gnome-wayland

    sudo tee /usr/local/bin/gnome-x11 >/dev/null <<'EOF'
#!/bin/sh
exec startx /usr/bin/gnome-session -- "$@"
EOF
    sudo chmod +x /usr/local/bin/gnome-x11

    sudo tee /usr/local/bin/hypr >/dev/null <<'EOF'
#!/bin/sh
if command -v start-hyprland >/dev/null 2>&1; then
    exec start-hyprland "$@"
fi
echo "start-hyprland not found. Install Hyprland from the Optional Window Managers menu." >&2
exit 127
EOF
    sudo chmod +x /usr/local/bin/hypr

# Flatpak
    echo -e "${YELLOW}Installing Flatpak & adding Flathub...${NC}"
    $XI flatpak
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install flathub net.waterfox.waterfox -y
    flatpak install flathub md.obsidian.Obsidian -y
    flatpak install flathub org.libreoffice.LibreOffice -y
    flatpak install flathub org.qbittorrent.qBittorrent -y
    flatpak install flathub io.missioncenter.MissionCenter -y
    flatpak install flathub io.github.shiftey.Desktop -y # Github Desktop

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
    $XI 7zip
    $XI jq
    $XI poppler
    $XI fd
    $XI ripgrep
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
    # Enable Printer
        $XI cups gutenprint cups-pk-helper nmap net-tools
        enable_service cupsd
    # Add dialout group for ZMK / VIA keyboards
        sudo usermod -aG uucp "$USER"
