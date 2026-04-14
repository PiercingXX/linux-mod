#!/bin/bash
# GitHub.com/PiercingXX

set -euo pipefail

XI="sudo xbps-install -y"
REAL_USER="${SUDO_USER:-${USER:-}}"
HYPR_SOURCE_FALLBACK="${HYPR_SOURCE_FALLBACK:-1}"
VOID_FORCE_DEFAULT_MIRROR="${VOID_FORCE_DEFAULT_MIRROR:-1}"

setup_void_default_mirror() {
    local libc
    libc="glibc"
    if ldd --version 2>&1 | grep -qi musl; then
        libc="musl"
    fi

    echo "Configuring stable default Void mirrors..."

    if [ "$libc" = "musl" ]; then
        sudo tee /etc/xbps.d/00-repository-main.conf >/dev/null <<'EOF'
repository=https://repo-default.voidlinux.org/current/musl
repository=https://repo-default.voidlinux.org/current/musl/nonfree
EOF
    else
        sudo tee /etc/xbps.d/00-repository-main.conf >/dev/null <<'EOF'
repository=https://repo-default.voidlinux.org/current
repository=https://repo-default.voidlinux.org/current/nonfree
repository=https://repo-default.voidlinux.org/current/multilib
repository=https://repo-default.voidlinux.org/current/multilib/nonfree
EOF
    fi

    sudo xbps-install -S
}

xi_install() {
    if ! $XI "$@"; then
        echo "Initial xbps install failed, refreshing repository index and retrying..."
        sudo xbps-install -S
        $XI "$@"
    fi
}

install_hyprland_from_source() {
    local build_root
    build_root="/tmp/hyprland-void-build"

    echo "Binary Hyprland install failed; falling back to source build."
    echo "This can take a while depending on CPU and network speed."

    xi_install base-devel git

    rm -rf "$build_root"
    mkdir -p "$build_root"

    git clone --depth=1 https://github.com/void-linux/void-packages "$build_root/void-packages"
    git clone --depth=1 https://github.com/Makrennel/hyprland-void "$build_root/hyprland-void"

    (
        cd "$build_root/void-packages"
        ./xbps-src binary-bootstrap
    )

    # Override Hyprland-related shlibs entries with versions from hyprland-void
    # so pkglint does not reject the older, internally consistent SONAME set.
    while read -r shlib_line; do
        [ -z "$shlib_line" ] && continue
        case "$shlib_line" in
            \#*) continue ;;
        esac

        shlib_name="${shlib_line%% *}"
        shlib_base="${shlib_name%%.so*}.so"
        shlib_base_escaped="$(printf '%s' "$shlib_base" | sed 's/[.[\*^$()+?{}|]/\\&/g')"

        case "$shlib_name" in
            libhypr*|libaquamarine*|libsdbus-c++*|libspng*|libtomlplusplus*)
                # Remove all SONAME variants (e.g. .so.10, .so.6) before appending
                # the version expected by the hyprland-void templates.
                sed -E -i "/^${shlib_base_escaped}(\.[0-9]+(\.[0-9]+)*)?[[:space:]]/d" "$build_root/void-packages/common/shlibs"
                echo "$shlib_line" >> "$build_root/void-packages/common/shlibs"
                ;;
        esac
    done < "$build_root/hyprland-void/common/shlibs"

    cp -r --remove-destination "$build_root/hyprland-void/srcpkgs"/* "$build_root/void-packages/srcpkgs/"

    (
        cd "$build_root/void-packages"
        ./xbps-src pkg \
            hyprutils hyprlang hyprgraphics hyprwayland-scanner aquamarine \
            hyprland hyprpaper hyprlock hypridle hyprcursor xdg-desktop-portal-hyprland
    )

    sudo xbps-install -yR "$build_root/void-packages/hostdir/binpkgs" \
        hyprutils hyprlang hyprgraphics hyprwayland-scanner aquamarine \
        hyprland hyprpaper hyprlock hypridle hyprcursor xdg-desktop-portal-hyprland
}

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

if [ "$VOID_FORCE_DEFAULT_MIRROR" = "1" ]; then
    setup_void_default_mirror
fi

# Ensure build dependencies are available
echo "Ensuring build dependencies are available..."
# Hyprland is installed from binary repositories here, so avoid base-devel
# to reduce failures on out-of-sync mirrors and cut install time.
xi_install git cmake meson pkg-config

# Install core Hyprland components
# Try official Void repositories first. If dependency resolution fails,
# fall back to hyprland-void repository with a full index/upgrade refresh.
echo "Installing Hyprland core components..."
if ! xi_install hyprland hyprpaper hyprlock hypridle hyprcursor xdg-desktop-portal-hyprland; then
    echo "Official repo install failed; enabling hyprland-void fallback repo..."
    setup_hyprland_repo

    # Sync the index — do NOT run a full `xbps-install -uy` here.
    # A full upgrade with both repos active causes the solver to see packages
    # from hyprland-void that require libhyprutils.so.6 while the official
    # repo's hyprutils provides an incompatible soname, aborting the transaction.
    sudo xbps-install -S

    # Force-install Hyprland deps from the hyprland-void repo to ensure the
    # correct soname/ABI is on disk before the main Hyprland packages are resolved.
    # -f overrides the version check so xbps won't refuse to "downgrade" hyprutils
    # if the official repo has a newer (ABI-incompatible) version installed already.
    _hypr_repo="$(hypr_repo_url)"
    if ! sudo xbps-install -fy -R "$_hypr_repo" \
            hyprutils hyprlang hyprgraphics hyprwayland-scanner aquamarine; then
        if [ "$HYPR_SOURCE_FALLBACK" = "1" ]; then
            install_hyprland_from_source
        else
            echo "Hyprland dependency chain is unresolved in binary repos, and source fallback is disabled." >&2
            exit 1
        fi
    fi

    if ! xi_install hyprland hyprpaper hyprlock hypridle hyprcursor xdg-desktop-portal-hyprland; then
        if [ "$HYPR_SOURCE_FALLBACK" = "1" ]; then
            install_hyprland_from_source
        else
            echo "Hyprland packages remain unresolved in binary repos, and source fallback is disabled." >&2
            exit 1
        fi
    fi
fi
xi_install polkit-gnome
xi_install seatd elogind dbus
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
xi_install wlsunset
xi_install wl-clipboard

# Set up Waybar and menus
xi_install Waybar
xi_install fuzzel
xi_install wlogout
xi_install libnotify
xi_install dunst
xi_install brightnessctl

# Add screenshot and clipboard utilities
xi_install grim
xi_install slurp
xi_install cliphist

# Install audio tools
xi_install pipewire
xi_install alsa-utils
xi_install pamixer
xi_install cava
xi_install wireplumber
xi_install playerctl
xi_install pavucontrol

# Network and Bluetooth utilities
xi_install NetworkManager
xi_install network-manager-applet
xi_install bluez
xi_install bluetuith

# GUI customization tools
xi_install nwg-look
xi_install dconf

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
