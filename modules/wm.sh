# shellcheck shell=bash
# GitHub.com/PiercingXX
# Window managers - unified per-WM installers with per-distro package branches.
# Package lists merged from every *-mod repo's wm install scripts.

# ---------------------------------------------------------------------------
# Shared package groups
# ---------------------------------------------------------------------------
_wm_build_deps() {
    case "$DISTRO" in
        arch|artix) pi base-devel git cmake meson pkg-config ;;
        debian)     pi build-essential git cmake meson pkg-config ;;
        fedora)     pi git cmake meson pkgconf gcc g++ ;;
        void)       pi base-devel git cmake meson pkg-config ninja ;;
        suse)       sudo zypper -n install -t pattern devel_basis 2>/dev/null || true
                    pi git cmake meson pkg-config ;;
        alpine)     pi build-base git cmake meson pkgconf ;;
    esac
}

_wm_x11_stack() {
    case "$DISTRO" in
        arch|artix) pi xorg-server xorg-xrandr xorg-xinput xorg-xsetroot xorg-xrdb \
                       xorg-setxkbmap xorg-xev numlockx feh ;;
        debian)     pi x11-xserver-utils x11-utils xinput x11-xkb-utils numlockx feh xterm xclip ;;
        void)       pi xorg-server xrandr xinput xsetroot xrdb setxkbmap xev numlockx feh ;;
        alpine)     pi xorg-server xrandr xinput xsetroot xrdb setxkbmap numlockx feh xterm ;;
        *)          pi xrandr xinput numlockx feh ;;
    esac
}

_wm_audio_stack() {
    case "$DISTRO" in
        void) pi pipewire pipewire-pulse alsa-pipewire alsa-utils wireplumber \
                 wireplumber-elogind pavucontrol pamixer playerctl easyeffects rtkit brightnessctl ;;
        *)    pi pipewire pipewire-pulse wireplumber pavucontrol pamixer playerctl \
                 easyeffects brightnessctl
              pi light || true ;;
    esac
    _configure_pipewire_session
}

_wm_auth_agent() {
    case "$DISTRO" in
        artix)  pi mate-polkit gnome-keyring ;;
        debian) pi policykit-1-gnome gnome-keyring xdg-user-dirs ;;
        *)      pi polkit-gnome gnome-keyring ;;
    esac
}

_wm_file_manager() {
    case "$DISTRO" in
        arch)       pi nautilus; aur nautilus-renamer nautilus-open-any-terminal code-nautilus-git ;;
        artix)      pi thunar thunar-archive-plugin thunar-volman tumbler ;;
        void)       pi thunar thunar-volman ;;
        *)          pi nautilus ;;
    esac
    pi kitty tmux
}

_wm_network_stack() {
    case "$DISTRO" in
        debian) pi network-manager network-manager-gnome bluez blueman ;;
        void)   pi NetworkManager network-manager-applet bluez bluetuith ;;
        suse)   pi NetworkManager NetworkManager-applet bluez ;;
        alpine) pi networkmanager network-manager-applet bluez ;;
        *)      pi networkmanager network-manager-applet bluez bluez-utils bluetui ;;
    esac
}

# Wayland launcher/bar set shared by hyprland & sway
_wm_wayland_utils() {
    pi waybar fuzzel wlogout wl-clipboard cliphist libnotify
    case "$DISTRO" in
        debian) pi grim slurp libnotify-bin jq golang-go
                _wm_compat_shims ;;
        void)   pi Waybar grim slurp swaync dunst nwg-drawer notification-daemon || true
                _hyprshot_from_github ;;
        *)      pi swaync notification-daemon
                aur nwg-drawer hyprshot wl-gammarelay ;;
    esac
    pi nwg-look nwg-displays dconf || true
}

