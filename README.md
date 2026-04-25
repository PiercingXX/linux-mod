
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
- Post-install health reports for base and Hyprland installers


## 🚀 Quick Start

```bash
git clone https://github.com/PiercingXX/void-mod
cd void-mod
chmod -R u+x scripts/
./void-mod.sh
```



## 🛠️ Usage

Run `./void-mod.sh` and follow the prompts.  
Options include minimal system install, window manager install, persistent TTY rotation, and reboot.

GDM is optional and disabled by default. To install and enable it during the base flow, run:

```bash
VOID_INSTALL_GDM=1 ./void-mod.sh
```



## ⚙️ Environment Flags

| Flag | Default | Description |
|------|---------|-------------|
| `VOID_INSTALL_GDM` | `0` | Set to `1` to install and enable GDM (display manager). Default: launch GNOME via `gnome-wayland` or `gnome-x11` wrappers. |
| `VOID_FORCE_DEFAULT_MIRROR` | `1` | Set to `0` to skip reconfiguring the xbps repo to `repo-default.voidlinux.org` before the Hyprland install. |
| `HYPR_SOURCE_FALLBACK` | `1` | Set to `0` to disable the source-build fallback in `hyprland-install.sh` when binary packages fail. |
| `HYPRSUNSET_PINNED_HYPRUTILS` | `hyprutils-0.7.1_1` | Override the pinned hyprutils version used for the hyprsunset ABI compatibility stack. |
| `HYPRSUNSET_PINNED_HYPRLANG` | `hyprlang-0.6.3_1` | Override the pinned hyprlang version. |
| `HYPRSUNSET_PINNED_PACKAGE` | `hyprsunset-0.2.0_1` | Override the pinned hyprsunset version. |

### Package availability behaviour

Both `step-1.sh` and `hyprland-install.sh` use mirror-tolerant install helpers:

- **`pkg_installed`** — checks `xbps-query -l` for `^ii <pkg>-` before installing; already-installed packages are skipped instantly on reruns.
- **`pkg_available`** — checks `xbps-query -Rs "^<pkg>$"` before any install attempt; packages absent from the current repo index are skipped with a `[warn]` line instead of aborting the script.
- **`xi_install_safe`** — wraps both checks; used for all optional/semi-optional packages (`waybar`, `pipewire-pulse`, `cava`, `bluetuith`, Hyprland Qt extras, etc.).

Required packages that anchor a fallback chain (e.g. `hyprland` core, `mesa`, `dbus`) still use the retrying `xi_install` helper so mirror-sync failures trigger an index refresh and retry rather than a silent skip.



## 🔧 Scripts

| Script                    | Purpose                                      |
|---------------------------|----------------------------------------------|
| `scripts/step-1.sh`       | Core system packages, GNOME, flatpak, dotfiles |
| `scripts/hyprland-install.sh` | Installs Hyprland and Wayland stack      |
| `scripts/sway-install.sh` | Installs Sway and Wayland stack              |
| `scripts/i3-install.sh`   | Installs i3 and X11 stack                    |
| `scripts/bspwm-install.sh`| Installs bspwm and X11 stack                 |
| `scripts/rotate-tty-clockwise.sh` | Rotates the Linux TTY 90 degrees clockwise and persists it in GRUB |
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