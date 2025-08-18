#!/bin/bash
# GitHub.com/PiercingXX

# Define colors for whiptail

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

# Checks for active network connection
if [[ -n "$(command -v nmcli)" && "$(nmcli -t -f STATE g)" != connected ]]; then
    awk '{print}' <<<"Network connectivity is required to continue."
    exit
fi

# Install required tools for TUI
if ! command -v whiptail &> /dev/null; then
    echo -e "${YELLOW}Installing whiptail...${NC}"
    sudo dnf install whiptail -y
fi

username=$(id -u -n 1000)
builddir=$(pwd)

# Cache sudo credentials
cache_sudo_credentials

# Function to display a message box
function msg_box() {
    whiptail --msgbox "$1" 0 0 0
}

# Function to display menu
function menu() {
    whiptail --backtitle "GitHub.com/PiercingXX" --title "Main Menu" \
        --menu "Run Options In Order:" 0 0 0 \
        "Install"                               "Install PiercingXX Fedora" \
        "Install Cosmic"                        "Install Cosmic Desktop"\
        "Install Hyprland"                      "Install Hyprland WM & dot files"\
        "Surface Kernel"                        "Install Surface Kernal" \
        "Reboot System"                         "Reboot the system" \
        "Exit"                                  "Exit the script" 3>&1 1>&2 2>&3
}
# Main menu loop
while true; do
    clear
    echo -e "${BLUE}PiercingXX's Fedora-Mod Script${NC}"
    echo -e "${GREEN}Welcome ${username}${NC}\n"
    choice=$(menu)
    case $choice in
        "Install")
            echo -e "${YELLOW}Starting: Installing Apps, Fonts, and Dependencies...${NC}"
            # Turn off sleep/suspend to avoid interruptions
                gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'false'
                gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'false'
                gsettings set org.gnome.settings-daemon.plugins.power idle-dim 'false'
            # Install Apps
                cd scripts || exit
                chmod u+x apps.sh
                sudo ./apps.sh
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
            # Apply Piercing Gnome Customizations as User
                cd piercing-dots/resources/scripts || exit
                ./gnome-customizations.sh
                wait
                cd "$builddir" || exit
            # Replace .bashrc
                cp -f piercing-dots/resources/bash/.bashrc /home/"$username"/.bashrc
                source ~/.bashrc
            # Clean Up
                rm -rf piercing-dots
            echo -e "${GREEN}PiercingXX Gnome Customizations Applied successfully!${NC}"
            msg_box "System will reboot now."
            sudo reboot
            ;;
        "Install Cosmic")
            sudo dnf update -y
            sudo dnf copr enable ryanabx/cosmic-epoch -y
            sudo dnf update -y
            sudo dnf install cosmic-desktop -y
            flatpak install flathub dev.edfloreshz.CosmicTweaks -y
            ;;
        "Install Hyprland")
            # Hyprland install
            echo -e "${YELLOW}Installing Hyprland & Dependencies...${NC}"
                cd scripts || exit
                chmod u+x hyprland-install.sh
                ./hyprland-install.sh
                cd "$builddir" || exit
            # Enable Bluetooth again
                sudo systemctl start bluetooth
                systemctl enable bluetooth
            # .config Dot Files
                echo -e "${YELLOW}Downloading PiercingXX Dot Files...${NC}"
                    git clone https://github.com/Piercingxx/piercing-dots.git
                        chmod -R u+x piercing-dots
                        chown -R "$username":"$username" piercing-dots
                        cd piercing-dots || exit
                        cp -Rf dots/* /home/"$username"/.config/
                        chown "$username":"$username" -R /home/"$username"/.config/*
                        cd "$builddir" || exit      
                    echo -e "${GREEN}PiercingXX Dot Files Applied Successfully!${NC}"
            echo -e "${GREEN}Installed successfully!${NC}"
            ;;
        "Surface Kernel")
            echo -e "${YELLOW}Microsoft Surface Kernel...${NC}"            
                cd scripts || exit
                chmod u+x Surface.sh
                ./Surface.sh
                cd "$builddir" || exit
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
    # Prompt to continue
    while true; do
        read -p "Press [Enter] to continue..." 
        break
    done
done
