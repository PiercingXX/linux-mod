# linux-mod

One clean set of scripts to replace **arch-mod, arch-mini-mod, artix-mod,
debian-mod, debian-mini-mod, fedora-mod, and void-mod**.

No per-distro script piles: every module is a single file that branches on the
detected distro internally — one place to fix a package name, one place to add
a distro.

```
linux-mod.sh                  entry point: detect distro -> menu -> modules
lib/
├── common.sh                 logging, sudo, network, resumable state
├── ui.sh                     designed TUI: gum → fzf → whiptail → select
└── pkg.sh                    the abstraction that makes unification work:
                              detect_distro, pi (install), aur, fp (flatpak),
                              svc_enable/disable (systemd/runit/openrc/dinit)
modules/
├── base.sh                   unified step-1: repos, CLI core, audio, network,
│                             services, fonts, theme, GNOME, debloat, mini tweaks
├── gnome-extensions.sh       pop-shell, blur-my-shell, appindicator, gsconnect,
│                             just-perfection, workspaces, super-key
├── apps.sh                   unified apps: flatpak core, yazi+plugins, neovim,
│                             vscode/opencode, tailscale/synology, docker...
├── dots.sh                   piercing-dots rice + .bashrc + first-login polish
├── wm.sh                     Hyprland, Sway, i3, bspwm, Awesome, Qtile, DWM,
│                             herbstluftwm, GNOME, BusyBox — per-distro branches
├── drivers.sh                Nvidia+CUDA, Surface kernel, KooTigers touchscreen,
│                             NuVision tablet, 3Dconnexion SpaceMouse, TTY rotation
└── extras.sh                 printers (Canon D530 / Canon MG3600 / Epson ET-4800 /
                              Omezizy), gaming, Cosmic
resources/
├── kootigers/                Goodix touchscreen boot service
└── nuvision/                 Broadcom wifi/BT + SOF audio firmware, hwdb
```

## Supported distros

| | Full | Mini | Notes |
|---|---|---|---|
| Arch (+ CachyOS, EndeavourOS, Manjaro) | ✅ | ✅ | paru auto-bootstrapped |
| Artix | ✅ | ✅ | runit/OpenRC/dinit aware, ly login |
| Debian / Ubuntu / Pop!_OS / Mint | ✅ | ✅ | Hyprland built from source |
| Fedora | ✅ | ✅ | COPR + RPM Fusion |
| Void | ✅ | ✅ | runit, GDM off by default, Hyprland built from source |
| openSUSE Tumbleweed | ✅ | ✅ | zypper, NVIDIA repo for drivers |
| Alpine | ⚠️ | ✅ | musl: mini-focused; flatpaks fill the gaps |

**Full** = complete workstation: desktop, media/production apps, docker, gaming
offer. **Mini** = lean tablet/mini-PC build: core system + rice, extra wifi/BT
firmware, boots to TTY on Arch (no display manager), skips the heavy apps.
Both profiles work on every distro.

## Usage

```bash
git clone https://github.com/Piercingxx/linux-mod.git
cd linux-mod
./linux-mod.sh                 # interactive menu
./linux-mod.sh --full          # unattended full install (no DE unless --wm)
./linux-mod.sh --mini          # unattended mini install
./linux-mod.sh --full --wm hyprland,gnome
./linux-mod.sh --full --spacemouse   # also set up a 3Dconnexion SpaceMouse
./linux-mod.sh --dry-run       # print what would happen, change nothing
./linux-mod.sh --reset-state   # forget completed steps, redo everything
./linux-mod.sh --no-color      # plain output (NO_COLOR env works too)
./linux-mod.sh update          # pull the latest linux-mod
```

Run as your normal user (not root); sudo is requested once and kept alive.
On Alpine, a stock install has neither: run `doas apk add bash sudo` first
(and add yourself to `wheel` in `/etc/sudoers`).
Everything is logged to `/tmp/linux-mod.log`, and every run ends with a
summary table of any warnings.

**Resumable installs:** each stage (base / dots / apps) writes a marker to
`~/.local/state/linux-mod/` on success. If an install dies halfway, rerun it —
completed stages are skipped. `--reset-state` starts fresh.

**Dry-run:** `--dry-run` short-circuits every package install, service change,
flatpak, AUR build, and sudo command into a `[dry-run]` echo. It's what the CI
matrix runs in each distro container. (It's an approximation: a few read-only
probes still execute.)

**TUI:** PiercingXX ink/signal chrome (not Charm pink). Prefers `gum`, then
`fzf`, then `whiptail`, then POSIX `select`. If gum is missing it is installed
from the distro repo, or (non-Alpine) fetched as one pinned static binary into
`~/.local/share/linux-mod/bin`. Full and Mini do **not** assume a desktop —
the menu asks you to pick one or more WMs after apps. Unattended runs skip
that unless you pass `--wm`. After the WM pick, interactive installs offer
3Dconnexion SpaceMouse support (spacenavd + spnavcfg, for the SpaceMouse
Compact 3DX-700059 and other 3Dconnexion devices) and the gaming extras;
unattended runs add the SpaceMouse with `--spacemouse`. No automatic reboot.

Menu: **Full Install** · **Mini Install** · **Window Managers** (multi-select) ·
**Drivers & Hardware** · **Extras** — options that don't apply to your distro
simply don't appear.

## Design rules

- `pi` installs packages and *skips* individually-unavailable ones with a
  warning instead of aborting a 40-minute install. It still returns 1 when
  something was skipped, so `pi a || pi b` fallbacks work.
- Networking is never pulled mid-install: if iwd/networkd/dhcpcd is carrying
  the connection, the swap to NetworkManager happens at the end (at next boot
  on systemd).
- `svc_enable bluetooth bluetoothd` — first service name that exists wins,
  regardless of init system.
- Distro detection uses `/etc/os-release` `ID` with `ID_LIKE` fallback, so
  derivatives just work.
- Modules never call `pacman`/`apt`/... directly except inside an explicit
  `case "$DISTRO"` branch that needs distro-specific behavior.

## Roadmap / ideas

- [x] openSUSE Tumbleweed support (`zypper` branch in `lib/pkg.sh`)
- [x] Alpine support for the mini profile (apk, OpenRC)
- [x] `--dry-run` flag that prints every install/enable action without executing
- [x] Per-module state markers (`~/.local/state/linux-mod/`) for resumable installs
- [x] CI: shellcheck + per-distro container dry-runs (`.github/workflows/ci.yml`)
- [x] Designed TUI (PiercingXX ink/signal): gum → fzf → whiptail → select, pinned gum bootstrap, no auto-reboot, `--wm`
- [x] Self-update: `linux-mod.sh update`
- [ ] Move package lists out to `packages/*` data files (skipped for now — the
      `case "$DISTRO"` blocks *are* the data, and one more indirection layer
      isn't worth it at this size)

## License

MIT — see [LICENSE](LICENSE).
