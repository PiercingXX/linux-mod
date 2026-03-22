#!/bin/bash
# https://github.com/piercingxx

set -e

username=$(id -u -n 1000)
builddir=$(pwd)

hyprutils_version="v0.11.0"
hyprlang_version="v0.6.7"
hyprland_protocols_version="v0.7.0"
hyprwayland_scanner_version="v0.4.5"
hyprgraphics_version="v0.2.0"
hyprpaper_version="v0.7.6"
aquamarine_version="v0.4.0"
hyprcursor_version="v0.1.8"
hyprland_version="v0.43.0"

if [ -f /etc/os-release ]; then
    . /etc/os-release
fi
if [[ "$ID" == "ubuntu" ]]; then
    sudo add-apt-repository universe -y
fi
sudo apt update
sudo apt upgrade -y

sudo apt install libsdbus-c++-dev -y
sudo apt install libpam0g-dev -y
sudo apt install libgbm-dev -y
sudo apt install libdrm-dev -y
sudo apt install libmagic-dev -y
sudo apt install rofi -y
sudo apt install fuzzel -y
sudo apt install waybar -y
sudo apt install xwayland -y
sudo apt install qtwayland5 -y
sudo apt install wayland-protocols -y
sudo apt install wl-clipboard -y
sudo apt install wlogout -y
sudo apt install pavucontrol -y
sudo apt install grim -y
sudo apt install slurp -y
sudo apt install golang-go -y
sudo apt install jq -y
sudo apt install libnotify-bin -y
sudo apt install easyeffects -y
sudo apt install network-manager-gnome -y
sudo apt install bluez -y
sudo apt install blueman -y
sudo apt install polkit-kde-agent-1 -y
sudo apt install libpixman-1-dev -y
sudo apt install libpugixml-dev -y
sudo apt install libjpeg-dev -y
sudo apt install libwebp-dev -y
sudo apt install librsvg2-dev -y
sudo apt install libgles2-mesa-dev -y
sudo apt install libgles-dev -y
sudo apt install libseat-dev -y
sudo apt install libinput-dev -y
sudo apt install libudev-dev -y
sudo apt install libdisplay-info-dev -y
sudo apt install hwdata -y
sudo apt install libzip-dev -y
sudo apt install libtomlplusplus-dev -y
sudo apt install libxkbcommon-dev -y
sudo apt install libxcursor-dev -y
sudo apt install libre2-dev -y
sudo apt install libxcb-xfixes0-dev -y
sudo apt install libxcb-icccm4-dev -y
sudo apt install libxcb-composite0-dev -y
sudo apt install libxcb-res0-dev -y
sudo apt install libxcb-errors-dev -y

bash "$(dirname "$0")/wm-compat.sh"

printf "Building and installing hyprutils ${hyprutils_version}...\n"
rm -rf hyprutils 2>/dev/null || true
git clone --depth 1 --recursive -b "${hyprutils_version}" https://github.com/hyprwm/hyprutils.git
cd hyprutils || exit 1
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
cmake --build ./build --config Release -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"
sudo cmake --install build >/dev/null 2>&1
cd "$builddir" || exit 1

printf "Building and installing hyprlang ${hyprlang_version}...\n"
rm -rf hyprlang 2>/dev/null || true
git clone --depth 1 --recursive -b "${hyprlang_version}" https://github.com/hyprwm/hyprlang.git
cd hyprlang || exit 1
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
cmake --build ./build --config Release -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"
sudo cmake --install build >/dev/null 2>&1
cd "$builddir" || exit 1

printf "Installing hyprland-protocols ${hyprland_protocols_version}...\n"
rm -rf hyprland-protocols 2>/dev/null || true
git clone --depth 1 --recursive -b "${hyprland_protocols_version}" https://github.com/hyprwm/hyprland-protocols.git
cd hyprland-protocols || exit 1
sudo mkdir -p /usr/share/wayland-protocols
sudo cp -r protocols/* /usr/share/wayland-protocols/ 2>/dev/null || true
cd "$builddir" || exit 1

printf "Building and installing hyprwayland-scanner ${hyprwayland_scanner_version}...\n"
rm -rf hyprwayland-scanner 2>/dev/null || true
git clone --depth 1 --recursive -b "${hyprwayland_scanner_version}" https://github.com/hyprwm/hyprwayland-scanner.git
cd hyprwayland-scanner || exit 1
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
cmake --build ./build --config Release -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"
sudo cmake --install build >/dev/null 2>&1
cd "$builddir" || exit 1

printf "Installing hyprlock...\n"
rm -rf hyprlock 2>/dev/null || true
if git clone --depth 1 --recursive -b v0.5.1 https://github.com/hyprwm/hyprlock.git 2>/dev/null; then
    cd hyprlock || exit 1
    cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
    cmake --build ./build --config Release -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)" 2>/dev/null
    sudo cmake --install build >/dev/null 2>&1 || true
    cd "$builddir" || exit 1
fi

printf "Installing hypridle...\n"
rm -rf hypridle 2>/dev/null || true
if git clone --depth 1 --recursive -b v0.3.1 https://github.com/hyprwm/hypridle.git 2>/dev/null; then
    cd hypridle || exit 1
    cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
    cmake --build ./build --config Release -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)" 2>/dev/null
    sudo cmake --install ./build >/dev/null 2>&1 || true
    cd "$builddir" || exit 1
fi

printf "Building and installing hyprgraphics ${hyprgraphics_version}...\n"
rm -rf hyprgraphics 2>/dev/null || true
git clone --depth 1 --recursive -b "${hyprgraphics_version}" https://github.com/hyprwm/hyprgraphics.git
cd hyprgraphics || exit 1
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
cmake --build ./build --config Release -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"
sudo cmake --install build >/dev/null 2>&1
cd "$builddir" || exit 1

printf "Building and installing hyprpaper ${hyprpaper_version}...\n"
rm -rf hyprpaper 2>/dev/null || true
if git clone --depth 1 --recursive -b "${hyprpaper_version}" https://github.com/hyprwm/hyprpaper.git; then
    cd hyprpaper || exit 1
    cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
    cmake --build ./build --config Release -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"
    sudo cmake --install build >/dev/null 2>&1 || true
    cd "$builddir" || exit 1
fi

printf "Building and installing aquamarine ${aquamarine_version}...\n"
rm -rf aquamarine 2>/dev/null || true
git clone --depth 1 --recursive -b "${aquamarine_version}" https://github.com/hyprwm/aquamarine.git
cd aquamarine || exit 1
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
cmake --build ./build --config Release -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"
sudo cmake --install build >/dev/null 2>&1
cd "$builddir" || exit 1

printf "Building and installing hyprcursor ${hyprcursor_version}...\n"
rm -rf hyprcursor 2>/dev/null || true
git clone --depth 1 --recursive -b "${hyprcursor_version}" https://github.com/hyprwm/hyprcursor.git
cd hyprcursor || exit 1
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
cmake --build ./build --config Release -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"
sudo cmake --install build >/dev/null 2>&1
cd "$builddir" || exit 1

printf "Building and installing Hyprland ${hyprland_version}...\n"
rm -rf Hyprland 2>/dev/null || true
git clone --depth 1 --recursive -b "${hyprland_version}" https://github.com/hyprwm/Hyprland.git
cd Hyprland || exit 1
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -S . -B ./build
cmake --build ./build --config Release -j"$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"
sudo cmake --install build >/dev/null 2>&1
cd "$builddir" || exit 1

printf "\nHyprland installation completed successfully!\n"

exit 0