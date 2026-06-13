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

install_gaming_stuff() {
    require_x86_64
    require_cmd sudo
    require_cmd xbps-query

    log 'Enabling Void multilib repositories for native Steam'
    xi_install_required void-repo-multilib void-repo-multilib-nonfree
    sudo xbps-install -S

    log 'Installing 32-bit libraries required by Steam'
    xi_install_required glibc-32bit libstdc++-32bit libgcc-32bit

    log 'Installing Steam natively'
    xi_install_required steam

    log 'Installing Discord from Flathub'
    require_flatpak_system
    sudo flatpak install --system -y flathub com.discordapp.Discord

    log 'Complete'
}

install_gaming_stuff