#!/bin/bash

# https://github.com/Piercing666

# Check if running as root. If root, script will exit
if [[ $EUID -eq 0 ]]; then
    echo "This script should not be executed as root! Exiting......."
    exit 1
fi




# Customizations
gsettings set org.gnome.desktop.interface clock-format 24h && echo "Clock Format: 24h"
gsettings set org.gnome.desktop.interface clock-show-weekday true && echo "Clock Show Weekday: True"
gsettings set org.gnome.desktop.peripherals.keyboard numlock-state true && echo "Numlock State: True"
gsettings set org.gnome.desktop.input-sources xkb-options "['caps:backspace']" && echo "Caps Lock: Backspace"
gsettings set org.gnome.desktop.peripherals.mouse.speed "0.11790393013100431"
gsettings set org.gnome.desktop.peripherals.mouse.accel-profile "'flat'"
gsettings set org.gnome.desktop.interface color-scheme prefer-dark && echo "Color Scheme: Dark"
gsettings set org.gnome.desktop.session idle-delay 0 && echo "Lock Screen Idle: 20"
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' && echo "Sleep Inactive AC: Nothing"
gsettings set org.gnome.desktop.interface show-battery-percentage true && echo "Show Battery Percentage: True"
gsettings set org.gnome.settings-daemon.plugins.power ambient-enabled false && echo "Ambient Enabled: False"
gsettings set org.gnome.settings-daemon.plugins.power idle-delay "unit32 900" && echo "Idle Delay: 15 minutes"
gsettings set org.gnome.desktop.interface enable-hot-corners false && echo "Enable Hot Corners: False"
gsettings set org.gnome.desktop.background picture-options 'spanned' && echo "Background Options: Spanned"
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true && echo "Night Light Enabled: True"
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-automatic false && echo "Night Light Schedule Automatic: False"
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-from 20 && echo "Night Light Schedule From: 20"
gsettings set org.gnome.settings-daemon.plugins.color night-light-schedule-to 04 && echo "Night Light Schedule To: 04"
gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 2500 && echo "Night Light Temperature: 2500"
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/']" && echo "Custom Keybindings: None"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ name "kitty" && echo "Kitty: Name"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ command "kitty" && echo "Kitty: Command"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding "<Super>W" && echo "Kitty: Binding"
gsettings set org.gnome.desktop.wm.keybindings close "['<Super>Q']" && echo "Super Q to Close"
gsettings set org.gnome.mutter.wayland.keybindings.restore-shortcuts "['']" 
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true && echo "Tap to Click: True"
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true && echo "Natural Scroll: True"
gsettings set org.gnome.desktop.peripherals.touchpad click-method 'areas' && echo "Click Method: Areas"
gsettings set org.gnome.settings-daemon.plugins.power power-button-action 'interactive' && echo "Power Button Action: Interactive"
gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark && echo "GTK Theme: Adwaita-dark"
gsettings set org.gnome.desktop.interface cursor-theme 'Nordzy-cursors' && echo "Cursor Theme: Nordzy"
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' && echo "Icon Theme: Papirus-Dark"
gsettings set org.gnome.shell favorite-apps "['org.mozilla.firefox.desktop', 'com.google.Chrome.desktop', 'org.gnome.Nautilus.desktop', 'org.libreoffice.LibreOffice.writer.desktop', 'org.gnome.Calculator.desktop', 'md.obsidian.Obsidian.desktop', 'com.visualstudio.code.desktop', 'code.desktop', 'synochat.desktop', 'org.gimp.GIMP.desktop', 'org.blender.Blender.desktop']" && echo "Favorite Apps: Chrome, Nautilus, LibreOffice, Calculator, Obsidian, VSCode, Discord, Gimp"
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal kitty
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal new-tab true
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal flatpak system
gnome-extensions enable ubuntu-appindicators@ubuntu.com && echo "App Indicator: Enabled"
gnome-extensions enable gsconnect@andyholmes.github.io && echo "GSConnect: Enabled"
gnome-extensions enable awesome-tiles@velitasali.com && echo "Awesome Tiles: Enabled"
gnome-extensions enable aztaskbar@aztaskbar.gitlab.com && echo "AzTaskbar: Enabled"
gnome-extensions enable blur-my-shell@aunetx && echo "Blur My Shell: Enabled"
gnome-extensions enable caffeine@patapon.info && echo "Caffeine: Enabled"
gnome-extensions enable just-perfection-desktop@just-perfection && echo "Just Perfection: Enabled"
gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com
gnome-extensions enable forge@jmmaranan.com
gnome-extensions disable background-logo@fedorahosted.org 
dconf write /org/gnome/shell/extensions/just-perfection/dash-icon-size "48" && echo "Just Perfection Dash Icon Size: 48"
dconf write /org/gnome/shell/extensions/just-perfection/animation "3" && echo "Just Perfection Animation: 3"
dconf write /org/gnome/shell/extensions/just-perfection/startup-status "0" && echo "Just Perfection Startup Status: 0"
dconf write /org/gnome/shell/extensions/just-perfection/app-menu-icon "false" && echo "Just Perfection App Menu Icon: False"
dconf write /org/gnome/shell/extensions/just-perfection/activities-button "false" && echo "Just Perfection Activities Button: False"
dconf write /org/gnome/shell/extensions/just-perfection/app-menu "false" && echo "Just Perfection App Menu: False"
dconf write /org/gnome/shell/extensions/just-perfection/app-menu-label "false" && echo "Just Perfection App Menu Label: False"
dconf write /org/gnome/shell/extensions/just-perfection/search "false" && echo "Just Perfection Search: False"
dconf write /org/gnome/shell/extensions/just-perfection/theme "true" && echo "Just Perfection Theme: True"
dconf write /org/gnome/shell/extensions/caffeine/duration-timer "4" && echo "Caffeine Duration Timer: 4"
dconf write /org/gnome/shell/extensions/awesome-tiles/gap-size-increments "1" && echo "Awesome Tiles Gap Size Increments: 1"
dconf write /org/gnome/shell/extensions/aztaskbar/favorites "false" && echo "AzTaskbar Favorites: False"
dconf write /org/gnome/shell/extensions/aztaskbar/main-panel-height "33" && echo "AzTaskbar Main Panel Height: 33"
dconf write /org/gnome/shell/extensions/aztaskbar/panel-on-all-monitors "false"
dconf write /org/gnome/shell/extensions/aztaskbar/show-panel-activities-button "false" && echo "AzTaskbar Show Panel Activities Button: False"
dconf write /org/gnome/shell/extensions/aztaskbar/icon-size "23" && echo "AzTaskbar Icon Size: 23"
dconf write /org/gnome/shell/extensions/blur-my-shell/brightness "1.0" && echo "Blur My Shell Brightness: 1.0"
dconf write /org/gnome/shell/extensions/aztaskbar/indicator-color-focused "'rgb(246,148,255)'"
dconf write /org/gnome/shell/extensions/aztaskbar/indicator-color-running "'rgb(130,226,255)'"
dconf write /org/gnome/desktop/interface/font-name 'MesloLGSDZ Nerd Font 11'
dconf write /org/gnome/desktop/interface/document-font-name 'FiraCode Nerd Font 11'
dconf write /org/gnome/desktop/interface/monospace-font-name 'Terminus (TTF) Medium 12'
dconf write /org/gnome/desktop/wm/preferences/button-layout 'appmenu:close'
dconf write /org/gnome/system/location/enabled 'false'
dconf write /org/gnome/desktop/privacy/report-technical-problems 'false'
dconf write /org/gnome/desktop/wm/preferences/focus-mode 'mouse'
dconf write /org/gnome/desktop/peripherals/touchpad/accel-profile 'flat'
dconf write /org/gnome/desktop/interface/icon-theme 'Papirus'
dconf write /org/gnome/shell/extensions/forge/move-pointer-focus-enabled 'true'


