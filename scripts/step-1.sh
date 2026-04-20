#!/bin/bash
# GitHub.com/PiercingXX

set -euo pipefail

trap 'echo "# Installer failed at line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

YELLOW='\033[1;33m'
NC='\033[0m'

username=$(id -u -n 1000)
builddir=$(pwd)
VOID_INSTALL_GDM="${VOID_INSTALL_GDM:-0}"

# xbps helper — install only (sync is handled by system update)
XI="sudo xbps-install -y"

# Package guard helpers — exact patterns required by installer spec.
#
# pkg_installed: xbps-query -l reports installed packages as "ii <name>-<ver>".
#   Greps for "^ii <pkg>-" to avoid false-matches (e.g. "foo-bar" matching "foo").
# pkg_available: xbps-query -Rs searches remote repo index by POSIX regex.
#   "^<pkg>$" matches the package name exactly; output line starts with [*] or [-].
# xi_install_safe: per-package loop — skip already-installed, warn if not in repos,
#   install and warn on failure; never aborts the calling script.

pkg_installed() {
    xbps-query -l 2>/dev/null | grep -q "^ii ${1}-"
}

pkg_available() {
    xbps-query -Rs "^${1}$" 2>/dev/null | grep -q "^\\[[-*]\\] ${1}-"
}

xi_install_safe() {
    local pkg
    for pkg in "$@"; do
        if pkg_installed "$pkg"; then
            echo "# [skip] ${pkg} already installed"
            continue
        fi
        if ! pkg_available "$pkg"; then
            echo "# [warn] ${pkg} not found in current repos — skipping"
            continue
        fi
        if ! $XI "$pkg"; then
            echo "# [warn] ${pkg} install failed — continuing"
        fi
    done
}

install_optional_packages() {
    local package_name
    for package_name in "$@"; do
        xi_install_safe "$package_name"
    done
}

disable_hyprland_fallback_repo() {
    local repo_conf="/etc/xbps.d/hyprland-void.conf"
    local hypr_pkgs=(
        aquamarine hyprcursor hyprgraphics hypridle hyprland hyprlang
        hyprlock hyprpaper hyprutils hyprwayland-scanner hyprsunset
        xdg-desktop-portal-hyprland
    )

    if [ -f "$repo_conf" ]; then
        echo "# Disabling stale Hyprland fallback repository for base system install..."
        sudo mv "$repo_conf" "${repo_conf}.disabled"
        # Delete the cached repodata files for hyprland-void from xbps's on-disk
        # index. Without this, xbps-install -Suv still sees ghost entries from
        # the old repo (e.g. aquamarine requiring libhyprutils.so.6) even though
        # the repo conf is now disabled, and aborts the transaction.
        sudo find /var/db/xbps/ -maxdepth 1 \
            \( -name '*hyprland-void*' -o -name '*Makrennel*' \) \
            -delete 2>/dev/null || true
        echo "# Removing stale Hyprland packages to clear broken shlib dependencies..."
        sudo xbps-remove -Fy "${hypr_pkgs[@]}" 2>/dev/null || true
        sudo xbps-install -S || true
    fi
}

get_runit_service_dir() {
    if [ -e /var/service ]; then
        printf '%s\n' /var/service
    elif [ -d /etc/runit/runsvdir/current ]; then
        printf '%s\n' /etc/runit/runsvdir/current
    elif [ -d /etc/runit/runsvdir/default ]; then
        printf '%s\n' /etc/runit/runsvdir/default
    else
        return 1
    fi
}

