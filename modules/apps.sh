# shellcheck shell=bash
# GitHub.com/PiercingXX
# Applications - unified from every *-mod apps.sh.
# Full profile = the whole workstation; mini = the lean tablet/mini-PC set.

# Flatpaks every machine gets
FLATPAKS_CORE=(
    net.waterfox.waterfox
    md.obsidian.Obsidian
    com.mattjakeman.ExtensionManager
    org.qbittorrent.qBittorrent
    io.missioncenter.MissionCenter
    io.github.shiftey.Desktop
    io.github.realmazharhussain.GdmSettings
)

# Heavier media/production flatpaks, full profile only
FLATPAKS_FULL=(
    org.libreoffice.LibreOffice
    org.gimp.GIMP
    org.darktable.Darktable
    org.blender.Blender
    org.gnome.SimpleScan
    org.kde.kdenlive
    com.flashforge.FlashPrint
    org.gnome.meld
    com.github.xournalpp.xournalpp
)

YAZI_PLUGINS=(
    dedukun/bookmarks
    yazi-rs/plugins:mount
    dedukun/relative-motions
    yazi-rs/plugins:chmod
    yazi-rs/plugins:smart-enter
    AnirudhG07/rich-preview
    grappas/wl-clipboard
    Rolv-Apneseth/starship
    yazi-rs/plugins:full-border
    uhs-robert/recycle-bin
    yazi-rs/plugins:diff
)

apps_install() {
    say "Installing applications (${PROFILE})..."
    _apps_flatpaks
    _apps_common_native
    _apps_yazi
    _apps_neovim
    _apps_editors
    _apps_networking
    if [ "$PROFILE" = "full" ]; then
        _apps_full_only
    fi
    _apps_cleanup
    ok "Applications installed."
}

_apps_flatpaks() {
    fp "${FLATPAKS_CORE[@]}"
    [ "$PROFILE" = "full" ] && fp "${FLATPAKS_FULL[@]}"
    # PipeWire audio access for chatty flatpaks
    local app
    for app in net.waterfox.waterfox com.discordapp.Discord dev.vencord.Vesktop; do
        flatpak override --user --socket=pulseaudio --filesystem=xdg-run/pipewire-0 "$app" 2>/dev/null || true
    done
}

_apps_common_native() {
    pi fwupd w3m
    case "$DISTRO" in
        arch|artix)
            pi kitty python vlc
            aur ulauncher || _apps_ulauncher_aur_webkit_fix
            aur proton-vpn-gtk-app ventoy-bin
            [ "$DISTRO" = "arch" ] && { pi github-cli; aur nautilus-open-any-terminal nautilus-renamer; }
            [ "$DISTRO" = "artix" ] && pi rofi
            aur vial-appimage && sudo usermod -aG uucp "$USER"
            ;;
        debian)
            pi fastfetch
            _apps_ulauncher_ppa
            _apps_protonvpn_deb
            ;;
        fedora)
            pi gnome-tweaks ulauncher qbittorrent
            sudo dnf copr enable -y karlisk/ventoy && pi ventoy
            ;;
        void)
            pi ulauncher vlc kitty
            fp com.protonvpn.www
            ;;
        suse)
            pi kitty vlc fastfetch gnome-tweaks ulauncher
            fp com.protonvpn.www
            ;;
        alpine)
            pi kitty fastfetch vlc
            fp com.protonvpn.www
            ;;
    esac
}

# arch: ulauncher AUR PKGBUILD wants old webkit2gtk; patch to 4.1 (from arch-mini-mod)
_apps_ulauncher_aur_webkit_fix() {
    if [ "$DRY_RUN" -eq 1 ]; then dry "build ulauncher from AUR with webkit2gtk-4.1 patch"; return 0; fi
    local tmp; tmp=$(mktemp -d)
    if git clone --depth 1 https://aur.archlinux.org/ulauncher.git "$tmp/ulauncher"; then
        (cd "$tmp/ulauncher" \
            && sed -i "s/'webkit2gtk'/'webkit2gtk-4.1'/" PKGBUILD \
            && makepkg -is --noconfirm) || warn "ulauncher AUR build failed."
    fi
    command rm -rf "$tmp"
}

