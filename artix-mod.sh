#!/bin/bash
# GitHub.com/PiercingXX

# Color definitions
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# Check/install gum if missing
if ! command -v gum &> /dev/null; then
    echo "gum not found. Installing..."
    if command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm gum
    else
        echo "Please install gum manually."
        exit 1
    fi
fi

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

# Function to install bashrc support (placeholder - extend as needed)
install_bashrc_support() {
    # This function ensures bashrc configurations are properly loaded
    # Add any bashrc initialization logic here
    return 0
}

# Check for active network connection
if command_exists nmcli; then
    state=$(nmcli -t -f STATE g)
    if [[ "$state" != connected ]]; then
        echo "Network connectivity is required to continue."
        exit 1
    fi
else
    # Fallback: ensure at least one interface has an IPv4 address
    if ! ip -4 addr show | grep -q "inet "; then
        echo "Network connectivity is required to continue."
        exit 1
    fi
fi

# Additional ping test to confirm internet reachability
if ! ping -c 1 -W 1 8.8.8.8 >/dev/null 2>&1; then
    echo "Network connectivity is required to continue."
    exit 1
fi




username=$(id -un)
builddir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$builddir" || exit 1

# shellcheck source=scripts/service-manager.sh
. "$builddir/scripts/service-manager.sh"

# Cache sudo credentials
cache_sudo_credentials

# Function to display a message box using gum
function msg_box() {
    gum style --border double --margin "1 2" --padding "1 2" --foreground 212 "$1"
    read -n 1 -s -r -p "Press any key to continue..."; echo
}

# Function to display menu using gum
function menu() {
    local options=(
        "Install Artix Mod"
        "Window Managers"
        "Optional Nvidia Drivers"
        "Optional Surface Kernel"
        "Rotate TTY Clockwise"
        "Reboot System"
        "Exit"
    )
    printf "%s\n" "${options[@]}" | gum choose --header "Run Options In Order:" --cursor.foreground 212 --selected.foreground 212
}

ensure_piercing_dots_repo() {
    if [ ! -d "piercing-dots/.git" ]; then
        rm -rf piercing-dots
        git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
    fi
}

run_wm_install_script() {
    local label="$1"
    local script_name="$2"

    echo -e "${YELLOW}Installing ${label}...${NC}" | tee -a /tmp/wm_install.log
    cd scripts || exit
    chmod u+x "$script_name"
    ./$script_name 2>&1 | tee -a /tmp/wm_install.log
    cd "$builddir" || exit
    echo -e "${GREEN}${label} installed successfully!${NC}" | tee -a /tmp/wm_install.log
}

install_terminal_minimal_session() {
    ensure_piercing_dots_repo
    sudo bash "$(pwd)/piercing-dots/scripts/setup-terminal-session.sh"
}

configure_default_display_manager() {
    echo -e "${YELLOW}Configuring default login manager (ly)...${NC}"

    # Stop and disable common alternatives so ly is the only active display manager.
    disable_and_stop_service lightdm sddm gdm lxdm xdm >/dev/null 2>&1 || true

    if enable_ly_service; then
        echo -e "${GREEN}ly is now enabled as the default login manager.${NC}"
    else
        echo "Warning: Could not enable/start ly service automatically on this init system."
    fi
}

window_manager_menu() {
    local options=(
        "Install i3"
        "Install bspwm"
        "Install Hyprland"
        "Install GNOME"
        "Install BusyBox Profile"
        "Install Terminal Minimal Session"
        "Back"
    )
    local wm_choices
    local wm_choice

    while true; do
        clear
        echo -e "${BLUE}Window Manager Installer${NC}"
        wm_choices=$(printf "%s\n" "${options[@]}" | gum choose --header "Choose one or more installs:" --cursor.foreground 212 --selected.foreground 212) || break

        [ -n "$wm_choices" ] || break

        if [ "$wm_choices" = "Back" ]; then
            break
        fi

        wm_choice="$wm_choices"
        case $wm_choice in
            "Install i3")
                run_wm_install_script "i3" "i3-install.sh"
                ;;
            "Install bspwm")
                run_wm_install_script "bspwm" "bspwm-install.sh"
                ;;
            "Install Hyprland")
                run_wm_install_script "Hyprland" "hyprland-install.sh"
                ;;
            "Install GNOME")
                run_wm_install_script "GNOME" "gnome-install.sh"
                ;;
            "Install BusyBox Profile")
                run_wm_install_script "BusyBox Profile" "busybox-install.sh"
                ;;
            "Install Terminal Minimal Session")
                install_terminal_minimal_session
                ;;
        esac

        read -n 1 -s -r -p "Press any key to continue..."; echo
    done
}

