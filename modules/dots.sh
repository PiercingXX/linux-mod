# shellcheck shell=bash
# GitHub.com/PiercingXX
# Apply the piercing-dots rice: dotfiles, GNOME customizations, .bashrc.
# Unified from the identical flows in all seven *-mod repos.

can_apply_gnome_polish_now() {
    command_exists gsettings || return 1
    command_exists dconf || return 1
    [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || return 1
    [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || return 1
    return 0
}

# One-time autostart so the GNOME polish applies on first login when the
# install ran from a TTY (from debian-mini-mod, useful everywhere).
setup_gnome_polish_autostart() {
    local script_src="$PIERCING_DOTS_DIR/scripts/gnome-customizations.sh"
    [ -f "$script_src" ] || return 0

    local autostart_dir="$HOME/.config/autostart"
    local script_dir="$HOME/.local/share/piercing-dots"
    local runner="$HOME/.local/bin/piercingxx-gnome-customizations-once.sh"

    mkdir -p "$autostart_dir" "$HOME/.local/bin" "$script_dir"
    cp -f "$script_src" "$script_dir/gnome-customizations.sh"
    chmod +x "$script_dir/gnome-customizations.sh"

    cat > "$runner" <<'EOF'
#!/bin/bash
set -e
marker="$HOME/.config/piercingxx-gnome-customizations.applied"
script="$HOME/.local/share/piercing-dots/gnome-customizations.sh"
autostart="$HOME/.config/autostart/piercingxx-gnome-customizations.desktop"
[ -f "$marker" ] && { rm -f "$autostart"; exit 0; }
[ -x "$script" ] || { rm -f "$autostart"; exit 0; }
"$script"
touch "$marker"
rm -f "$autostart"
EOF
    chmod +x "$runner"

    cat > "$autostart_dir/piercingxx-gnome-customizations.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=PiercingXX Gnome Customizations (One-time)
Exec=$runner
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
}

apply_dots() {
    if [ "$DRY_RUN" -eq 1 ]; then
        dry "apply piercing-dots rice: dotfiles, GNOME polish, .bashrc"
        return 0
    fi
    say "Applying PiercingXX customizations (piercing-dots)..."
    ensure_piercing_dots

    (cd "$PIERCING_DOTS_DIR" && chmod u+x install.sh && ./install.sh) || warn "piercing-dots install.sh reported errors."

    # Bluetooth back on (whatever the init system calls it)
    svc_enable bluetooth bluetoothd || true

    # GNOME polish: now if a session is live, otherwise once on first login
    if can_apply_gnome_polish_now; then
        (cd "$PIERCING_DOTS_DIR/scripts" && chmod u+x gnome-customizations.sh && ./gnome-customizations.sh) \
            || warn "gnome-customizations.sh reported errors."
    else
        say "No active GNOME session — scheduling GNOME polish for first login."
        setup_gnome_polish_autostart
    fi

    # Replace .bashrc with the piercing-dots one
    cp -f "$PIERCING_DOTS_DIR/resources/bash/.bashrc" "$HOME/.bashrc"
    if ! grep -q 'export PATH.*\.local/bin' "$HOME/.bashrc"; then
        printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    # shellcheck disable=SC1091
    source "$HOME/.bashrc" 2>/dev/null || true

    cleanup_piercing_dots
    ok "PiercingXX customizations applied!"
}