_apps_ulauncher_ppa() {
    if [ "$DRY_RUN" -eq 1 ]; then dry "add ulauncher PPA + install"; return 0; fi
    if ! command_exists ulauncher; then
        gpg --keyserver keyserver.ubuntu.com --recv 0xfaf1020699503176 2>/dev/null
        gpg --export 0xfaf1020699503176 | sudo tee /usr/share/keyrings/ulauncher-archive-keyring.gpg >/dev/null
        echo "deb [signed-by=/usr/share/keyrings/ulauncher-archive-keyring.gpg] \
http://ppa.launchpad.net/agornostal/ulauncher/ubuntu noble main" \
            | sudo tee /etc/apt/sources.list.d/ulauncher-noble.list >/dev/null
        sudo apt update && pi ulauncher
    fi
}

_apps_protonvpn_deb() {
    if [ "$DRY_RUN" -eq 1 ]; then dry "add ProtonVPN stable apt repo + install proton-vpn-gnome-desktop"; return 0; fi
    local deb="protonvpn-stable-release_1.0.8_all.deb" tmp
    tmp=$(mktemp -d)
    wget -q "https://repo.protonvpn.com/debian/dists/stable/main/binary-all/${deb}" -O "$tmp/$deb" \
        && sudo dpkg -i "$tmp/$deb" && sudo apt update && pi proton-vpn-gnome-desktop
    command rm -rf "$tmp"
}

_apps_yazi() {
    say "Installing yazi + plugins..."
    case "$DISTRO" in
        arch)   aur yazi-nightly-bin || pi yazi ;;
        artix)  aur yazi-nightly-bin || pi yazi ;;
        debian)
            command_exists cargo || _ensure_rust
            cargo install --force --git https://github.com/sxyazi/yazi.git yazi-build yazi-cli \
                || warn "yazi cargo build failed."
            ;;
        fedora) sudo dnf copr enable -y lihaohong/yazi && pi yazi ;;
        void|suse|alpine) pi yazi ;;
    esac
    # preview/extract helpers (name differences handled by pi's skip logic)
    case "$DISTRO" in
        debian) pi ffmpeg poppler-utils fd-find ripgrep fzf zoxide imagemagick
                pi 7zip || pi p7zip-full ;;
        void)   pi ffmpeg 7zip jq poppler fd ripgrep fzf zoxide ImageMagick ;;
        fedora) pi ffmpeg 7zip jq poppler-utils fd-find ripgrep fzf zoxide ImageMagick ;;
        alpine) pi ffmpeg 7zip jq poppler-utils fd ripgrep fzf zoxide imagemagick ;;
        suse)   pi ffmpeg 7zip jq poppler-tools fd ripgrep fzf zoxide ImageMagick ;;
        *)      pi ffmpeg 7zip jq poppler fd ripgrep fzf zoxide imagemagick ;;
    esac
    if command_exists ya; then
        local plugin
        for plugin in "${YAZI_PLUGINS[@]}"; do
            ya pkg add "$plugin" 2>/dev/null || true
        done
    fi
}

_ensure_rust() {
    if [ "$DRY_RUN" -eq 1 ]; then dry "ensure Rust toolchain (rustup)"; return 0; fi
    if ! command_exists cargo; then
        say "Installing Rust toolchain..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        # shellcheck disable=SC1091
        source "$HOME/.cargo/env"
    fi
}

