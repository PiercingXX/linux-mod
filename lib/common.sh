# shellcheck shell=bash
# GitHub.com/PiercingXX
# linux-mod shared helpers. Source this file, do not execute it.

# PiercingXX 256-color stand-ins. lib/ui.sh upgrades to truecolor + chrome.
# $'...' so printf (not just echo -e) emits real ESC bytes.
YELLOW=$'\033[38;5;252m'
GREEN=$'\033[38;5;252m'
BLUE=$'\033[38;5;244m'
RED=$'\033[38;5;203m'
NC=$'\033[0m'
C_SIGNAL=$'\033[38;5;15m'
C_TEXT=$'\033[38;5;252m'
C_MUTED=$'\033[38;5;244m'
C_WARN=$'\033[38;5;215m'
C_ERR=$'\033[38;5;203m'
C_BOLD=$'\033[1m'

# --no-color flag, NO_COLOR env (no-color.org), or non-tty output
disable_colors() {
    YELLOW=''; GREEN=''; BLUE=''; RED=''; NC=''
    C_SIGNAL=''; C_TEXT=''; C_MUTED=''; C_WARN=''; C_ERR=''; C_BOLD=''
}
{ [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; } && disable_colors

LOG_FILE="${LOG_FILE:-/tmp/linux-mod.log}"
DRY_RUN="${DRY_RUN:-0}"

# Warnings are collected for the end-of-run summary table
WARNINGS=()

say()  { echo -e "${C_MUTED}$*${NC}" | tee -a "$LOG_FILE"; }
ok()   { echo -e "${C_TEXT}$*${NC}"  | tee -a "$LOG_FILE"; }
warn() { echo -e "${C_WARN}$*${NC}"  | tee -a "$LOG_FILE"; WARNINGS+=("$*"); }
dry()  { echo -e "${C_MUTED}[dry-run]${NC} ${C_TEXT}$*${NC}" | tee -a "$LOG_FILE"; }

# ---------------------------------------------------------------------------
# Install state markers - lets a failed run resume where it died
# ---------------------------------------------------------------------------
STATE_DIR="${STATE_DIR:-$HOME/.local/state/linux-mod}"

mark_done()   { [ "$DRY_RUN" -eq 1 ] && return 0; mkdir -p "$STATE_DIR"; touch "$STATE_DIR/$1.done"; }
is_done()     { [ -f "$STATE_DIR/$1.done" ]; }
reset_state() { command rm -rf "$STATE_DIR"; ok "Install state cleared."; }

# step <function> : run a module step once; skip on rerun, record on success
step() {
    local marker="$1-$DISTRO-$PROFILE"
    if is_done "$marker"; then
        say "Skipping $1 — already completed. (--reset-state to redo)"
        return 0
    fi
    if "$1"; then
        mark_done "$marker"
    else
        warn "$1 hit errors — check $LOG_FILE"
    fi
}

# install_summary lives in lib/ui.sh (gum table / branded block)

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Keep sudo credentials fresh for the duration of the script
cache_sudo_credentials() {
    echo "Caching sudo credentials for script execution..."
    sudo -v
    (while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &)
}

ensure_network_online() {
    local state=""

    if command_exists nmcli && state=$(nmcli -t -f STATE g 2>/dev/null); then
        if [[ "$state" != connected ]]; then
            echo "Network connectivity is required to continue."
            echo "nmcli reports state: $state"
        fi
    fi

    if ip route show default 2>/dev/null | grep -q '^default ' && ip -4 addr show up 2>/dev/null | grep -q "inet "; then
        return 0
    fi

    if ! ip -4 addr show up 2>/dev/null | grep -q "inet "; then
        echo "Network connectivity is required to continue."
        exit 1
    fi

    if ! ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1 && ! ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
        echo "Network connectivity is required to continue."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# piercing-dots checkout shared by every module that needs the rice
# ---------------------------------------------------------------------------
PIERCING_DOTS_DIR="${PIERCING_DOTS_DIR:-$LINUX_MOD_ROOT/piercing-dots}"

ensure_piercing_dots() {
    if [ ! -d "$PIERCING_DOTS_DIR/.git" ]; then
        command rm -rf "$PIERCING_DOTS_DIR"
        with_spin "Cloning piercing-dots..." \
            git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git "$PIERCING_DOTS_DIR"
    fi
}

# run_remote_installer "name" url [shell] - curl|sh installers, dry-run aware
run_remote_installer() {
    local name="$1" url="$2" shell_bin="${3:-sh}"
    if [ "$DRY_RUN" -eq 1 ]; then dry "run installer: $name ($url)"; return 0; fi
    curl -fsSL "$url" | "$shell_bin" || warn "$name install failed."
}

# with_spin "title" cmd... - gum spinner for quiet long-running commands
with_spin() {
    local title="$1"; shift
    if [ "$DRY_RUN" -eq 0 ] && [ "$UI_BACKEND" = "gum" ] && [ -t 1 ]; then
        gum spin --spinner dot --title "$title" -- "$@"
    else
        say "$title"
        "$@"
    fi
}

cleanup_piercing_dots() {
    command rm -rf "$PIERCING_DOTS_DIR"
}

# TUI widgets live in lib/ui.sh (sourced after lib/pkg.sh).
