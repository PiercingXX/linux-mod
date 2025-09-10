# Fedora‑Mod

A minimal installer for a fully‑featured Fedora workstation.  
Automates package installation, GNOME customizations, optional desktop environments, and Surface kernel modules.

---

## 📦 Features

- Installs GNOME “Piercing‑Rice” customizations and curated dotfiles
- Menu‑driven setup with `whiptail` TUI
- Optional Cosmic and Hyprland desktop environments
- Microsoft Surface kernel support
- POSIX‑friendly scripting

---

## 🚀 Quick Start

```bash
git clone https://github.com/PiercingXX/fedora-mod
cd fedora-mod
chmod +x fedora-mod.sh
./fedora-mod.sh
```

---

## 🛠️ Usage

Run `./fedora-mod.sh` and follow the menu prompts.  
Options include full install, Cosmic, Hyprland, Surface kernel, reboot, and exit.

---

## 📋 Prerequisites

| Requirement         | Command                       |
|---------------------|------------------------------|
| Fedora 38+          | `rpm -q fedora-release`      |
| Internet connection | `ping -c 1 8.8.8.8`          |
| `whiptail` TUI      | `dnf install -y whiptail`    |

---

## 🔧 Optional Scripts

| Script                      | Purpose                                 |
|-----------------------------|-----------------------------------------|
| `scripts/apps.sh`           | Installs core desktop applications      |
| `scripts/hyprland-install.sh` | Installs Hyprland and dependencies     |
| `scripts/Surface.sh`        | Installs Microsoft Surface kernel       |

---

## 📄 License

MIT © PiercingXX  
See LICENSE for details.

---

## 🤝 Contributing

Fork, branch, and PR welcome.  
Keep scripts POSIX‑friendly and avoid hard‑coded paths.

---

## 📞 Support

*No direct support provided.*