# shellcheck shell=bash
# GitHub.com/PiercingXX
# Drivers & hardware - Nvidia, Microsoft Surface kernel, KooTigers touchscreen,
# NuVision 8in tablet, 3Dconnexion SpaceMouse, TTY rotation. One function per
# item, distro-branched.

RES_DIR="$LINUX_MOD_ROOT/resources"

drivers_menu() {
    local options=("Nvidia Drivers" "Microsoft Surface Kernel")
    # Tablet hardware fixes need systemd for the boot services
    case "$DISTRO" in
        arch|artix|debian|suse)
            options+=("KooTigers Touchscreen Driver" "NuVision 8in Tablet Fixes") ;;
    esac
    options+=("3Dconnexion SpaceMouse" "Rotate TTY Clockwise" "Back")

    local choice
    while true; do
        ui_screen "drivers & hardware  ·  ${DISTRO}"
        choice=$(ui_choose "choose an option" "${options[@]}") || break
        case "$choice" in
            "Nvidia Drivers")               drivers_nvidia ;;
            "Microsoft Surface Kernel")     drivers_surface ;;
            "KooTigers Touchscreen Driver") drivers_kootigers ;;
            "NuVision 8in Tablet Fixes")    drivers_nuvision ;;
            "3Dconnexion SpaceMouse")       drivers_spacemouse ;;
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
            nvidia_arch_driver || return 1
            pi cuda
            ;;
        debian)
            _nvidia_debian || return 1
            ;;
        fedora)
            # via RPM Fusion (enabled during base setup)
            pi akmod-nvidia xorg-x11-drv-nvidia-cuda
            ;;
        void)
            if [ "$LIBC" = "musl" ]; then
                warn "Proprietary Nvidia drivers aren't built for void-musl; using nouveau."
                return 1
            fi
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

# Which Arch driver branch fits this GPU, from the codename lspci prints
# (e.g. "GP104 [GeForce GTX 1080]"):
#   open   - Turing (RTX 20 / GTX 16) and newer: nvidia-open-dkms (repo)
#   580xx  - Maxwell/Pascal (GM/GP): last driver that supports them (AUR)
#   none   - Kepler/Fermi and older: nouveau only
_nvidia_arch_branch() {
    local gpu
    gpu=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -i nvidia)
    if printf '%s' "$gpu" | grep -qE '\bG(K|F)[0-9]{3}'; then
        echo none
    elif printf '%s' "$gpu" | grep -qE '\bG(M|P)[0-9]{3}'; then
        echo 580xx
    else
        echo open
    fi
}

# Driver + 32-bit userspace (Steam needs it). Arch dropped `nvidia` and
# `nvidia-dkms`; dkms builds for whatever kernels are installed (surface,
# zen, cachyos...), so pull their headers too. Shared with extras_gaming.
nvidia_arch_driver() {
    local headers=() f
    for f in /usr/lib/modules/*/pkgbase; do
        [ -f "$f" ] && headers+=("$(cat "$f")-headers")
    done
    [ ${#headers[@]} -gt 0 ] || headers=(linux-headers)
    case "$(_nvidia_arch_branch)" in
        open)
            pi "${headers[@]}" nvidia-open-dkms nvidia-utils nvidia-settings lib32-nvidia-utils
            ;;
        580xx)
            say "Maxwell/Pascal GPU: using the 580xx legacy driver from the AUR."
            pi "${headers[@]}"
            aur nvidia-580xx-dkms nvidia-580xx-utils nvidia-580xx-settings lib32-nvidia-580xx-utils
            ;;
        none)
            warn "This Nvidia GPU is too old for the current drivers; staying on nouveau."
            return 1
            ;;
    esac
}

# Debian: non-free nvidia-driver + NVIDIA's CUDA network repo.
# Ubuntu/Pop/Mint: their own driver tooling + the distro CUDA toolkit.
_nvidia_debian() {
    sudo apt update
    case "$OS_ID" in
        debian)
            pi linux-headers-amd64 nvidia-driver firmware-misc-nonfree nvidia-settings nvtop
            local major="${OS_VERSION_ID%%.*}" tmp
            tmp=$(mktemp -d)
            # cuda-keyring tracks NVIDIA's repo, unlike the pinned local
            # installer this used to download (which 404s now)
            if [ -n "$major" ] && wget -q -O "$tmp/cuda-keyring.deb" \
                    "https://developer.download.nvidia.com/compute/cuda/repos/debian${major}/x86_64/cuda-keyring_1.1-1_all.deb"; then
                sudo dpkg -i "$tmp/cuda-keyring.deb" && sudo apt update && pi cuda-toolkit
            else
                warn "No NVIDIA CUDA repo for Debian ${major:-?}; using Debian's nvidia-cuda-toolkit."
                pi nvidia-cuda-toolkit
            fi
            command rm -rf "$tmp"
            sudo dpkg --add-architecture i386 && sudo apt update
            pi nvidia-driver-libs:i386
            ;;
        pop)
            pi system76-driver-nvidia nvtop nvidia-cuda-toolkit
            ;;
        *)
            pi ubuntu-drivers-common nvtop
            sudo ubuntu-drivers install || { warn "ubuntu-drivers could not pick a driver."; return 1; }
            pi nvidia-cuda-toolkit
            ;;
    esac
    sudo apt autoremove -y
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
# 3Dconnexion SpaceMouse Compact (3DX-700059, USB 256f:c635) - spacenavd
# Blender/FreeCAD talk to spacenavd over /run/spnav.sock (the Blender flatpak
# already has that socket in its permissions). spnavcfg is the tuning GUI.
# ---------------------------------------------------------------------------
drivers_spacemouse() {
    say "Setting up 3Dconnexion SpaceMouse support (spacenavd)..."
    case "$DISTRO" in
        arch|artix)
            pi libspnav
            aur spacenavd spnavcfg
            ;;
        suse)
            pi spacenavd   # no spnavcfg package on Tumbleweed
            ;;
        *)
            pi spacenavd spnavcfg
            ;;
    esac

    # Desktop/browser apps that open the device directly (WebHID: Onshape)
    # need hidraw access; uaccess hands it to the logged-in seat user.
    sudo tee /etc/udev/rules.d/70-spacemouse.rules >/dev/null <<'EOF'
# 3Dconnexion devices (SpaceMouse Compact 256f:c635 and friends) - linux-mod
KERNEL=="hidraw*", ATTRS{idVendor}=="256f", TAG+="uaccess"
EOF
    sudo udevadm control --reload-rules 2>/dev/null || true
    sudo udevadm trigger --subsystem-match=hidraw 2>/dev/null || true

    svc_enable spacenavd || say "Start the daemon by hand with 'sudo spacenavd' until a service exists."

    if [ "$DRY_RUN" -eq 0 ] && command_exists lsusb && ! lsusb -d 256f: >/dev/null 2>&1; then
        say "No 3Dconnexion device plugged in right now; spacenavd picks it up on hotplug."
    fi
    ok "SpaceMouse support installed. Tune it with spnavcfg."
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
