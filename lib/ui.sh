# shellcheck shell=bash
# GitHub.com/PiercingXX
# Designed TUI: gum first, fzf picker fallback, whiptail, then select.
# Palette is PiercingXX (ink / signal / muted) — not Charm's default magenta.

# Pinned so a fresh box gets a known-good static binary, not "whatever is latest".
GUM_VERSION="${GUM_VERSION:-0.17.0}"
GUM_BIN_DIR="${GUM_BIN_DIR:-$HOME/.local/share/linux-mod/bin}"

UI_BACKEND="${UI_BACKEND:-}"
UI_HBAR="-"
UI_WIDTH=72

# ---------------------------------------------------------------------------
# Color tokens (brand guide §3). Truecolor when the terminal can; 256 if not.
# ---------------------------------------------------------------------------
ui_init_colors() {
    if [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
        disable_colors
        C_SIGNAL=''; C_TEXT=''; C_MUTED=''; C_WARN=''; C_ERR=''; C_BOLD=''
        return 0
    fi

    C_BOLD=$'\033[1m'
    if [ "${COLORTERM:-}" = "truecolor" ] || [ "${COLORTERM:-}" = "24bit" ]; then
        C_SIGNAL=$'\033[38;2;255;255;255m'
        C_TEXT=$'\033[38;2;230;230;230m'     # 90% white
        C_MUTED=$'\033[38;2;128;128;128m'    # 50% white
        C_WARN=$'\033[38;2;253;186;116m'     # #FDBA74
        C_ERR=$'\033[38;2;255;103;103m'      # #FF6767
    else
        C_SIGNAL=$'\033[38;5;15m'
        C_TEXT=$'\033[38;5;252m'
        C_MUTED=$'\033[38;5;244m'
        C_WARN=$'\033[38;5;215m'
        C_ERR=$'\033[38;5;203m'
    fi

    # Keep legacy names used by modules; remap onto the brand ramp.
    YELLOW="$C_TEXT"
    GREEN="$C_TEXT"
    BLUE="$C_MUTED"
    RED="$C_ERR"
    NC=$'\033[0m'
}

# UTF-8 box drawing when the locale can; ASCII otherwise (fresh Debian C locale).
ui_init_geometry() {
    local cols
    cols="${COLUMNS:-}"
    [ -z "$cols" ] && cols=$(tput cols 2>/dev/null || echo 72)
    [ "$cols" -lt 48 ] && cols=48
    [ "$cols" -gt 72 ] && cols=72
    UI_WIDTH="$cols"

    if locale charmap 2>/dev/null | grep -qi 'utf-8'; then
        UI_HBAR="─"
    else
        UI_HBAR="-"
    fi
}

ui_rule() {
    local i
    printf '%s' "$C_MUTED"
    for ((i = 0; i < UI_WIDTH; i++)); do printf '%s' "$UI_HBAR"; done
    printf '%s\n' "$NC"
}

# ---------------------------------------------------------------------------
# gum bootstrap: PATH -> distro package -> official static binary -> give up
# Never drop a glibc GitHub binary onto Alpine (musl).
# ---------------------------------------------------------------------------
_gum_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "x86_64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armv7)  echo "armv7" ;;
        i386|i686)     echo "i386" ;;
        *)             echo "" ;;
    esac
}

_is_alpine() {
    [ "${DISTRO:-}" = "alpine" ] || [ -f /etc/alpine-release ]
}

