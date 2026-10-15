#!/bin/bash
# GitHub.com/PiercingXX
#
# linux-mod - one repo to replace arch-mod, arch-mini-mod, artix-mod,
# debian-mod, debian-mini-mod, fedora-mod, and void-mod.
#
# Detects the distro, then runs truly unified modules: every module contains
# the per-distro branches internally (package names, service managers, AUR),
# so there is exactly one script per concern instead of one repo per distro.
#
# Usage:  ./linux-mod.sh                 interactive menu
#         ./linux-mod.sh --full          run the full install non-interactively
#         ./linux-mod.sh --mini          run the mini install non-interactively
#         ./linux-mod.sh --wm list       after --full/--mini, install these WMs
#         ./linux-mod.sh --spacemouse    after --full/--mini, add SpaceMouse support
#         ./linux-mod.sh --dry-run       print actions instead of executing
#         ./linux-mod.sh --reset-state   forget completed steps and start fresh
#         ./linux-mod.sh --no-color      plain output (NO_COLOR env also works)
#         ./linux-mod.sh update          git pull the latest linux-mod
#
# --wm accepts a comma list: hyprland,gnome,herbst,sway,i3,bspwm,awesome,
# qtile,dwm,busybox

LINUX_MOD_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LINUX_MOD_ROOT

# ---------------------------------------------------------------------------
# Flags (before sourcing libs so DRY_RUN/NO_COLOR take effect immediately)
# ---------------------------------------------------------------------------
UNATTENDED=0
ACTION=""
WM_FLAGS=""
SPACEMOUSE=0
for arg in "$@"; do
    case "$arg" in
        --full)        ACTION="full"; UNATTENDED=1 ;;
        --mini)        ACTION="mini"; UNATTENDED=1 ;;
        --dry-run)     DRY_RUN=1 ;;
        --reset-state) ACTION="${ACTION:-reset-state}" ;;
        --no-color)    NO_COLOR=1 ;;
        --spacemouse)  SPACEMOUSE=1 ;;
        --wm)          ;; # value is the next arg; handled below
        --wm=*)        WM_FLAGS="${arg#--wm=}" ;;
        update)        ACTION="update" ;;
        -h|--help)
            sed -n '3,23p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            if [ "${prev:-}" = "--wm" ]; then
                WM_FLAGS="$arg"
            else
                echo "Unknown option: $arg (try --help)"; exit 1
            fi ;;
    esac
    prev="$arg"
done
export DRY_RUN="${DRY_RUN:-0}" NO_COLOR="${NO_COLOR:-}"

# shellcheck disable=SC1091
. "$LINUX_MOD_ROOT/lib/common.sh"
# shellcheck disable=SC1091
. "$LINUX_MOD_ROOT/lib/pkg.sh"
# shellcheck disable=SC1091
. "$LINUX_MOD_ROOT/lib/ui.sh"
[ -n "$NO_COLOR" ] && disable_colors

# Self-update runs before anything else
if [ "$ACTION" = "update" ]; then
    say "Updating linux-mod..."
    command git -C "$LINUX_MOD_ROOT" pull --ff-only || { warn "git pull failed."; exit 1; }
    ok "linux-mod is up to date."
    exit 0
fi

# Root is refused for real runs; allowed for --dry-run (CI containers run as root)
if [[ $EUID -eq 0 ]] && [ "$DRY_RUN" -eq 0 ]; then
    echo "This script should not be executed as root! Exiting......."
    exit 1
fi

username=$(id -un)

detect_distro

if [ "$ACTION" = "reset-state" ]; then
    ui_init_colors
    reset_state
    exit 0
fi

# ---------------------------------------------------------------------------
# Dry-run: shadow every mutating command with an echo. Package/service/flatpak
# primitives short-circuit in lib/pkg.sh; this net catches the direct calls.
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" -eq 1 ]; then
    sudo()    { dry "sudo $*" >&2; }   # stderr: survives `sudo tee ... >/dev/null`
    flatpak() { dry "flatpak $*"; }
    makepkg() { dry "makepkg $*"; }
    cargo()   { dry "cargo $*"; }
    pipx()    { dry "pipx $*"; }
    go()      { dry "go $*"; }
    ya()      { dry "ya $*"; }
    git()     { dry "git $*"; }
    make()    { dry "make $*"; }
    wget()    { dry "wget $*"; }
    curl()    { dry "curl $*"; }
    hyprpm()  { dry "hyprpm $*"; }
    say "DRY RUN — nothing will be installed or changed."
else
    cache_sudo_credentials
    ensure_network_online
fi

if [ "$UNATTENDED" -eq 1 ]; then
    ui_init_colors
    ui_init_geometry
    UI_BACKEND="select"
else
    ui_init
fi

