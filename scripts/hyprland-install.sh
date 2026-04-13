#!/bin/bash
# GitHub.com/PiercingXX

set -euo pipefail

XI="sudo xbps-install -y"
REAL_USER="${SUDO_USER:-${USER:-}}"

hypr_repo_url() {
    local arch libc
    arch="$(uname -m)"
    if ldd --version 2>&1 | grep -qi musl; then
        libc="musl"
    else
        libc="glibc"
    fi

    case "$arch" in
        x86_64|aarch64) ;;
        *)
            echo "Unsupported architecture for hyprland-void binaries: $arch" >&2
            exit 1
            ;;
    esac

    echo "https://raw.githubusercontent.com/Makrennel/hyprland-void/repository-${arch}-${libc}"
}

setup_hyprland_repo() {
    local repo_url conf_file
    repo_url="$(hypr_repo_url)"
    conf_file="/etc/xbps.d/hyprland-void.conf"

    echo "Configuring Hyprland binary repository: ${repo_url}"
    echo "repository=${repo_url}" | sudo tee "${conf_file}" >/dev/null
    sudo xbps-install -S
}

enable_service() {
    local service_name="$1"
    if [ -d "/etc/sv/$service_name" ]; then
        sudo ln -sf "/etc/sv/$service_name" /var/service/
        sudo sv up "$service_name" || true
    fi
}

# Ensure build dependencies are available
echo "Ensuring build dependencies are available..."
$XI base-devel
$XI git
$XI cmake
$XI meson
$XI pkg-config

# Install core Hyprland components
# NOTE: Hyprland and its ecosystem are available in the void-packages repo.
echo "Installing Hyprland core components..."
setup_hyprland_repo
$XI hyprland hyprpaper hyprlock hypridle hyprcursor xdg-desktop-portal-hyprland
$XI polkit-gnome
$XI seatd elogind dbus
enable_service seatd
enable_service elogind
enable_service dbus

if [ -n "$REAL_USER" ]; then
    sudo usermod -aG _seatd "$REAL_USER" || true
fi

# Hyprland wiki recommends launching from TTY with start-hyprland.
# Always install wrappers so launch behavior is consistent across systems.
echo "Creating /usr/local/bin/start-hyprland wrapper..."
sudo tee /usr/local/bin/start-hyprland >/dev/null <<'EOF'
#!/bin/sh
if command -v hyprland >/dev/null 2>&1; then
    exec dbus-run-session hyprland "$@"
fi
if command -v Hyprland >/dev/null 2>&1; then
    exec dbus-run-session Hyprland "$@"
fi
echo "Hyprland binary not found in PATH." >&2
exit 127
EOF
sudo chmod +x /usr/local/bin/start-hyprland

echo "Creating /usr/local/bin/hypr wrapper..."
sudo tee /usr/local/bin/hypr >/dev/null <<'EOF'
#!/bin/sh
exec /usr/local/bin/start-hyprland "$@"
EOF
sudo chmod +x /usr/local/bin/hypr

# Install additional utilities
$XI wlsunset
$XI wl-clipboard

# Set up Waybar and menus
$XI waybar
$XI fuzzel
$XI wlogout
$XI libnotify
$XI dunst
$XI brightnessctl

# Install file manager and customization tools
$XI thunar
$XI thunar-volman

# Add screenshot and clipboard utilities
$XI grim
$XI slurp
$XI cliphist

# Install audio tools
 $XI pipewire
 $XI pipewire-pulse
 $XI alsa-utils
$XI pamixer
$XI cava
$XI wireplumber
$XI playerctl
$XI pavucontrol

# Network and Bluetooth utilities
$XI NetworkManager
$XI network-manager-applet
$XI bluez
$XI bluetuith

# GUI customization tools
$XI nwg-look
$XI dconf

# Hyprland plugins via hyprpm (if hyprpm is available)
if command -v hyprpm &>/dev/null; then
    echo "Updating and loading Hyprland plugin manager..."
    hyprpm update
    hyprpm reload

    echo "Adding Hyprland plugins..."
    hyprpm add https://github.com/hyprwm/hyprland-plugins || echo "Warning: Failed to add hyprland-plugins"
    hyprpm add https://github.com/virtcode/hypr-dynamic-cursors || echo "Warning: Failed to add hypr-dynamic-cursors"
    hyprpm enable dynamic-cursors || echo "Warning: Failed to enable dynamic-cursors"
    hyprpm add https://github.com/horriblename/hyprgrass || echo "Warning: Failed to add hyprgrass"
    hyprpm enable hyprgrass || echo "Warning: Failed to enable hyprgrass"
else
    echo "hyprpm not found, skipping plugin install."
fi

# Success message
echo -e "\nAll Hyprland packages and plugins installed successfully!"
echo "Start from TTY with: start-hyprland"
echo "Shortcut command also available: hypr"
