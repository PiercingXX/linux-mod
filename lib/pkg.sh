# shellcheck shell=bash
# GitHub.com/PiercingXX
# Distro abstraction layer: detection, package installs, services, AUR.
# Source after lib/common.sh.

# Sets: DISTRO (arch|artix|debian|fedora|void|suse|alpine)
#       PKG    (pacman|apt|dnf|xbps|zypper|apk)
#       INIT   (systemd|runit|openrc|s6|dinit)
detect_distro() {
    local id="" id_like=""
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        id="${ID:-}"; id_like="${ID_LIKE:-}"
    fi

    case "$id" in
        artix)                       DISTRO="artix" ;;
        arch|cachyos|endeavouros|manjaro) DISTRO="arch" ;;
        debian|ubuntu|pop|linuxmint) DISTRO="debian" ;;
        fedora)                      DISTRO="fedora" ;;
        void)                        DISTRO="void" ;;
        opensuse*|sles|suse)         DISTRO="suse" ;;
        alpine)                      DISTRO="alpine" ;;
        *)
            case " $id_like " in
                *artix*)             DISTRO="artix" ;;
                *arch*)              DISTRO="arch" ;;
                *debian*|*ubuntu*)   DISTRO="debian" ;;
                *fedora*|*rhel*)     DISTRO="fedora" ;;
                *suse*)              DISTRO="suse" ;;
                *)
                    echo "Unsupported distro (ID='$id' ID_LIKE='$id_like')."
                    echo "linux-mod supports Arch, Artix, Debian/Ubuntu/Pop, Fedora, Void, openSUSE, and Alpine."
                    exit 1 ;;
            esac ;;
    esac

    case "$DISTRO" in
        arch|artix) PKG="pacman" ;;
        debian)     PKG="apt" ;;
        fedora)     PKG="dnf" ;;
        void)       PKG="xbps" ;;
        suse)       PKG="zypper" ;;
        alpine)     PKG="apk" ;;
    esac

    if [ -d /run/systemd/system ]; then
        INIT="systemd"
    elif command_exists sv && [ -d /etc/runit ] || [ -d /var/service ]; then
        INIT="runit"
    elif command_exists rc-update; then
        INIT="openrc"
    elif command_exists dinitctl; then
        INIT="dinit"
    elif [ -d /etc/s6 ] || command_exists s6-rc; then
        INIT="s6"
    else
        INIT="unknown"
    fi

    export DISTRO PKG INIT
}

pkg_update() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then dry "system update ($PKG)"; return 0; fi
    case "$PKG" in
        pacman) sudo pacman -Syu --noconfirm ;;
        apt)    sudo apt update && sudo apt upgrade -y ;;
        dnf)    sudo dnf upgrade -y ;;
        xbps)   sudo xbps-install -Suy ;;
        zypper) sudo zypper -n refresh && sudo zypper -n dup ;;  # Tumbleweed rolling
        apk)    sudo apk update && sudo apk upgrade ;;
    esac
}

# pi pkg... : install packages, tolerating individually-missing ones.
# Unified modules pass distro-appropriate names; anything a repo doesn't
# carry is skipped with a warning instead of aborting the run.
pi() {
    [ $# -gt 0 ] || return 0
    if [ "${DRY_RUN:-0}" -eq 1 ]; then dry "install ($PKG): $*"; return 0; fi
    case "$PKG" in
        pacman)
            if ! sudo pacman -S --needed --noconfirm "$@"; then
                local p
                for p in "$@"; do
                    sudo pacman -S --needed --noconfirm "$p" || warn "Skipping unavailable package: $p"
                done
            fi ;;
        apt)
            if ! sudo apt install -y "$@"; then
                local p
                for p in "$@"; do
                    sudo apt install -y "$p" || warn "Skipping unavailable package: $p"
                done
            fi ;;
        dnf)
            sudo dnf install -y --skip-unavailable "$@" \
                || sudo dnf install -y --skip-broken "$@" \
                || {
                    local p
                    for p in "$@"; do
                        sudo dnf install -y "$p" || warn "Skipping unavailable package: $p"
                    done
                } ;;
        xbps)
            if ! sudo xbps-install -Sy "$@"; then
                local p
                for p in "$@"; do
                    sudo xbps-install -Sy "$p" || warn "Skipping unavailable package: $p"
                done
            fi ;;
        zypper)
            if ! sudo zypper -n install --no-recommends "$@"; then
                local p
                for p in "$@"; do
                    sudo zypper -n install --no-recommends "$p" || warn "Skipping unavailable package: $p"
                done
            fi ;;
        apk)
            if ! sudo apk add "$@"; then
                local p
                for p in "$@"; do
                    sudo apk add "$p" || warn "Skipping unavailable package: $p"
                done
            fi ;;
    esac
}