_gum_from_github() {
    local arch tarball url tmp want sum
    arch=$(_gum_arch)
    [ -n "$arch" ] || return 1
    command_exists curl || return 1
    command_exists tar || return 1

    tarball="gum_${GUM_VERSION}_Linux_${arch}.tar.gz"
    url="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/${tarball}"
    tmp=$(mktemp -d) || return 1

    say "Fetching gum v${GUM_VERSION} (one static binary)..."
    if ! command curl -fsSL "$url" -o "$tmp/$tarball"; then
        command rm -rf "$tmp"
        return 1
    fi

    if command_exists sha256sum && command curl -fsSL \
        "https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/checksums.txt" \
        -o "$tmp/checksums.txt" 2>/dev/null; then
        want=$(awk -v f="$tarball" '$2 == f { print $1; exit }' "$tmp/checksums.txt")
        sum=$(sha256sum "$tmp/$tarball" | awk '{ print $1 }')
        if [ -n "$want" ] && [ "$want" != "$sum" ]; then
            warn "gum checksum mismatch — not using the download."
            command rm -rf "$tmp"
            return 1
        fi
    fi

    mkdir -p "$GUM_BIN_DIR"
    if ! tar -xzf "$tmp/$tarball" -C "$tmp"; then
        command rm -rf "$tmp"
        return 1
    fi
    # tarball layout is versioned; find the binary
    local found
    found=$(find "$tmp" -type f -name gum -perm -u+x | head -n 1)
    [ -n "$found" ] || found=$(find "$tmp" -type f -name gum | head -n 1)
    if [ -z "$found" ]; then
        command rm -rf "$tmp"
        return 1
    fi
    command cp "$found" "$GUM_BIN_DIR/gum"
    command chmod 0755 "$GUM_BIN_DIR/gum"
    command rm -rf "$tmp"
    export PATH="$GUM_BIN_DIR:$PATH"
    command_exists gum
}

_ensure_gum() {
    if command_exists gum; then
        return 0
    fi
    if [ -x "$GUM_BIN_DIR/gum" ]; then
        export PATH="$GUM_BIN_DIR:$PATH"
        command_exists gum && return 0
    fi

    # Dry-run / no network: do not try to install anything.
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        return 1
    fi

    if pkg_install_quiet gum && command_exists gum; then
        return 0
    fi

    if _is_alpine; then
        return 1
    fi

    _gum_from_github
}

_ensure_fzf() {
    command_exists fzf && return 0
    [ "${DRY_RUN:-0}" -eq 1 ] && return 1
    pkg_install_quiet fzf && command_exists fzf
}

_ensure_whiptail() {
    command_exists whiptail && return 0
    [ "${DRY_RUN:-0}" -eq 1 ] && return 1
    { pkg_install_quiet whiptail || pkg_install_quiet libnewt || pkg_install_quiet newt; } \
        && command_exists whiptail
}

ui_apply_gum_theme() {
    # Signal white on ink. No Charm pink.
    export GUM_CHOOSE_CURSOR_FOREGROUND="#FFFFFF"
    export GUM_CHOOSE_SELECTED_FOREGROUND="#FFFFFF"
    export GUM_CHOOSE_HEADER_FOREGROUND="#808080"
    export GUM_CHOOSE_ITEM_FOREGROUND="#E6E6E6"
    export GUM_CHOOSE_CURSOR_PREFIX="> "
    export GUM_CHOOSE_SELECTED_PREFIX="* "
    export GUM_CHOOSE_UNSELECTED_PREFIX="  "
    export GUM_CHOOSE_HEIGHT="14"

    export GUM_CONFIRM_PROMPT_FOREGROUND="#E6E6E6"
    export GUM_CONFIRM_SELECTED_FOREGROUND="#000000"
    export GUM_CONFIRM_SELECTED_BACKGROUND="#FFFFFF"
    export GUM_CONFIRM_UNSELECTED_FOREGROUND="#808080"
    export GUM_CONFIRM_UNSELECTED_BACKGROUND="#000000"

    export GUM_SPIN_SPINNER="dot"
    export GUM_SPIN_SPINNER_FOREGROUND="#FFFFFF"
    export GUM_SPIN_TITLE_FOREGROUND="#808080"

    export GUM_STYLE_FOREGROUND="#E6E6E6"
    export GUM_STYLE_BORDER_FOREGROUND="#FFFFFF"
    export GUM_STYLE_BORDER="normal"

    export FZF_DEFAULT_OPTS="--reverse --height=40% --border=sharp --info=inline --prompt=> --pointer=> --marker=* --color=fg:252,bg:-1,hl:15,fg+:15,bg+:-1,hl+:15,prompt:244,pointer:15,marker:15,header:244,border:244"
}

ui_init() {
    ui_init_colors
    ui_init_geometry

    if _ensure_gum; then
        UI_BACKEND="gum"
        ui_apply_gum_theme
        return 0
    fi
    if _ensure_fzf; then
        UI_BACKEND="fzf"
        ui_apply_gum_theme
        return 0
    fi
    if _ensure_whiptail; then
        UI_BACKEND="whiptail"
        return 0
    fi
    UI_BACKEND="select"
}

