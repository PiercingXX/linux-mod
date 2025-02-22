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

sudo dnf update && upgrade -y
wait


# Making .config and.fonts Directories
cd "$builddir" || exit
mkdir -p /home/"$username"/.fonts
chown -R "$username":"$username" /home/"$username"/.fonts
mkdir -p /home/"$username"/.icons
chown -R "$username":"$username" /home/"$username"/.icons
mkdir -p /home/"$username"/Pictures/backgrounds
chown -R "$username":"$username" /home/"$username"/Pictures/backgrounds
cp -R dotconf/kitty /home/"$username"/.config/
chown -R "$username":"$username" /home/"$username"/.config/kitty


# Installing important things && stuff && some dependencies
echo "Installing Programs and Drivers"
dnf install kitty -y
dnf install dconf* -y
dnf install pipx -y
dnf install typescript -y
dnf install gnome-tweaks -y
dnf install papirus-icon-theme -y
pipx install gnome-extensions-cli --system-site-packages
flatpak install flathub com.mattjakeman.ExtensionManager -y
flatpak install flathub md.obsidian.Obsidian -y
flatpak install flathub org.libreoffice.LibreOffice -y
flatpak install https://flathub.org/beta-repo/appstream/org.gimp.GIMP.flatpakref -y
#flatpak install flathub org.blender.Blender -y
flatpak install flathub org.qbittorrent.qBittorrent -y
flatpak install flathub io.missioncenter.MissionCenter -y
flatpak install flathub com.tomjwatson.Emote -y
flatpak install flathub com.visualstudio.code -y
flatpak install flathub com.synology.SynologyDrive -y

# Gimp dotfiles
git clone https://github.com/Piercingxx/gimp-dots.git
chmod -R u+x gimp-dots
chown -R "$username":"$username" gimp-dots
rm -Rf /home/"$username"/.var/app/org.gimp.GIMP/config/GIMP/*
rm -Rf /home/"$username"/.config/GIMP/*
mkdir /home/"$username"/.config/GIMP/3.0
chown -R "$username":"$username" /home/"$username"/.config/GIMP
cd gimp-dots/Gimp || exit
cp -R "3.0" /home/"$username"/.config/GIMP/
chown "$username":"$username" -R /home/"$username"/.config/GIMP
cd "$builddir" || exit


echo "Installing Fonts"
sleep 2
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
sleep 2
dnf install gnome-shell-extension-appindicator -y
dnf install gnome-shell-extension-gsconnect -y
dnf install gnome-shell-extension-caffeine -y
dnf install gnome-shell-extension-blur-my-shell -y
dnf install gnome-shell-extension-pop-shell -y
dnf install gnome-shell-extension-just-perfection -y
# App Icons Taskbar
wget https://gitlab.com/AndrewZaech/aztaskbar/-/archive/main/aztaskbar-main.tar
gnome-extensions install aztaskbar-main.tar
# Awesome Tiles
git clone https://github.com/velitasali/gnome-shell-extension-awesome-tiles.git
chmod -R u+x gnome-shell-extension-awesome-tiles
cd gnome-shell-extension-awesome-tiles || exit
./install.sh local-install
cd ..
rm -rf gnome-shell-extension-awesome-tiles
# Worthless Gaps
git clone https://github.com/mipmip/gnome-shell-extensions-useless-gaps.git
chmod -R u+x gnome-shell-extensions-useless-gaps
cd gnome-shell-extensions-useless-gaps || exit
./install.sh local-install
# Space Bar
git clone https://github.com/christopher-l/space-bar.git
chmod -R u+x space-bar
cd space-bar
./scripts/build.sh
./scripts/build.sh -i


sudo dnf update && upgrade -y
wait
dnf autoremove -y
flatpak update -y


read -r -p "2.sh complete. Press enter to reboot"
sudo reboot
