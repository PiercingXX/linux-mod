#!/bin/bash
# GitHub.com/PiercingXX

# Define colors for whiptail

# Function to check if a command exists
    command_exists() {
        command -v "$1" >/dev/null 2>&1
    }

# Cache sudo credentials
    cache_sudo_credentials() {
        echo "Caching sudo credentials for script execution..."
        sudo -v
        # Keep sudo credentials fresh for the duration of the script
        (while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &)
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


# Install required tools for TUI
    if ! command -v whiptail &> /dev/null; then
        echo -e "${YELLOW}Installing whiptail...${NC}"
        apt install whiptail -y
    fi

username=$(id -u -n 1000)
builddir=$(pwd)

setup_gnome_customizations_autostart_from_repo() {
    local repo_dir="$builddir/piercing-dots"
    local script_src="$repo_dir/scripts/gnome-customizations.sh"
    local home_dir
    home_dir="$(getent passwd "$username" | cut -d: -f6)"
    [ -z "$home_dir" ] && home_dir="/home/$username"

    [ -f "$script_src" ] || return 0

    local autostart_dir="$home_dir/.config/autostart"
    local runner_dir="$home_dir/.local/bin"
    local script_dir="$home_dir/.local/share/piercing-dots"
    local runner="$runner_dir/piercingxx-gnome-customizations-once.sh"
    local autostart_file="$autostart_dir/piercingxx-gnome-customizations.desktop"

    sudo mkdir -p "$autostart_dir" "$runner_dir" "$script_dir"
    sudo cp -f "$script_src" "$script_dir/gnome-customizations.sh"
    sudo chmod +x "$script_dir/gnome-customizations.sh"
    sudo chown -R "$username":"$username" "$runner_dir" "$script_dir" "$autostart_dir"

    sudo tee "$runner" >/dev/null <<'EOF'
#!/bin/bash
set -e

marker="$HOME/.config/piercingxx-gnome-customizations.applied"
script="$HOME/.local/share/piercing-dots/gnome-customizations.sh"
autostart="$HOME/.config/autostart/piercingxx-gnome-customizations.desktop"

if [ -f "$marker" ]; then
    rm -f "$autostart"
    exit 0
fi

if [ ! -x "$script" ]; then
    rm -f "$autostart"
    exit 0
fi

"$script"
touch "$marker"
rm -f "$autostart"
EOF
    sudo chmod +x "$runner"
    sudo chown "$username":"$username" "$runner"

    sudo tee "$autostart_file" >/dev/null <<EOF
[Desktop Entry]
Type=Application
Name=PiercingXX Gnome Customizations (One-time)
Exec=$runner
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
    sudo chown "$username":"$username" "$autostart_file"
}

# Function to display a message box
function msg_box() {
    whiptail --msgbox "$1" 0 0 0
}

# Function to display menu
function menu() {
    whiptail --backtitle "GitHub.com/PiercingXX" --title "Main Menu" \
        --menu "Run Options In Order:" 0 0 0 \
        "Install"                               "Install PiercingXX Debian" \
        "Nvidia Driver"                         "Install Nvidia Drivers (Do not install on a Surface Device)" \
        "Apply KooTigers Touchscreen Driver"    "Apply KooTigers Touchscreen Driver" \
        "Apply NuVision 8in Tablet Fixes"       "Apply NuVision 8in Tablet Fixes" \
        "Optional Surface Kernel"               "Microsoft Surface Kernel" \
        "Reboot System"                         "Reboot the system" \
        "Exit"                                  "Exit the script" 3>&1 1>&2 2>&3
}
# Main menu loop
while true; do
    clear
    echo -e "${GREEN}Welcome ${username}${NC}\n"
    choice=$(menu)
    case $choice in
        "Install")
            echo -e "${YELLOW}Updating System...${NC}"
            # Install Rust here, not in subscript
                # Ensure Rust is installed
                    if ! command_exists cargo; then
                        echo -e "${YELLOW}Installing Rust toolchain…${NC}"
                        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
                        rustup update
                        # Load the new cargo environment for this shell
                        source "$HOME/.cargo/env"
                    fi
            # Install Gnome and Dependencies
                cd scripts || exit
                chmod u+x step-1.sh
                sudo ./step-1.sh
                wait
                cd "$builddir" || exit
            # Apply Piercing Rice
                echo -e "${YELLOW}Applying PiercingXX Gnome Customizations...${NC}"
                rm -rf piercing-dots
                git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
                cd piercing-dots || exit
                chmod u+x install.sh
                ./install.sh
                wait
                cd "$builddir" || exit
            # Install Apps & Dependencies
                echo -e "${YELLOW}Installing Apps & Dependencies...${NC}"
                cd scripts || exit
                chmod u+x apps.sh
                sudo ./apps.sh
                wait
                cd "$builddir" || exit
            # Apply Piercing Gnome Customizations as User
                cd piercing-dots/scripts || exit
                ./gnome-customizations.sh
                wait
                cd "$builddir" || exit
            # Ensure Gnome customizations run once on first login
                setup_gnome_customizations_autostart_from_repo
            # Replace .bashrc
                cp -f piercing-dots/resources/bash/.bashrc /home/"$username"/.bashrc
                source ~/.bashrc
            # Bash Stuff
                install_bashrc_support
            # Clean Up
                rm -rf piercing-dots
            echo -e "${GREEN}PiercingXX Gnome Customizations Applied successfully!${NC}"
            sudo systemctl enable gdm3 --now
            wait
            msg_box "System will reboot now."
            sudo reboot
            ;;
        "Nvidia Driver")
            echo -e "${YELLOW}Installing Nvidia Drivers...${NC}"
            # Install Nvidia Drivers
                cd scripts || exit
                chmod u+x nvidia.sh
                sudo ./nvidia.sh
                wait
                cd "$builddir" || exit
            echo -e "${GREEN}Nvidia Drivers Installed Successfully!${NC}"
            msg_box "Nvidia Drivers installed successfully. Reboot the system to apply changes."
            sudo reboot
            ;;
        "Apply KooTigers Touchscreen Driver")
            echo -e "${YELLOW}Applying KooTigers Touchscreen Driver...${NC}"
            cd resources/KooTigers-drivers/ || exit
            chmod +x ./kootigers-drivers.sh
            sudo ./kootigers-drivers.sh
            cd "$builddir" || exit
            echo -e "${GREEN}KooTigers Touchscreen Driver Applied Successfully! Please Reboot!${NC}"
            ;;
        "Apply NuVision 8in Tablet Fixes")
            echo -e "${YELLOW}Applying NuVision 8in Tablet Fixes...${NC}"
            cd resources/NuVision-8in-tablet/ || exit
            chmod +x ./nuvision-tablet-drivers.sh
            sudo ./nuvision-tablet-drivers.sh
            cd "$builddir" || exit
            echo -e "${GREEN}NuVision 8in Tablet Fixes Applied Successfully! Please Reboot!${NC}"
            ;;
        "Optional Surface Kernel")
            echo -e "${YELLOW}Microsoft Surface Kernel...${NC}"            
                cd scripts || exit
                chmod u+x Surface.sh
                sudo ./Surface.sh
                cd "$builddir" || exit
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
    while true; do
        read -p "Press [Enter] to continue..." 
        break
    done
done

