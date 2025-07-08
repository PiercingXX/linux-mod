#!/bin/bash
# GitHub.com/PiercingXX

# Set up variables for better readability
PKGMGR="sudo dnf install -y"
username=$(id -u -n 1000)
builddir=$(pwd)

#COPR
sudo dnf copr enable materka/swww -y
sudo dnf copr enable solopasha/hyprland -y
sudo dnf copr enable erikreider/SwayNotificationCenter -y
sudo dnf copr enable errornointernet/packages -y
sudo dnf copr enable tofik/nwg-shell -y
sudo dnf update -y

# Install core Hyprland components
${PKGMGR} hyprland
${PKGMGR} hyprpaper
${PKGMGR} hyprlock
${PKGMGR} hypridle
${PKGMGR} hyprcursor-git
${PKGMGR} hyprpolkitagent
${PKGMGR} hyprsunset

# Install additional utilities
${PKGMGR} wlsunset
${PKGMGR} wl-clipboard
${PKGMGR} libdbusmenu-gtk3
${PKGMGR} wl-gammactl
${PKGMGR} brightnessctl
${PKGMGR} light
${PKGMGR} grim
${PKGMGR} slurp
${PKGMGR} cliphist
${PKGMGR} nwg-look


# Set up Waybar and menus
${PKGMGR} waybar
${PKGMGR} nwg-drawer
${PKGMGR} fuzzel
${PKGMGR} wlogout
${PKGMGR} libnotify
${PKGMGR} notification-daemon
${PKGMGR} swaync
${PKGMGR} polkit-gnome
${PKGMGR} SwayNotificationCenter

# Install file manager and customization tools
${PKGMGR} ranger
${PKGMGR} nautilus

# Install audio tools
${PKGMGR} pamixer
${PKGMGR} cava
${PKGMGR} wireplumber
${PKGMGR} playerctl
${PKGMGR} pavucontrol
${PKGMGR} pamixer

# Network and Bluetooth utilities
${PKGMGR} networkmanager
${PKGMGR} network-manager-applet
${PKGMGR} bluez
${PKGMGR} bluez-tools
${PKGMGR} blueman

#Gnome customization tool
${PKGMGR} dconf

#Monitor locator
${PKGMGR} nwg-displays

${PKGMGR} wallust
${PKGMGR} swww


# Additional Hyprland plugins and configurations
hyprpm update
hyprpm reload
hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm add https://github.com/virtcode/hypr-dynamic-cursors
hyprpm enable dynamic-cursors
hyprpm enable hyprtrails

# Success message
echo -e "\nAll packages installed successfully!"
