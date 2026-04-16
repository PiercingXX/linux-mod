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

disable_stale_hyprland_repo() {
    local repo_conf="/etc/xbps.d/hyprland-void.conf"

    if [ -f "$repo_conf" ]; then
        echo "Disabling stale hyprland-void repository configuration..."
        sudo mv "$repo_conf" "${repo_conf}.disabled"
    fi

    # Purge cached metadata from previous hyprland-void/Makrennel mirrors so
    # xbps does not keep resolving against stale ABI indexes.
    sudo find /var/db/xbps/ -maxdepth 1 \
        \( -name '*hyprland-void*' -o -name '*Makrennel*' \) \
        -delete 2>/dev/null || true
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

configure_hyprland_audio_startup() {
    local target_user target_home execs_file
    target_user="${REAL_USER:-${USER:-}}"

    if [ -z "$target_user" ]; then
        return 0
    fi

    target_home="$(getent passwd "$target_user" | cut -d: -f6)"
    if [ -z "$target_home" ]; then
        return 0
    fi

    execs_file="$target_home/.config/hypr/hyprland/execs.conf"
    if [ ! -f "$execs_file" ]; then
        return 0
    fi

    sudo -u "$target_user" bash -lc '
set -e
file="$1"

line1="exec-once = bash -lc '\''pgrep -x pipewire >/dev/null || (pipewire >/tmp/pipewire.log 2>&1 &) '\''"
line2="exec-once = bash -lc '\''pgrep -x wireplumber >/dev/null || (wireplumber >/tmp/wireplumber.log 2>&1 &) '\''"
line3="exec-once = bash -lc '\''pgrep -f \"pipewire -c pipewire-pulse.conf\" >/dev/null || (pipewire -c pipewire-pulse.conf >/tmp/pipewire-pulse.log 2>&1 &) '\''"

grep -Fqx "$line1" "$file" || printf "\n%s\n" "$line1" >> "$file"
grep -Fqx "$line2" "$file" || printf "%s\n" "$line2" >> "$file"
grep -Fqx "$line3" "$file" || printf "%s\n" "$line3" >> "$file"
' bash "$execs_file"
}

configure_hyprsunset() {
    # hyprsunset.conf is deployed via piercing-dots; installer only adds the exec-once autostart
    local target_user target_home execs_file
    target_user="${REAL_USER:-${USER:-}}"

    if [ -z "$target_user" ]; then
        return 0
    fi

    target_home="$(getent passwd "$target_user" | cut -d: -f6)"
    if [ -z "$target_home" ]; then
        return 0
    fi

    execs_file="$target_home/.config/hypr/hyprland/execs.conf"

    if [ -f "$execs_file" ]; then
        sudo -u "$target_user" bash -lc '
set -e
file="$1"
line="exec-once = bash -lc '\''pgrep -x hyprsunset >/dev/null || hyprsunset'\''"

grep -Fqx "$line" "$file" || printf "\n%s\n" "$line" >> "$file"
' bash "$execs_file"
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

    if [ ! -d "/etc/sv/$service_name" ]; then
        echo "Missing service directory: /etc/sv/$service_name"
        [ "$required" -eq 1 ] && return 1
        return 0
    fi

    if ! service_dir="$(get_runit_service_dir)"; then
        echo "Unable to determine runit service directory: $service_name"
        [ "$required" -eq 1 ] && return 1
        return 0
    fi

    sudo mkdir -p "$service_dir"
    sudo rm -f "$service_dir/$service_name"
    sudo ln -s "/etc/sv/$service_name" "$service_dir/$service_name"

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
        echo "Failed to start service automatically: $service_name"
        echo "Expected service files in /etc/sv/$service_name and supervision via $service_dir/$service_name"
        [ "$required" -eq 1 ] && return 1
    fi
}

if [ "$VOID_FORCE_DEFAULT_MIRROR" = "1" ]; then
    setup_void_default_mirror
fi
disable_stale_hyprland_repo
sudo xbps-install -S

# Ensure build dependencies are available
echo "Ensuring build dependencies are available..."
# Hyprland is installed from binary repositories here, so avoid base-devel
# to reduce failures on out-of-sync mirrors and cut install time.
xi_install git cmake meson pkg-config
xi_install mesa mesa-dri mesa-vulkan-intel

# Install core Hyprland components
# Try official Void repositories first. If dependency resolution fails,
# fall back to hyprland-void repository with a full index/upgrade refresh.
echo "Installing Hyprland core components..."
if ! xi_install hyprutils hyprlang hyprgraphics hyprwayland-scanner aquamarine \
    hyprland hyprpaper hyprlock hypridle hyprcursor xdg-desktop-portal-hyprland; then
    echo "Official repo install failed; enabling hyprland-void fallback repo..."
    setup_hyprland_repo
    sudo xbps-install -S

    # Remove any installed Hyprland packages that carry the wrong ABI soname.
    # This clears the solver's view of broken shlib requirements so xbps can
    # plan a clean install from hyprland-void without hitting the
    # "libhyprutils.so.6 unresolvable" abort.
    echo "Clearing stale Hyprland packages before ABI-consistent reinstall..."
    sudo xbps-remove -Fy \
        aquamarine hyprcursor hyprgraphics hypridle hyprland hyprlang \
        hyprlock hyprpaper hyprutils hyprwayland-scanner \
        xdg-desktop-portal-hyprland 2>/dev/null || true

    if ! $XI hyprutils hyprlang hyprgraphics hyprwayland-scanner aquamarine; then
        if [ "$HYPR_SOURCE_FALLBACK" = "1" ]; then
            install_hyprland_from_source
        else
            echo "Hyprland dependency chain is unresolved in binary repos, and source fallback is disabled." >&2
            exit 1
        fi
    fi

    if ! $XI hyprutils hyprlang hyprgraphics hyprwayland-scanner aquamarine \
        hyprland hyprpaper hyprlock hypridle hyprcursor xdg-desktop-portal-hyprland; then
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
xi_install hyprsunset
xi_install wl-clipboard

# Set up Waybar and menus
xi_install waybar
xi_install fuzzel
xi_install wlogout
xi_install libnotify
xi_install dunst
xi_install brightnessctl

# Add screenshot and clipboard utilities
xi_install grim
xi_install slurp
xi_install cliphist

# Install hyprshot (not in Void repos, install from upstream)
if ! command -v hyprshot >/dev/null 2>&1; then
    sudo curl -fsSL https://raw.githubusercontent.com/Gustash/Hyprshot/main/hyprshot \
        -o /usr/local/bin/hyprshot
    sudo chmod +x /usr/local/bin/hyprshot
fi

# Install audio tools
xi_install pipewire
xi_install pipewire-pulse
xi_install alsa-pipewire
xi_install alsa-utils
xi_install rtkit
xi_install pamixer
xi_install cava
xi_install wireplumber
xi_install wireplumber-elogind
xi_install playerctl
xi_install pavucontrol
configure_pipewire_session
configure_hyprland_audio_startup
configure_hyprsunset
enable_service alsa
enable_service rtkit 0

# Network and Bluetooth utilities
xi_install NetworkManager
xi_install network-manager-applet
xi_install bluez
xi_install bluetuith

# GUI customization tools
xi_install nwg-look
xi_install hyprland-qt-support
xi_install hyprland-qtutils
xi_install qt5ct
xi_install qt6ct
xi_install dconf

# Hyprland plugins via hyprpm (if hyprpm is available)
if command -v hyprpm &>/dev/null; then
    echo "Updating and loading Hyprland plugin manager..."
    # hyprpm update clones and builds Hyprland from source to compile plugins.
    # On Void, GLES/OpenGL and Wayland headers come from these packages.
    xi_install wayland-devel wayland-protocols MesaLib-devel || true

    if ! hyprpm update; then
        echo "Warning: hyprpm update failed (plugin build prerequisites may still be missing)."
        echo "Hyprland itself is installed; skipping plugin operations."
    else
        hyprpm reload || true

        echo "Adding Hyprland plugins..."
        hyprpm add https://github.com/hyprwm/hyprland-plugins || echo "Warning: Failed to add hyprland-plugins"
        hyprpm add https://github.com/virtcode/hypr-dynamic-cursors || echo "Warning: Failed to add hypr-dynamic-cursors"
        hyprpm enable dynamic-cursors || echo "Warning: Failed to enable dynamic-cursors"
        hyprpm add https://github.com/horriblename/hyprgrass || echo "Warning: Failed to add hyprgrass"
        hyprpm enable hyprgrass || echo "Warning: Failed to enable hyprgrass"
    fi
else
    echo "hyprpm not found, skipping plugin install."
fi

# Success message
echo -e "\nAll Hyprland packages and plugins installed successfully!"
echo "Start from TTY with: start-hyprland"
echo "Shortcut command also available: hypr"
