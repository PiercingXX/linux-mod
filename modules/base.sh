# shellcheck shell=bash
# GitHub.com/PiercingXX
# Base system setup - the unified step-1 of all seven *-mod repos.
# Every step branches on $DISTRO internally; $PROFILE (full|mini) gates
# the heavier desktop pieces and the tablet/mini-PC tweaks.

base_setup() {
    say "Base setup: ${DISTRO^} (${PROFILE})..."
    _base_dirs
    _base_repos_and_update
    _base_core_cli
    _base_audio
    _base_network
    _base_services
    _base_fonts
    _base_theme
    _base_gnome
    gnome_extensions_install
    _base_debloat
    [ "$PROFILE" = "mini" ] && _base_mini_tweaks
    ok "Base setup complete."
}

_base_dirs() {
    if [ "$DRY_RUN" -eq 1 ]; then
        dry "create ~/.fonts ~/.icons ~/.config ~/Pictures/{backgrounds,profile-image}"
        return 0
    fi
    mkdir -p "$HOME/.fonts" "$HOME/.icons" "$HOME/.config" \
             "$HOME/Pictures/backgrounds" "$HOME/Pictures/profile-image"

    # External drive mount points (full profile only - desktops/workstations)
    if [ "$PROFILE" = "full" ]; then
        for d in /media/Working-Storage /media/Archived-Storage; do
            if [ ! -d "$d" ]; then
                sudo mkdir -p "$d"
                sudo chown "$username":"$username" "$d"
            fi
        done
    fi
}

_base_repos_and_update() {
    say "Enabling repos & updating system..."
    case "$DISTRO" in
        debian)
            # non-free + firmware components (from repositories.sh)
            if [ -f /etc/apt/sources.list ] && ! grep -q non-free-firmware /etc/apt/sources.list; then
                sudo tee /etc/apt/sources.list >/dev/null <<'EOF'
deb https://deb.debian.org/debian/ stable main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security stable-security main contrib non-free non-free-firmware
deb https://deb.debian.org/debian/ stable-updates main contrib non-free non-free-firmware
deb-src https://deb.debian.org/debian/ stable-updates main contrib non-free non-free-firmware
EOF
            fi
            pkg_update
            sudo apt install -f -y; sudo dpkg --configure -a
            sudo apt --fix-broken install -y; sudo apt autoremove -y
            ;;
        void)
            sudo xbps-install -u xbps -y || true
            pkg_update
            pi void-repo-nonfree
            ;;
        fedora)
            pkg_update
            # RPM Fusion free+nonfree (needed for codecs/nvidia later)
            local rel; rel=$(rpm -E %fedora)
            sudo dnf install -y \
                "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${rel}.noarch.rpm" \
                "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${rel}.noarch.rpm" || true
            ;;
        alpine)
            # community repo carries most of what we install
            if [ -f /etc/apk/repositories ] && grep -q '^#.*community' /etc/apk/repositories; then
                sudo sed -i '/community/s/^#\s*//' /etc/apk/repositories
            fi
            pkg_update
            ;;
        *)  pkg_update ;;
    esac
    ensure_flatpak
}