# ---------------------------------------------------------------------------
# Chrome: title, badges, resumable step rail
# ---------------------------------------------------------------------------
_step_marker_done() {
    local name="$1"
    [ -n "${DISTRO:-}" ] || return 1
    if [ -n "${PROFILE:-}" ] && [ -f "$STATE_DIR/${name}-${DISTRO}-${PROFILE}.done" ]; then
        return 0
    fi
    local f
    for f in "$STATE_DIR/${name}-${DISTRO}-"*.done; do
        [ -f "$f" ] && return 0
    done
    return 1
}

_step_cell() {
    local label="$1"
    if _step_marker_done "$label"; then
        printf '%s%s%s%s' "$C_SIGNAL" "$label" "$NC" "$C_MUTED ✓$NC"
    else
        printf '%s%s%s' "$C_MUTED" "$label" "$NC"
    fi
}

ui_banner() {
    local dry=""
    [ "${DRY_RUN:-0}" -eq 1 ] && dry="  dry-run"

    printf '%s\n' ""
    ui_rule
    printf '%s  %sLINUX-MOD%s%s%s\n' "$C_SIGNAL" "$C_BOLD" "$NC" "$C_MUTED" "$dry"
    printf '%s  workstation installer%s\n' "$C_MUTED" "$NC"
    ui_rule
}

ui_badges() {
    local user distro pkg init profile backend
    user="${username:-$(id -un)}"
    distro="${DISTRO:-?}"
    pkg="${PKG:-?}"
    init="${INIT:-?}"
    profile="${PROFILE:-—}"
    backend="${UI_BACKEND:-}"

    printf '%s  %s%s%s  %s · %s · %s · %s · %s%s\n' \
        "$C_TEXT" "$C_SIGNAL" "$user" "$NC" \
        "$distro" "$pkg" "$init" "$profile" "$backend" "$NC"
}

ui_step_rail() {
    printf '  '
    _step_cell base
    printf '%s  ·  %s' "$C_MUTED" "$NC"
    _step_cell dots
    printf '%s  ·  %s' "$C_MUTED" "$NC"
    _step_cell apps
    printf '%s  ·  %s' "$C_MUTED" "$NC"
    printf '%s%s%s\n' "$C_MUTED" "wm" "$NC"
}

ui_screen() {
    local subtitle="${1:-}"
    clear
    ui_banner
    ui_badges
    ui_step_rail
    if [ -n "$subtitle" ]; then
        ui_rule
        printf '%s  %s%s\n' "$C_TEXT" "$subtitle" "$NC"
    fi
    printf '%s\n' ""
}

# ---------------------------------------------------------------------------
# Widgets
# ---------------------------------------------------------------------------
ui_choose() {
    local header="$1"; shift
    case "$UI_BACKEND" in
        gum)
            printf '%s\n' "$@" | gum choose --header "$header"
            ;;
        fzf)
            printf '%s\n' "$@" | fzf --header "$header" --prompt "> "
            ;;
        whiptail)
            local args=() opt
            for opt in "$@"; do args+=("$opt" ""); done
            whiptail --backtitle "PiercingXX" --title "linux-mod" \
                --menu "$header" 0 0 0 "${args[@]}" 3>&1 1>&2 2>&3
            ;;
        *)
            local choice
            echo "$header" >&2
            select choice in "$@"; do
                [ -n "$choice" ] && { echo "$choice"; return 0; }
            done
            ;;
    esac
}

ui_choose_multi() {
    local header="$1"; shift
    local opts=("$@") have_back=0 opt out
    for opt in "${opts[@]}"; do
        [ "$opt" = "Back" ] && have_back=1
    done
    [ "$have_back" -eq 0 ] && opts+=("Back")

    case "$UI_BACKEND" in
        gum)
            out=$(printf '%s\n' "${opts[@]}" | gum choose --no-limit \
                --header "$header  ·  space selects, enter confirms, Back to leave") || return 1
            ;;
        fzf)
            out=$(printf '%s\n' "${opts[@]}" | fzf --multi \
                --header "$header  ·  tab selects, enter confirms, Back to leave" --prompt "> ") || return 1
            ;;
        whiptail)
            local args=()
            for opt in "${opts[@]}"; do args+=("$opt" "" OFF); done
            out=$(whiptail --backtitle "PiercingXX" --title "linux-mod" \
                --checklist "$header" 0 0 0 "${args[@]}" 3>&1 1>&2 2>&3) || return 1
            out=$(eval "printf '%s\n' $out")
            ;;
        *)
            local choice
            echo "$header (pick repeatedly; choose Back to finish)" >&2
            while true; do
                select choice in "${opts[@]}"; do
                    [ -n "$choice" ] || continue
                    [ "$choice" = "Back" ] && return 1
                    echo "$choice"
                    break
                done
            done
            return 0
            ;;
    esac

    [ -n "$out" ] || return 1
    # Back alone (or only Back selected) means leave.
    if ! printf '%s\n' "$out" | grep -vxq 'Back'; then
        return 1
    fi
    printf '%s\n' "$out" | grep -vx 'Back' || true
}

