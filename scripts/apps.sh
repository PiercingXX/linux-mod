#!/bin/bash
# https://github.com/Piercingxx

username=$(id -u -n 1000)
builddir=$(pwd)

# Installing important things && stuff && some dependencies
    sudo dnf install typescript -y
    sudo dnf install gnome-tweaks -y
    sudo dnf install papirus-icon-theme -y
    sudo dnf install qbittorrent -y
    flatpak install flathub net.waterfox.waterfox -y
    flatpak install flathub md.obsidian.Obsidian -y
    flatpak install flathub org.libreoffice.LibreOffice -y
    flatpak install https://flathub.org/beta-repo/appstream/org.gimp.GIMP.flatpakref -y
    flatpak install flathub org.darktable.Darktable -y
    flatpak install flathub org.gnome.SimpleScan -y
    flatpak install flathub org.blender.Blender -y
    flatpak install flathub com.mattjakeman.ExtensionManager -y
    flatpak install flathub org.qbittorrent.qBittorrent -y
    flatpak install flathub io.missioncenter.MissionCenter -y
    flatpak install flathub org.kde.kdenlive -y
    flatpak install flathub io.github.shiftey.Desktop -y
    flatpak install flathub com.discordapp.Discord -y
    flatpak install --noninteractive flathub io.github.realmazharhussain.GdmSettings -y
    flatpak install flathub com.flashforge.FlashPrint -y
    flatpak install flathub com.synology.synology-note-station -y

# Install pipx for gnome-extensions-cli
    sudo dnf install pipx -y
    pipx ensurepath

# Install Gnome-extensions-cli
    pipx install gnome-extensions-cli --system-site-packages

# Synology Drive
    sudo dnf copr enable emixampp/synology-drive -y
    sudo dnf update -y
    sudo dnf install synology-drive -y
    #flatpak install flathub com.synology.SynologyDrive -y

# Synology Chat
    wget  'https://global.synologydownload.com/download/Utility/ChatClient/1.2.3-0232/Ubuntu/x86_64/Synology%20Chat%20Client-1.2.3-0232.deb?model=DS223j&bays=2&dsm_version=7.2.2&build_number=72806'

# Install Yazi
    sudo dnf copr enable lihaohong/yazi -y
    sudo dnf update -y
    dnf install yazi -y

# Nvim & Depends
    sudo dnf install neovim -y
    sudo dnf install luarocks -y
    sudo dnf install python3-pip -y
    sudo dnf copr enable atim/lazygit -y
    sudo dnf update -y
    sudo dnf install lazygit -y
    sudo dnf install pdflatex -y
    sudo dnf install sqlite3 -y
    sudo npm install -g @mermaid-js/mermaid-cli
    sudo npm install -g neovim
    python3 -m pip install --user --upgrade pynvim
    # Add Yazi COPR and install
    sudo dnf copr enable lihaohong/yazi -y
    sudo dnf install yazi -y

# VScode
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
    dnf check-update -y
    sudo dnf install code -y

# Ventoy
    sudo dnf copr enable karlisk/ventoy -y
    sudo dnf update -y
    sudo dnf install ventoy -y

# Ollama
    curl -fsSL https://ollama.com/install.sh | sh
    #ollama pull codellama:latest
    #ollama pull gemma3:12b
    #ollama pull gemma3n:latest

# Tailscale
    curl -fsSL https://tailscale.com/install.sh | sh
    wait

# Overkill is underrated.
    sudo dnf update -y
    wait
    dnf autoremove -y
    flatpak update -y