_base_core_cli() {
    say "Installing core CLI tools & build deps..."
    # Shared everywhere; identical names across repos
    pi trash-cli fastfetch tree zoxide bash-completion starship eza bat fzf \
       chafa w3m tmux sshpass rsync htop multitail git make cmake wget curl \
       zip unzip gzip tar fontconfig jq

    case "$DISTRO" in
        arch|artix)
            pi base-devel gcc meson pkg-config rust reflector linux-firmware \
               bc brightnessctl glm cpio lnav
            [ "$DISTRO" = "arch" ] && pi webkit2gtk-4.1
            ensure_paru
            aur nvtop-git jump-bin
            aur wmctrl xdotool libinput-gestures dconf
            ;;
        debian)
            pi build-essential gpg gcc gettext pipx gnome-tweaks dbus-x11 \
               util-linux xdg-utils gdebi fuse libfuse2 libinput-tools \
               x11-xserver-utils dh-dkms devscripts seahorse rename mpv gparted \
               gh libtool libtool-bin autoconf automake g++ pkg-config \
               libncurses-dev libtinfo-dev libacl1-dev libgpm-dev libjemalloc-dev \
               libpython3-dev luajit libluajit-5.1-dev lnav dconf-cli
            if [ "$PROFILE" = "mini" ]; then
                # dual-target firmware: one of these errors on Debian, the other on PopOS
                pi firmware-linux-free; pi firmware-misc-nonfree; pi linux-firmware
            else
                pi linux-firmware firmware-misc-nonfree nvtop
            fi
            pi ffmpeg poppler-utils fd-find ripgrep
            pi 7zip || pi p7zip-full
            mkdir -p "$HOME/.local/share/zoxide"
            command_exists nala || pi nala
            ;;
        fedora)
            pi gcc make cmake meson pipx alien curl sushi fd-find lnav \
               dconf gnome-tweaks ripgrep
            ;;
        void)
            pi xz nano vim gptfdisk xtools mtools mlocate ntfs-3g fuse-exfat \
               linux-headers gtksourceview4 ffmpeg mesa mesa-dri mesa-vdpau mesa-vaapi \
               autoconf automake bison m4 libtool flex meson ninja optipng sassc cpio \
               base-devel gcc linux-firmware iw bluetuith dconf fwupd perl \
               python3 nodejs lnav nvtop wmctrl xdotool libinput \
               xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr \
               xdg-user-dirs xdg-user-dirs-gtk xdg-utils \
               dbus elogind polkit
            pi libinput-gestures notification-daemon || true
            ;;
        suse)
            sudo zypper -n install -t pattern devel_basis 2>/dev/null || true
            pi gcc gcc-c++ meson pkg-config kernel-firmware bc brightnessctl \
               cpio lnav nvtop dconf wmctrl xdotool ripgrep fd
            ;;
        alpine)
            pi build-base gcc meson pkgconf linux-firmware iw bc brightnessctl \
               cpio dconf ripgrep fd doas-sudo-shim || true
            pi shadow dbus polkit elogind xdg-utils xdg-user-dirs
            ;;
    esac
}

_base_audio() {
    say "Setting up PipeWire audio..."
    case "$DISTRO" in
        arch|artix)
            pi pipewire wireplumber pipewire-pulse pipewire-alsa
            pi gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav
            ;;
        debian)
            pi pipewire wireplumber pipewire-pulse pipewire-audio
            ;;
        fedora)
            : # Fedora ships PipeWire by default
            ;;
        void)
            pi pipewire pipewire-pulse alsa-pipewire alsa-utils wireplumber \
               wireplumber-elogind playerctl pavucontrol pamixer pulseaudio-utils \
               pulsemixer rtkit
            ;;
        suse)
            pi pipewire wireplumber pipewire-pulseaudio \
               gstreamer-plugins-good gstreamer-plugins-bad gstreamer-plugins-ugly
            ;;
        alpine)
            pi pipewire wireplumber pipewire-pulse pipewire-alsa alsa-utils rtkit
            ;;
    esac
    _configure_pipewire_session
}

_configure_pipewire_session() {
    # Autostart pipewire/wireplumber for session managers that don't
    local f
    for f in pipewire pipewire-pulse wireplumber; do
        if [ -f "/usr/share/applications/$f.desktop" ] && [ ! -e "/etc/xdg/autostart/$f.desktop" ]; then
            sudo ln -sf "/usr/share/applications/$f.desktop" "/etc/xdg/autostart/$f.desktop"
        fi
    done
}

