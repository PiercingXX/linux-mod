#!/bin/bash
# https://github.com/Piercingxx

# Check if Script is Run as Root
if [[ $EUID -ne 0 ]]; then
  echo "You must be a root user to run this script, please run sudo su then try again" 2>&1
  exit 1
fi

username=$(id -u -n 1000)
builddir=$(pwd)

echo "Starting Script 1.sh"


# Checks for active network connection
if [[ -n "$(command -v nmcli)" && "$(nmcli -t -f STATE g)" != connected ]]; then
  awk '{print}' <<<"Network connectivity is required to continue."
  exit
fi

echo "Updating Repositories"

sudo dnf update -y
wait

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
            sudo mkdir -p /media/Working-Storage
        fi
        chown "$username":"$username" /home/"$username"/media/Working-Storage
        if [ ! -d "$HOME/.media/Archived-Storage" ]; then
            sudo mkdir -p /media/Archived-Storage
        fi
        chown "$username":"$username" /home/"$username"/media/Archived-Storage

# Installing important things && stuff && some dependencies
echo "Installing Programs and Drivers"
sudo dnf install kitty -y
sudo dnf install dconf* -y
sudo dnf install pipx -y
sudo dnf install typescript -y
sudo dnf install gnome-tweaks -y
sudo dnf install papirus-icon-theme -y
sudo dnf install alien -y
sudo dnf install ulauncher -y
sudo dnf install curl -y
sudo dnf install sushi -y
flatpak install flathub net.waterfox.waterfox -y
flatpak install flathub md.obsidian.Obsidian -y
flatpak install flathub org.libreoffice.LibreOffice -y
flatpak install https://flathub.org/beta-repo/appstream/org.gimp.GIMP.flatpakref -y
flatpak install flathub org.darktable.Darktable -y
flatpak install flathub org.blender.Blender -y
flatpak install flathub com.mattjakeman.ExtensionManager -y
flatpak install flathub org.qbittorrent.qBittorrent -y
flatpak install flathub io.missioncenter.MissionCenter -y
flatpak install flathub com.tomjwatson.Emote -y
flatpak install flathub org.kde.kdenlive -y
flatpak install flathub io.github.shiftey.Desktop -y
flatpak install flathub com.flashforge.FlashPrint -y
flatpak install flathub com.synology.SynologyDrive -y

# Install Gnome-extensions-cli
pipx install gnome-extensions-cli --system-site-packages

# VScode
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
dnf check-update
sudo dnf install code -y
# Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh
# Ollama
    curl -fsSL https://ollama.com/install.sh | sh

echo "Installing Fonts"
# Installing fonts
cd "$builddir" || exit
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/FiraCode.zip
chmod -R 777 FiraCode.zip
unzip FiraCode.zip -d /home/"$username"/.fonts
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.1.0/Meslo.zip
chmod -R 777 Meslo.zip
unzip Meslo.zip -d /home/"$username"/.fonts
mv dotfonts/fontawesome/otfs/*.otf /home/"$username"/.fonts/
chown -R "$username":"$username" /home/"$username"/.fonts
dnf install fontawesome-fonts -y 
dnf install google-noto-emoji-color-fonts -y
sudo yum install curl cabextract xorg-x11-font-utils fontconfig -y
sudo rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm
# Reloading Font
fc-cache -vf
wait
# Removing zip files and stuff
rm -rf FiraCode.zip
rm -rf Meslo.zip


# Extensions
echo "Gnome Extensions"
sudo dnf install gnome-shell-extension-appindicator -y
sudo dnf install gnome-shell-extension-gsconnect -y
sudo dnf install gnome-shell-extension-caffeine -y
sudo dnf install gnome-shell-extension-blur-my-shell -y
sudo dnf install gnome-shell-extension-pop-shell -y
sudo dnf install gnome-shell-extension-just-perfection -y
# Super Key
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


sudo dnf update && upgrade -y
wait
dnf autoremove -y
flatpak update -y

