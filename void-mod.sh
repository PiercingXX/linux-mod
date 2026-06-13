#!/bin/bash
# GitHub.com/PiercingXX

# Define terminal colors
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
NC='\033[0m'

# Check if running as root. If root, script will exit
if [[ $EUID -eq 0 ]]; then
    echo "This script should not be executed as root! Exiting......."
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to cache sudo credentials
cache_sudo_credentials() {
    echo "Caching sudo credentials for script execution..."
    sudo -v
    # Keep sudo credentials fresh for the duration of the script
    (while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &)
}

ensure_network_online() {
    local state=""

    if command_exists nmcli && state=$(nmcli -t -f STATE g 2>/dev/null); then
        if [[ "$state" != connected ]]; then
            echo "Network connectivity is required to continue."
            echo "nmcli reports state: $state"
        fi
    else
        echo "NetworkManager status unavailable, falling back to route/interface checks..."
    fi

    if ip route show default 2>/dev/null | grep -q '^default ' && ip -4 addr show up 2>/dev/null | grep -q "inet "; then
        return 0
    fi

    # Fallback: ensure at least one interface has an IPv4 address and internet is reachable
    if ! ip -4 addr show up 2>/dev/null | grep -q "inet "; then
        echo "Network connectivity is required to continue."
        exit 1
    fi

    # Additional ping test to confirm internet reachability when default route detection is inconclusive
    if ! ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
        if ! ping -c 1 -W 1 1.1.1.1 >/dev/null 2>&1; then
            echo "Network connectivity is required to continue."
            exit 1
        fi
    fi
}

enable_service() {
    local service_name="$1"
    local required="${2:-0}"
    local service_dir

    if [ ! -d "/etc/sv/$service_name" ]; then
        echo "Skipping missing service: $service_name"
        if [ "$required" -eq 1 ]; then
            return 1
        fi
        return 0
    fi

    if [ -e /var/service ]; then
        service_dir="/var/service"
    elif [ -d /etc/runit/runsvdir/current ]; then
        service_dir="/etc/runit/runsvdir/current"
    elif [ -d /etc/runit/runsvdir/default ]; then
        service_dir="/etc/runit/runsvdir/default"
    else
        echo "Unable to determine runit service directory for: $service_name"
        if [ "$required" -eq 1 ]; then
            return 1
        fi
        return 0
    fi

    sudo mkdir -p "$service_dir"
    sudo rm -f "$service_dir/$service_name"
    sudo ln -s "/etc/sv/$service_name" "$service_dir/$service_name"
    sudo sv up "$service_name" >/dev/null 2>&1 || true
}

install_safe_launcher_helpers() {
    sudo tee /usr/local/bin/gnome-wayland >/dev/null <<'EOF'
#!/bin/sh
if ! command -v gnome-session >/dev/null 2>&1; then
    echo "gnome-session is not installed. Re-run the base installer or install GNOME packages first." >&2
    exit 127
fi

exec env XDG_SESSION_TYPE=wayland XDG_RUNTIME_DIR="/run/user/$(id -u)" dbus-run-session gnome-session "$@"
EOF
    sudo chmod +x /usr/local/bin/gnome-wayland

    sudo tee /usr/local/bin/gnome-x11 >/dev/null <<'EOF'
#!/bin/sh
if ! command -v gnome-session >/dev/null 2>&1; then
    echo "gnome-session is not installed. Re-run the base installer or install GNOME packages first." >&2
    exit 127
fi

if ! command -v startx >/dev/null 2>&1; then
    echo "startx is not installed. Install xinit before launching GNOME X11." >&2
    exit 127
fi

exec dbus-run-session startx /usr/bin/gnome-session -- "$@"
EOF
    sudo chmod +x /usr/local/bin/gnome-x11

    sudo tee /usr/local/bin/hypr >/dev/null <<'EOF'
#!/bin/sh
if command -v start-hyprland >/dev/null 2>&1; then
    exec start-hyprland "$@"
fi

echo "start-hyprland is not installed. Install Hyprland from the Optional Window Managers menu first." >&2
exit 127
EOF
    sudo chmod +x /usr/local/bin/hypr
}

ensure_local_bin_on_path() {
    local bashrc_path="/home/$username/.bashrc"

    if ! grep -q 'export PATH.*\.local/bin' "$bashrc_path"; then
        printf '%s\n' 'export PATH="$HOME/.local/bin:$PATH"' >> "$bashrc_path"
    fi
}

ensure_jump_shell_integration() {
    local bashrc_path="/home/$username/.bashrc"

    if ! grep -q 'jump shell' "$bashrc_path"; then
        printf '%s\n' 'command -v jump >/dev/null 2>&1 && eval "$(jump shell)"' >> "$bashrc_path"
    fi
}



# Ensure gum is installed, auto-install if missing
if ! command -v gum &> /dev/null; then
    echo -e "${YELLOW}gum is not installed. Attempting to install via xbps...${NC}"
    sudo xbps-install -Sy gum
