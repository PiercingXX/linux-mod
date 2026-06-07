#!/bin/bash
# GitHub.com/PiercingXX

set -uo pipefail

XI="sudo xbps-install"
REAL_USER="${SUDO_USER:-${USER:-}}"
HYPR_SOURCE_FALLBACK="${HYPR_SOURCE_FALLBACK:-1}"
VOID_FORCE_DEFAULT_MIRROR="${VOID_FORCE_DEFAULT_MIRROR:-1}"
HYPR_REPO_PRIORITY="${HYPR_REPO_PRIORITY:-source}"
HYPRLAND_TEMPLATE_REPO="${HYPRLAND_TEMPLATE_REPO:-https://github.com/Makrennel/hyprland-void}"
HYPRLAND_TEMPLATE_REF="${HYPRLAND_TEMPLATE_REF:-}"
HYPRSUNSET_PINNED_HYPRUTILS="${HYPRSUNSET_PINNED_HYPRUTILS:-hyprutils-0.2.4_1}"
HYPRSUNSET_PINNED_HYPRLANG="${HYPRSUNSET_PINNED_HYPRLANG:-hyprlang-0.6.7_1}"
HYPRSUNSET_PINNED_PACKAGE="${HYPRSUNSET_PINNED_PACKAGE:-hyprsunset-0.2.0_1}"

HYPRLAND_CORE_PACKAGES=(
    hyprutils hyprlang hyprgraphics hyprwayland-scanner aquamarine
    hyprland hyprpaper hyprlock hypridle hyprcursor xdg-desktop-portal-hyprland
)

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

# Package guard helpers — same semantics as step-1.sh.
# xi_install_safe: check installed → check available → install; never aborts.
# Use this for optional utilities that may be absent from some mirrors.
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

xi_install_optional() {
    if ! xi_install "$@"; then
        echo "Warning: optional package install failed: $*"
        return 1
    fi
}

git_clone_at_ref() {
    local repo_url="$1"
    local dest_dir="$2"
    local ref="${3:-}"

    rm -rf "$dest_dir"
    git clone --depth=1 "$repo_url" "$dest_dir"

    if [ -n "$ref" ]; then
        (
            cd "$dest_dir" || exit
            git fetch --depth=1 origin "$ref"
            git checkout --detach FETCH_HEAD
        )
    fi
}

installed_pkgver() {
    xbps-query -p pkgver "$1" 2>/dev/null | sed 's/^pkgver: //'
}

hyprsunset_pinned_stack_installed() {
    [ "$(installed_pkgver hyprutils)" = "${HYPRSUNSET_PINNED_HYPRUTILS#hyprutils-}" ] && \
    [ "$(installed_pkgver hyprlang)" = "${HYPRSUNSET_PINNED_HYPRLANG#hyprlang-}" ] && \
    [ "$(installed_pkgver hyprsunset)" = "${HYPRSUNSET_PINNED_PACKAGE#hyprsunset-}" ]
}

install_pinned_hyprsunset_stack() {
    echo "Installing pinned hyprsunset compatibility stack from hyprland-void repository..."
    setup_hyprland_repo
    sudo xbps-install -S
    sudo xbps-install -f \
        "$HYPRSUNSET_PINNED_HYPRUTILS" \
        "$HYPRSUNSET_PINNED_HYPRLANG" \
        "$HYPRSUNSET_PINNED_PACKAGE"
}

install_hyprsunset_with_fallback() {
    if command -v hyprsunset >/dev/null 2>&1 && hyprsunset_pinned_stack_installed; then
        echo "Pinned hyprsunset compatibility stack already installed."
        return 0
    fi

    if xi_install hyprsunset; then
        return 0
    fi

    echo "hyprsunset install failed from current repos; trying pinned compatibility fallback..."

    if install_pinned_hyprsunset_stack; then
        return 0
    fi

    echo "Pinned hyprsunset compatibility install failed."
    if [ "$HYPR_SOURCE_FALLBACK" = "1" ]; then
        echo "Falling back to source build for Hyprland stack including hyprsunset..."
        install_hyprland_from_source
        command -v hyprsunset >/dev/null 2>&1
        return
    fi

    echo "hyprsunset remains unresolved and source fallback is disabled." >&2
    return 1
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
    git_clone_at_ref "$HYPRLAND_TEMPLATE_REPO" "$build_root/hyprland-void" "$HYPRLAND_TEMPLATE_REF"

    (
        cd "$build_root/void-packages" || exit
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
        # shellcheck disable=SC2016
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
        cd "$build_root/void-packages" || exit
        ./xbps-src pkg \
            hyprutils hyprlang hyprgraphics hyprwayland-scanner aquamarine \
            hyprland hyprpaper hyprlock hypridle hyprcursor hyprsunset \
            hyprland-qt-support hyprland-qtutils xdg-desktop-portal-hyprland
    )

    sudo xbps-install -R "$build_root/void-packages/hostdir/binpkgs" \
        hyprutils hyprlang hyprgraphics hyprwayland-scanner aquamarine \
        hyprland hyprpaper hyprlock hypridle hyprcursor hyprsunset \
        hyprland-qt-support hyprland-qtutils xdg-desktop-portal-hyprland
}