pkg_install_quiet() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then dry "install ($PKG): $*"; return 0; fi
    case "$PKG" in
        pacman) sudo pacman -S --needed --noconfirm "$@" >/dev/null 2>&1 ;;
        apt)    sudo apt install -y "$@" >/dev/null 2>&1 ;;
        dnf)    sudo dnf install -y "$@" >/dev/null 2>&1 ;;
        xbps)   sudo xbps-install -Sy "$@" >/dev/null 2>&1 ;;
        zypper) sudo zypper -n install --no-recommends "$@" >/dev/null 2>&1 ;;
        apk)    sudo apk add "$@" >/dev/null 2>&1 ;;
        *)      return 1 ;;
    esac
}

# Flatpak with flathub, shared across distros
ensure_flatpak() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then dry "ensure flatpak + flathub remote"; return 0; fi
    command_exists flatpak || pi flatpak
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
}

fp() { # fp app.id...
    if [ "${DRY_RUN:-0}" -eq 1 ]; then dry "flatpak install: $*"; return 0; fi
    ensure_flatpak
    local app
    for app in "$@"; do
        flatpak install -y flathub "$app" || warn "Flatpak install failed: $app"
    done
}

# AUR helper (arch/artix). Bootstraps paru if missing.
ensure_paru() {
    if [ "${DRY_RUN:-0}" -eq 1 ]; then dry "ensure paru (AUR helper)"; return 0; fi
    command_exists paru && return 0
    say "Bootstrapping paru (AUR helper)..."
    pi base-devel git
    local tmp
    tmp=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin" \
        && (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
    command rm -rf "$tmp"
}

aur() { # aur pkg...
    case "$DISTRO" in arch|artix) ;; *) return 0 ;; esac
    if [ "${DRY_RUN:-0}" -eq 1 ]; then dry "AUR install: $*"; return 0; fi
    ensure_paru || { warn "paru unavailable; skipping AUR packages: $*"; return 1; }
    paru -S --needed --noconfirm "$@" || warn "AUR install had errors: $*"
}

# ---------------------------------------------------------------------------
# Service management across systemd / runit / openrc / dinit / s6
# svc_enable <systemd-name> [alt-name ...]  - first existing name wins
# ---------------------------------------------------------------------------
svc_enable() {
    local name
    if [ "${DRY_RUN:-0}" -eq 1 ]; then dry "enable service ($INIT): $*"; return 0; fi
    case "$INIT" in
        systemd)
            for name in "$@"; do
                if systemctl list-unit-files "${name}.service" --no-legend 2>/dev/null | grep -q .; then
                    sudo systemctl enable --now "$name" && return 0
                fi
            done ;;
        runit)
            local service_dir=""
            if [ -e /var/service ]; then service_dir="/var/service"
            elif [ -d /etc/runit/runsvdir/current ]; then service_dir="/etc/runit/runsvdir/current"
            elif [ -d /etc/runit/runsvdir/default ]; then service_dir="/etc/runit/runsvdir/default"
            fi
            [ -n "$service_dir" ] || { warn "No runit service dir found for: $*"; return 1; }
            for name in "$@"; do
                if [ -d "/etc/sv/$name" ]; then
                    sudo mkdir -p "$service_dir"
                    sudo rm -f "$service_dir/$name"
                    sudo ln -s "/etc/sv/$name" "$service_dir/$name"
                    sudo sv up "$name" >/dev/null 2>&1 || true
                    return 0
                fi
            done ;;
        openrc)
            for name in "$@"; do
                if [ -x "/etc/init.d/$name" ]; then
                    sudo rc-update add "$name" default
                    sudo rc-service "$name" start || true
                    return 0
                fi
            done ;;
        dinit)
            for name in "$@"; do
                sudo dinitctl enable "$name" 2>/dev/null && { sudo dinitctl start "$name" 2>/dev/null || true; return 0; }
            done ;;
        s6)
            for name in "$@"; do
                sudo touch "/etc/s6/adminsv/default/contents.d/$name" 2>/dev/null && {
                    sudo s6-db-reload 2>/dev/null || true
                    sudo s6-rc -u change "$name" 2>/dev/null || true
                    return 0
                }
            done ;;
    esac
    warn "Could not enable service ($INIT): $*"
    return 1
}

svc_disable() {
    local name
    if [ "${DRY_RUN:-0}" -eq 1 ]; then dry "disable service ($INIT): $*"; return 0; fi
    for name in "$@"; do
        case "$INIT" in
            systemd) sudo systemctl disable --now "$name" 2>/dev/null || true ;;
            runit)   sudo rm -f "/var/service/$name" "/etc/runit/runsvdir/current/$name" "/etc/runit/runsvdir/default/$name" 2>/dev/null || true ;;
            openrc)  sudo rc-update del "$name" default 2>/dev/null || true
                     sudo rc-service "$name" stop 2>/dev/null || true ;;
            dinit)   sudo dinitctl disable "$name" 2>/dev/null || true ;;
        esac
    done
}