fi

username=$(id -u -n 1000)
builddir=$(pwd)
PIERCING_DOTS_DIR="$builddir/piercing-dots"

ensure_piercing_dots_checkout() {
    if [ -d "$PIERCING_DOTS_DIR/.git" ]; then
        return 0
    fi

    rm -rf "$PIERCING_DOTS_DIR"
    git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git "$PIERCING_DOTS_DIR"
}

cleanup_piercing_dots_checkout() {
    rm -rf "$PIERCING_DOTS_DIR"
}

can_apply_gnome_polish_now() {
    command_exists gsettings || return 1
    command_exists dconf || return 1
    [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || return 1
    [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || return 1
    return 0
}

install_gnome_polish_optional() {
    local remove_after=0

    if [ ! -d "$PIERCING_DOTS_DIR/.git" ]; then
        ensure_piercing_dots_checkout
        remove_after=1
    fi

    echo -e "${YELLOW}Applying GNOME polish...${NC}"
    cd "$PIERCING_DOTS_DIR/scripts" || exit
    chmod u+x gnome-customizations.sh
    ./gnome-customizations.sh
    cd "$builddir" || exit

    if [ "$remove_after" -eq 1 ]; then
        cleanup_piercing_dots_checkout
    fi
}

# Cache sudo credentials
cache_sudo_credentials

# Require network for installs/downloads
ensure_network_online


# Function to display a message box using gum
function msg_box() {
    gum style --border double --margin "1 2" --padding "1 2" --foreground 212 "$1" | gum pager
}

# Function to display menu using gum
function menu() {
    gum choose \
    "Install Void Mod" \
    "Install Optional Window Managers" \
    "Rotate TTY 90 Clockwise" \
    "Reboot System" \
    "Exit"
}

function window_manager_menu() {
    gum choose \
    "Install DWM (Optional)" \
    "Install herbstluftwm (Optional)" \
    "Install Awesome (Optional)" \
    "Install Hyprland (Optional)" \
    "Install Qtile (Optional)" \
    "Install Sway (Optional)" \
    "Install i3 (Optional)" \
    "Install bspwm (Optional)" \
        "Back"
}

function printer_menu() {
    gum choose \
    "Install Canon D530 Printer" \
    "Install Omezizy Label Printer" \
    "Back"
}

run_wm_install_script() {
    local label="$1"
    local script_name="$2"

    echo -e "${YELLOW}Installing ${label} & Dependencies...${NC}"
    cd scripts || exit
    chmod u+x "$script_name"
    if ! ./"$script_name"; then
        cd "$builddir" || true
        echo -e "${YELLOW}${label} install encountered errors — check output above.${NC}"
        return 1
    fi
    cd "$builddir" || exit
    echo -e "${GREEN}${label} Installed successfully!${NC}"
}

run_helper_script() {
    local label="$1"
    local script_name="$2"

    echo -e "${YELLOW}${label}...${NC}"
    cd scripts || exit
    chmod u+x "$script_name"
    ./"$script_name"
    cd "$builddir" || exit
}

run_printer_install_script() {
    local label="$1"
    local target="$2"

    echo -e "${YELLOW}${label}...${NC}"
    cd scripts || exit
    chmod u+x install-printers.sh
    if ! ./install-printers.sh "$target"; then
        cd "$builddir" || true
        echo -e "${YELLOW}${label} encountered errors — check output above.${NC}"
        return 1
    fi
    cd "$builddir" || exit
    echo -e "${GREEN}${label} completed successfully!${NC}"
}

run_gnome_extension_install_script() {
    echo -e "${YELLOW}Installing GNOME extensions...${NC}"
    cd scripts || exit
    chmod u+x install-gnome-extensions.sh
    if ! ./install-gnome-extensions.sh; then
        cd "$builddir" || true
        echo -e "${YELLOW}GNOME extension install encountered errors — check output above.${NC}"
        return 1
    fi
    cd "$builddir" || exit
    echo -e "${GREEN}GNOME extensions installed successfully!${NC}"
}

run_gaming_install_script() {
    echo -e "${YELLOW}Installing gaming stuff...${NC}"
    cd scripts || exit
    chmod u+x install-gaming-stuff.sh
    if ! ./install-gaming-stuff.sh; then
        cd "$builddir" || true
        echo -e "${YELLOW}Gaming install encountered errors — check output above.${NC}"
        return 1
    fi
    cd "$builddir" || exit
    echo -e "${GREEN}Gaming stuff installed successfully!${NC}"
}

install_selected_window_managers() {
    local wm_choices
    local wm_choice

    wm_choices=$(window_manager_menu) || wm_choices=""
    [ -n "$wm_choices" ] || return 0

    if [ "$wm_choices" = "Back" ]; then
        return 0
    fi

    wm_choice="$wm_choices"
    case $wm_choice in
        "Install DWM (Optional)")
            run_wm_install_script "DWM" "dwm-install.sh"
            ;;
        "Install herbstluftwm (Optional)")
            run_wm_install_script "herbstluftwm" "herbstluftwm-install.sh"
            ;;
        "Install Awesome (Optional)")
            run_wm_install_script "Awesome" "awesome-install.sh"
            ;;
        "Install Hyprland (Optional)")
            run_wm_install_script "Hyprland" "hyprland-install.sh"
            ;;
        "Install Qtile (Optional)")
            run_wm_install_script "Qtile" "qtile-install.sh"
            ;;
        "Install Sway (Optional)")
            run_wm_install_script "Sway" "sway-install.sh"
            ;;
        "Install i3 (Optional)")
            run_wm_install_script "i3" "i3-install.sh"
            ;;
        "Install bspwm (Optional)")
            run_wm_install_script "bspwm" "bspwm-install.sh"
            ;;
    esac
}