# Only write /usr/local shims when the real binary is missing. Never shadow
# /usr/bin/hyprlock (old code did — that is why Debian Hyprland felt broken).
_wm_compat_shims() {
    if [ -x /usr/bin/hyprlock ] && [ -x /usr/local/bin/hyprlock ]; then
        if grep -q 'linux-mod hyprlock shim' /usr/local/bin/hyprlock 2>/dev/null; then
            sudo rm -f /usr/local/bin/hyprlock
        fi
    fi
    if ! command_exists hyprshot; then
        sudo tee /usr/local/bin/hyprshot >/dev/null <<'EOF'
#!/bin/sh
# linux-mod hyprshot shim: grim+slurp on wayland, flameshot on X11
if [ -n "$WAYLAND_DISPLAY" ] && command -v grim >/dev/null 2>&1; then
    out="$HOME/Pictures/$(date +%s).png"
    mkdir -p "$HOME/Pictures"
    case "$1" in
        -m) shift; case "$1" in region) grim -g "$(slurp)" "$out" ;; *) grim "$out" ;; esac ;;
        *)  grim "$out" ;;
    esac
    command -v wl-copy >/dev/null 2>&1 && wl-copy < "$out"
else
    exec flameshot gui
fi
EOF
        sudo chmod +x /usr/local/bin/hyprshot
    fi
    if ! command_exists hyprlock; then
        sudo tee /usr/local/bin/hyprlock >/dev/null <<'EOF'
#!/bin/sh
# linux-mod hyprlock shim
command -v swaylock >/dev/null 2>&1 && exec swaylock "$@"
exec i3lock -c 000000
EOF
        sudo chmod +x /usr/local/bin/hyprlock
    fi
}

_hyprshot_from_github() {
    if ! command_exists hyprshot; then
        sudo curl -fsSL -o /usr/local/bin/hyprshot \
            https://raw.githubusercontent.com/Gustash/Hyprshot/main/hyprshot \
            && sudo chmod +x /usr/local/bin/hyprshot
    fi
}

_wm_offer_dots() {
    if ui_confirm "Apply PiercingXX dotfiles for this window manager now?"; then
        apply_dots
    fi
}

# ---------------------------------------------------------------------------
# Hyprland
# ---------------------------------------------------------------------------
wm_hyprland() {
    say "Installing Hyprland..."
    _wm_build_deps
    case "$DISTRO" in
        arch|artix)
            aur hyprland-meta-git hyprcursor-git wlsunset-git
            pi hyprpaper hyprlock hypridle hyprsunset xdg-desktop-portal-hyprland \
               xdg-desktop-portal-gtk xdg-user-dirs xdg-utils
            pi wl-clipboard libdbusmenu-gtk3 gum jq
            [ "$DISTRO" = "artix" ] && { pi seatd elogind; svc_enable seatd; svc_enable elogind; }
            ;;
        debian)
            _wm_hyprland_debian
            ;;
        fedora)
            local repo
            for repo in solopasha/hyprland erikreider/SwayNotificationCenter tofik/nwg-shell; do
                sudo dnf copr enable -y "$repo" || true
            done
            sudo dnf update -y
            pi hyprland hyprpaper hyprlock hypridle hyprpolkitagent hyprsunset \
               wlsunset wl-clipboard grim slurp cliphist swww SwayNotificationCenter
            ;;
        void)
            pi hyprutils hyprlang hyprgraphics aquamarine hyprland hyprpaper hyprlock \
               hypridle hyprcursor xdg-desktop-portal-hyprland hyprland-qt-support \
               hyprland-qtutils qt5ct qt6ct
            pi polkit-gnome seatd elogind dbus mesa mesa-dri
            svc_enable seatd; svc_enable elogind; svc_enable dbus
            sudo usermod -aG _seatd "$username" 2>/dev/null || true
            sudo tee /usr/local/bin/start-hyprland >/dev/null <<'EOF'
#!/bin/sh
exec dbus-run-session Hyprland "$@"
EOF
            sudo chmod +x /usr/local/bin/start-hyprland
            ;;
        suse)
            pi hyprland hyprpaper hyprlock hypridle hyprcursor \
               xdg-desktop-portal-hyprland xdg-desktop-portal-gtk wl-clipboard \
               grim slurp jq
            ;;
    esac
    _wm_wayland_utils
    _wm_audio_stack
    _wm_auth_agent
    _wm_file_manager
    _wm_network_stack
    _wm_hyprpm_plugins
    _wm_offer_dots
    ok "Hyprland installed."
}