_apps_neovim() {
    say "Installing Neovim (nightly where possible)..."
    case "$DISTRO" in
        arch|artix)
            pi nodejs npm ripgrep python python-pip chafa gcc
            aur lua51 python-pynvim neovim-nightly-bin
            ;;
        debian)
            pi cmake ninja-build gettext unzip curl build-essential lua5.4 python3-pip \
               python3-pynvim chafa ripgrep
            if [ "$DRY_RUN" -eq 1 ]; then
                dry "build Neovim nightly from source"
            else
                local tmp; tmp=$(mktemp -d)
                if git clone --depth 1 --branch nightly https://github.com/neovim/neovim.git "$tmp/neovim"; then
                    (cd "$tmp/neovim" \
                        && make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=/usr/local/ \
                        && sudo make install) || warn "Neovim build failed."
                fi
                command rm -rf "$tmp"
                echo 'export PATH="/usr/local/bin:$PATH"' | sudo tee /etc/profile.d/local-path.sh >/dev/null
                sudo chmod 644 /etc/profile.d/local-path.sh
            fi
            ;;
        fedora)
            pi neovim luarocks python3-pip python3-neovim nodejs gcc
            sudo dnf copr enable -y atim/lazygit && pi lazygit
            sudo npm install -g neovim @mermaid-js/mermaid-cli 2>/dev/null || true
            ;;
        void|suse)
            pi neovim nodejs ripgrep chafa python3-pip python3-neovim gcc
            ;;
        alpine)
            pi nodejs ripgrep chafa py3-pip py3-pynvim build-base
            # a plain `apk add neovim` would drop an existing edge pin (downgrade)
            grep -qx 'neovim@edgecommunity' /etc/apk/world 2>/dev/null || pi neovim
            _alpine_neovim_edge
            ;;
    esac
    # nvim-treesitter compiles parsers: needs a C compiler (above) + tree-sitter-cli
    _apps_tree_sitter_cli
    # pip only as a last resort: distro Pythons are externally managed (PEP 668)
    if [ "$DRY_RUN" -eq 0 ] && ! python3 -c 'import pynvim' 2>/dev/null; then
        python3 -m pip install --user --upgrade pynvim 2>/dev/null \
            || warn "pynvim not installed (no distro package, pip refused)."
    fi
}

# _version_ge have want: true if version $1 >= $2
_version_ge() {
    [ -n "$1" ] && [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]
}

# The nvim dots need vim.pack (Neovim 0.12+). Alpine stable can lag behind
# (3.23 ships 0.11), so take just Neovim from edge via a tagged repo:
# packages only come from it when asked for as name@edgecommunity.
NVIM_MIN="0.12.0"
ALPINE_EDGE="https://dl-cdn.alpinelinux.org/alpine/edge"

_alpine_edge_repos() {
    grep -q '^@edgecommunity ' /etc/apk/repositories 2>/dev/null && return 0
    say "Adding Alpine edge as tagged repos (@edge, @edgecommunity)..."
    printf '@edge %s/main\n@edgecommunity %s/community\n' "$ALPINE_EDGE" "$ALPINE_EDGE" \
        | sudo tee -a /etc/apk/repositories >/dev/null
    sudo apk update -q
}

_alpine_neovim_edge() {
    local v
    if [ "$DRY_RUN" -eq 1 ]; then dry "neovim@edgecommunity if Alpine's neovim is older than ${NVIM_MIN}"; return 0; fi
    v=$(nvim --version 2>/dev/null | awk 'NR == 1 { sub(/^v/, "", $2); print $2 }')
    _version_ge "$v" "$NVIM_MIN" && return 0
    say "Alpine's Neovim (${v:-missing}) is older than ${NVIM_MIN}; installing it from edge..."
    _alpine_edge_repos && pi neovim@edgecommunity
    hash -r
}

# nvim-treesitter (main branch) needs tree-sitter-cli >= 0.26.1.
# distro package where new enough -> Alpine edge (musl) -> pinned upstream
# binary (glibc) -> cargo
TREE_SITTER_MIN="0.26.1"
TREE_SITTER_VERSION="0.26.13"

_tree_sitter_ok() {
    _version_ge "$(tree-sitter --version 2>/dev/null | awk '{ print $2 }')" "$TREE_SITTER_MIN"
}

_tree_sitter_from_github() {
    local arch want asset tmp bin rc=1
    case "$(uname -m)" in
        x86_64|amd64)  arch="x64";   want="c9c8bef027658d60249ca4fc0663578ceb2e2029346bb8702e091e20d7716475" ;;
        aarch64|arm64) arch="arm64"; want="088c5ebf4b4b558c8abfd167c9c4f9669c2f9070da3edd9c0157dc051d77ac5d" ;;
        *)             return 1 ;;
    esac
    [ "$LIBC" = "glibc" ] || return 1
    command_exists curl || return 1
    command_exists sha256sum || return 1

    asset="tree-sitter-linux-${arch}.gz"
    tmp=$(mktemp -d) || return 1
    bin="$tmp/tree-sitter-linux-${arch}"
    say "Fetching tree-sitter-cli v${TREE_SITTER_VERSION} (one binary)..."
    if command curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/download/v${TREE_SITTER_VERSION}/${asset}" \
        -o "$tmp/$asset"; then
        if [ "$(sha256sum "$tmp/$asset" | awk '{ print $1 }')" != "$want" ]; then
            warn "tree-sitter-cli checksum mismatch — not using the download."
        # running it first catches a glibc too old for the upstream build
        elif gunzip "$tmp/$asset" && chmod 0755 "$bin" && "$bin" --version >/dev/null 2>&1; then
            sudo install -m 0755 "$bin" /usr/local/bin/tree-sitter && rc=0
        fi
    fi
    command rm -rf "$tmp"
    hash -r
    return "$rc"
}