/org/gnome/shell/extensions/space-bar/shortcuts/open-menu
  @as []

/org/gnome/shell/extensions/space-bar/shortcuts/enable-move-to-workspace-shortcuts
  true

/org/gnome/desktop/wm/keybindings/move-to-workspace-1
  ['<Super><Shift>1']

/org/gnome/desktop/wm/keybindings/move-to-workspace-10
  ['<Super><Shift>0']
/org/gnome/desktop/wm/keybindings/move-to-workspace-2
  ['<Super><Shift>2']
/org/gnome/desktop/wm/keybindings/move-to-workspace-3
  ['<Super><Shift>3']
/org/gnome/desktop/wm/keybindings/move-to-workspace-4
  ['<Super><Shift>4']
/org/gnome/desktop/wm/keybindings/move-to-workspace-5
  ['<Super><Shift>5']
/org/gnome/desktop/wm/keybindings/move-to-workspace-6
  ['<Super><Shift>6']
/org/gnome/desktop/wm/keybindings/move-to-workspace-7
  ['<Super><Shift>7']
/org/gnome/desktop/wm/keybindings/move-to-workspace-8
  ['<Super><Shift>8']
/org/gnome/desktop/wm/keybindings/move-to-workspace-9
  ['<Super><Shift>9']

/org/gnome/shell/extensions/space-bar/behavior/show-empty-workspaces
  false
  /org/gnome/shell/extensions/space-bar/behavior/toggle-overview
  false

  
/org/gnome/shell/extensions/forge/stacked-tiling-mode-enabled
  false

