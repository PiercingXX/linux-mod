# shellcheck shell=bash
# GitHub.com/PiercingXX
# Extras - printers, gaming, Cosmic desktop.

extras_menu() {
    local options=("Printers" "Gaming Stuff" "GNOME Extensions")
    [ "$DISTRO" = "fedora" ] && options+=("Cosmic Desktop")
    options+=("Back")

    local choice
    while true; do
        ui_screen "extras  ·  ${DISTRO}"
        choice=$(ui_choose "choose an option" "${options[@]}") || break
        case "$choice" in
            "Printers")         printers_menu ;;
            "Gaming Stuff")     extras_gaming ;;
            "GNOME Extensions") gnome_extensions_install ;;
            "Cosmic Desktop")   extras_cosmic ;;
            "Back"|"")          break ;;
        esac
        pause_for_key
    done
}

# ---------------------------------------------------------------------------
# Printers: Canon D530 laser + Omezizy/XPrinter label printer
# Unified from the four install-printers.sh variants.
# ---------------------------------------------------------------------------
CANON_PRINTER_NAME="${CANON_PRINTER_NAME:-Canon-D530}"
OMEZIZY_QUEUE_NAME="${OMEZIZY_QUEUE_NAME:-Omezizy_Label}"
OMEZIZY_MODEL_NAME="${OMEZIZY_MODEL_NAME:-XP-420B}"

printers_menu() {
    local choice
    choice=$(ui_choose "Select a printer to configure:" \
        "Canon D530" "Omezizy Label Printer" "Both" "Back") || return 0
    case "$choice" in
        "Canon D530")            printers_canon ;;
        "Omezizy Label Printer") printers_omezizy ;;
        "Both")                  printers_canon; printers_omezizy ;;
    esac
}

_printers_cups_up() {
    pi cups cups-filters ghostscript usbutils
    case "$DISTRO" in
        debian) pi cups-client cups-bsd ;;
    esac
    svc_enable cups cupsd org.cups.cupsd
    sudo modprobe usblp 2>/dev/null || true
}

_printers_restart_cups() {
    case "$INIT" in
        systemd) sudo systemctl restart cups.service 2>/dev/null || sudo systemctl restart cups ;;
        runit)   sudo sv restart cupsd 2>/dev/null || true ;;
        *)       sudo rc-service cupsd restart 2>/dev/null || sudo service cups restart 2>/dev/null || true ;;
    esac
    sleep 2
}

printers_canon() {
    if [ "$DRY_RUN" -eq 1 ]; then
        dry "configure Canon D530: cups + driver install, USB detection, lpadmin queue"
        return 0
    fi
    say "Setting up the Canon D530 queue..."
    _printers_cups_up

    # Driver: AUR package on pacman family; Debian ships no cnrdrvcups path by default
    local ppd=""
    case "$DISTRO" in
        arch|artix)
            aur cnrdrvcups-lb-bin
            for f in /usr/share/cups/model/CNRCUPSD560ZS.ppd /usr/share/cups/model/CNRCUPSD560ZK.ppd; do
                [ -f "$f" ] && { ppd="$f"; break; }
            done
            ;;
        debian)
            for f in /usr/share/ppd/cnrdrvcups-lb/CNRCUPSD560ZS.ppd \
                     /usr/share/cups/model/CNRCUPSD560ZS.ppd \
                     /usr/share/ppd/cnrdrvcups-lb/CNRCUPSD560ZK.ppd \
                     /usr/share/cups/model/CNRCUPSD560ZK.ppd; do
                [ -f "$f" ] && { ppd="$f"; break; }
            done
            ;;
        *)
            for f in /usr/share/cups/model/CNRCUPSD560ZS.ppd /usr/share/cups/model/CNRCUPSD560ZK.ppd; do
                [ -f "$f" ] && { ppd="$f"; break; }
            done
            ;;
    esac
    _printers_restart_cups

    # Find the device URI: lpinfo first, lsusb (Canon vendor 04a9) fallback
    local uri
    uri=$(lpinfo -v 2>/dev/null | awk '/usb:\/\/Canon/{print $2; exit}')
    if [ -z "$uri" ] && lsusb -d 04a9:2775 >/dev/null 2>&1; then
        local serial
        serial=$(sudo lsusb -v -d 04a9:2775 2>/dev/null | awk '/iSerial/{print $3; exit}')
        [ -n "$serial" ] && uri="usb://Canon/D530/D560?serial=${serial}&interface=1"
    fi
    [ -n "$uri" ] || { warn "No Canon D530 detected over USB — plug it in and rerun."; return 1; }

    sudo lpadmin -x "$CANON_PRINTER_NAME" 2>/dev/null || true
    if [ -n "$ppd" ]; then
        sudo lpadmin -p "$CANON_PRINTER_NAME" -E -v "$uri" -P "$ppd"
    else
        warn "Canon PPD not found; using generic 'everywhere' driver."
        sudo lpadmin -p "$CANON_PRINTER_NAME" -E -v "$uri" -m everywhere
    fi
    case "$uri" in usb://*) sudo lpadmin -p "$CANON_PRINTER_NAME" -o usb-no-reattach-default=true ;; esac
    sudo cupsenable "$CANON_PRINTER_NAME" 2>/dev/null || true
    sudo cupsaccept "$CANON_PRINTER_NAME" 2>/dev/null || true
    sudo lpoptions -d "$CANON_PRINTER_NAME" >/dev/null 2>&1 || true
    _printers_flatpak_portal_fix
    ok "Canon D530 configured (queue: $CANON_PRINTER_NAME)."
}

