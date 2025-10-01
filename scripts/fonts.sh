#!/bin/bash
# GitHub.com/PiercingXX

username=$(id -u -n 1000)
builddir=$(pwd)

# Create Directories if needed
    # font directory
        if [ ! -d "$HOME/.fonts" ]; then
            mkdir -p "$HOME/.fonts"
        fi
        chown -R "$username":"$username" "$HOME"/.fonts
    # icons directory
        if [ ! -d "$HOME/.icons" ]; then
            mkdir -p /home/"$username"/.icons
        fi
        chown -R "$username":"$username" /home/"$username"/.icons
            # Installing fonts
        echo "Installing Fonts"
        cd "$builddir" || exit
        wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/FiraCode.zip
        wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Meslo.zip
        wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.zip
        unzip FiraCode.zip -d /home/"$username"/.fonts
        unzip Meslo.zip -d /home/"$username"/.fonts
        unzip NerdFontsSymbolsOnly.zip -d /home/"$username"/.fonts
        sudo rm FiraCode.zip Meslo.zip NerdFontsSymbolsOnly.zip
        dnf install fontawesome-fonts -y 
        dnf install google-noto-emoji-color-fonts -y
        sudo yum install curl cabextract xorg-x11-font-utils fontconfig -y
        sudo rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
    # Reloading Font
        fc-cache -vf
        wait