# Debian/Ubuntu Hyprland.
# Old path built 0.43 with a cmake loop (wrong for Hyprland + protocols) and then
# dropped a /usr/local/bin/hyprlock shim over the real binary. piercing-dots
# expects a current compositor.
#
# Order: Debian 13 backports (0.54+) → any apt candidate >= 0.50 → source.
# Ubuntu universe 0.41.x is skipped on purpose (Hyprland wiki: do not use it).
_wm_hyprland_debian() {
    _wm_debian_apt_prep
    if _wm_hyprland_debian_try_packages; then
        return 0
    fi
    _wm_hyprland_debian_source_build
}

_wm_debian_apt_prep() {
    local id=""
    [ -r /etc/os-release ] && . /etc/os-release && id="${ID:-}"
    if [ "$id" = "ubuntu" ] || [ "$id" = "pop" ] || [ "$id" = "linuxmint" ]; then
        pi software-properties-common
        if [ "${DRY_RUN:-0}" -eq 0 ]; then
            sudo add-apt-repository -y universe >/dev/null 2>&1 || true
        else
            dry "add-apt-repository universe"
        fi
    fi
    [ "${DRY_RUN:-0}" -eq 1 ] && { dry "apt update"; return 0; }
    sudo apt update
}

_wm_debian_enable_backports() {
    local code="${VERSION_CODENAME:-}"
    [ -n "$code" ] || return 1
    if grep -Rqs "${code}-backports" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
        return 0
    fi
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        dry "enable ${code}-backports"
        return 0
    fi
    say "Enabling ${code}-backports for Hyprland..."
    echo "deb http://deb.debian.org/debian ${code}-backports main contrib non-free non-free-firmware" \
        | sudo tee /etc/apt/sources.list.d/linux-mod-backports.list >/dev/null
    sudo apt update
}

_wm_apt_hyprland_candidate() {
    apt-cache policy hyprland 2>/dev/null | awk '/Candidate:/ { print $2; exit }'
}

_wm_hyprland_debian_pkgs() {
    # Install the ecosystem; pi skips names a given suite does not ship.
    pi hyprland hypridle hyprlock hyprpaper hyprcursor hyprpolkitagent \
       hyprland-guiutils xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
       xdg-desktop-portal xwayland qtwayland5
}

_wm_hyprland_debian_try_packages() {
    local id="" ver="" code="" cand="" major=""
    [ -r /etc/os-release ] && . /etc/os-release
    id="${ID:-}"; ver="${VERSION_ID:-}"; code="${VERSION_CODENAME:-}"
    major="${ver%%.*}"

    if [ "$id" = "debian" ] && [ "$major" = "13" ]; then
        _wm_debian_enable_backports || true
        if [ "${DRY_RUN:-0}" -eq 1 ]; then
            dry "apt install -t ${code}-backports hyprland + ecosystem"
            return 0
        fi
        if sudo apt install -y -t "${code}-backports" \
            hyprland hypridle hyprlock hyprpaper hyprcursor hyprpolkitagent \
            hyprland-guiutils xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
            xdg-desktop-portal xwayland 2>/dev/null; then
            ok "Hyprland from ${code}-backports."
            return 0
        fi
        warn "trixie-backports Hyprland install failed — trying other apt, then source."
    fi

    cand=$(_wm_apt_hyprland_candidate)
    [ -n "$cand" ] && [ "$cand" != "(none)" ] || return 1
    # Strip debian revision: 0.54.3-1 -> 0.54.3
    cand="${cand%%-*}"
    if dpkg --compare-versions "$cand" ge 0.50; then
        say "Using distro Hyprland ${cand} (new enough for piercing-dots)."
        _wm_hyprland_debian_pkgs
        return 0
    fi
    say "apt Hyprland is ${cand} — too old (Ubuntu universe). Building from source."
    return 1
}