ui_confirm() {
    case "$UI_BACKEND" in
        gum)      gum confirm "$1" ;;
        fzf)
            local a
            a=$(printf '%s\n' "Yes" "No" | fzf --header "$1" --prompt "> ") || return 1
            [ "$a" = "Yes" ]
            ;;
        whiptail) whiptail --backtitle "PiercingXX" --title "linux-mod" --yesno "$1" 0 0 ;;
        *)        local a; read -r -p "$1 [y/N] " a; [[ "$a" =~ ^[Yy] ]] ;;
    esac
}

ui_msg_box() {
    case "$UI_BACKEND" in
        gum)
            gum style --border normal --padding "1 2" --foreground "#E6E6E6" --border-foreground "#FFFFFF" "$1"
            read -n 1 -s -r -p "  press any key"
            echo
            ;;
        fzf)
            printf '%s\n' "$1" "Continue" | fzf --header "$1" --prompt "> " >/dev/null
            ;;
        whiptail) whiptail --msgbox "$1" 0 0 0 ;;
        *)        echo "$1"; read -n 1 -s -r -p "  press any key"; echo ;;
    esac
}

pause_for_key() {
    printf '%s  press any key%s' "$C_MUTED" "$NC"
    read -n 1 -s -r
    echo
}

# End-of-run report — gum table when we have it, plain block otherwise.
install_summary() {
    local dry="no" n warn_line
    [ "${DRY_RUN:-0}" -eq 1 ] && dry="yes"
    n=${#WARNINGS[@]}

    echo
    if [ "$UI_BACKEND" = "gum" ]; then
        {
            printf 'field\tvalue\n'
            printf 'distro\t%s (%s, %s)\n' "${DISTRO^}" "${PKG}" "${INIT}"
            printf 'profile\t%s\n' "${PROFILE:-n/a}"
            printf 'dry-run\t%s\n' "$dry"
            printf 'warnings\t%s\n' "$n"
            printf 'log\t%s\n' "$LOG_FILE"
        } | gum table --separator $'\t' --border none --print

        if [ "$n" -gt 0 ]; then
            echo
            printf '%s  %s warning(s)%s\n' "$C_WARN" "$n" "$NC"
            local w
            for w in "${WARNINGS[@]}"; do
                printf '%s  - %s%s\n' "$C_WARN" "$w" "$NC"
            done
        else
            printf '%s  clean run%s\n' "$C_MUTED" "$NC"
        fi
    else
        ui_rule
        printf '%s  summary%s\n' "$C_SIGNAL" "$NC"
        printf '%s  distro    %s%s (%s, %s)\n' "$C_MUTED" "$C_TEXT" "${DISTRO^}" "$PKG" "$INIT"
        printf '%s  profile   %s%s\n' "$C_MUTED" "$C_TEXT" "${PROFILE:-n/a}"
        printf '%s  dry-run   %s%s\n' "$C_MUTED" "$C_TEXT" "$dry"
        if [ "$n" -eq 0 ]; then
            printf '%s  warnings  %snone%s\n' "$C_MUTED" "$C_TEXT" "$NC"
        else
            printf '%s  warnings  %s%s%s\n' "$C_MUTED" "$C_WARN" "$n" "$NC"
            for warn_line in "${WARNINGS[@]}"; do
                printf '%s  - %s%s\n' "$C_WARN" "$warn_line" "$NC"
            done
        fi
        printf '%s  log       %s%s\n' "$C_MUTED" "$C_TEXT" "$LOG_FILE"
        ui_rule
    fi
}
