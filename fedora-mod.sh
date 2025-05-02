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
    apt install whiptail -y
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
        "Install Apps"                          "Installs Apps,fonts,etcs" \
        "Piercing Gimp"                         "Piercing Gimp Presets (Distro Agnostic)" \
        "PiercingXX Rice"                       "Apply Piercing Rice (Distro Agnostic)" \
        "Beautiful Bash"                        "Chris Titus' Beautiful Bash Script" \
        "Surface Kernel"                        "Install Surface Kernal" \
        "Reboot System"                         "Reboot the system" \
        "Exit"                                  "Exit the script" 3>&1 1>&2 2>&3
}
# Main menu loop
while true; do
    clear
    echo -e "${BLUE}PiercingXX's Arch Mod Script${NC}"
    echo -e "${GREEN}Welcome ${username}${NC}\n"
    choice=$(menu)
    case $choice in
        "Install Apps")
            echo -e "${YELLOW}Installing Gnome...${NC}"
            cd scripts || exit
            chmod u+x 1.sh
            sudo ./1.sh
            cd "$builddir" || exit
            ;;
        "Piercing Gimp")
            # Gimp Dots
                echo -e "${YELLOW}Installing Piercing Gimp Presets...${NC}"
                if git clone https://github.com/Piercingxx/gimp-dots.git; then
                    chmod -R u+x gimp-dots
                    chown -R "$username":"$username" gimp-dots
                    sudo rm -Rf /home/"$username"/.var/app/org.gimp.GIMP/config/GIMP/*
                    sudo rm -Rf /home/"$username"/.config/GIMP/*
                    mkdir -p /home/"$username"/.config/GIMP/3.0
                    chown -R "$username":"$username" /home/"$username"/.config/GIMP
                    cd gimp-dots/Gimp || exit
                    cp -Rf 3.0/* /home/"$username"/.config/GIMP/3.0
                    chown "$username":"$username" -R /home/"$username"/.config/GIMP
                    cd "$builddir" || exit
                    echo -e "${GREEN}Piercing Gimp Presets Installed Successfully!${NC}"
                else
                    echo -e "${RED}Failed to clone gimp-dots repository${NC}"
                fi
            ;;
        "PiercingXX Rice")
            echo -e "${YELLOW}Downloading and Applying PiercingXX Rice...${NC}"
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
                # Piercings Gnome Customizations
                    echo -e "${YELLOW}Applying PiercingXX Gnome Customizations...${NC}"
                        cd piercing-dots || exit
                        cd scripts || exit
                        ./gnome-customizations.sh
                        cd "$builddir" || exit
                # Add in backgrounds and themes and apply them
                rm -rf piercing-dots
            echo -e "${GREEN}PiercingXX Rice Applied Successfully!${NC}"
            ;;
        "Beautiful Bash")
            echo -e "${YELLOW}Installing Beautiful Bash...${NC}"
                git clone https://github.com/christitustech/mybash
                    chmod -R u+x mybash
                    chown -R "$username":"$username" mybash
                    cd mybash || exit
                    /setup.sh
                    cd "$builddir" || exit
                    rm -rf mybash
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
            sleep 2
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