/org/gnome/shell/extensions/forge/tabbed-tiling-mode-enabled
  false

/org/gnome/shell/extensions/forge/preview-hint-enabled
  false


  /org/gnome/shell/extensions/forge/window-gap-size
  uint32 7



/org/gtk/gtk4/settings/color-chooser/selected-color
  (true, 1.0, 1.0, 1.0, 1.0)

/org/gtk/gtk4/settings/color-chooser/custom-colors
  [(0.92549020051956177, 0.36862745881080627, 0.36862745881080627, 1.0)]
/org/gtk/gtk4/settings/color-chooser/selected-color
  (true, 0.92549020051956177, 0.36862745881080627, 0.36862745881080627, 1.0)

/org/gtk/gtk4/settings/color-chooser/selected-color
  (true, 1.0, 1.0, 1.0, 1.0)

/org/gnome/shell/extensions/forge/css-updated
  '1740018402267'

/org/gnome/shell/extensions/forge/css-updated
  '1740018402273'

/org/gnome/shell/extensions/forge/css-updated
  '1740018406352'

/org/gtk/gtk4/settings/color-chooser/custom-colors
  [(0.066666670143604279, 0.78039216995239258, 0.87843137979507446, 1.0), (0.92549020051956177, 0.36862745881080627, 0.36862745881080627, 1.0)]
/org/gtk/gtk4/settings/color-chooser/selected-color
  (true, 0.066666670143604279, 0.78039216995239258, 0.87843137979507446, 1.0)

/org/gtk/gtk4/settings/color-chooser/selected-color
  (true, 1.0, 1.0, 1.0, 1.0)

/org/gnome/shell/extensions/forge/css-updated
  '1740018418899'

/org/gnome/shell/extensions/forge/css-updated
  '1740018418906'

/org/gnome/shell/extensions/forge/css-updated
  '1740018418912'

/org/gnome/shell/extensions/forge/css-updated
  '1740018420643'

/org/gtk/gtk4/settings/color-chooser/custom-colors
  [(0.9686274528503418, 0.63529413938522339, 0.16862745583057404, 1.0), (0.066666670143604279, 0.78039216995239258, 0.87843137979507446, 1.0), (0.92549020051956177, 0.36862745881080627, 0.36862745881080627, 1.0)]
/org/gtk/gtk4/settings/color-chooser/selected-color
  (true, 0.9686274528503418, 0.63529413938522339, 0.16862745583057404, 1.0)

/org/gtk/gtk4/settings/color-chooser/selected-color
  (true, 1.0, 1.0, 1.0, 1.0)

/org/gnome/shell/extensions/forge/css-updated
  '1740018423629'

/org/gnome/shell/extensions/forge/css-updated
  '1740018423636'

/org/gnome/shell/extensions/forge/css-updated
  '1740018425890'

/org/gtk/gtk4/settings/color-chooser/custom-colors
  [(0.70588237047195435, 0.65490198135375977, 0.83921569585800171, 1.0), (0.9686274528503418, 0.63529413938522339, 0.16862745583057404, 1.0), (0.066666670143604279, 0.78039216995239258, 0.87843137979507446, 1.0), (0.92549020051956177, 0.36862745881080627, 0.36862745881080627, 1.0)]
/org/gtk/gtk4/settings/color-chooser/selected-color
  (true, 0.70588237047195435, 0.65490198135375977, 0.83921569585800171, 1.0)

/org/gtk/gtk4/settings/color-chooser/selected-color
  (true, 1.0, 1.0, 1.0, 1.0)

/org/gnome/shell/extensions/forge/css-updated
  '1740018430865'

/org/gnome/shell/extensions/forge/css-updated
  '1740018433128'

/org/gtk/gtk4/settings/color-chooser/custom-colors
  [(1.0, 0.96470588445663452, 0.42352941632270813, 1.0), (0.70588237047195435, 0.65490198135375977, 0.83921569585800171, 1.0), (0.9686274528503418, 0.63529413938522339, 0.16862745583057404, 1.0), (0.066666670143604279, 0.78039216995239258, 0.87843137979507446, 1.0), (0.92549020051956177, 0.36862745881080627, 0.36862745881080627, 1.0)]
/org/gtk/gtk4/settings/color-chooser/selected-color
  (true, 1.0, 0.96470588445663452, 0.42352941632270813, 1.0)

/org/gtk/gtk4/settings/color-chooser/selected-color
  (true, 1.0, 1.0, 1.0, 1.0)

/org/gnome/shell/extensions/forge/css-updated
  '1740018465757'

/org/gnome/shell/extensions/forge/css-updated
  '1740018466910'


/org/gnome/shell/extensions/forge/keybindings/prefs-open
  @as []
