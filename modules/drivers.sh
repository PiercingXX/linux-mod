# shellcheck shell=bash
# GitHub.com/PiercingXX
# Drivers & hardware - Nvidia, Microsoft Surface kernel, KooTigers touchscreen,
# NuVision 8in tablet, TTY rotation. One function per item, distro-branched.

RES_DIR="$LINUX_MOD_ROOT/resources"

drivers_menu() {
    local options=("Nvidia Drivers" "Microsoft Surface Kernel")
    # Tablet hardware fixes need systemd for the boot services
    case "$DISTRO" in
        arch|artix|debian|suse)
            options+=("KooTigers Touchscreen Driver" "NuVision 8in Tablet Fixes") ;;
    esac
    options+=("Rotate TTY Clockwise" "Back")

    local choice
    while true; do
        ui_screen "drivers & hardware  ·  ${DISTRO}"
        choice=$(ui_choose "choose an option" "${options[@]}") || break
        case "$choice" in
            "Nvidia Drivers")               drivers_nvidia ;;
            "Microsoft Surface Kernel")     drivers_surface ;;
            "KooTigers Touchscreen Driver") drivers_kootigers ;;
            "NuVision 8in Tablet Fixes")    drivers_nuvision ;;
            "Rotate TTY Clockwise")         drivers_rotate_tty ;;
            "Back"|"")                      break ;;
        esac
        pause_for_key
    done
}

# ---------------------------------------------------------------------------
# Nvidia (do not install on a Surface device)
# ---------------------------------------------------------------------------
drivers_nvidia() {
    say "Installing Nvidia drivers + CUDA..."
    case "$DISTRO" in
        arch|artix)
            pkg_update
            pi nvidia nvidia-utils nvidia-settings nvidia-dkms cuda \
               lib32-nvidia-libgl lib32-nvidia-utils
            ;;
        debian)
            sudo apt update
            pi nvidia-driver-535 nvidia-dkms-535 nvidia-settings nvidia-utils-535 nvtop
            local cuda_deb="cuda-repo-debian13-13-0-local_13.0.0-580.65.06-1_amd64.deb"
            wget -q "https://developer.download.nvidia.com/compute/cuda/13.0.0/local_installers/${cuda_deb}" -O "/tmp/${cuda_deb}" \
                && sudo dpkg -i "/tmp/${cuda_deb}" \
                && sudo cp /var/cuda-repo-debian13-13-0-local/cuda-*-keyring.gpg /usr/share/keyrings/ \
                && sudo apt update \
                && pi cuda-toolkit-13-0
            sudo dpkg --add-architecture i386 && sudo apt update
            pi libgl1-nvidia-glvnd-glx:i386
            command rm -f "/tmp/${cuda_deb}"
            sudo apt autoremove -y
            ;;
        fedora)
            # via RPM Fusion (enabled during base setup)
            pi akmod-nvidia xorg-x11-drv-nvidia-cuda
            ;;
        void)
            pi void-repo-nonfree && sudo xbps-install -S
            pi nvidia nvidia-libs-32bit
            ;;
        suse)
            sudo zypper -n addrepo -f https://download.nvidia.com/opensuse/tumbleweed NVIDIA 2>/dev/null || true
            sudo zypper --gpg-auto-import-keys -n refresh
            sudo zypper -n install-new-recommends --repo NVIDIA \
                || warn "Nvidia install via the NVIDIA repo failed."
            ;;
        alpine)
            warn "Proprietary Nvidia drivers are not supported on Alpine (musl); using nouveau."
            return 1
            ;;
    esac
    ok "Nvidia drivers installed."
    if [ "$DRY_RUN" -eq 0 ] && ui_confirm "Reboot now to load the Nvidia driver?"; then
        sudo reboot
    fi
}

