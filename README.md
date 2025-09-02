# Fedora‑Mod

A one‑step installer that turns a fresh Fedora installation into a fully‑featured workstation.  
It installs the same curated dotfiles that power the **Piercing‑Dots** repo, adds optional desktop environments, and can even pull in the Microsoft Surface kernel.

---

## 📦 What is Fedora‑Mod?

- **All‑in‑one**: Installs packages, fonts, and the “Piercing‑Rice” Gnome customisations.
- **Menu‑driven**: Uses `whiptail` to present a clean, text‑based UI.
- **Extensible**: Supports Cosmic, Hyprland, Surface kernel, and a reboot option.
- **POSIX‑friendly**: Avoids hard‑coded paths and works on any Fedora release.

---

## 🚀 Quick Start

```bash
# 1️⃣  Clone the repo
git clone https://github.com/PiercingXX/fedora-mod
cd fedora-mod

# 2️⃣  Make the script executable
chmod +x fedora-mod.sh

# 3️⃣  Run the installer
fedora-mod.sh
```

The script will ask for your password, check network connectivity, and then present a menu.  
Choose **Install** to apply the full Gnome “Rice”, or pick any of the other options.

---

## 📋 Prerequisites

| Item | Why it matters | Check |
|------|----------------|-------|
| Fresh Fedora 38+ | The script assumes a clean install | `rpm -q fedora-release` |
| Internet connection | Packages are fetched from the network | `ping -c 1 8.8.8.8` |
| `whiptail` | Required for the TUI | `dnf install -y whiptail` (script will install it automatically) |

---

## 📚 Usage

```bash
fedora-mod.sh
```

The menu offers the following actions:

| Option | Description |
|--------|-------------|
| **Install** | Installs apps, fonts, dependencies, and the Piercing‑Rice Gnome customisations. |
| **Install Cosmic** | Installs the Cosmic desktop and Cosmic Tweaks. |
| **Install Hyprland** | Installs Hyprland, its dependencies, and the Hyprland dotfiles. |
| **Surface Kernel** | Installs the Microsoft Surface kernel modules. |
| **Reboot System** | Reboots the machine immediately. |
| **Exit** | Exits the script. |

After **Install** the script will reboot automatically.

---

## 🔧 Optional Scripts

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `scripts/apps.sh` | Installs core applications (GIMP, VS Code, etc.). | Run automatically during **Install**. |
| `scripts/hyprland-install.sh` | Installs Hyprland and Wayland dependencies. | Run automatically during **Install Hyprland**. |
| `scripts/Surface.sh` | Installs Microsoft Surface kernel modules. | Run automatically during **Surface Kernel**. |

---

## ⚙️ Hardware‑Specific Notes

- **Surface Devices**: Skip `nvidia.sh` (not part of this repo) to avoid driver conflicts.
- **Multiple Drives**: Edit `/etc/fstab` after installation if you need auto‑mounting.
- **Bluetooth**: The script starts and enables the Bluetooth service after installing Hyprland.

---

## 🎉 Post‑Installation

- **Gnome**: Log out and log back in to see the new theme, extensions, and keybindings.
- **Hyprland**: Log out of Gnome, select Hyprland at the login screen, and enjoy a Wayland session.
- **Cosmic**: If installed, log out and choose Cosmic from the session selector.

---

## 📚 Credits

- **Linux‑Surface** – Surface kernel bits from the [linux‑surface](https://github.com/linux-surface/linux-surface) project.
- **Piercing‑Dots** – Dotfiles and the `maintenance.sh` script.
- **Fedora Community** – For the base OS and package repositories.

---

## 📄 License

MIT © PiercingXX  
See the LICENSE file for details.

---

## 📞 Support & Contact

*Don't*  

---

## 🤝 Contributing
If you have suggestions, fork, hack, or PR. I'd love to see it.

```