printers_omezizy() {
    if [ "$DRY_RUN" -eq 1 ]; then
        dry "configure Omezizy label printer: cups install, USB detection, lpadmin queue + label options"
        return 0
    fi
    say "Setting up the Omezizy label printer..."
    _printers_cups_up
    case "$DISTRO" in
        arch|artix) pi dpkg; aur xprinter-cups || warn "xprinter-cups unavailable; relying on stock PPDs." ;;
        void)       pi dpkg || true ;;
    esac

    # lprint fights over the USB device
    case "$INIT" in
        systemd) sudo systemctl disable --now lprint.service 2>/dev/null || true ;;
        runit)   sudo sv down lprint 2>/dev/null; sudo rm -f /var/service/lprint ;;
    esac
    _printers_restart_cups

    local uri
    uri=$(lpinfo -v 2>/dev/null | awk '/usb:\/\/.*(D520|LabelPrinter)/{print $2; exit}')
    [ -n "$uri" ] || { warn "No Omezizy/XPrinter label printer detected over USB."; return 1; }

    local model="xprinter/${OMEZIZY_MODEL_NAME}.ppd.gz"
    lpinfo -m 2>/dev/null | grep -q "$model" || model="drv:///sample.drv/zebra.ppd"

    sudo lpadmin -x "$OMEZIZY_QUEUE_NAME" 2>/dev/null || true
    sudo lpadmin -p "$OMEZIZY_QUEUE_NAME" -E -v "$uri" -m "$model"
    sudo lpoptions -p "$OMEZIZY_QUEUE_NAME" \
        -o PageSize=w4h6 -o Resolution=203dpi -o PaperType=LabelGaps \
        -o GapsHeight=3 -o PostAction=TearOff -o PrintSpeed=6 -o Darkness=12 2>/dev/null || true
    sudo cupsenable "$OMEZIZY_QUEUE_NAME" 2>/dev/null || true
    sudo cupsaccept "$OMEZIZY_QUEUE_NAME" 2>/dev/null || true
    ok "Omezizy label printer configured (queue: $OMEZIZY_QUEUE_NAME)."
}

# LibreOffice flatpak sees printers only after the portals restart
_printers_flatpak_portal_fix() {
    if flatpak list --app 2>/dev/null | grep -q org.libreoffice.LibreOffice; then
        systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-gtk.service 2>/dev/null \
            || { pkill -x xdg-desktop-portal 2>/dev/null; pkill -x xdg-desktop-portal-gtk 2>/dev/null; } || true
    fi
}

# ---------------------------------------------------------------------------
# Gaming: Steam + 32-bit runtime + Discord
# ---------------------------------------------------------------------------
extras_gaming() {
    say "Installing gaming stuff..."
    case "$DISTRO" in
        arch|artix)
            pi steam vulkan-tools vulkan-icd-loader lib32-vulkan-icd-loader \
               mesa lib32-mesa mesa-demos lib32-gcc-libs lib32-glibc lib32-libdrm \
               lib32-libx11 lib32-libxext lib32-libxcomposite lib32-libxrender \
               lib32-libxfixes lib32-libxrandr lib32-libxtst lib32-libpulse \
               lib32-openssl lib32-sdl2
            pi vulkan-radeon lib32-vulkan-radeon || true
            if lspci 2>/dev/null | grep -qi nvidia; then
                pi nvidia nvidia-utils lib32-nvidia-utils
            fi
            ;;
        debian)
            sudo dpkg --add-architecture i386 && sudo apt update
            local deb="steam.deb"
            wget -q "https://steamcdn-a.akamaihd.net/client/installer/steam.deb" -O "/tmp/$deb" \
                && sudo dpkg -i "/tmp/$deb"; sudo apt --fix-broken install -y
            command rm -f "/tmp/$deb"
            ;;
        fedora)
            pi steam   # via RPM Fusion nonfree
            ;;
        void)
            pi void-repo-multilib void-repo-multilib-nonfree
            sudo xbps-install -S
            pi glibc-32bit libstdc++-32bit libgcc-32bit
            [ -f /usr/lib32/libGL.so.1 ] || pi libglvnd-32bit libdrm-32bit mesa-32bit mesa-dri-32bit libgbm-32bit
            pi steam
            ;;
        suse)
            pi steam
            ;;
        alpine)
            say "Native Steam is not available on Alpine (musl); installing the flatpak."
            fp com.valvesoftware.Steam
            ;;
    esac
    fp com.discordapp.Discord
    flatpak override --user --socket=pulseaudio --filesystem=xdg-run/pipewire-0 com.discordapp.Discord 2>/dev/null || true
    ok "Gaming stuff installed."
}

# ---------------------------------------------------------------------------
# Cosmic desktop (Fedora COPR)
# ---------------------------------------------------------------------------
extras_cosmic() {
    say "Installing Cosmic Desktop..."
    sudo dnf update -y
    sudo dnf copr enable -y ryanabx/cosmic-epoch
    sudo dnf update -y
    pi cosmic-desktop
    fp dev.edfloreshz.CosmicTweaks
    ok "Cosmic Desktop installed."
}
