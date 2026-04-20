#!/usr/bin/env bash

# Service management helpers that work across Artix init systems.

detect_init_system() {
    if command -v rc-service >/dev/null 2>&1 && command -v rc-update >/dev/null 2>&1; then
        printf 'openrc\n'
        return 0
    fi

    if command -v sv >/dev/null 2>&1; then
        printf 'runit\n'
        return 0
    fi

    if command -v dinitctl >/dev/null 2>&1; then
        printf 'dinit\n'
        return 0
    fi

    printf 'unknown\n'
}

_try_services() {
    local fn="$1"
    shift
    local service

    for service in "$@"; do
        if "$fn" "$service"; then
            return 0
        fi
    done

    return 1
}

_runit_enable() {
    local service="$1"
    local src="/etc/runit/sv/$service"

    if [ ! -d "$src" ]; then
        return 1
    fi

    if [ -d /etc/runit/runsvdir/default ]; then
        sudo ln -sfn "$src" "/etc/runit/runsvdir/default/$service"
        return 0
    fi

    if [ -d /run/runit/service ]; then
        sudo ln -sfn "$src" "/run/runit/service/$service"
        return 0
    fi

    return 1
}

_enable_and_start_one() {
    local service="$1"
    local init
    init="$(detect_init_system)"

    case "$init" in
        openrc)
            sudo rc-update add "$service" default >/dev/null 2>&1 || true
            sudo rc-service "$service" start >/dev/null 2>&1
            ;;
        runit)
            _runit_enable "$service" || return 1
            sudo sv up "$service" >/dev/null 2>&1
            ;;
        dinit)
            sudo dinitctl enable "$service" >/dev/null 2>&1 || true
            sudo dinitctl start "$service" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

enable_and_start_service() {
    if [ "$#" -lt 1 ]; then
        return 1
    fi
    _try_services _enable_and_start_one "$@"
}

_disable_and_stop_one() {
    local service="$1"
    local init
    init="$(detect_init_system)"

    case "$init" in
        openrc)
            sudo rc-service "$service" stop >/dev/null 2>&1 || true
            sudo rc-update del "$service" default >/dev/null 2>&1 || true
            ;;
        runit)
            sudo sv down "$service" >/dev/null 2>&1 || true
            sudo rm -f "/etc/runit/runsvdir/default/$service" >/dev/null 2>&1 || true
            sudo rm -f "/run/runit/service/$service" >/dev/null 2>&1 || true
            ;;
        dinit)
            sudo dinitctl stop "$service" >/dev/null 2>&1 || true
            sudo dinitctl disable "$service" >/dev/null 2>&1 || true
            ;;
        *)
            return 1
            ;;
    esac
}

disable_and_stop_service() {
    if [ "$#" -lt 1 ]; then
        return 1
    fi
    _try_services _disable_and_stop_one "$@"
}

_is_active_one() {
    local service="$1"
    local init
    init="$(detect_init_system)"

    case "$init" in
        openrc)
            rc-service "$service" status >/dev/null 2>&1
            ;;
        runit)
            sv status "$service" 2>/dev/null | grep -q '^run:'
            ;;
        dinit)
            dinitctl status "$service" 2>/dev/null | grep -qi 'running'
            ;;
        *)
            return 1
            ;;
    esac
}

is_service_active() {
    if [ "$#" -lt 1 ]; then
        return 1
    fi
    _try_services _is_active_one "$@"
}

_is_enabled_one() {
    local service="$1"
    local init
    init="$(detect_init_system)"

    case "$init" in
        openrc)
            rc-update show default 2>/dev/null | awk '{print $1}' | grep -qx "$service"
            ;;
        runit)
            [ -L "/etc/runit/runsvdir/default/$service" ] || [ -L "/run/runit/service/$service" ]
            ;;
        dinit)
            dinitctl list 2>/dev/null | awk '{print $1}' | grep -qx "$service"
            ;;
        *)
            return 1
            ;;
    esac
}

is_service_enabled() {
    if [ "$#" -lt 1 ]; then
        return 1
    fi
    _try_services _is_enabled_one "$@"
}

restart_user_services() {
    return 0
}

install_init_service_package_if_available() {
    if [ "$#" -lt 1 ]; then
        return 1
    fi

    local pkg="$1"

    if ! command -v pacman >/dev/null 2>&1; then
        return 1
    fi

    if pacman -Si "$pkg" >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm "$pkg" >/dev/null 2>&1
        return $?
    fi

    return 1
}

ensure_ly_service_support() {
    local init
    init="$(detect_init_system)"

    case "$init" in
        openrc)
            install_init_service_package_if_available ly-openrc >/dev/null 2>&1 || true
            ;;
        runit)
            install_init_service_package_if_available ly-runit >/dev/null 2>&1 || true
            ;;
        dinit)
            install_init_service_package_if_available ly-dinit >/dev/null 2>&1 || true
            ;;
    esac
}

enable_ly_service() {
    if enable_and_start_service ly ly-dm; then
        return 0
    fi

    ensure_ly_service_support

    enable_and_start_service ly ly-dm
}