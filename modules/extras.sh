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
# Printers: Canon D530 laser, Canon MG3600 inkjet, Epson ET-4800 EcoTank,
# Omezizy/XPrinter label printer. Unified from the four install-printers.sh
# variants.
# ---------------------------------------------------------------------------
CANON_PRINTER_NAME="${CANON_PRINTER_NAME:-Canon-D530}"
MG3600_QUEUE_NAME="${MG3600_QUEUE_NAME:-Canon-MG3600}"
EPSON_QUEUE_NAME="${EPSON_QUEUE_NAME:-Epson_ET-4800}"
OMEZIZY_QUEUE_NAME="${OMEZIZY_QUEUE_NAME:-Omezizy_Label}"
OMEZIZY_MODEL_NAME="${OMEZIZY_MODEL_NAME:-XP-420B}"

printers_menu() {
    local choice
    choice=$(ui_choose "Select a printer to configure:" \
        "Canon D530" "Canon MG3600" "Epson ET-4800" "Omezizy Label Printer" "All" "Back") || return 0
    case "$choice" in
        "Canon D530")            printers_canon ;;
        "Canon MG3600")          printers_mg3600 ;;
        "Epson ET-4800")         printers_epson ;;
        "Omezizy Label Printer") printers_omezizy ;;
        "All")                   printers_canon; printers_mg3600; printers_epson; printers_omezizy ;;
    esac
}

# First installed driver (lpinfo -m) whose line matches <regex>
_printers_model() {
    lpinfo -m 2>/dev/null | grep -iE "$1" | head -n1 | awk '{print $1}'
}

# First connected device URI (lpinfo -v) matching <regex>
_printers_uri() {
    lpinfo -v 2>/dev/null | awk -v re="$1" '$2 ~ re {print $2; exit}'
}

_printers_cups_up() {
    pi cups cups-filters ghostscript usbutils
    # Broad driver set, a "print to PDF" queue, and the printer settings GUI
    case "$DISTRO" in
        debian) pi cups-client cups-bsd printer-driver-gutenprint printer-driver-cups-pdf system-config-printer ;;
        fedora) pi gutenprint-cups cups-pdf system-config-printer ;;
        alpine) pi gutenprint-cups system-config-printer ;;
        arch|artix) pi gutenprint cups-pdf cups-pk-helper system-config-printer ;;
        *)      pi gutenprint cups-pdf system-config-printer ;;
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
    # Canon's own UFRII backend first (more reliable than plain usb:// here)
    local uri
    uri=$(_printers_uri '^cnusbufr2:')
    [ -n "$uri" ] || uri=$(_printers_uri '^usb://Canon/D5[36]0')
    if [ -z "$uri" ] && lsusb -d 04a9:2775 >/dev/null 2>&1; then
        local serial
        serial=$(sudo lsusb -v -d 04a9:2775 2>/dev/null | awk '/iSerial/{print $3; exit}')
        [ -n "$serial" ] && uri="usb://Canon/D530/D560?serial=${serial}&interface=1"
    fi
    [ -n "$uri" ] || { warn "No Canon D530 detected over USB — plug it in and rerun."; return 1; }

    # No generic fallback: 'everywhere' needs an IPP printer, and the D530
    # only speaks Canon's UFRII LT over USB
    if [ -z "$ppd" ]; then
        warn "Canon UFRII LT driver not installed (CNRCUPSD560 PPD). Get it from Canon's D530 support page and rerun."
        return 1
    fi
    sudo lpadmin -x "$CANON_PRINTER_NAME" 2>/dev/null || true
    sudo lpadmin -p "$CANON_PRINTER_NAME" -E -v "$uri" -P "$ppd"
    case "$uri" in usb://*) sudo lpadmin -p "$CANON_PRINTER_NAME" -o usb-no-reattach-default=true ;; esac
    sudo cupsenable "$CANON_PRINTER_NAME" 2>/dev/null || true
    sudo cupsaccept "$CANON_PRINTER_NAME" 2>/dev/null || true
    sudo lpoptions -d "$CANON_PRINTER_NAME" >/dev/null 2>&1 || true
    _printers_flatpak_portal_fix
    ok "Canon D530 configured (queue: $CANON_PRINTER_NAME)."
}