for module in "$LINUX_MOD_ROOT"/modules/*.sh; do
    # shellcheck disable=SC1090
    . "$module"
done

# ---------------------------------------------------------------------------
# --wm hyprland,gnome -> dispatch names used by wm.sh
# ---------------------------------------------------------------------------
wm_from_flag() {
    local raw item items=()
    raw=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    IFS=',' read -ra items <<< "$raw"
    for item in "${items[@]}"; do
        item="${item// /}"
        [ -n "$item" ] || continue
        case "$item" in
            hyprland)              _wm_dispatch "Hyprland" ;;
            gnome)                 _wm_dispatch "GNOME" ;;
            herbst|herbstluftwm)   _wm_dispatch "Herbstluftwm" ;;
            sway)                  _wm_dispatch "Sway" ;;
            i3)                    _wm_dispatch "i3" ;;
            bspwm)                 _wm_dispatch "bspwm" ;;
            awesome)               _wm_dispatch "Awesome" ;;
            qtile)                 _wm_dispatch "Qtile" ;;
            dwm)                   _wm_dispatch "DWM" ;;
            busybox)               _wm_dispatch "BusyBox Profile" ;;
            *)             warn "Unknown --wm value: $item" ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Install flows (step = resumable: completed stages are skipped on rerun)
# No DE/WM is assumed. Interactive runs require a WM pick after apps.
# ---------------------------------------------------------------------------
run_full_install() {
    PROFILE="full"
    say "Running the ${DISTRO^} full install..."
    step base_setup
    step apply_dots
    step apps_install
    finish_install
}

run_mini_install() {
    PROFILE="mini"
    say "Running the ${DISTRO^} mini install..."
    step base_setup
    step apply_dots
    step apps_install
    finish_install
}

# Say so when a 3Dconnexion device (USB vendor 256f) is already plugged in
_spacemouse_prompt() {
    if command_exists lsusb && lsusb -d 256f: >/dev/null 2>&1; then
        echo "SpaceMouse detected. Install 3Dconnexion SpaceMouse support (spacenavd)?"
    else
        echo "Install 3Dconnexion SpaceMouse support (spacenavd)?"
    fi
}

# Login manager after the WM pick (so GNOME's gdm exists), and the
# NetworkManager handoff last, once nothing else needs to download
finish_install() {
    ok "${DISTRO^} ${PROFILE} install complete."

    if [ "$UNATTENDED" -eq 1 ]; then
        if [ -n "$WM_FLAGS" ]; then
            wm_from_flag "$WM_FLAGS"
        else
            say "No desktop installed. Pass --wm hyprland,gnome (or open the menu) when you want one."
        fi
        configure_login_manager
        [ "$SPACEMOUSE" -eq 1 ] && drivers_spacemouse
        network_handoff
        install_summary
        say "Reboot when ready."
        return 0
    fi

    ui_screen "pick at least one desktop or window manager"
    wm_menu
    configure_login_manager
    if ui_confirm "$(_spacemouse_prompt)"; then
        drivers_spacemouse
    fi
    if ui_confirm "Install gaming stuff?"; then
        extras_gaming
    fi
    network_handoff
    install_summary
    if ui_confirm "Reboot now?"; then
        [ "$DRY_RUN" -eq 1 ] && { dry "reboot"; return 0; }
        sudo reboot
    fi
    say "Reboot when ready."
}

case "$ACTION" in
    full) run_full_install; exit 0 ;;
    mini) run_mini_install; exit 0 ;;
esac

# ---------------------------------------------------------------------------
# Main menu
# ---------------------------------------------------------------------------
while true; do
    ui_screen "full = workstation · mini = tablet / mini-PC · no DE until you pick one"

    MENU=(
        "Full Install"
        "Mini Install"
        "Window Managers"
        "Drivers & Hardware"
        "Extras"
        "Reset Install State"
        "Reboot System"
        "Exit"
    )
    choice=$(ui_choose "what now" "${MENU[@]}") || choice=""

    case "$choice" in
        "Full Install")        run_full_install ;;
        "Mini Install")        run_mini_install ;;
        "Window Managers")     PROFILE="${PROFILE:-full}"; wm_menu; continue ;;
        "Drivers & Hardware")  drivers_menu; continue ;;
        "Extras")              extras_menu; continue ;;
        "Reset Install State") reset_state ;;
        "Reboot System")
            if ui_confirm "Reboot now?"; then
                [ "$DRY_RUN" -eq 1 ] && { dry "reboot"; continue; }
                sudo reboot
            fi ;;
        "Exit"|"")
            clear
            [ ${#WARNINGS[@]} -gt 0 ] && install_summary
            printf '%s  thank you handsome%s\n' "$C_MUTED" "$NC"
            exit 0 ;;
    esac
    pause_for_key
done
