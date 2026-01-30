
# Debian‑Mini‑Mod

A minimal Debian installer focused on GNOME.  
Designed for lightweight setups, ideal for Linux tablets and touch devices.
Automates essential package installation, GNOME setup, and basic configuration for a streamlined, touch-friendly experience.



## 📦 Features

- Minimal install: core packages and GNOME
- Lightweight and fast, perfect for tablets or low-resource devices
- Optional Microsoft Surface kernel support
- Touch-friendly configuration
- Applies [Piercing‑Dots](https://github.com/PiercingXX/piercing-dots) minimal dotfiles



## 🚀 Quick Start

```bash
git clone https://github.com/PiercingXX/debian-mini-mod
cd debian-mini-mod
chmod -R u+x scripts/
./debian-mini-mod.sh
```



## 🛠️ Usage

Run `./debian-mod.sh` and follow the prompts.  


## Linux on KooTigers Mini Pc
Almost everything worked out of the box. Touch Screen and screen rotation both didnt work.
Both now work perfectly even though I dislike screen rotation and turned it off in GNOME.

**How to fix:**
Just run the script or from inside ./debian-mod.sh hit "Apply KooTigers Touchscreen Driver".
After just reboot and you're ready to go.

Check the [README](https://github.com/Piercingxx/arch-mini-mod/blob/main/resources/KooTigers-drivers/README.md) for more information.




## Linux on NuVision 8" Tablet TM800W610L
Wi-Fi and bluetooth drivers are not found in linux kernel by default. I ripped the wifi driver out of the windows install but the bluetooth driver was a royal pain. Had to rebuild it from binary...4 hours of my life gone.
    - Wi-Fi and Bluetooth both work perfectly now.

Audio is also non-functional out of the box.

Screen orientation is rotated 90° on Debian GNOME and Plasma, and does not auto-rotate on Arch until you install the Wi-Fi driver.

**How to fix:**

Just run the `nuvision-tablet-drivers.sh` script. This script is also included in the whiptail menu of the main `debian-mod.sh` installer.

Check the [README](https://github.com/Piercingxx/arch-mini-mod/blob/main/resources/NuVision-8in-tablet/README.md) for more information.




## 🔧 Optional Scripts

| Script                | Purpose                                 |
|-----------------------|-----------------------------------------|
| `scripts/apps.sh`     | Installs core desktop applications      |
| `scripts/nvidia.sh`   | Installs proprietary NVIDIA drivers     |
| `kootigers-drivers.sh` | Copies drivers and applies patch          |
| `nuvision-tablet-drivers.sh` | Copies drivers and applies patch     |
| `scripts/Surface.sh`  | Installs Microsoft Surface kernel       |

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