#!/bin/bash
# GitHub.com/PiercingXX

username=$(id -un)
builddir=$(pwd)

# shellcheck source=service-manager.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/service-manager.sh"

# Fallback color definitions (script may be run standalone)
: "${YELLOW:=''}"
: "${GREEN:=''}"
: "${NC:=''}"


# Create Directories if needed
    echo -e "${YELLOW}Creating Necessary Directories...${NC}"
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
            if [ ! -d "/media/Working-Storage" ]; then
                sudo mkdir -p /media/Working-Storage
                sudo chown "$username":"$username" /media/Working-Storage
            fi
            if [ ! -d "/media/Archived-Storage" ]; then
                sudo mkdir -p /media/Archived-Storage
                sudo chown "$username":"$username" /media/Archived-Storage
            fi
# System Update
        sudo pacman -Syu --noconfirm

# Install dependencies
        echo "# Installing dependencies..."
    sudo pacman -S --needed ly --noconfirm
        sudo pacman -S trash-cli --noconfirm
        sudo pacman -S base-devel gcc cmake meson --noconfirm
        sudo pacman -S git make pkg-config --noconfirm
    sudo pacman -S rust --noconfirm
        sudo pacman -S fastfetch --noconfirm
        sudo pacman -S tree --noconfirm
        sudo pacman -S zoxide --noconfirm
        sudo pacman -S bash-completion --noconfirm
        sudo pacman -S starship --noconfirm
        sudo pacman -S eza --noconfirm
        sudo pacman -S bat --noconfirm
        sudo pacman -S fzf --noconfirm
        sudo pacman -S trash-cli --noconfirm
        sudo pacman -S chafa --noconfirm
        sudo pacman -S w3m --noconfirm
        sudo pacman -S reflector --noconfirm
        sudo pacman -S zip unzip gzip tar make wget tar fontconfig --noconfirm
        sudo pacman -Syu linux-firmware --noconfirm
        sudo pacman -S bc brightnessctl --noconfirm        
        sudo pacman -S tmux --noconfirm
        sudo pacman -S sshpass --noconfirm
        sudo pacman -S rsync --noconfirm
        sudo pacman -S htop --noconfirm
        sudo pacman -S glm --noconfirm
# Ensure Pipewire for audio
    sudo pacman -S pipewire wireplumber pipewire-pulse pipewire-alsa --noconfirm
    sudo pacman -S gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav --noconfirm
    restart_user_services pipewire pipewire-pulse wireplumber

# Add Paru, Flatpak, & Dependencies if needed
    echo -e "${YELLOW}Installing Paru, Flatpak, & Dependencies...${NC}"
        # Clone and install Paru
        echo "# Cloning and installing Paru..."
        if command -v paru &> /dev/null && paru --version &> /dev/null; then
            echo "Paru already installed (working)"
        else
            echo "Paru missing or broken; building from source to match current libalpm..."
            # Remove potentially broken prebuilt helper if present
            sudo pacman -Rns --noconfirm paru-bin paru 2>/dev/null || true

            PARU_BUILD_DIR=$(mktemp -d)
            git clone https://aur.archlinux.org/paru.git "$PARU_BUILD_DIR/paru"
            if [ -d "$PARU_BUILD_DIR/paru" ]; then
                cd "$PARU_BUILD_DIR/paru" || exit
                makepkg -si --noconfirm
                PARU_INSTALL_STATUS=$?
                cd "$builddir" || exit
                rm -rf "$PARU_BUILD_DIR"
                if [ $PARU_INSTALL_STATUS -ne 0 ]; then
                    echo "ERROR: Paru installation failed!"
                    exit 1
                fi

                if ! command -v paru &> /dev/null || ! paru --version &> /dev/null; then
                    echo "ERROR: Paru installed but still not runnable."
                    exit 1
                fi
                echo "Paru installed successfully!"
            else
                echo "ERROR: Failed to clone paru repository."
                exit 1
            fi
        fi

        # Packages that require AUR helper
        paru -S nvtop-git --noconfirm
        paru -S lnav --noconfirm
        # Add Flatpak
        echo "# Installing Flatpak..."
        sudo pacman -S flatpak --noconfirm
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo

# Installing more Depends
        echo "# Installing more dependencies..."
        paru -S dconf --noconfirm
        paru -S cpio --noconfirm
        paru -S wmctrl xdotool libinput-gestures --noconfirm
        paru -S multitail jump-bin --noconfirm

# System Control Services
    echo "# Enabling Bluetooth and Printer services..."
    # Enable Bluetooth
        if ! enable_and_start_service bluetooth bluetoothd; then
            echo "Warning: Could not start/enable Bluetooth service on this init system."
        fi
    # Enable Printer 
        sudo pacman -S cups gutenprint cups-pdf gtk3-print-backends nmap net-tools cmake meson cpio --noconfirm
        if ! enable_and_start_service cups cupsd org.cups.cupsd; then
            echo "Warning: Could not start/enable CUPS service on this init system."
        fi
    # Printer Drivers
        paru -S cnijfilter2-mg3600 --noconfirm #Canon mg3600 driver
        #paru -S cndrvcups-lb --noconfirm # Canon D530 driver
    # Add dialout to edit ZMK and VIA Keyboards
        sudo usermod -aG uucp $USER

# Theme stuffs
    paru -S papirus-icon-theme-git --noconfirm

# Install fonts
    echo "Installing Fonts"
    cd "$builddir" || exit
    sudo pacman -S ttf-firacode-nerd --noconfirm
    paru -S ttf-nerd-fonts-symbols --noconfirm
    paru -S noto-fonts-emoji-colrv1 --noconfirm
    sudo pacman -S ttf-jetbrains-mono-nerd --noconfirm
    paru -S awesome-terminal-fonts-patched --noconfirm
    paru -S ttf-ms-fonts --noconfirm
    paru -S terminus-font-ttf --noconfirm
    paru -S xcursor-simp1e-gruvbox-light --noconfirm
    # Reload Font
    fc-cache -vf
    wait