enable_service() {
    local service_name="$1"
    local required="${2:-1}"
    local service_dir
    local started=0

    if [ -d "/etc/sv/$service_name" ]; then
        if ! service_dir="$(get_runit_service_dir)"; then
            echo "# Unable to determine runit service directory: $service_name"
            if [ "$required" -eq 1 ]; then
                return 1
            fi
            return 0
        fi

        sudo mkdir -p "$service_dir"
        # Recreate the link so runsvdir reliably notices newly enabled services.
        sudo rm -f "$service_dir/$service_name"
        sudo ln -s "/etc/sv/$service_name" "$service_dir/$service_name"

        # runsv can take a moment to create supervise/control after linking.
        # Retry briefly so first-boot service bring-up is more reliable.
        for _ in 1 2 3 4 5; do
            if sudo sv up "$service_name" 2>/dev/null; then
                if sudo sv status "$service_name" >/dev/null 2>&1; then
                    started=1
                    break
                fi
            fi
            sleep 1
        done

        if [ "$started" -ne 1 ]; then
            echo "# Failed to start service automatically: $service_name"
            echo "# Expected service files in /etc/sv/$service_name and supervision via $service_dir/$service_name"
            echo "# Check runit (ps -p 1 -o comm=, pgrep -a runsvdir) or reboot, then run: sudo sv up $service_name"
            if [ "$required" -eq 1 ]; then
                return 1
            fi
            return 0
        fi
    else
        echo "# Missing service directory: /etc/sv/$service_name"
        if [ "$required" -eq 1 ]; then
            return 1
        fi
        return 0
    fi
}