_apps_tree_sitter_cli() {
    if [ "$DRY_RUN" -eq 1 ]; then dry "ensure tree-sitter-cli >= ${TREE_SITTER_MIN}"; return 0; fi
    _tree_sitter_ok && return 0
    say "Installing tree-sitter-cli (Neovim treesitter parsers)..."
    # Debian/Ubuntu and Void stable ship versions older than the minimum;
    # quiet so a missing/old package doesn't warn when a fallback succeeds
    case "$DISTRO" in
        arch|artix|fedora|alpine) pkg_install_quiet tree-sitter-cli || true ;;
        suse)                     pkg_install_quiet tree-sitter || true ;;
    esac
    hash -r
    _tree_sitter_ok && return 0
    if [ "$DISTRO" = "alpine" ]; then
        _alpine_edge_repos && pkg_install_quiet tree-sitter-cli@edgecommunity
        hash -r
        _tree_sitter_ok && return 0
    fi
    _tree_sitter_from_github && _tree_sitter_ok && return 0
    command_exists cargo || _ensure_rust
    cargo install --locked --version "$TREE_SITTER_VERSION" tree-sitter-cli \
        || warn "tree-sitter-cli cargo build failed."
    hash -r
    _tree_sitter_ok || warn "tree-sitter-cli >= ${TREE_SITTER_MIN} not installed; Neovim treesitter parsers won't build."
}

_apps_editors() {
    say "Installing VSCode & opencode..."
    case "$DISTRO" in
        arch|artix)
            aur visual-studio-code-bin opencode-desktop-bin
            [ "$DISTRO" = "arch" ] && aur code-nautilus-git
            ;;
        debian)
            # MS repo instead of the old hardcoded .deb
            if [ "$DRY_RUN" -eq 1 ]; then
                dry "add Microsoft VSCode apt repo + install code"
            elif ! command_exists code; then
                wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor \
                    | sudo tee /usr/share/keyrings/ms-vscode.gpg >/dev/null
                echo "deb [arch=amd64 signed-by=/usr/share/keyrings/ms-vscode.gpg] https://packages.microsoft.com/repos/code stable main" \
                    | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
                sudo apt update && pi code
            fi
            run_remote_installer "opencode" https://opencode.ai/install bash
            ;;
        fedora)
            if ! command_exists code; then
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
                pi code
            fi
            ;;
        void)
            # Native VSCode tarball into ~/.local/opt (from void-mod); it's a
            # glibc build, so void-musl gets the flatpak like Alpine
            if [ "$LIBC" = "musl" ]; then
                fp com.visualstudio.code
            elif [ "$DRY_RUN" -eq 0 ] && [ ! -x "$HOME/.local/opt/vscode/bin/code" ]; then
                local tmp; tmp=$(mktemp -d)
                if wget -qO "$tmp/vscode.tar.gz" "https://update.code.visualstudio.com/latest/linux-x64/stable"; then
                    mkdir -p "$HOME/.local/opt/vscode" "$HOME/.local/bin"
                    tar -xzf "$tmp/vscode.tar.gz" -C "$HOME/.local/opt/vscode" --strip-components=1
                    ln -sf "$HOME/.local/opt/vscode/bin/code" "$HOME/.local/bin/code"
                fi
                command rm -rf "$tmp"
            fi
            fp ai.opencode.opencode
            ;;
        suse)
            if ! command_exists code; then
                sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                sudo zypper -n addrepo -f https://packages.microsoft.com/yumrepos/vscode vscode 2>/dev/null || true
                pi code
            fi
            run_remote_installer "opencode" https://opencode.ai/install bash
            ;;
        alpine)
            # glibc binaries don't run on musl - use the flatpaks
            fp com.visualstudio.code ai.opencode.opencode
            ;;
    esac
}

