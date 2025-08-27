#!/bin/bash
# https://github.com/Piercingxx

# Check if Script is Run as Root
if [[ $EUID -ne 0 ]]; then
    echo "You must be a root user to run this script, please run sudo su then try again" 2>&1
    exit 1
fi

username=$(id -u -n 1000)
builddir=$(pwd)

# Checks for active network connection
if [[ -n "$(command -v nmcli)" && "$(nmcli -t -f STATE g)" != connected ]]; then
    awk '{print}' <<<"Network connectivity is required to continue."
    exit
fi

sudo dnf update -y

# Create Directories if needed
    # font directory
        if [ ! -d "$HOME/.fonts" ]; then
            mkdir -p "$HOME/.fonts"
        fi
        chown -R "$username":"$username" "$HOME"/.fonts
    # config directory
        if [ ! -d "$HOME/.config" ]; then
            mkdir -p /home/"$username"/.config
        fi
        chown -R "$username":"$username" /home/"$username"/.config
    # icons directory
        if [ ! -d "$HOME/.icons" ]; then
            mkdir -p /home/"$username"/.icons
        fi
        chown -R "$username":"$username" /home/"$username"/.icons
    # Background and Profile Image Directories
        if [ ! -d "$HOME/$username/Pictures/backgrounds" ]; then
            mkdir -p /home/"$username"/Pictures/backgrounds
        fi
        chown -R "$username":"$username" /home/"$username"/Pictures/backgrounds
        if [ ! -d "$HOME/$username/Pictures/profile-image" ]; then
            mkdir -p /home/"$username"/Pictures/profile-image
        fi
        chown -R "$username":"$username" /home/"$username"/Pictures/profile-image
    # fstab external drive mounting directory
        if [ ! -d "$HOME/.media/Working-Storage" ]; then
            mkdir -p /home/"$username"/media/Working-Storage
        fi
        chown "$username":"$username" /home/"$username"/media/Working-Storage
        if [ ! -d "$HOME/.media/Archived-Storage" ]; then
            mkdir -p /home/"$username"/media/Archived-Storage
        fi
        chown "$username":"$username" /home/"$username"/media/Archived-Storage

# Installing Dependencies
    sudo dnf install kitty -y
    sudo dnf install dconf* -y
    sudo dnf install pipx -y
    sudo dnf install alien -y
    sudo dnf install ulauncher -y
    sudo dnf install curl -y
    sudo dnf install sushi -y
    sudo dnf install fd-find -y
    sudo dnf install fzf -y
    sudo dnf install zip unzip gzip tar make wget -y
    sudo dnf install bash bash-completion -y
    sudo dnf install tar bat tree multitail fastfetch fontconfig trash-cli -y
    sudo dnf install zoxide -y
    curl -sS https://starship.rs/install.sh | sh

# Install Apps
    cd scripts || exit
    chmod u+x apps.sh
    sudo ./apps.sh
    wait
    cd "$builddir" || exit

# Installing fonts
    cd scripts || exit
    chmod u+x fonts.sh
    sudo ./fonts.sh
    wait
    cd "$builddir" || exit

# Extensions
    echo "Gnome Extensions"
        sudo dnf install gnome-shell-extension-appindicator -y
        sudo dnf install gnome-shell-extension-gsconnect -y
        sudo dnf install gnome-shell-extension-caffeine -y
        sudo dnf install gnome-shell-extension-blur-my-shell -y
        sudo dnf install gnome-shell-extension-pop-shell -y
        sudo dnf install gnome-shell-extension-just-perfection -y
    # Super Key
        git clone https://github.com/Tommimon/super-key.git
        chmod -R u+x super-key
        cd super-key || exit
        ./build.sh -i
        cd "$builddir" || exit
        rm -rf super-key
    # App Icons Taskbar
        wget https://gitlab.com/AndrewZaech/aztaskbar/-/archive/main/aztaskbar-main.tar
        chmod u+x aztaskbar-main.tar
        gnome-extensions install aztaskbar-main.tar
    # Useless Gaps
        git clone https://github.com/mipmip/gnome-shell-extensions-useless-gaps.git
        chmod -R u+x nome-shell-extensions-useless-gaps
        cd gnome-shell-extensions-useless-gaps || exit
        sudo ./install.sh local-install
        wait
        cd "$builddir" || exit
        rm -rf gnome-shell-extensions-useless-gaps
    # Just Perfection
        # gext install just-perfection-desktop@just-perfection
        git clone https://gitlab.gnome.org/jrahmatzadeh/just-perfection/-/archive/main/just-perfection-main.zip
        extract just-perfection-main.zip
        chmod -R u+x just-perfection-main
        cd just-perfection-main || exit
        ./scripts/build.sh -i
        wait
        cd "$builddir" || exit
        rm -rf just-perfection-main
    # Workspaces indicator by open apps
        git clone https://codeload.github.com/Favo02/workspaces-by-open-apps/zip/refs/heads/main
        extract workspaces-by-open-apps-main.zip
        chmod -R u+x workspaces-by-open-apps-main
        cd workspaces-by-open-apps-main || exit
        sudo ./install.sh local-install
        wait
        cd "$builddir" || exit
        rm -rf workspaces-by-open-apps-main

# Apply Piercing Rice
    echo -e "${YELLOW}Applying PiercingXX Gnome Customizations...${NC}"
        rm -rf piercing-dots
        git clone --depth 1 https://github.com/Piercingxx/piercing-dots.git
        chmod -R u+x piercing-dots
        chown -R "$username":"$username" piercing-dots
        cd piercing-dots || exit
        ./install.sh
        cd "$builddir" || exit
        rm -rf piercing-dots

# Overkill is underrated.
    sudo dnf update && upgrade -y
    wait
    dnf autoremove -y
    flatpak update -y