# ---------------------------------------------------------------------------
# Microsoft Surface kernel (linux-surface)
# ---------------------------------------------------------------------------
drivers_surface() {
    say "Installing the linux-surface kernel..."
    case "$DISTRO" in
        arch|artix)
            # signing key + repo
            curl -s https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc \
                | sudo pacman-key --add -
            sudo pacman-key --finger 56C464BAAC421453
            sudo pacman-key --lsign-key 56C464BAAC421453
            if ! grep -q '\[linux-surface\]' /etc/pacman.conf; then
                printf '\n[linux-surface]\nServer = https://pkg.surfacelinux.com/arch/\n' \
                    | sudo tee -a /etc/pacman.conf >/dev/null
            fi
            sudo pacman -Syu --noconfirm
            pi linux-surface linux-surface-headers iptsd
            aur libwacom-surface
            pi linux-firmware-marvell linux-firmware-intel linux-surface-secureboot-mok
            _surface_bootloader_arch
            ;;
        debian)
            wget -qO - https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc \
                | gpg --dearmor | sudo dd of=/etc/apt/trusted.gpg.d/linux-surface.gpg status=none
            echo "deb [arch=amd64] https://pkg.surfacelinux.com/debian release main" \
                | sudo tee /etc/apt/sources.list.d/linux-surface.list >/dev/null
            sudo apt update
            pi linux-image-surface linux-headers-surface libwacom-surface iptsd
            pi linux-surface-secureboot-mok
            sudo update-grub
            say "After reboot run 'vainfo' to verify."
            ;;
        fedora)
            sudo dnf config-manager addrepo \
                --from-repofile=https://pkg.surfacelinux.com/fedora/linux-surface.repo || true
            sudo dnf install -y --allowerasing kernel-surface iptsd libwacom-surface
            pi surface-secureboot
            sudo systemctl enable --now linux-surface-default-watchdog.path 2>/dev/null || true
            linux-surface-default-watchdog.py 2>/dev/null || true
            ;;
        void|suse|alpine)
            warn "linux-surface has no official ${DISTRO^} repo; skipping. See github.com/linux-surface for manual builds."
            return 1
            ;;
    esac
    ok "Surface kernel installed. Reboot to use it."
}

_surface_bootloader_arch() {
    if command_exists grub-mkconfig; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    fi
    # systemd-boot: create an entry if none references the surface kernel
    if command_exists bootctl && sudo bootctl is-installed >/dev/null 2>&1; then
        if ! sudo grep -qs surface /boot/loader/entries/*.conf 2>/dev/null; then
            local root_part
            root_part=$(findmnt -no PARTUUID / 2>/dev/null)
            sudo tee /boot/loader/entries/linux-surface.conf >/dev/null <<EOF
title   Arch Linux (Surface)
linux   /vmlinuz-linux-surface
initrd  /initramfs-linux-surface.img
options root=PARTUUID=${root_part} rw quiet splash
EOF
            sudo sed -i 's/^default.*/default linux-surface.conf/' /boot/loader/loader.conf 2>/dev/null \
                || echo "default linux-surface.conf" | sudo tee -a /boot/loader/loader.conf >/dev/null
        fi
    elif ! command_exists grub-mkconfig; then
        say "Unknown bootloader: select the linux-surface kernel in your boot manager manually."
    fi
}

# ---------------------------------------------------------------------------
# KooTigers touchscreen (Goodix GDIX1002) - systemd service + iio-sensor-proxy
# ---------------------------------------------------------------------------
drivers_kootigers() {
    say "Applying KooTigers touchscreen driver..."
    [ "$INIT" = "systemd" ] || { warn "KooTigers setup needs systemd (found: $INIT)."; return 1; }

    sudo install -m 755 "$RES_DIR/kootigers/boot-touchscreen.sh" /usr/local/bin/boot-touchscreen.sh
    sudo cp "$RES_DIR/kootigers/kootigers-drivers.service" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable --now kootigers-drivers.service

    pi iio-sensor-proxy
    if systemctl list-unit-files 2>/dev/null | grep -q '^iio-sensor-proxy\.service'; then
        sudo systemctl enable --now iio-sensor-proxy.service 2>/dev/null \
            || sudo systemctl restart iio-sensor-proxy 2>/dev/null || true
    fi
    ok "KooTigers touchscreen driver applied. Reboot!"
}