remove_hyprland_core_stack() {
    sudo xbps-remove -Fy "${HYPRLAND_CORE_PACKAGES[@]}" 2>/dev/null || true
}

install_hyprland_core_from_official_repo() {
    echo "Installing Hyprland core components from official Void repositories..."
    xi_install "${HYPRLAND_CORE_PACKAGES[@]}"
}

install_hyprland_core_from_hyprland_repo() {
    echo "Installing Hyprland core components from hyprland-void repository..."
    setup_hyprland_repo
    sudo xbps-install -S
    remove_hyprland_core_stack
    $XI "${HYPRLAND_CORE_PACKAGES[@]}"
}

install_hyprland_core_packages() {
    case "$HYPR_REPO_PRIORITY" in
        hyprland-void)
            if install_hyprland_core_from_hyprland_repo; then
                return 0
            fi

            echo "hyprland-void install failed; trying official Void repositories..."
            if install_hyprland_core_from_official_repo; then
                return 0
            fi
            ;;
        official)
            if install_hyprland_core_from_official_repo; then
                return 0
            fi

            echo "Official repo install failed; enabling hyprland-void fallback repo..."
            if install_hyprland_core_from_hyprland_repo; then
                return 0
            fi
            ;;
        source)
            install_hyprland_from_source
            return 0
            ;;
        *)
            echo "Unsupported HYPR_REPO_PRIORITY value: $HYPR_REPO_PRIORITY" >&2
            return 1
            ;;
    esac

    if [ "$HYPR_SOURCE_FALLBACK" = "1" ]; then
        install_hyprland_from_source
        return 0
    fi

    echo "Hyprland packages remain unresolved, and source fallback is disabled." >&2
    return 1
}

require_hyprland_qt_packages() {
    if xi_install hyprland-qt-support hyprland-qtutils; then
        return 0
    fi

    echo "Hyprland Qt packages failed from current repos; enabling hyprland-void fallback repo..."
    setup_hyprland_repo
    sudo xbps-install -S

    if xi_install hyprland-qt-support hyprland-qtutils; then
        return 0
    fi

    echo "Failed to install hyprland-qt-support and hyprland-qtutils." >&2
    return 1
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
line3="exec-once = bash -lc '\''pgrep -x pipewire-pulse >/dev/null || (pipewire-pulse >/tmp/pipewire-pulse.log 2>&1 &) '\''"

grep -Fqx "$line1" "$file" || printf "\n%s\n" "$line1" >> "$file"
grep -Fqx "$line2" "$file" || printf "%s\n" "$line2" >> "$file"
grep -Fqx "$line3" "$file" || printf "%s\n" "$line3" >> "$file"
' bash "$execs_file"
}

