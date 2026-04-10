# Artix-Mod

A streamlined installer for a fully-featured Artix Linux workstation (systemd-free).  
Automates core package installation, GPU drivers, Surface kernel modules, and curated dotfiles for X11 workflows.

---

## 📦 Features

- Focused on bspwm and i3 (X11 only), plus developer tools and essential apps
- Installs and defaults to `ly` as the login screen/display manager
- Supports Artix init variants (OpenRC, runit, dinit) for service setup
- Applies [Piercing‑Dots](https://github.com/PiercingXX/piercing-dots) dotfiles and customizations
    - Window Manager Dots and all there utilities
      - BSPWM/i3
    - GIMP dots
    - Yazi/kitty setup
    - Scripts that make linux easy:
      - Maintenance.sh - identifies your distro | updates and cleans everything is your system | will auto update any scripts I modify in the github repo.
      - terminal_software_manager.sh - lets you install or uninstall all your software from the terminal even if you dont remember how it was installed, or what the exact name is.
      - open_daily_note.sh - daily notes using nvim and a folder backed up on my own server cloud for sync across all devices.
- Firewall configuration with UFW
- Paru & Flatpak integration and core desktop applications
- Optional NVIDIA driver and Microsoft Surface kernel support

---

## 🚀 Quick Start

```bash
git clone https://github.com/PiercingXX/artix-mod
cd artix-mod
chmod -R u+x scripts/
./artix-mod.sh
```

---

## 🛠️ Usage

Run `./artix-mod.sh` and follow the menu prompts.  
Options include system install, NVIDIA drivers, Surface kernel, X11 window manager setup (bspwm/i3), and reboot.

---

## 🔧 Optional Scripts

| Script                | Purpose                                 |
|-----------------------|-----------------------------------------|
| `scripts/apps.sh`     | Installs core desktop applications      |
| `scripts/bspwm-install.sh` | Installs bspwm and dependencies |
| `scripts/i3-install.sh` | Installs i3 and dependencies |
| `scripts/hyprland-install.sh` | Installs Hyprland and Wayland dependencies |
| `scripts/gnome-install.sh` | Installs GNOME desktop while keeping Ly as display manager |
| `scripts/install-printers.sh` | Configures Canon D530 or Omezizy label printers |
| `scripts/nvidia.sh`   | Installs proprietary NVIDIA drivers     |
| `scripts/surface-kernel-setup.sh`  | Installs Microsoft Surface kernel (GRUB-focused) |

---

## 📄 License

MIT © PiercingXX  
See the LICENSE file for details.

---

## 🤝 Contributing

Fork, branch, and PR welcome.  

---

## 📞 Support

*No direct support provided.*