_wm_cmake_hypr() {
    local name="$1" url="$2" tag="$3" tmp
    tmp=$(mktemp -d)
    say "Building ${name} ${tag}..."
    if git clone --depth 1 --recursive --branch "$tag" "$url" "$tmp/$name"; then
        (cd "$tmp/$name" \
            && cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_INSTALL_PREFIX=/usr -S . -B build \
            && cmake --build build --config Release -j"$(nproc 2>/dev/null || echo 2)" \
            && sudo cmake --install build) || warn "${name} build failed."
    else
        warn "Could not clone ${name} ${tag}."
    fi
    command rm -rf "$tmp"
}

_wm_hyprland_debian_source_build() {
    # Coherent recent stack (matches void-mod pins). Hyprland itself uses
    # official `make all` — not a generic cmake loop.
    local hyprland_tag="v0.55.3"
    if [ "${DRY_RUN:-0}" -eq 1 ]; then
        dry "build Hyprland ${hyprland_tag} + hypr* stack from source (cmake libs, make all compositor)"
        return 0
    fi
    say "Building Hyprland ${hyprland_tag} from source. This takes a while."

    pi meson ninja-build cmake cmake-extras build-essential git pkg-config \
       gettext gettext-base fontconfig libfontconfig-dev libffi-dev libxml2-dev \
       libdrm-dev libgbm-dev libegl-dev libgles2 libgles2-mesa-dev \
       libpixman-1-dev libudev-dev libseat-dev seatd libinput-dev libinput-bin \
       libxkbcommon-dev libxkbcommon-x11-dev libxkbregistry-dev libxcursor-dev \
       libxcb-dri3-dev libxcb-composite0-dev libxcb-ewmh-dev libxcb-present-dev \
       libxcb-icccm4-dev libxcb-render-util0-dev libxcb-res0-dev libxcb-xinput-dev \
       libxcb-xfixes0-dev libxcb-errors-dev libdisplay-info-dev hwdata \
       wayland-protocols libwayland-dev glslang-tools libglvnd-dev \
       libcairo2-dev libpango1.0-dev libjpeg-dev libwebp-dev librsvg2-dev \
       libzip-dev libtomlplusplus-dev libre2-dev libpugixml-dev libmagic-dev \
       libsdbus-c++-dev libpam0g-dev libavutil-dev libavcodec-dev libavformat-dev \
       xwayland qtwayland5
    pi clang-19
    command_exists clang++-19 || pi clang-18
    command_exists clang++-19 || command_exists clang++-18 || pi g++-14 || true

    # Latest Hyprland wants clang>=19 or gcc>=16. Prefer clang-19 when present.
    if command_exists clang++-19; then
        export CC=clang-19 CXX=clang++-19
    elif command_exists clang++-18; then
        export CC=clang-18 CXX=clang++-18
        warn "clang-19 missing; clang-18 may fail on Hyprland ${hyprland_tag} (C++26)."
    elif command_exists g++-14; then
        export CC=gcc-14 CXX=g++-14
        warn "No clang-19; g++-14 may fail on Hyprland ${hyprland_tag}."
    fi

    _wm_cmake_hypr hyprwayland-scanner https://github.com/hyprwm/hyprwayland-scanner.git v0.4.6
    _wm_cmake_hypr hyprutils            https://github.com/hyprwm/hyprutils.git            v0.13.1
    _wm_cmake_hypr hyprlang             https://github.com/hyprwm/hyprlang.git             v0.6.7
    _wm_cmake_hypr hyprcursor           https://github.com/hyprwm/hyprcursor.git           v0.1.11
    _wm_cmake_hypr hyprgraphics         https://github.com/hyprwm/hyprgraphics.git         v0.5.1
    _wm_cmake_hypr aquamarine           https://github.com/hyprwm/aquamarine.git           v0.9.3

    local tmp
    tmp=$(mktemp -d)
    say "Installing hyprland-protocols..."
    if git clone --depth 1 --branch v0.7.0 https://github.com/hyprwm/hyprland-protocols.git "$tmp/hyprland-protocols"; then
        (cd "$tmp/hyprland-protocols" && meson setup build --prefix=/usr && meson install -C build) \
            || warn "hyprland-protocols install failed."
    fi
    command rm -rf "$tmp"

    tmp=$(mktemp -d)
    say "Building Hyprland ${hyprland_tag} (make all)..."
    if git clone --depth 1 --recursive --branch "$hyprland_tag" \
        https://github.com/hyprwm/Hyprland.git "$tmp/Hyprland"; then
        (cd "$tmp/Hyprland" && make all && sudo make install) \
            || warn "Hyprland ${hyprland_tag} build failed."
    else
        warn "Could not clone Hyprland ${hyprland_tag}."
    fi
    command rm -rf "$tmp"

    _wm_cmake_hypr hyprlock  https://github.com/hyprwm/hyprlock.git  v0.5.1
    _wm_cmake_hypr hypridle  https://github.com/hyprwm/hypridle.git  v0.3.1
    _wm_cmake_hypr hyprpaper https://github.com/hyprwm/hyprpaper.git v0.7.6
    _wm_cmake_hypr xdg-desktop-portal-hyprland \
        https://github.com/hyprwm/xdg-desktop-portal-hyprland.git v1.3.9

    sudo ldconfig
    command_exists Hyprland || command_exists hyprland \
        || warn "Hyprland binary not on PATH after build."
}