_base_network() {
    say "Standardizing on NetworkManager..."
    case "$DISTRO" in
        void)
            pi NetworkManager NetworkManager-openvpn NetworkManager-openconnect \
               NetworkManager-vpnc network-manager-applet wpa_supplicant
            ;;
        arch|artix)
            pi networkmanager network-manager-applet
            ;;
        suse)
            pi NetworkManager NetworkManager-applet
            ;;
        alpine)
            pi networkmanager networkmanager-wifi networkmanager-tui network-manager-applet
            ;;
        *)  pi network-manager ;;
    esac
    # Turn off competing network daemons, enable NM, kill wifi powersave
    svc_disable iwd connmand connman systemd-networkd dhcpcd
    sudo mkdir -p /etc/NetworkManager/conf.d
    sudo tee /etc/NetworkManager/conf.d/10-wifi-powersave-off.conf >/dev/null <<'EOF'
[connection]
wifi.powersave = 2
EOF
    svc_enable NetworkManager networkmanager
}

_base_services() {
    say "Enabling services (bluetooth, printing, ssh, firewall)..."
    case "$DISTRO" in
        arch|artix) pi bluez bluez-utils ;;
        void)       pi bluez cronie tlp tlp-rdw powertop ;;
        alpine)     pi bluez bluez-openrc ;;
        suse)       pi bluez ;;
    esac
    svc_enable bluetooth bluetoothd

    # Printing
    case "$DISTRO" in
        arch|artix)
            pi cups gutenprint cups-pdf gtk3-print-backends nmap net-tools
            aur cnijfilter2-mg3600
            svc_enable cups cupsd org.cups.cupsd
            ;;
        void)
            pi cups gutenprint cups-pk-helper nmap net-tools
            svc_enable cupsd cups
            ;;
        *)
            pi cups nmap net-tools
            svc_enable cups
            ;;
    esac
    sudo usermod -aG uucp "$username" 2>/dev/null || true

    # SSH + firewall
    case "$DISTRO" in
        debian) pi ssh ufw ;;
        *)      pi openssh ufw ;;
    esac
    svc_enable sshd ssh
    sudo ufw allow OpenSSH 2>/dev/null || sudo ufw allow SSH 2>/dev/null || true
    sudo ufw --force enable 2>/dev/null || true
    svc_enable ufw || true

    # Void extras: dbus/elogind/polkit/cron/power
    if [ "$DISTRO" = "void" ]; then
        svc_enable dbus; svc_enable elogind; svc_enable polkitd
        svc_enable cronie; svc_enable tlp; svc_enable alsa
    fi
}

_base_fonts() {
    say "Installing fonts..."
    case "$DISTRO" in
        arch|artix)
            pi ttf-firacode-nerd ttf-jetbrains-mono-nerd
            aur ttf-nerd-fonts-symbols noto-fonts-emoji-colrv1 \
                awesome-terminal-fonts-patched ttf-ms-fonts terminus-font-ttf
            if [ "$DISTRO" = "artix" ]; then
                aur xcursor-simp1e-gruvbox-light
            else
                aur wtype-git win2xcur
            fi
            ;;
        debian|suse)
            local zip url
            for zip in FiraCode Meslo NerdFontsSymbolsOnly; do
                url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${zip}.zip"
                wget -q "$url" -O "/tmp/${zip}.zip" \
                    && unzip -o -q "/tmp/${zip}.zip" -d "$HOME/.fonts" \
                    && command rm -f "/tmp/${zip}.zip"
            done
            if [ "$DISTRO" = "suse" ]; then
                pi fontawesome-fonts google-noto-coloremoji-fonts terminus-bitmap-fonts fetchmsttfonts
            else
                pi fonts-font-awesome fonts-noto-color-emoji fonts-terminus
            fi
            ;;
        alpine)
            pi font-fira-code-nerd font-jetbrains-mono-nerd font-awesome \
               font-noto-emoji terminus-font font-terminus
            ;;
        fedora)
            local zip url
            for zip in FiraCode Meslo NerdFontsSymbolsOnly; do
                url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${zip}.zip"
                wget -q "$url" -O "/tmp/${zip}.zip" \
                    && unzip -o -q "/tmp/${zip}.zip" -d "$HOME/.fonts" \
                    && command rm -f "/tmp/${zip}.zip"
            done
            pi fontawesome-fonts google-noto-emoji-color-fonts cabextract xorg-x11-font-utils
            sudo rpm -i https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm 2>/dev/null || true
            ;;
        void)
            pi font-firacode-nerd font-jetbrains-mono-nerd noto-fonts-emoji \
               noto-fonts-ttf noto-fonts-ttf-extra terminus-font
            [ -f /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf ] \
                && sudo ln -sf /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/ 2>/dev/null
            sudo xbps-reconfigure -f fontconfig || true
            ;;
    esac
    fc-cache -vf >/dev/null 2>&1 || true
}