configure_hyprsunset() {
    # On Void's hyprsunset version, schedule profiles are unreliable.
    # Use the scheduler script from piercing-dots when available.
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
line="exec-once = bash -lc '\''pgrep -af \"hyprsunset-scheduler.sh\" >/dev/null || ~/.scripts/Control-Scripts/hyprsunset-scheduler.sh >/tmp/hyprsunset-scheduler.log 2>&1 &'\''"

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

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

resolve_hyprland_binary() {
    local candidate

    for candidate in \
        "$(command -v Hyprland 2>/dev/null || true)" \
        "$(command -v hyprland 2>/dev/null || true)" \
        /usr/bin/Hyprland \
        /usr/bin/hyprland \
        /usr/local/bin/Hyprland \
        /usr/local/bin/hyprland; do
        [ -n "$candidate" ] || continue
        [ -x "$candidate" ] || continue
        printf '%s\n' "$candidate"
        return 0
    done

    return 1
}

service_enabled() {
    local service_name="$1"

    [ -L "/var/service/$service_name" ] && return 0
    [ -L "/etc/runit/runsvdir/current/$service_name" ] && return 0
    [ -L "/etc/runit/runsvdir/default/$service_name" ] && return 0
    return 1
}

post_install_hypr_report() {
    local missing=()
    local cmd
    local svc

    echo "Running Hyprland post-install validation..."

    for cmd in start-hyprland hyprlock hypridle hyprpaper xdg-desktop-portal-hyprland; do
        if ! command_exists "$cmd"; then
            missing+=("missing-command:$cmd")
        fi
    done

    if ! resolve_hyprland_binary >/dev/null 2>&1; then
        missing+=("missing-command:Hyprland")
    fi

    for svc in seatd elogind dbus NetworkManager; do
        if ! service_enabled "$svc"; then
            missing+=("service-not-enabled:$svc")
        fi
    done

    if [ "${#missing[@]}" -eq 0 ]; then
        echo "Hyprland report: all core checks passed."
        return 0
    fi

    echo "Hyprland report: non-fatal warnings detected"
    for item in "${missing[@]}"; do
        echo " - $item"
    done
    echo "Re-run this installer after fixing network/repository issues if needed."
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
# By default, prefer the newer hyprland-void repo. Set HYPR_REPO_PRIORITY=official
# to keep the old official-first behavior, or HYPR_REPO_PRIORITY=source to force
# a source build using HYPRLAND_TEMPLATE_REPO / HYPRLAND_TEMPLATE_REF.
echo "Installing Hyprland core components..."
install_hyprland_core_packages || exit 1
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
HYPR_BIN=""

for candidate in \
    "$(command -v Hyprland 2>/dev/null || true)" \
    "$(command -v hyprland 2>/dev/null || true)" \
    /usr/bin/Hyprland \
    /usr/bin/hyprland \
    /usr/local/bin/Hyprland \
    /usr/local/bin/hyprland; do
    [ -n "$candidate" ] || continue
    if [ -x "$candidate" ]; then
        HYPR_BIN="$candidate"
        break
    fi
done

if [ -n "$HYPR_BIN" ]; then
    exec dbus-run-session "$HYPR_BIN" "$@"
fi

echo "Hyprland binary not found in PATH or expected install locations." >&2
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
xi_install_safe wlsunset
install_hyprsunset_with_fallback
xi_install wl-clipboard
xi_install xdg-user-dirs xdg-utils xdg-desktop-portal xdg-desktop-portal-gtk
xi_install gum kitty neovim jq yazi nautilus gnome-keyring

# Set up menus — use xi_install_safe for utilities that may lag on some mirrors
xi_install_safe nwg-drawer
xi_install_safe fuzzel
xi_install_safe wlogout
xi_install libnotify
xi_install_safe notification-daemon
xi_install_safe dunst
xi_install_safe swaync
xi_install_safe brightnessctl
xi_install_safe easyeffects
xi_install_safe wl-gammarelay

# Add screenshot and clipboard utilities
xi_install_safe grim
xi_install_safe slurp
xi_install_safe cliphist
xi_install_safe hyprpicker
xi_install_safe satty
xi_install_safe swappy
xi_install_safe wf-recorder

# Install hyprshot (not in Void repos, install from upstream)
if ! command -v hyprshot >/dev/null 2>&1; then
    sudo curl -fsSL https://raw.githubusercontent.com/Gustash/Hyprshot/main/hyprshot \
        -o /usr/local/bin/hyprshot
    sudo chmod +x /usr/local/bin/hyprshot
fi

# Install audio tools
# pipewire-pulse is the ALSA-compat shim — absent on some mirrors; core session still works.
xi_install pipewire
xi_install_safe pipewire-pulse
xi_install alsa-pipewire
xi_install alsa-utils
xi_install rtkit
xi_install pamixer
xi_install_safe cava
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
xi_install_safe bluetuith
enable_service NetworkManager
enable_service bluetoothd 0

# GUI customization tools
xi_install_safe nwg-look
require_hyprland_qt_packages || exit 1
xi_install_safe qt5ct
xi_install_safe qt6ct
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

post_install_hypr_report

# Success message
echo -e "\nAll Hyprland packages and plugins installed successfully!"
echo "Start from TTY with: start-hyprland"
echo "Shortcut command also available: hypr"