_wm_hyprpm_plugins() {
    command_exists hyprpm || return 0
    say "Adding hyprpm plugins (needs a running Hyprland session to fully enable)..."
    hyprpm add https://github.com/hyprwm/hyprland-plugins 2>/dev/null || true
    hyprpm add https://github.com/VirtCode/hypr-dynamic-cursors 2>/dev/null || true
    hyprpm enable dynamic-cursors 2>/dev/null || true
    hyprpm add https://github.com/horriblename/hyprgrass 2>/dev/null || true
    hyprpm enable hyprgrass 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Sway
# ---------------------------------------------------------------------------
wm_sway() {
    say "Installing Sway..."
    _wm_build_deps
    case "$DISTRO" in
        arch|artix)
            pi sway swaybg swayidle xdg-desktop-portal xdg-desktop-portal-wlr plasma-workspace
            aur swaylock-effects || pi swaylock
            [ "$PROFILE" = "full" ] && pi libinput-gestures
            ;;
        debian)
            pi sway swaybg swayidle swaylock xdg-desktop-portal xdg-desktop-portal-wlr \
               xwayland qtwayland5 plasma-workspace
            ;;
        void)
            pi sway swaybg swayidle swaylock xdg-desktop-portal xdg-desktop-portal-wlr
            ;;
        *)  # fedora, suse, alpine
            pi sway swaybg swayidle swaylock xdg-desktop-portal-wlr
            ;;
    esac
    _wm_wayland_utils
    _wm_audio_stack
    _wm_auth_agent
    _wm_file_manager
    _wm_network_stack
    _wm_offer_dots
    ok "Sway installed."
}

# ---------------------------------------------------------------------------
# i3
# ---------------------------------------------------------------------------
wm_i3() {
    say "Installing i3..."
    _wm_build_deps
    _wm_x11_stack
    case "$DISTRO" in
        arch)
            pi i3-wm i3blocks i3lock i3status picom fuzzel wl-clipboard cliphist acpi upower
            aur nwg-drawer hyprshot betterlockscreen hyprlock
            [ "$PROFILE" = "full" ] && pi libinput-gestures
            ;;
        artix)
            pi i3-wm i3blocks i3lock i3status picom rofi dmenu flameshot xclip acpi upower
            aur betterlockscreen
            ;;
        debian)
            pi i3 i3blocks picom rofi wl-clipboard flameshot jq libnotify-bin golang-go acpi upower
            _wm_compat_shims
            ;;
        void)
            pi i3 i3blocks i3lock i3status picom fuzzel grim slurp wl-clipboard cliphist acpi upower
            pi nwg-drawer || true
            ;;
        *)  # suse, alpine, fedora
            pi i3 i3blocks i3lock i3status picom rofi flameshot acpi upower
            ;;
    esac
    _wm_audio_stack
    _wm_auth_agent
    _wm_file_manager
    _wm_network_stack
    _wm_offer_dots
    ok "i3 installed."
}