_base_theme() {
    say "Applying Papirus icon theme..."
    case "$DISTRO" in
        arch|artix) aur papirus-icon-theme-git || pi papirus-icon-theme ;;
        *)          pi papirus-icon-theme ;;
    esac
    if [ "$DRY_RUN" -eq 0 ] && command_exists gsettings && [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        gsettings set org.gnome.desktop.interface icon-theme "Papirus" 2>/dev/null || true
    fi

    # Nordzy cursors (from debian-mod, nice everywhere)
    if [ "$DRY_RUN" -eq 0 ] && [ ! -d "$HOME/.local/share/icons/Nordzy-cursors" ]; then
        local tmp; tmp=$(mktemp -d)
        if git clone --depth 1 https://github.com/Taiko2k/Nordzy-cursors.git "$tmp/nordzy" 2>/dev/null; then
            mkdir -p "$HOME/.local/share/icons"
            cp -r "$tmp/nordzy/cursors"/* "$HOME/.local/share/icons/" 2>/dev/null || true
        fi
        command rm -rf "$tmp"
    fi
}

_base_gnome() {
    say "Installing GNOME shell & desktop basics..."
    case "$DISTRO" in
        arch|artix)
            pi gnome-shell gnome-shell-extensions nautilus gnome-disk-utility \
               gnome-calculator seahorse gnome-keyring
            ;;
        debian)
            pi gnome-shell gnome-sushi nautilus gnome-disk-utility gnome-calculator \
               kitty imagemagick gir1.2-gtk-4.0
            pipx install gnome-extensions-cli --system-site-packages 2>/dev/null || true
            pipx ensurepath 2>/dev/null || true
            # GDM greeting (yes, this matters)
            if [ -d /etc/gdm3 ] && ! sudo grep -q "Hello Handsome" /etc/gdm3/greeter.dconf-defaults 2>/dev/null; then
                sudo tee -a /etc/gdm3/greeter.dconf-defaults >/dev/null <<'EOF'
[org/gnome/login-screen]
banner-message-enable=true
banner-message-text='Hello Handsome'
EOF
            fi
            ;;
        fedora)
            pi kitty ulauncher
            pipx install gnome-extensions-cli --system-site-packages 2>/dev/null || true
            ;;
        void)
            pi xorg-minimal xorg-server-xwayland xinit xauth xterm
            pi gnome-session gnome-shell gnome-disk-utility gnome-calculator \
               seahorse gnome-keyring gnome-shell-extensions greetd tuigreet \
               chrome-gnome-shell
            pi wl-clipboard Waybar fuzzel wlogout libnotify dunst brightnessctl \
               nwg-look grim slurp
            _void_launcher_helpers
            ;;
        suse)
            pi gnome-shell nautilus gnome-disk-utility gnome-calculator seahorse \
               gnome-keyring gnome-tweaks kitty
            ;;
        alpine)
            # GNOME on Alpine is heavy; install the shell basics, tolerate misses
            pi gnome-session gnome-shell nautilus gnome-keyring gnome-tweaks kitty \
               gnome-shell-extensions || true
            ;;
    esac
}

# Safe GNOME/Hyprland launchers for systems without a display manager (void)
_void_launcher_helpers() {
    sudo tee /usr/local/bin/gnome-wayland >/dev/null <<'EOF'
#!/bin/sh
if ! command -v gnome-session >/dev/null 2>&1; then
    echo "gnome-session is not installed." >&2; exit 127
fi
exec env XDG_SESSION_TYPE=wayland XDG_RUNTIME_DIR="/run/user/$(id -u)" dbus-run-session gnome-session "$@"
EOF
    sudo tee /usr/local/bin/gnome-x11 >/dev/null <<'EOF'
#!/bin/sh
command -v gnome-session >/dev/null 2>&1 || { echo "gnome-session is not installed." >&2; exit 127; }
command -v startx >/dev/null 2>&1 || { echo "startx is not installed." >&2; exit 127; }
exec dbus-run-session startx /usr/bin/gnome-session -- "$@"
EOF
    sudo tee /usr/local/bin/hypr >/dev/null <<'EOF'
#!/bin/sh
command -v start-hyprland >/dev/null 2>&1 && exec start-hyprland "$@"
echo "start-hyprland is not installed. Install Hyprland from the Window Managers menu first." >&2
exit 127
EOF
    sudo chmod +x /usr/local/bin/gnome-wayland /usr/local/bin/gnome-x11 /usr/local/bin/hypr
}

_base_debloat() {
    say "Removing bloat..."
    case "$DISTRO" in
        arch|artix)
            local p
            for p in gnome-console firefox epiphany gnome-terminal gnome-software \
                     dolphin gnome-maps gnome-photos gnome-calendar gnome-contacts \
                     gnome-music gnome-text-editor gnome-weather; do
                sudo pacman -Rs --noconfirm "$p" 2>/dev/null || true
            done
            ;;
        debian)
            sudo apt remove --purge -y gnome-terminal firefox firefox-esr evolution shotwell 2>/dev/null || true
            sudo apt autoremove -y
            ;;
        void)
            sudo xbps-remove -Ry firefox 2>/dev/null || true
            sudo xbps-remove -Ry epiphany 2>/dev/null || true
            ;;
        fedora)
            sudo dnf autoremove -y || true
            ;;
    esac
}

# Tablet / mini-PC specific tweaks (from arch-mini-mod & debian-mini-mod)
_base_mini_tweaks() {
    say "Applying mini-profile tweaks..."
    case "$DISTRO" in
        arch|artix)
            # Extra wifi/bt firmware for cheap tablet chipsets
            local p
            for p in linux-firmware-brcm43752 linux-firmware-broadcom linux-firmware-realtek; do
                sudo pacman -S --needed --noconfirm "$p" 2>/dev/null \
                    || warn "Optional firmware not in repos, skipping: $p"
            done
            pi iw bluez bluez-utils
            aur bluetuith
            ;;
        void)
            pi iw bluetuith
            ;;
        alpine)
            pi iw linux-firmware-brcm linux-firmware-rtlwifi || true
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Login manager, run at the end of an install (finish_install)
# ---------------------------------------------------------------------------
configure_login_manager() {
    case "$DISTRO" in
        debian)
            svc_enable gdm3 gdm
            ;;
        artix)
            pi ly
            svc_disable lightdm sddm gdm lxdm xdm
            svc_enable ly ly-dm || warn "Could not enable ly automatically on this init system."
            ;;
        arch)
            if [ "$PROFILE" = "mini" ]; then
                # Boot to TTY: no display manager on the tablet builds
                if systemctl list-unit-files 2>/dev/null | grep -q '^gdm\.service'; then
                    sudo systemctl disable --now gdm.service || true
                    sudo systemctl mask gdm.service || true
                fi
                sudo systemctl set-default multi-user.target
            fi
            ;;
        void)
            if [ "${VOID_INSTALL_GDM:-0}" = "1" ]; then
                pi gdm && svc_enable gdm
            else
                say "GDM stays off (default on Void); use gnome-wayland, gnome-x11, or hypr to launch a session."
            fi
            ;;
        suse)
            svc_enable gdm display-manager || true
            ;;
        alpine)
            say "No display manager configured on Alpine; launch your WM from the TTY."
            ;;
    esac
}