prompt_install_window_managers_after_install() {
    if gum confirm "Install window managers before reboot?"; then
        window_manager_menu
    fi
}

# Main menu loop
while true; do
    clear
    echo -e "${BLUE}PiercingXX's Artix Mod Script${NC}"
    echo -e "${GREEN}Welcome ${username}${NC}\n"
    choice=$(menu)
    case $choice in
        "Install Artix Mod")
            echo -e "${YELLOW}Installing Essentials...${NC}"
            # Essentials
                cd scripts || exit
                chmod u+x step-1.sh
                ./step-1.sh
                wait
                cd "$builddir" || exit
            # Install bash support
                # Load user's bashrc
                if [ -f "/home/$username/.bashrc" ]; then
                    . "/home/$username/.bashrc"
                fi
                install_bashrc_support
            echo -e "${GREEN}Essentials Installed successfully!${NC}"
            # Apply Piercing Rice
                echo -e "${YELLOW}Applying PiercingXX Base Customizations...${NC}"
                rm -rf piercing-dots
                git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
                cd piercing-dots || exit
                chmod u+x install.sh
                ./install.sh
                wait
                cd "$builddir" || exit
            # App install
            echo -e "${YELLOW}Installing Core Applications...${NC}"
                cd scripts || exit
                chmod u+x apps.sh
                ./apps.sh
                wait
                cd "$builddir" || exit
            echo -e "${GREEN}Core Apps Installed successfully!${NC}"
            configure_default_display_manager
            # Window managers now installed from dedicated menu option
            echo -e "${YELLOW}Window manager install/style is now in the Window Managers menu option.${NC}"
            # Enable Bluetooth again
                if ! enable_and_start_service bluetooth bluetoothd; then
                    echo "Warning: Could not start/enable Bluetooth service on this init system."
                fi
            # Replace .bashrc
                cp -f piercing-dots/resources/bash/.bashrc /home/"$username"/.bashrc
                source "$HOME/.bashrc"
            # Install Printers
                chmod u+x scripts/install-printers.sh
                PRINTER_TARGET="${PRINTER_TARGET:-canon-d530}" ./scripts/install-printers.sh "${PRINTER_TARGET:-canon-d530}"
                wait
                cd "$builddir" || exit
            # Clean Up
                rm -rf piercing-dots
            echo -e "${GREEN}PiercingXX Base Customizations Applied successfully!${NC}"
            prompt_install_window_managers_after_install
            msg_box "System will reboot now."
            sudo reboot
            ;;
        "Optional Nvidia Drivers")
            echo -e "${YELLOW}Installing Nvidia Drivers...${NC}"
                cd scripts || exit
                chmod +x ./nvidia.sh
                sudo ./nvidia.sh
                cd "$builddir" || exit
            ;;
        "Window Managers")
            window_manager_menu
            ;;
        "Optional Surface Kernel")
            echo -e "${YELLOW}Microsoft Surface Kernel...${NC}"            
                chmod +x scripts/surface-kernel-setup.sh
                sudo ./scripts/surface-kernel-setup.sh
                cd "$builddir" || exit
                echo -e "${GREEN}Microsoft Kernel Installed.!${NC}"
            ;;
        "Rotate TTY Clockwise")
            echo -e "${YELLOW}Rotating TTY 90 degrees clockwise and persisting in GRUB...${NC}"
                chmod +x scripts/rotate-tty-clockwise.sh
                sudo ./scripts/rotate-tty-clockwise.sh
                cd "$builddir" || exit
                echo -e "${GREEN}TTY rotation applied. Reboot for full effect.${NC}"
            ;;
        "Reboot System")
            echo -e "${YELLOW}Rebooting system in 3 seconds...${NC}"
            sleep 1
            reboot
            ;;
        "Exit")
            clear
            echo -e "${BLUE}Thank You Handsome!${NC}"
            exit 0
            ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."; echo
done