# ---------------------------------------------------------------------------
# bspwm
# ---------------------------------------------------------------------------
wm_bspwm() {
    say "Installing bspwm..."
    _wm_build_deps
    _wm_x11_stack
    pi bspwm sxhkd polybar picom hsetroot flameshot sxiv zathura
    case "$DISTRO" in
        arch)
            pi fuzzel fcitx
            aur dragon-drag-and-drop
            pi xdo || true; aur bspwm-swallow-git || true
            [ "$PROFILE" = "full" ] && pi libinput-gestures
            ;;
        artix)
            pi rofi dmenu fcitx
            aur dragon-drag-and-drop
            pi xdo || true; aur bspwm-swallow-git || true
            ;;
        debian)
            pi rofi xclip fcitx5 fcitx5-frontend-gtk3 fcitx5-module-xorg jq libnotify-bin
            pi xdo || true
            _wm_compat_shims
            ;;
        void)
            pi fuzzel xdragon fcitx5
            pi xdo || true
            ;;
        *)  # suse, alpine, fedora
            pi rofi
            pi xdo || true
            ;;
    esac
    _wm_audio_stack
    _wm_auth_agent
    _wm_file_manager
    _wm_network_stack
    _wm_offer_dots
    ok "bspwm installed."
}

# ---------------------------------------------------------------------------
# Awesome
# ---------------------------------------------------------------------------
wm_awesome() {
    say "Installing Awesome..."
    _wm_build_deps
    _wm_x11_stack
    pi awesome picom dunst rofi feh nitrogen lxappearance xclip xdotool arandr neovim
    case "$DISTRO" in
        arch)   pi libnotify xterm
                pi ttf-jetbrains-mono-nerd
                [ "$PROFILE" = "full" ] && pi libinput-gestures ;;
        artix)  pi libnotify xterm ttf-jetbrains-mono-nerd ;;
        debian) pi libnotify-bin fonts-jetbrains-mono
                _wm_compat_shims ;;
        void)   pi libnotify xterm
                pi font-jetbrains-mono-nerd || true ;;
        *)      pi libnotify xterm || true ;;
    esac
    _wm_audio_stack
    _wm_auth_agent
    _wm_file_manager
    _wm_network_stack
    _wm_offer_dots
    ok "Awesome installed."
}

# ---------------------------------------------------------------------------
# Qtile
# ---------------------------------------------------------------------------
wm_qtile() {
    say "Installing Qtile..."
    _wm_build_deps
    _wm_x11_stack
    case "$DISTRO" in
        arch|artix)
            pi qtile python-psutil picom dmenu fuzzel wl-clipboard cliphist acpi upower
            aur nwg-drawer hyprshot betterlockscreen hyprlock
            [ "$PROFILE" = "full" ] && pi xcape libinput-gestures
            ;;
        void)
            pi qtile python3-psutil picom dmenu fuzzel grim slurp wl-clipboard cliphist \
               i3lock flameshot acpi upower xorg-xinit
            pi nwg-drawer nitrogen rofi || true
            ;;
        *)
            pi qtile picom dmenu rofi flameshot acpi upower
            ;;
    esac
    _wm_audio_stack
    _wm_auth_agent
    _wm_file_manager
    _wm_network_stack
    # Session wrappers (from arch/void qtile scripts)
    sudo tee /usr/local/bin/start-qtile >/dev/null <<'EOF'
#!/bin/sh
if command -v startx >/dev/null 2>&1 && [ -z "$WAYLAND_DISPLAY" ]; then
    exec dbus-run-session startx /usr/bin/qtile start
fi
exec dbus-run-session qtile start
EOF
    sudo chmod +x /usr/local/bin/start-qtile
    _wm_offer_dots
    ok "Qtile installed."
}

# ---------------------------------------------------------------------------
# DWM / herbstluftwm (suckless-style, buildable anywhere)
# ---------------------------------------------------------------------------
_install_or_build_suckless() {
    local name="$1"
    if [ "$DRY_RUN" -eq 1 ]; then dry "install or build suckless: $name"; return 0; fi
    pi "$name" && command_exists "$name" && return 0
    say "Building $name from suckless source..."
    local tmp; tmp=$(mktemp -d)
    if git clone --depth 1 "https://git.suckless.org/$name" "$tmp/$name"; then
        (cd "$tmp/$name" && sudo make clean install) || warn "$name build failed."
    fi
    command rm -rf "$tmp"
}