install_selected_printer() {
    local printer_choice

    printer_choice=$(printer_menu) || printer_choice=""
    [ -n "$printer_choice" ] || return 0

    case "$printer_choice" in
        "Install Canon D530 Printer")
            run_printer_install_script "Installing Canon D530 printer" "canon-d530"
            ;;
        "Install Omezizy Label Printer")
            run_printer_install_script "Installing Omezizy label printer" "omezizy"
            ;;
    esac
}

install_all_printers() {
    run_printer_install_script "Installing Canon D530 printer" "canon-d530" || return 1
    run_printer_install_script "Installing Omezizy label printer" "omezizy" || return 1
}

prompt_install_printers_after_install() {
    echo -e "${YELLOW}Installing both printer configurations...${NC}"
    install_all_printers
}

apply_gnome_polish_after_install() {
    if ! can_apply_gnome_polish_now; then
        echo -e "${YELLOW}Skipping GNOME polish: no active GNOME session detected during install.${NC}"
        return 0
    fi

    install_gnome_polish_optional
}

prompt_install_window_managers_after_install() {
    if gum confirm "Install optional window managers before reboot?"; then
        install_selected_window_managers
    fi
}

prompt_install_gaming_stuff_after_install() {
    if gum confirm "Install gaming stuff before reboot?"; then
        run_gaming_install_script
    fi
}

# Main menu loop
while true; do
    clear
    echo -e "${BLUE}PiercingXX's Void Mod Script${NC}"
    echo -e "${GREEN}Welcome ${username}${NC}\n"
    choice=$(menu)
    case $choice in
        "Install Void Mod")
                echo -e "${YELLOW}Installing Essentials...${NC}"
                cd scripts || exit
                chmod u+x step-1.sh
                ./step-1.sh
                wait
                cd "$builddir" || exit
                echo -e "${GREEN}Essentials Installed successfully!${NC}"
                echo -e "${YELLOW}Applying PiercingXX Dotfiles...${NC}"
                cleanup_piercing_dots_checkout
                ensure_piercing_dots_checkout
                cd "$PIERCING_DOTS_DIR" || exit
                chmod u+x install.sh
                ./install.sh
                cd "$builddir" || exit
                wait
                # Enable bluetooth via runit
                enable_service bluetoothd
            # Bash support
                cp -f "$PIERCING_DOTS_DIR/resources/bash/.bashrc" /home/"$username"/.bashrc
                ensure_local_bin_on_path
                ensure_jump_shell_integration
                # shellcheck disable=SC1090
                source "/home/$username/.bashrc"
                install_safe_launcher_helpers
                run_gnome_extension_install_script
            prompt_install_printers_after_install
            apply_gnome_polish_after_install
            cleanup_piercing_dots_checkout
            prompt_install_window_managers_after_install
            prompt_install_gaming_stuff_after_install
            if [ "${VOID_INSTALL_GDM:-0}" = "1" ]; then
                msg_box "System will reboot now. GDM was enabled for graphical login."
            else
                msg_box "System will reboot now. GDM is off by default; use gnome-wayland, gnome-x11, or install an optional window manager after reboot."
            fi
            sudo reboot
            ;;
        "Install Optional Window Managers")
            install_selected_window_managers
            ;;
        "Rotate TTY 90 Clockwise")
            run_helper_script "Rotating TTY 90 degrees clockwise" "rotate-tty-clockwise.sh"
            msg_box "TTY rotation applied. Reboot for persistent boot-time rotation."
            ;;
        "Reboot System")
            echo -e "${YELLOW}Rebooting system in 3 seconds...${NC}"
            sleep 1
            sudo reboot
            ;;
        "Exit")
            clear
            echo -e "${BLUE}Thank You Handsome!${NC}"
            exit 0
            ;;
    esac
    # Prompt to continue
    read -r -p "Press Enter to continue..." _
done