# Canon PIXMA MG3600 inkjet: Canon's cnijfilter2 driver on Arch, Gutenprint
# everywhere else (it ships an MG3600 model).
printers_mg3600() {
    if [ "$DRY_RUN" -eq 1 ]; then
        dry "configure Canon MG3600: cups + cnijfilter2/gutenprint driver, USB detection, lpadmin queue"
        return 0
    fi
    say "Setting up the Canon MG3600 queue..."
    _printers_cups_up
    case "$DISTRO" in
        arch|artix) aur cnijfilter2-mg3600 || warn "cnijfilter2-mg3600 unavailable; falling back to Gutenprint." ;;
    esac
    _printers_restart_cups

    local uri
    uri=$(_printers_uri '^cnijbe2://Canon/.*port=usb')
    [ -n "$uri" ] || uri=$(_printers_uri '^usb://Canon/MG3600')
    [ -n "$uri" ] || { warn "No Canon MG3600 detected over USB — plug it in and rerun."; return 1; }

    local model
    model=$(_printers_model 'canonmg3600\.ppd')
    [ -n "$model" ] || model=$(_printers_model 'MG3600.*Gutenprint')
    [ -n "$model" ] || { warn "No Canon MG3600 driver found (cnijfilter2-mg3600 or Gutenprint)."; return 1; }

    sudo lpadmin -x "$MG3600_QUEUE_NAME" 2>/dev/null || true
    sudo lpadmin -p "$MG3600_QUEUE_NAME" -E -v "$uri" -m "$model" -D "Canon MG3600" -o printer-is-shared=false
    sudo cupsenable "$MG3600_QUEUE_NAME" 2>/dev/null || true
    sudo cupsaccept "$MG3600_QUEUE_NAME" 2>/dev/null || true
    _printers_flatpak_portal_fix
    ok "Canon MG3600 configured (queue: $MG3600_QUEUE_NAME, driver: $model)."
}

# Epson EcoTank ET-4800: Epson's ESC/P-R driver
printers_epson() {
    if [ "$DRY_RUN" -eq 1 ]; then
        dry "configure Epson ET-4800: cups + ESC/P-R driver, USB detection, lpadmin queue"
        return 0
    fi
    say "Setting up the Epson ET-4800 queue..."
    _printers_cups_up
    case "$DISTRO" in
        arch|artix) aur epson-inkjet-printer-escpr ;;
        debian)     pi printer-driver-escpr ;;
        *)          pi epson-inkjet-printer-escpr ;;
    esac
    _printers_restart_cups

    local uri
    uri=$(_printers_uri '^usb://EPSON/ET-4800')
    [ -n "$uri" ] || { warn "No Epson ET-4800 detected over USB — plug it in and rerun."; return 1; }

    local model
    model=$(_printers_model 'ET-4800.*ESC/P-R')
    [ -n "$model" ] || model=$(_printers_model 'ET-4800')
    [ -n "$model" ] || { warn "No Epson ET-4800 driver found (epson-inkjet-printer-escpr)."; return 1; }

    sudo lpadmin -x "$EPSON_QUEUE_NAME" 2>/dev/null || true
    sudo lpadmin -p "$EPSON_QUEUE_NAME" -E -v "$uri" -m "$model" -D "Epson EcoTank ET-4800" -L "USB"
    sudo cupsenable "$EPSON_QUEUE_NAME" 2>/dev/null || true
    sudo cupsaccept "$EPSON_QUEUE_NAME" 2>/dev/null || true
    _printers_flatpak_portal_fix
    ok "Epson ET-4800 configured (queue: $EPSON_QUEUE_NAME, driver: $model)."
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
                nvidia_arch_driver || true
            fi
            ;;
        debian)
            sudo dpkg --add-architecture i386 && sudo apt update
            local tmp; tmp=$(mktemp -d)
            wget -q "https://steamcdn-a.akamaihd.net/client/installer/steam.deb" -O "$tmp/steam.deb" \
                && sudo dpkg -i "$tmp/steam.deb"; sudo apt --fix-broken install -y
            command rm -rf "$tmp"
            ;;
        fedora)
            pi steam   # via RPM Fusion nonfree
            ;;
        void)
            if [ "$LIBC" = "musl" ]; then
                say "No multilib/Steam on void-musl; installing the flatpak."
                fp com.valvesoftware.Steam
                fp com.discordapp.Discord
                ok "Gaming stuff installed."
                return 0
            fi
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
    # COSMIC is in the official Fedora repos now (the old COPR says so)
    pi @cosmic-desktop-environment
    fp dev.edfloreshz.CosmicTweaks
    ok "Cosmic Desktop installed."
}