wm_dwm() {
    say "Installing DWM..."
    _wm_build_deps
    _wm_x11_stack
    _install_or_build_suckless dwm
    _install_or_build_suckless dmenu
    _install_or_build_suckless st
    pi slstatus sxhkd picom rofi flameshot libnotify neovim || true
    _wm_audio_stack
    _wm_auth_agent
    _wm_file_manager
    _wm_network_stack
    _wm_offer_dots
    ok "DWM installed."
}

wm_herbstluftwm() {
    say "Installing herbstluftwm..."
    _wm_build_deps
    _wm_x11_stack
    pi herbstluftwm sxhkd polybar picom dmenu rofi libnotify flameshot neovim xclip xdotool
    _wm_audio_stack
    _wm_auth_agent
    _wm_file_manager
    _wm_network_stack
    _wm_offer_dots
    ok "herbstluftwm installed."
}

# ---------------------------------------------------------------------------
# GNOME (full DE, artix-style) & BusyBox profile
# ---------------------------------------------------------------------------
wm_gnome() {
    say "Installing GNOME desktop..."
    case "$DISTRO" in
        arch|artix)
            pi gnome gnome-extra nautilus gnome-tweaks dconf
            [ "$DISTRO" = "artix" ] && { pi elogind dbus; svc_enable dbus; svc_enable elogind; }
            ;;
        debian) pi gnome-core gnome-tweaks ;;
        fedora) pi @workstation-product-environment 2>/dev/null || pi gnome-tweaks ;;
        void)   pi gnome-session gnome-shell gnome-tweaks ;;
        suse)   pi gnome gnome-tweaks nautilus ;;
        alpine) pi gnome gnome-tweaks ;;
    esac
    _wm_network_stack
    gnome_extensions_install
    _wm_offer_dots
    ok "GNOME installed."
}

wm_busybox() {
    say "Installing BusyBox profile (bspwm session on busybox userspace)..."
    case "$DISTRO" in
        arch|artix) pi busybox bash ;;
        *)          pi busybox ;;
    esac
    wm_bspwm
    pi rofi xclip flameshot hsetroot jq i3lock cava fcitx5 || true
    ok "BusyBox profile installed."
}

# ---------------------------------------------------------------------------
# Menu — same set as piercing-dots (~/.config): Hyprland, GNOME, Herbst,
# Sway, i3, bspwm, Awesome, Qtile, DWM. No Niri/River/Cosmic rice.
# ---------------------------------------------------------------------------
_wm_dispatch() {
    case "$1" in
        "Hyprland")        wm_hyprland ;;
        "GNOME")           wm_gnome ;;
        "Herbstluftwm")    wm_herbstluftwm ;;
        "Sway")            wm_sway ;;
        "i3")              wm_i3 ;;
        "bspwm")           wm_bspwm ;;
        "Awesome")         wm_awesome ;;
        "Qtile")           wm_qtile ;;
        "DWM")             wm_dwm ;;
        "BusyBox Profile") wm_busybox ;;
    esac
}

wm_menu() {
    local options=()
    [ "$DISTRO" != "alpine" ] && options+=("Hyprland")
    options+=("GNOME" "Herbstluftwm" "Sway" "i3" "bspwm" "Awesome" "Qtile" "DWM")
    case "$DISTRO" in
        arch|artix) options+=("BusyBox Profile") ;;
    esac
    options+=("Back")

    local choice
    while true; do
        ui_screen "window managers  ·  ${DISTRO} ${PROFILE:-full}  ·  pick one, then another, or Back"
        choice=$(ui_choose "install which desktop" "${options[@]}") || return 0
        case "$choice" in
            "Back"|"") return 0 ;;
            *)         _wm_dispatch "$choice" ;;
        esac
        pause_for_key
    done
}
