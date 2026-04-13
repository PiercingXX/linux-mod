
# Void‑Mod

A Void Linux installer for GNOME and multiple window manager setups.  
Designed for a lightweight but practical desktop setup.  
Automates core package installation, GNOME setup, optional WM installs, and basic configuration for a streamlined experience.

> Uses `xbps-install` for native packages, `flatpak` (Flathub) for apps without Void packages, and `runit` (`sv`) for service management.



## 📦 Features

- Core system install with GNOME desktop support
- Lightweight and fast, perfect for tablets or low-resource devices
- Wayland-first: Hyprland, Sway, i3, and bspwm all supported
- Applies [Piercing‑Dots](https://github.com/PiercingXX/piercing-dots) minimal dotfiles



## 🚀 Quick Start

```bash
git clone https://github.com/PiercingXX/void-mod
cd void-mod
chmod -R u+x scripts/
./void-mod.sh
```



## 🛠️ Usage

Run `./void-mod.sh` and follow the prompts.  
Options include minimal system install, window manager install, and reboot.



## 🔧 Scripts

| Script                    | Purpose                                      |
|---------------------------|----------------------------------------------|
| `scripts/step-1.sh`       | Core system packages, GNOME, flatpak, dotfiles |
| `scripts/hyprland-install.sh` | Installs Hyprland and Wayland stack      |
| `scripts/sway-install.sh` | Installs Sway and Wayland stack              |
| `scripts/i3-install.sh`   | Installs i3 and X11 stack                    |
| `scripts/bspwm-install.sh`| Installs bspwm and X11 stack                 |
| `scripts/install-printers.sh` | Configures Canon D530 or Omezizy label printer |

---

## 📄 License

MIT © PiercingXX  
See the LICENSE file for details.

---

## 🤝 Contributing

Fork, branch, and PR welcome.  

---

## 📞 Support & Contact

    Email: Don’t

    Open an issue in the relevant repo instead. If it’s a rant make it entertaining.