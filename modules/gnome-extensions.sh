# shellcheck shell=bash
# GitHub.com/PiercingXX
# GNOME shell extensions - unified across distros.
# Native packages where the distro has them, git/extension-installer otherwise.

GNOME_EXT_UUIDS=(
    "appindicatorsupport@rgcjonas.gmail.com"
    "blur-my-shell@aunetx"
    "just-perfection-desktop@just-perfection"
    "gsconnect@andyholmes.github.io"
    "pop-shell@system76.com"
    "workspaces-by-open-apps@favo02"
    "super-key@tommimon.github.com"
)

gnome_extensions_install() {
    command_exists gnome-shell || { say "GNOME shell not present, skipping extensions."; return 0; }
    say "Installing GNOME extensions..."

    # 1. Native packages first
    case "$DISTRO" in
        arch|artix)
            pi gnome-shell-extensions gnome-shell-extension-appindicator libappindicator-gtk3
            aur libayatana-appindicator gnome-shell-extension-blur-my-shell-git \
                gnome-shell-extension-just-perfection-desktop gnome-shell-extension-gsconnect
            aur gnome-shell-extension-pop-shell || aur gnome-shell-extension-pop-shell-git || _build_pop_shell
            aur nautilus-open-any-terminal
            ;;
        debian)
            pi gnome-shell-extension-appindicator gnome-shell-extension-blur-my-shell \
               gnome-shell-extension-tiling-assistant
            [ "$PROFILE" = "full" ] && pi gnome-shell-extension-gsconnect
            pi nodejs npm libglib2.0-dev-bin
            _build_pop_shell
            _ego_install 3843   # Just Perfection
            ;;
        fedora)
            pi gnome-shell-extension-appindicator gnome-shell-extension-gsconnect \
               gnome-shell-extension-caffeine gnome-shell-extension-blur-my-shell \
               gnome-shell-extension-pop-shell gnome-shell-extension-just-perfection
            ;;
        void)
            pi gnome-shell-extensions chrome-gnome-shell nodejs npm make typescript perl
            _ego_install 615    # AppIndicator
            _ego_install 3193   # Blur My Shell
            _ego_install 3843   # Just Perfection
            _ego_install 1319   # GSConnect
            _build_pop_shell
            ;;
        suse|alpine)
            pi gnome-shell-extensions nodejs npm make || true
            _ego_install 615    # AppIndicator
            _ego_install 3193   # Blur My Shell
            _ego_install 3843   # Just Perfection
            _ego_install 1319   # GSConnect
            _build_pop_shell
            ;;
    esac

    # 2. Git-built extensions shared by every distro
    _ego_install 5967 || _build_workspaces_by_open_apps
    _build_super_key

    # 3. Enable now if we can, otherwise once on first login
    _enable_gnome_extensions
}

# brunelli/gnome-shell-extension-installer wrapper (installs by e.g.o ID)
_ego_install() {
    local installer="$HOME/.local/bin/gnome-shell-extension-installer"
    if [ ! -x "$installer" ]; then
        mkdir -p "$HOME/.local/bin"
        wget -qO "$installer" \
            "https://github.com/brunelli/gnome-shell-extension-installer/raw/master/gnome-shell-extension-installer" \
            && chmod +x "$installer"
    fi
    [ -x "$installer" ] || return 1
    "$installer" "$1" --yes >/dev/null 2>&1
}

_build_pop_shell() {
    if [ "$DRY_RUN" -eq 1 ]; then dry "build Pop Shell from source (branch by GNOME version)"; return 0; fi
    say "Building Pop Shell from source..."
    local gnome_major branch tmp
    gnome_major=$(gnome-shell --version 2>/dev/null | grep -oE '[0-9]+' | head -1)
    case "${gnome_major:-0}" in
        4[2-4]) branch="master_jammy" ;;
        45)     branch="master_mantic" ;;
        4[6-9]|5*) branch="master_noble" ;;
        *)      branch="master_focal" ;;
    esac
    tmp=$(mktemp -d)
    if git clone --depth 1 --branch "$branch" https://github.com/pop-os/shell.git "$tmp/pop-shell" 2>/dev/null \
        || git clone --depth 1 https://github.com/pop-os/shell.git "$tmp/pop-shell"; then
        (cd "$tmp/pop-shell" && make local-install) || warn "Pop Shell build failed."
        local schemas="$HOME/.local/share/gnome-shell/extensions/pop-shell@system76.com/schemas"
        [ -d "$schemas" ] && glib-compile-schemas "$schemas" 2>/dev/null
    fi
    command rm -rf "$tmp"
}

_build_workspaces_by_open_apps() {
    if [ "$DRY_RUN" -eq 1 ]; then dry "build workspaces-by-open-apps extension"; return 0; fi
    local tmp; tmp=$(mktemp -d)
    if git clone --depth 1 https://github.com/Favo02/workspaces-by-open-apps.git "$tmp/wboa" 2>/dev/null; then
        (cd "$tmp/wboa" && chmod +x install.sh && ./install.sh local-install) || warn "workspaces-by-open-apps build failed."
    fi
    command rm -rf "$tmp"
}

_build_super_key() {
    if [ "$DRY_RUN" -eq 1 ]; then dry "build super-key extension"; return 0; fi
    local tmp; tmp=$(mktemp -d)
    if git clone --depth 1 https://github.com/Tommimon/super-key.git "$tmp/super-key" 2>/dev/null; then
        (cd "$tmp/super-key" && chmod +x build.sh && ./build.sh -i) || warn "super-key build failed."
    fi
    command rm -rf "$tmp"
}

_enable_gnome_extensions() {
    if [ "$DRY_RUN" -eq 1 ]; then
        dry "write extension enable-script + first-login autostart (${#GNOME_EXT_UUIDS[@]} extensions)"
        return 0
    fi
    local enable_script="$HOME/.local/bin/piercingxx-enable-gnome-extensions.sh"
    mkdir -p "$HOME/.local/bin"
    {
        echo '#!/bin/bash'
        echo '# Enable PiercingXX GNOME extensions (self-removing autostart)'
        local uuid
        for uuid in "${GNOME_EXT_UUIDS[@]}"; do
            echo "gnome-extensions enable '$uuid' 2>/dev/null || true"
        done
        # Point Super Key at ulauncher
        echo 'if command -v ulauncher-toggle >/dev/null 2>&1; then'
        echo '    dconf write /org/gnome/shell/extensions/super-key/command "'"'"'ulauncher-toggle'"'"'" 2>/dev/null || true'
        echo 'fi'
        echo 'rm -f "$HOME/.config/autostart/piercingxx-enable-gnome-extensions.desktop"'
    } > "$enable_script"
    chmod +x "$enable_script"

    if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command_exists gnome-extensions; then
        "$enable_script" || true
    fi
    # Also queue for first login (extensions only register after shell restart)
    mkdir -p "$HOME/.config/autostart"
    cat > "$HOME/.config/autostart/piercingxx-enable-gnome-extensions.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Enable PiercingXX GNOME Extensions
Exec=$enable_script
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
}
