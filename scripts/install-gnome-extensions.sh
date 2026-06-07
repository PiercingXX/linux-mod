#!/usr/bin/env bash

set -uo pipefail

TARGET_USER="${SUDO_USER:-${USER:-}}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
GNOME_EXTENSION_INSTALLER_URL="https://raw.githubusercontent.com/brunelli/gnome-shell-extension-installer/master/gnome-shell-extension-installer"
INSTALLER_PATH="$TARGET_HOME/.local/bin/gnome-shell-extension-installer"
ENABLE_SCRIPT_PATH="$TARGET_HOME/.local/bin/piercingxx-enable-gnome-extensions.sh"
AUTOSTART_PATH="$TARGET_HOME/.config/autostart/piercingxx-enable-gnome-extensions.desktop"

log() {
    printf '[gnome-extensions] %s\n' "$*"
}

warn() {
    printf '[gnome-extensions] WARNING: %s\n' "$*" >&2
}

die() {
    printf '[gnome-extensions] ERROR: %s\n' "$*" >&2
    exit 1
}

set_owner_if_root() {
    if [ "$EUID" -eq 0 ]; then
        chown "$TARGET_USER":"$TARGET_USER" "$@"
    fi
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

pkg_exists() {
    xbps-query -Rs "^$1$" >/dev/null 2>&1
}

install_available_packages() {
    local pkg
    local installable=()

    for pkg in "$@"; do
        if pkg_exists "$pkg"; then
            installable+=("$pkg")
        else
            warn "Skipping unavailable package: $pkg"
        fi
    done

    if [ "${#installable[@]}" -eq 0 ]; then
        return 0
    fi

    sudo xbps-install "${installable[@]}"
}

user_run() {
    sudo -u "$TARGET_USER" env \
        HOME="$TARGET_HOME" \
        XDG_CONFIG_HOME="$TARGET_HOME/.config" \
        XDG_DATA_HOME="$TARGET_HOME/.local/share" \
        "$@"
}

user_bash() {
    sudo -u "$TARGET_USER" env \
        HOME="$TARGET_HOME" \
        XDG_CONFIG_HOME="$TARGET_HOME/.config" \
        XDG_DATA_HOME="$TARGET_HOME/.local/share" \
        bash -lc "$1"
}

ensure_extension_installer() {
    mkdir -p "$TARGET_HOME/.local/bin"

    log 'Installing gnome-shell-extension-installer helper'
    curl -fsSL "$GNOME_EXTENSION_INSTALLER_URL" -o "$INSTALLER_PATH"
    chmod +x "$INSTALLER_PATH"
    set_owner_if_root "$INSTALLER_PATH"
}

install_extension_by_id() {
    local extension_id="$1"
    local label="$2"

    log "Installing ${label}"
    user_run "$INSTALLER_PATH" --yes "$extension_id"
}

gnome_shell_major() {
    gnome-shell --version 2>/dev/null | awk '{print $3}' | cut -d. -f1
}

pop_shell_branch() {
    local major="$(gnome_shell_major)"

    case "$major" in
        ''|3[6-9]|40|41)
            printf 'master_focal\n'
            ;;
        42|43|44)
            printf 'master_jammy\n'
            ;;
        45)
            printf 'master_mantic\n'
            ;;
        *)
            printf 'master_noble\n'
            ;;
    esac
}

install_pop_shell() {
    local branch
    local build_dir

    branch="$(pop_shell_branch)"
    build_dir="$(mktemp -d)"

    log "Installing Pop Shell from ${branch}"
    git clone --depth=1 --branch "$branch" https://github.com/pop-os/shell.git "$build_dir/pop-shell"
    user_bash "cd '$build_dir/pop-shell' && make local-install"
    rm -rf "$build_dir"
}

install_super_key() {
    local build_dir
    local uuid

    build_dir="$(mktemp -d)"

    log 'Installing Super Key'
    git clone --depth=1 https://github.com/Tommimon/super-key.git "$build_dir/super-key"

    if ! user_bash "cd '$build_dir/super-key' && chmod +x ./build.sh && ./build.sh -i"; then
        uuid="$(sed -n 's/.*"uuid"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$build_dir/super-key/metadata.json" | head -n1)"
        [ -n "$uuid" ] || uuid='super-key@tommimon.github.com'
        user_run mkdir -p "$TARGET_HOME/.local/share/gnome-shell/extensions"
        user_run rm -rf "$TARGET_HOME/.local/share/gnome-shell/extensions/$uuid"
        user_run cp -r "$build_dir/super-key" "$TARGET_HOME/.local/share/gnome-shell/extensions/$uuid"
    fi

    rm -rf "$build_dir"
}