# ---------------------------------------------------------------------------
# NuVision 8in tablet - Broadcom wifi/BT + SOF audio firmware + accelerometer
# ---------------------------------------------------------------------------
drivers_nuvision() {
    say "Applying NuVision 8in tablet fixes..."
    local nv="$RES_DIR/nuvision"

    # Packages
    case "$DISTRO" in
        arch|artix)
            pi linux-firmware bluez bluez-utils sof-firmware alsa-utils iw
            aur broadcom-wl-dkms || true
            ;;
        debian)
            pi firmware-brcm80211 bluez bluez-tools iw alsa-utils
            pi firmware-linux-free || true
            pi firmware-linux-nonfree || true
            pi firmware-sof-signed || true
            ;;
        *)
            pi linux-firmware bluez alsa-utils iw sof-firmware || true
            ;;
    esac

    # Firmware blobs
    sudo install -d /lib/firmware/brcm /lib/firmware/intel
    sudo cp -f "$nv"/wifi-bluetooth-drivers/* /lib/firmware/brcm/
    [ -d "$nv/audio-drivers" ] && sudo cp -f "$nv"/audio-drivers/* /lib/firmware/intel/

    # Reload wifi + detect interface
    sudo modprobe -r brcmfmac 2>/dev/null || true
    sudo modprobe brcmfmac 2>/dev/null || true
    local iface
    iface=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
    iface="${iface:-wlan0}"
    sudo ip link set "$iface" up 2>/dev/null || true

    # Bluetooth
    sudo modprobe -r btusb 2>/dev/null || true
    sudo modprobe btusb 2>/dev/null || true
    svc_enable bluetooth bluetoothd || true

    # Wifi restart-at-boot
    sudo install -m 755 "$nv/wifi-startup.sh" /usr/local/bin/wifi-startup.sh
    if [ "$INIT" = "systemd" ]; then
        sudo cp "$nv/wifi-startup.service" /etc/systemd/system/
        sudo systemctl daemon-reload
        sudo systemctl enable --now wifi-startup.service 2>/dev/null || true
    else
        mkdir -p "$HOME/.config/autostart"
        cp "$nv/wifi-startup.desktop" "$HOME/.config/autostart/"
    fi

    # SOF audio module reload
    local m
    for m in snd_sof_pci snd_sof_acpi_intel_byt snd_sof_acpi snd_sof_intel_atom \
             snd_sof_xtensa_dsp snd_sof snd_intel_sst_acpi snd_intel_sst_core \
             snd_soc_sst_atom_hifi2_platform snd_soc_core snd_pcm; do
        sudo modprobe -r "$m" 2>/dev/null || true
    done
    sudo modprobe snd_sof_pci 2>/dev/null || true

    # Accelerometer orientation (KIOX000A)
    sudo tee /etc/udev/hwdb.d/61-sensor-local.hwdb >/dev/null <<'EOF'
sensor:modalias:acpi:KIOX000A*:dmi:*
 ACCEL_MOUNT_MATRIX=0,1,0;1,0,0;0,0,-1
EOF
    sudo systemd-hwdb update 2>/dev/null || true
    sudo udevadm trigger /sys/bus/iio/devices/iio:device0 2>/dev/null || true
    sudo systemctl restart iio-sensor-proxy 2>/dev/null || true

    ok "NuVision tablet fixes applied. Reboot!"
}

# ---------------------------------------------------------------------------
# Rotate TTY 90 degrees clockwise (portrait-native panels)
# ---------------------------------------------------------------------------
drivers_rotate_tty() {
    say "Rotating TTY clockwise (fbcon=rotate:1)..."

    # Runtime
    if [ -w /sys/class/graphics/fbcon/rotate_all ] || [ -e /sys/class/graphics/fbcon/rotate_all ]; then
        echo 1 | sudo tee /sys/class/graphics/fbcon/rotate_all >/dev/null || true
    fi

    # systemd oneshot for early-boot rotation (from arch-mini-mod)
    if [ "$INIT" = "systemd" ]; then
        sudo tee /etc/systemd/system/rotate-tty-clockwise.service >/dev/null <<'EOF'
[Unit]
Description=Rotate TTY framebuffer clockwise
DefaultDependencies=no
After=systemd-modules-load.service
Before=getty.target
ConditionPathExists=/sys/class/graphics/fbcon/rotate_all

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'echo 1 > /sys/class/graphics/fbcon/rotate_all'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        sudo systemctl daemon-reload
        sudo systemctl enable rotate-tty-clockwise.service
    fi

    # GRUB persistence
    if [ -f /etc/default/grub ]; then
        if grep -q 'fbcon=rotate:[0-3]' /etc/default/grub; then
            sudo sed -i 's/fbcon=rotate:[0-3]/fbcon=rotate:1/' /etc/default/grub
        elif grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
            sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 fbcon=rotate:1"/' /etc/default/grub
        elif grep -q '^GRUB_CMDLINE_LINUX=' /etc/default/grub; then
            sudo sed -i 's/^GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="\1 fbcon=rotate:1"/' /etc/default/grub
        else
            echo 'GRUB_CMDLINE_LINUX_DEFAULT="fbcon=rotate:1"' | sudo tee -a /etc/default/grub >/dev/null
        fi
        local grub_cfg="/boot/grub/grub.cfg"
        [ -f /boot/grub2/grub.cfg ] && grub_cfg="/boot/grub2/grub.cfg"
        sudo grub-mkconfig -o "$grub_cfg" 2>/dev/null || sudo update-grub 2>/dev/null || true
    fi
    ok "TTY rotation applied. Reboot for full effect."
}