configure_gdm_for_portrait_touchscreen() {
    echo "# Configuring GDM for portrait touchscreen (Xorg, 90 deg clockwise)..."

    # Force GDM to Xorg on this hardware; Wayland path is unstable here.
    sudo mkdir -p /etc/gdm
    sudo tee /etc/gdm/custom.conf >/dev/null <<'EOF'
[daemon]
WaylandEnable=false
EOF

    # Rotate the built-in display for Xorg sessions (including GDM).
    sudo mkdir -p /etc/X11/xorg.conf.d
    sudo tee /etc/X11/xorg.conf.d/10-monitor-rotate.conf >/dev/null <<'EOF'
Section "Monitor"
    Identifier "DSI-1"
    Option "Rotate" "right"
EndSection
EOF

    # Map touchscreen coordinates for 90 degree clockwise rotation.
    # Matrix corresponds to: x' = y, y' = 1 - x
    sudo tee /etc/X11/xorg.conf.d/40-libinput-touch-rotate.conf >/dev/null <<'EOF'
Section "InputClass"
    Identifier "Rotate touchscreen clockwise"
    MatchIsTouchscreen "on"
    Driver "libinput"
    Option "CalibrationMatrix" "0 1 0 -1 0 1 0 0 1"
EndSection
EOF
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

install_launcher_helpers() {
    echo "# Creating desktop launch wrappers..."

    sudo tee /usr/local/bin/gnome-wayland >/dev/null <<'EOF'
#!/bin/sh
if ! command -v gnome-session >/dev/null 2>&1; then
    echo "gnome-session is not installed. Re-run the base installer or install GNOME packages first." >&2
    exit 127
fi

exec env XDG_SESSION_TYPE=wayland XDG_RUNTIME_DIR="/run/user/$(id -u)" dbus-run-session gnome-session "$@"
EOF
    sudo chmod +x /usr/local/bin/gnome-wayland

    sudo tee /usr/local/bin/gnome-x11 >/dev/null <<'EOF'
#!/bin/sh
if ! command -v gnome-session >/dev/null 2>&1; then
    echo "gnome-session is not installed. Re-run the base installer or install GNOME packages first." >&2
    exit 127
fi

if ! command -v startx >/dev/null 2>&1; then
    echo "startx is not installed. Install xinit before launching GNOME X11." >&2
    exit 127
fi

exec dbus-run-session startx /usr/bin/gnome-session -- "$@"
EOF
    sudo chmod +x /usr/local/bin/gnome-x11

    sudo tee /usr/local/bin/hypr >/dev/null <<'EOF'
#!/bin/sh
if command -v start-hyprland >/dev/null 2>&1; then
    exec start-hyprland "$@"
fi

echo "start-hyprland is not installed. Install Hyprland from the Optional Window Managers menu first." >&2
exit 127
EOF
    sudo chmod +x /usr/local/bin/hypr
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
    disable_hyprland_fallback_repo
    # Run system update; if xbps still sees a broken shlib from a previous hyprland-void
    # install that survived the cleanup above, the transaction would abort with -euo pipefail.
    # Use || true so a dirty-state upgrade failure is reported but does not kill the script.
    sudo xbps-install -Suv || {
        echo "# [warn] xbps -Suv exited non-zero (may indicate a residual broken dependency)."
        echo "# Attempting targeted self-update and index refresh before continuing..."
        sudo xbps-install -Suv xbps 2>/dev/null || true
        sudo xbps-install -S || true
    }
    sudo xbps-install -y void-repo-nonfree 2>/dev/null || true
    sudo xbps-install -S

# Install core dependencies (deduped)
    echo "# Installing dependencies..."
    xi_install_safe curl wget git xz unzip zip nano vim gptfdisk xtools mtools mlocate ntfs-3g fuse-exfat
    xi_install_safe bash-completion linux-headers gtksourceview4 ffmpeg mesa mesa-dri mesa-vdpau mesa-vaapi
    xi_install_safe autoconf automake bison m4 make libtool flex meson ninja optipng sassc cmake cpio
    xi_install_safe trash-cli fastfetch tree zoxide starship eza bat fzf chafa w3m fontconfig
    xi_install_safe base-devel gcc linux-firmware iw tmux sshpass htop multitail bluetuith dconf fwupd kitty
    xi_install_safe python3 nodejs npm lnav ulauncher nvtop wmctrl xdotool libinput
    xi_install_safe xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr xdg-user-dirs xdg-user-dirs-gtk xdg-utils
    xi_install_safe dbus elogind polkit gnome-browser-connector

# GNOME stack
    echo "# Installing GNOME..."
    xi_install_safe xorg xorg-server-xwayland xinit xauth xterm twm
    xi_install_safe gnome gnome-session gnome-shell gnome-keyring
    install_optional_packages gnome-disk-utility gnome-calculator seahorse gnome-shell-extensions
    if [ "$VOID_INSTALL_GDM" = "1" ]; then
        xi_install_safe gdm
    else
        echo "# VOID_INSTALL_GDM is not enabled; skipping GDM install."
    fi

# Networking, audio, Bluetooth, power
    xi_install_safe NetworkManager NetworkManager-openvpn NetworkManager-openconnect NetworkManager-vpnc NetworkManager-l2tp network-manager-applet wpa_supplicant
    # pipewire-pulse is optional — absent in some Void mirrors; core PipeWire session still works
    xi_install_safe pipewire alsa-pipewire alsa-utils wireplumber wireplumber-elogind playerctl pavucontrol pamixer cava pulseaudio-utils pulsemixer rtkit
    xi_install_safe pipewire-pulse
    xi_install_safe bluez cronie tlp tlp-rdw powertop

# Wayland / compositor utilities
    # waybar is occasionally absent from tier-2 mirrors; install individually so one failure
    # does not abort the rest of the Wayland toolkit.
    xi_install_safe wl-clipboard waybar fuzzel wlogout libnotify dunst brightnessctl nwg-look

# Fonts and font config
    xi_install_safe noto-fonts-emoji noto-fonts-ttf noto-fonts-ttf-extra
    sudo ln -sf /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/
    sudo xbps-reconfigure -f fontconfig
    configure_pipewire_session

# Enable core services
    echo "# Enabling desktop services..."
    enable_service dbus
    enable_service elogind
    enable_service polkitd
    enable_service NetworkManager
    enable_service bluetoothd
    enable_service cronie
    enable_service tlp
    enable_service alsa
    enable_service rtkit 0

    if [ "$VOID_INSTALL_GDM" = "1" ]; then
        configure_gdm_for_portrait_touchscreen
        enable_service gdm
    else
        echo "# GDM disabled by default. Set VOID_INSTALL_GDM=1 to install and enable it."
    fi

    sudo usermod -aG bluetooth "$username" || true

    install_launcher_helpers

# Flatpak
    echo -e "${YELLOW}Installing Flatpak & adding Flathub...${NC}"
    xi_install_safe flatpak
    if command -v flatpak >/dev/null 2>&1; then
        sudo flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        sudo flatpak install --system flathub net.waterfox.waterfox -y
        sudo flatpak install --system flathub md.obsidian.Obsidian -y
        sudo flatpak install --system flathub org.libreoffice.LibreOffice -y
        sudo flatpak install --system flathub org.qbittorrent.qBittorrent -y
        sudo flatpak install --system flathub io.missioncenter.MissionCenter -y
        sudo flatpak install --system flathub com.synology.SynologyDrive -y
        sudo flatpak install --system flathub io.github.shiftey.Desktop -y # Github Desktop
        sudo flatpak install --system flathub com.mattjakeman.ExtensionManager -y
    else
        echo "# [warn] flatpak not available; skipping Flathub app installs"
    fi

# VS Code (native install)
    echo "# Installing VS Code natively..."
    mkdir -p "$HOME/.local/opt/vscode" "$HOME/.local/bin"
    
    # Download VS Code if not already present
    if [ ! -f "$HOME/Downloads/code.tar.gz" ]; then
        echo "# Downloading VS Code from update server..."
        cd "$HOME/Downloads"
        wget -q -O code.tar.gz https://update.code.visualstudio.com/latest/linux-x64/stable || {
            echo "# Warning: Failed to download VS Code. Skipping native install."
            echo "# Download manually: wget -q -O ~/Downloads/code.tar.gz https://update.code.visualstudio.com/latest/linux-x64/stable"
        }
        cd - >/dev/null
    fi
    
    # Extract if archive exists
    if [ -f "$HOME/Downloads/code.tar.gz" ]; then
        echo "# Extracting VS Code..."
        tar -xzf "$HOME/Downloads/code.tar.gz" -C "$HOME/.local/opt/vscode" --strip-components=1 2>/dev/null || true
        ln -snf "$HOME/.local/opt/vscode/bin/code" "$HOME/.local/bin/code"
        if ! grep -q 'export PATH.*\.local/bin' "$HOME/.bashrc"; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        fi
        echo "# VS Code installed to $HOME/.local/opt/vscode"
    fi

# Firewall
    xi_install_safe ufw
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw allow OpenSSH
        enable_service ufw 0
    fi

# Yazi
    xi_install_safe yazi 7zip jq poppler fd ripgrep ImageMagick
    if command -v yazi >/dev/null 2>&1 && command -v ya >/dev/null 2>&1; then
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
    else
        echo "# [warn] yazi or 'ya' not available; skipping Yazi plugin install"
    fi

# Apps to remove
    sudo xbps-remove -Ry firefox 2>/dev/null || true
    sudo xbps-remove -Ry epiphany 2>/dev/null || true

# Tailscale
    xi_install_safe tailscale
    if pkg_installed tailscale; then
        enable_service tailscaled
    fi

# Theme stuffs
    xi_install_safe papirus-icon-theme

# Install fonts
    echo "Installing Fonts"
    cd "$builddir" || exit
    xi_install_safe font-firacode-nerd font-jetbrains-mono-nerd noto-fonts-emoji terminus-font
    # Reload Font
    fc-cache -vf

# OpenSSH
    echo "# Enabling OpenSSH Service..."
    xi_install_safe openssh
    if pkg_installed openssh; then
        enable_service sshd
    fi

# System Control Services
    echo "# Enabling Audio, Bluetooth, WiFi and CUPS services..."
    # Enable Audio
        enable_service alsa
    # Enable Printer
        xi_install_safe cups gutenprint cups-pk-helper nmap net-tools
        if pkg_installed cups; then
            enable_service cupsd
        fi
    # Add dialout group for ZMK / VIA keyboards
        sudo usermod -aG uucp "$USER"