write_enable_script() {
    mkdir -p "$TARGET_HOME/.local/bin" "$TARGET_HOME/.config/autostart"

    cat > "$ENABLE_SCRIPT_PATH" <<'EOF'
#!/usr/bin/env bash

set -u

AUTOSTART_PATH="$HOME/.config/autostart/piercingxx-enable-gnome-extensions.desktop"
UUIDS=(
    appindicatorsupport@rgcjonas.gmail.com
    blur-my-shell@aunetx
    just-perfection-desktop@just-perfection
    gsconnect@andyholmes.github.io
    pop-shell@system76.com
    workspaces-by-open-apps@favo02
    super-key@tommimon.github.com
    super-key@tommimon
)

if ! command -v gnome-extensions >/dev/null 2>&1; then
    exit 0
fi

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] || [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    exit 0
fi

for uuid in "${UUIDS[@]}"; do
    if gnome-extensions info "$uuid" >/dev/null 2>&1; then
        gnome-extensions enable "$uuid" >/dev/null 2>&1 || true
    fi
done

super_key_uuid=''
for candidate in super-key@tommimon.github.com super-key@tommimon; do
    if gnome-extensions info "$candidate" >/dev/null 2>&1; then
        super_key_uuid="$candidate"
        break
    fi
done

if [ -n "$super_key_uuid" ] && command -v gsettings >/dev/null 2>&1; then
    metadata_path="$HOME/.local/share/gnome-shell/extensions/$super_key_uuid/metadata.json"
    schema_dir="$HOME/.local/share/gnome-shell/extensions/$super_key_uuid/schemas"
    schema=''

    if [ -d "$schema_dir" ] && command -v glib-compile-schemas >/dev/null 2>&1; then
        glib-compile-schemas "$schema_dir" >/dev/null 2>&1 || true
    fi

    if [ -f "$metadata_path" ]; then
        schema="$(sed -n 's/.*"settings-schema"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$metadata_path" | head -n1)"
    fi

    if [ -z "$schema" ]; then
        schema="$(gsettings list-schemas 2>/dev/null | grep -iE 'tommimon|super[- ]?key' | head -n1 || true)"
    fi

    if [ -n "$schema" ]; then
        if [ -d "$schema_dir" ]; then
            keys="$(gsettings --schemadir "$schema_dir" list-keys "$schema" 2>/dev/null || true)"
        else
            keys="$(gsettings list-keys "$schema" 2>/dev/null || true)"
        fi

        for key in command custom-command launcher; do
            if printf '%s\n' "$keys" | grep -qx "$key"; then
                if [ -d "$schema_dir" ]; then
                    gsettings --schemadir "$schema_dir" set "$schema" "$key" 'ulauncher-toggle' >/dev/null 2>&1 || true
                else
                    gsettings set "$schema" "$key" 'ulauncher-toggle' >/dev/null 2>&1 || true
                fi
            fi
        done

        for key in application default-application default-app app; do
            if printf '%s\n' "$keys" | grep -qx "$key"; then
                if [ -d "$schema_dir" ]; then
                    gsettings --schemadir "$schema_dir" set "$schema" "$key" 'ulauncher.desktop' >/dev/null 2>&1 || true
                else
                    gsettings set "$schema" "$key" 'ulauncher.desktop' >/dev/null 2>&1 || true
                fi
            fi
        done
    fi
fi

rm -f "$AUTOSTART_PATH"
EOF

    chmod +x "$ENABLE_SCRIPT_PATH"
    set_owner_if_root "$ENABLE_SCRIPT_PATH"

    cat > "$AUTOSTART_PATH" <<'EOF'
[Desktop Entry]
Type=Application
Name=PiercingXX GNOME Extensions
Exec=/bin/sh -lc "$HOME/.local/bin/piercingxx-enable-gnome-extensions.sh"
OnlyShowIn=GNOME;
X-GNOME-Autostart-enabled=true
Terminal=false
EOF

    set_owner_if_root "$AUTOSTART_PATH"
}

main() {
    require_cmd curl
    require_cmd git
    require_cmd sudo
    require_cmd xbps-install
    require_cmd gnome-shell

    [ -n "$TARGET_HOME" ] || die "Unable to determine home directory for ${TARGET_USER}"

    install_available_packages git curl perl nodejs npm make typescript gnome-shell-extensions dconf
    ensure_extension_installer

    install_extension_by_id 615 'AppIndicator and KStatusNotifierItem Support'
    install_extension_by_id 3193 'Blur My Shell'
    install_extension_by_id 3843 'Just Perfection'
    install_extension_by_id 1319 'GSConnect'
    install_extension_by_id 5967 'Workspaces by Open Apps'
    install_pop_shell
    install_super_key

    write_enable_script
    user_run "$ENABLE_SCRIPT_PATH" || true
    log 'Complete'
}

main "$@"