_apps_networking() {
    say "Installing Tailscale & Synology Drive..."
    case "$DISTRO" in
        arch|artix)
            pi tailscale || aur tailscale
            aur synology-drive synochat
            ;;
        debian)
            run_remote_installer "tailscale" https://tailscale.com/install.sh
            local deb="synology-drive-client-17885.x86_64.deb" tmp
            tmp=$(mktemp -d)
            wget -q "https://global.download.synology.com/download/Utility/SynologyDriveClient/4.0.1-17885/Ubuntu/Installer/${deb}" -O "$tmp/$deb" \
                && sudo dpkg -i "$tmp/$deb"; sudo apt --fix-broken install -y
            command rm -rf "$tmp"
            ;;
        fedora)
            run_remote_installer "tailscale" https://tailscale.com/install.sh
            sudo dnf copr enable -y emixampp/synology-drive && pi synology-drive
            ;;
        void|alpine)
            pi tailscale
            fp com.synology.SynologyDrive
            ;;
        suse)
            run_remote_installer "tailscale" https://tailscale.com/install.sh
            fp com.synology.SynologyDrive
            ;;
    esac
    svc_enable tailscaled tailscale || true
}

_apps_full_only() {
    say "Installing full-profile extras (docker, clamav, jump)..."
    case "$DISTRO" in
        arch|artix)
            pi docker docker-compose clamav
            svc_enable docker
            # clamd won't start without signatures: fetch them first, then
            # hand updates to the freshclam service
            sudo freshclam 2>/dev/null || warn "freshclam could not fetch ClamAV signatures yet."
            svc_enable clamav-freshclam freshclam
            svc_enable clamav-daemon clamd
            sudo usermod -aG docker "$username" || true
            ;;
        debian)
            pi apt-transport-https ca-certificates curl gnupg lsb-release
            if ! command_exists docker; then
                # Docker publishes Debian and Ubuntu repos; Pop/Mint ride on
                # Ubuntu's codename (Mint's own, e.g. 'wilma', 404s)
                local dist="debian" code="$OS_CODENAME"
                if [ "$OS_ID" != "debian" ]; then
                    dist="ubuntu"; code="${OS_UBUNTU_CODENAME:-$OS_CODENAME}"
                fi
                sudo install -m 0755 -d /etc/apt/keyrings
                curl -fsSL "https://download.docker.com/linux/${dist}/gpg" \
                    | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${dist} ${code} stable" \
                    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
                if sudo apt update; then
                    pi docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                    sudo usermod -aG docker "$username" || true
                else
                    # A dead repo would break every later apt update
                    warn "Docker repo for ${dist}/${code} failed; removing it. Falling back to docker.io."
                    sudo rm -f /etc/apt/sources.list.d/docker.list
                    sudo apt update
                    pi docker.io docker-compose && sudo usermod -aG docker "$username"
                fi
            fi
            run_remote_installer "ollama" https://ollama.com/install.sh
            ;;
        fedora)
            run_remote_installer "ollama" https://ollama.com/install.sh
            ;;
        void)
            # jump CLI via go (from void-mod)
            if ! command_exists jump; then
                pi go && go install github.com/gsamokovarov/jump@latest 2>/dev/null \
                    || warn "jump install failed."
            fi
            ;;
        suse)
            pi docker docker-compose
            svc_enable docker && sudo usermod -aG docker "$username" || true
            run_remote_installer "ollama" https://ollama.com/install.sh
            ;;
        alpine)
            pi docker docker-cli-compose
            svc_enable docker && sudo usermod -aG docker "$username" || true
            ;;
    esac
}

_apps_cleanup() {
    case "$DISTRO" in
        debian)
            sudo apt update; sudo apt upgrade -y; sudo apt full-upgrade -y
            sudo apt install -f -y; sudo dpkg --configure -a
            sudo apt --fix-broken install -y; sudo apt autoremove -y
            ;;
        fedora) sudo dnf autoremove -y ;;
    esac
    flatpak update -y 2>/dev/null || true
}
