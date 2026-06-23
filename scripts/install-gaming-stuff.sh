#!/usr/bin/env bash

set -uo pipefail

XI="sudo xbps-install"
FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"

log() {
    printf '[gaming-install] %s\n' "$*"
}

die() {
    printf '[gaming-install] ERROR: %s\n' "$*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

clear_broken_hyprland_stack_if_present() {
    local stale_hypr_pkgs=(
        aquamarine hyprgraphics hyprland hyprlang
        hyprcursor libzip re2 xcb-util-errors tomlplusplus
        libseat libspng
    )

    if xbps-pkgdb -a 2>/dev/null | grep -Eq "unresolvable shlib .*libhyprutils\.so\.6"; then
        log 'Detected broken Hyprland shlib state; removing stale packages to unblock xbps transactions'
        sudo xbps-remove -Fy "${stale_hypr_pkgs[@]}" >/dev/null 2>&1 || true
        sudo xbps-install -S >/dev/null 2>&1 || true
    fi
}

pkg_available() {
    xbps-query -Rs "^$1$" >/dev/null 2>&1
}

xi_install_required() {
    local pkg
    local installable=()

    for pkg in "$@"; do
        if pkg_available "$pkg"; then
            installable+=("$pkg")
        else
            die "Required package not found in repos: $pkg"
        fi
    done

    $XI "${installable[@]}"
}

ensure_steam_runtime_loader() {
    if [ -e /lib/ld-linux.so.2 ] && [ -e /usr/lib32/libc.so.6 ]; then
        return 0
    fi

    log 'Steam 32-bit loader/libc path missing; forcing glibc-32bit reinstall'
    sudo xbps-install -f glibc-32bit

    [ -e /lib/ld-linux.so.2 ] && [ -e /usr/lib32/libc.so.6 ] \
        || die 'Steam 32-bit runtime is still incomplete (/lib/ld-linux.so.2 or /usr/lib32/libc.so.6 missing).'
}

ensure_steam_graphics_runtime() {
    if [ -e /usr/lib32/libGL.so.1 ] && [ -e /usr/lib32/libdrm.so.2 ]; then
        return 0
    fi

    log 'Steam 32-bit graphics runtime missing; installing OpenGL/DRM compatibility libraries'
    xi_install_required libglvnd-32bit libdrm-32bit mesa-32bit mesa-dri-32bit libgbm-32bit

    [ -e /usr/lib32/libGL.so.1 ] && [ -e /usr/lib32/libdrm.so.2 ] \
        || die 'Steam graphics runtime is still incomplete (/usr/lib32/libGL.so.1 or /usr/lib32/libdrm.so.2 missing).'
}

require_x86_64() {
    if [ "$(uname -m)" != "x86_64" ]; then
        die 'Native Steam install is only supported here on x86_64 Void.'
    fi
}

require_flatpak_system() {
    if ! pkg_available flatpak; then
        die 'Flatpak package is unavailable in current repos.'
    fi

    if ! command -v flatpak >/dev/null 2>&1; then
        xi_install_required flatpak
    fi

    sudo mkdir -p /var/lib/flatpak /var/tmp/flatpak-cache
    sudo flatpak remote-add --system --if-not-exists flathub "$FLATHUB_URL"
}

flatpak_apply_audio_override() {
    local app_id="$1"
    local target_user="${SUDO_USER:-${USER:-}}"

    if ! sudo flatpak info --system "$app_id" >/dev/null 2>&1; then
        return 0
    fi

    if [ -z "$target_user" ] || [ "$target_user" = "root" ]; then
        log "No non-root target user detected; skipping user Flatpak override for $app_id"
        return 0
    fi

    if command -v runuser >/dev/null 2>&1; then
        runuser -u "$target_user" -- flatpak override --user \
            --socket=pulseaudio \
            --filesystem=xdg-run/pipewire-0 \
            "$app_id" || true
    else
        log "runuser not found; skipping user Flatpak override for $app_id"
    fi
}

install_gaming_stuff() {
    require_x86_64
    require_cmd sudo
    require_cmd xbps-query
    require_cmd xbps-pkgdb

    clear_broken_hyprland_stack_if_present

    log 'Enabling Void multilib repositories for native Steam'
    xi_install_required void-repo-multilib void-repo-multilib-nonfree
    sudo xbps-install -S

    log 'Installing 32-bit libraries required by Steam'
    xi_install_required glibc-32bit libstdc++-32bit libgcc-32bit
    ensure_steam_runtime_loader
    ensure_steam_graphics_runtime

    log 'Installing Steam natively'
    xi_install_required steam

    log 'Installing Discord from Flathub'
    require_flatpak_system
    sudo flatpak install --system -y flathub com.discordapp.Discord
    flatpak_apply_audio_override com.discordapp.Discord

    log 'Complete'
}

install_gaming_stuff