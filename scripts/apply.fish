#!/usr/bin/env fish
# Deploy Cae-Mod. Mapa de propiedad: ver docs/OWNERSHIP.md y fork/README.md.
# home/ -> $HOME (propio), system/ -> /etc (propio, sudo),
# fork/ -> upstream modificado (migrar a Brimx/shell, deploy frágil vía sudo a /etc/xdg).
set REPO_DIR (dirname (status dirname))

echo "Deploying configs..."

# Hyprland (fork de caelestia-dots/caelestia rev d459e91 — migrar a hypr-user.lua/hypr-vars.lua)
cp $REPO_DIR/fork/dots-hypr/hyprland.lua ~/.config/hypr/hyprland.lua
cp $REPO_DIR/fork/dots-hypr/variables.lua ~/.config/hypr/variables.lua
cp $REPO_DIR/fork/dots-hypr/animations.lua ~/.config/hypr/hyprland/animations.lua
cp $REPO_DIR/fork/dots-hypr/decoration.lua ~/.config/hypr/hyprland/decoration.lua
cp $REPO_DIR/fork/dots-hypr/env.lua ~/.config/hypr/hyprland/env.lua
cp $REPO_DIR/fork/dots-hypr/execs.lua ~/.config/hypr/hyprland/execs.lua
cp $REPO_DIR/fork/dots-hypr/general.lua ~/.config/hypr/hyprland/general.lua
cp $REPO_DIR/fork/dots-hypr/gestures.lua ~/.config/hypr/hyprland/gestures.lua
cp $REPO_DIR/fork/dots-hypr/group.lua ~/.config/hypr/hyprland/group.lua
cp $REPO_DIR/fork/dots-hypr/input.lua ~/.config/hypr/hyprland/input.lua
cp $REPO_DIR/fork/dots-hypr/keybinds.lua ~/.config/hypr/hyprland/keybinds.lua
cp $REPO_DIR/fork/dots-hypr/misc.lua ~/.config/hypr/hyprland/misc.lua
cp $REPO_DIR/fork/dots-hypr/monitors.lua ~/.config/hypr/hyprland/monitors.lua
cp $REPO_DIR/fork/dots-hypr/rules.lua ~/.config/hypr/hyprland/rules.lua
cp $REPO_DIR/fork/dots-hypr/utils/functions.lua ~/.config/hypr/utils/functions.lua
cp $REPO_DIR/fork/dots-hypr/utils/json.lua ~/.config/hypr/utils/json.lua

# Limpieza de strays legacy (nwg-displays, Nothing shell, hyprmoncfg, backups)
rm -f ~/.config/hypr/monitors.lua ~/.config/hypr/monitors.conf ~/.config/hypr/displays.lua ~/.config/hypr/accent.lua ~/.config/hypr/layout.lua ~/.config/hypr/workspaces.conf ~/.config/hypr/hyprmoncfg-monitors.lua ~/.config/hypr/variables.lua.new ~/.config/hypr/hyprland/*.new

# Caelestia (propio)
cp $REPO_DIR/home/caelestia/shell.json ~/.config/caelestia/shell.json

# Fish (copia upstream + paths — migrar a ~/.config/caelestia/user-config.fish)
cp $REPO_DIR/home/fish/config.fish ~/.config/fish/config.fish

# Systemd user (propio)
cp $REPO_DIR/home/systemd/user/trackpad-gestures.service ~/.config/systemd/user/trackpad-gestures.service
cp $REPO_DIR/home/systemd/user/bezel.service ~/.config/systemd/user/bezel.service
cp $REPO_DIR/home/systemd/user/taps-center.service ~/.config/systemd/user/taps-center.service
cp $REPO_DIR/home/systemd/user/trackpad-edges.service ~/.config/systemd/user/trackpad-edges.service
cp $REPO_DIR/home/systemd/user/audio-inhibit.service ~/.config/systemd/user/audio-inhibit.service
cp $REPO_DIR/home/systemd/user/monitor-watch.service ~/.config/systemd/user/monitor-watch.service
systemctl --user daemon-reload
# bezel/taps-center/trackpad-edges retirados 2026-09-30 (ver trackpad-gestures)
for s in bezel taps-center trackpad-edges
    systemctl --user stop $s.service; or true
    systemctl --user disable $s.service; or true
end
systemctl --user enable --now trackpad-gestures.service audio-inhibit.service monitor-watch.service

# rclone: disco virtual bajo demanda (Santi: -> ~/Drive) + backup diario a Santi:Backup
cp $REPO_DIR/home/systemd/user/rclone-drive.service ~/.config/systemd/user/rclone-drive.service
cp $REPO_DIR/home/systemd/user/rclone-backup.service ~/.config/systemd/user/rclone-backup.service
cp $REPO_DIR/home/systemd/user/rclone-backup.timer ~/.config/systemd/user/rclone-backup.timer
mkdir -p ~/Drive
# Config del backup: no pisar la del usuario si ya existe
mkdir -p ~/.config/rclone-backup
if not test -f ~/.config/rclone-backup/config
    cp $REPO_DIR/home/rclone-backup/config ~/.config/rclone-backup/config
end
systemctl --user daemon-reload
# Mount bajo demanda (no al login): se usa con `rclone-drive on|off|status`.
# Mantenerlo montado hace que Thunar se bloquee al abrir el bookmark, porque
# listar carpetas grandes de Drive puede tardar >30 s.
systemctl --user disable rclone-drive.service; or true
systemctl --user enable rclone-backup.timer
# Bookmark de Thunar/GTK (idempotente)
for gtk in gtk-3.0 gtk-4.0
    mkdir -p ~/.config/$gtk
    grep -qxF "file://$HOME/Drive" ~/.config/$gtk/bookmarks 2>/dev/null; or echo "file://$HOME/Drive" >> ~/.config/$gtk/bookmarks
end

# Audio (WirePlumber: anti-stutter + auto-switch jack, propio)
mkdir -p ~/.config/wireplumber/wireplumber.conf.d
cp $REPO_DIR/home/wireplumber/wireplumber.conf.d/*.conf ~/.config/wireplumber/wireplumber.conf.d/

# Scripts (propios)
# NOTA: con "/." se fusiona el contenido (evita anidar overview/overview
# cuando el destino ya existe).
rm -rf ~/.config/quickshell/overview/overview
cp -rf $REPO_DIR/home/quickshell/overview/. ~/.config/quickshell/overview/
# Limpieza del clip-picker standalone (porteado al drawer, ver fork/shell/modules/clipboard/)
rm -rf ~/.config/quickshell/clip-picker
cp $REPO_DIR/scripts/trackpad-gestures.py ~/.local/bin/trackpad-gestures.py
cp $REPO_DIR/scripts/audio-inhibit.py ~/.local/bin/audio-inhibit.py
cp $REPO_DIR/scripts/monitor-watch.py ~/.local/bin/monitor-watch.py
cp $REPO_DIR/scripts/clipboard-actions.sh ~/.local/bin/clipboard-actions.sh
cp $REPO_DIR/scripts/emoji-actions.sh ~/.local/bin/emoji-actions.sh
cp $REPO_DIR/scripts/build-emoji-json.py ~/.local/bin/build-emoji-json.py
cp $REPO_DIR/scripts/ocr.sh ~/.local/bin/ocr.sh
cp $REPO_DIR/scripts/rclone-backup.sh ~/.local/bin/rclone-backup.sh
chmod 755 ~/.local/bin/rclone-backup.sh
cp $REPO_DIR/scripts/rclone-drive.sh ~/.local/bin/rclone-drive
chmod 755 ~/.local/bin/rclone-drive
cp $REPO_DIR/scripts/rclone-backup-tui.sh ~/.local/bin/rclone-sync
chmod 755 ~/.local/bin/rclone-sync
# Regenera el JSON categorizado (best-effort: sin red conserva el existente)
python3 ~/.local/bin/build-emoji-json.py; or true

# Fork shell (sudo, frágil — migrar a Brimx/shell clonado en ~/.config/quickshell/caelestia/)
echo "Deploying fork shell (sudo, ver fork/README.md)..."
sudo cp $REPO_DIR/fork/shell/components/ScreenState.qml /etc/xdg/quickshell/caelestia/components/ScreenState.qml
sudo cp $REPO_DIR/fork/shell/modules/Shortcuts.qml /etc/xdg/quickshell/caelestia/modules/Shortcuts.qml
sudo cp $REPO_DIR/fork/shell/modules/drawers/Panels.qml /etc/xdg/quickshell/caelestia/modules/drawers/Panels.qml
sudo cp $REPO_DIR/fork/shell/modules/drawers/ContentWindow.qml /etc/xdg/quickshell/caelestia/modules/drawers/ContentWindow.qml
sudo cp $REPO_DIR/fork/shell/modules/drawers/Regions.qml /etc/xdg/quickshell/caelestia/modules/drawers/Regions.qml
sudo mkdir -p /etc/xdg/quickshell/caelestia/modules/clipboard/items /etc/xdg/quickshell/caelestia/modules/clipboard/services /etc/xdg/quickshell/caelestia/modules/clipboard/scripts
# Drawer porteado de clip-picker (riadloukili rev d25ba94 → fork/shell/modules/clipboard/).
# Backup del drawer simple anterior: fork/shell/modules.clipboard-simple-backup/ (no se deploya).
sudo cp $REPO_DIR/fork/shell/modules/clipboard/Wrapper.qml /etc/xdg/quickshell/caelestia/modules/clipboard/Wrapper.qml
sudo cp $REPO_DIR/fork/shell/modules/clipboard/Content.qml /etc/xdg/quickshell/caelestia/modules/clipboard/Content.qml
sudo cp $REPO_DIR/fork/shell/modules/clipboard/ClipboardList.qml /etc/xdg/quickshell/caelestia/modules/clipboard/ClipboardList.qml
sudo cp $REPO_DIR/fork/shell/modules/clipboard/Preview.qml /etc/xdg/quickshell/caelestia/modules/clipboard/Preview.qml
sudo cp $REPO_DIR/fork/shell/modules/clipboard/HelpBar.qml /etc/xdg/quickshell/caelestia/modules/clipboard/HelpBar.qml
sudo cp $REPO_DIR/fork/shell/modules/clipboard/KeyCap.qml /etc/xdg/quickshell/caelestia/modules/clipboard/KeyCap.qml
sudo cp $REPO_DIR/fork/shell/modules/clipboard/LinkMenu.qml /etc/xdg/quickshell/caelestia/modules/clipboard/LinkMenu.qml
sudo cp $REPO_DIR/fork/shell/modules/clipboard/PickerSearchBar.qml /etc/xdg/quickshell/caelestia/modules/clipboard/PickerSearchBar.qml
sudo cp $REPO_DIR/fork/shell/modules/clipboard/items/ClipItem.qml /etc/xdg/quickshell/caelestia/modules/clipboard/items/ClipItem.qml
sudo rm -f /etc/xdg/quickshell/caelestia/modules/clipboard/items/ClipboardItem.qml
sudo cp $REPO_DIR/fork/shell/modules/clipboard/services/Cliphist.qml /etc/xdg/quickshell/caelestia/modules/clipboard/services/Cliphist.qml
sudo cp $REPO_DIR/fork/shell/modules/clipboard/services/ClipboardConfig.qml /etc/xdg/quickshell/caelestia/modules/clipboard/services/ClipboardConfig.qml
sudo cp $REPO_DIR/fork/shell/modules/clipboard/scripts/fzf.js /etc/xdg/quickshell/caelestia/modules/clipboard/scripts/fzf.js
sudo cp $REPO_DIR/fork/shell/modules/clipboard/scripts/markup.js /etc/xdg/quickshell/caelestia/modules/clipboard/scripts/markup.js
sudo mkdir -p /etc/xdg/quickshell/caelestia/modules/emoji/items /etc/xdg/quickshell/caelestia/modules/emoji/services /etc/xdg/quickshell/caelestia/modules/emoji/scripts
sudo cp $REPO_DIR/fork/shell/modules/emoji/Wrapper.qml /etc/xdg/quickshell/caelestia/modules/emoji/Wrapper.qml
sudo cp $REPO_DIR/fork/shell/modules/emoji/Content.qml /etc/xdg/quickshell/caelestia/modules/emoji/Content.qml
sudo cp $REPO_DIR/fork/shell/modules/emoji/EmojiGrid.qml /etc/xdg/quickshell/caelestia/modules/emoji/EmojiGrid.qml
sudo cp $REPO_DIR/fork/shell/modules/emoji/items/EmojiCell.qml /etc/xdg/quickshell/caelestia/modules/emoji/items/EmojiCell.qml
sudo cp $REPO_DIR/fork/shell/modules/emoji/services/Emoji.qml /etc/xdg/quickshell/caelestia/modules/emoji/services/Emoji.qml
sudo cp $REPO_DIR/fork/shell/modules/clipboard/scripts/fzf.js /etc/xdg/quickshell/caelestia/modules/emoji/scripts/fzf.js
sudo cp $REPO_DIR/fork/shell/modules/bar/popouts/BatteryConservation.qml /etc/xdg/quickshell/caelestia/modules/bar/popouts/BatteryConservation.qml
sudo cp $REPO_DIR/fork/shell/modules/bar/popouts/Battery.qml /etc/xdg/quickshell/caelestia/modules/bar/popouts/Battery.qml
sudo cp $REPO_DIR/fork/shell/modules/dashboard/dash/Media.qml /etc/xdg/quickshell/caelestia/modules/dashboard/dash/Media.qml
sudo cp $REPO_DIR/fork/shell/modules/dashboard/Media.qml /etc/xdg/quickshell/caelestia/modules/dashboard/Media.qml
sudo cp $REPO_DIR/fork/shell/modules/dashboard/media/CoverVisualiser.qml /etc/xdg/quickshell/caelestia/modules/dashboard/media/CoverVisualiser.qml
sudo cp $REPO_DIR/fork/shell/modules/dashboard/media/Details.qml /etc/xdg/quickshell/caelestia/modules/dashboard/media/Details.qml
sudo cp $REPO_DIR/fork/shell/modules/dashboard/media/LyricsAndSelector.qml /etc/xdg/quickshell/caelestia/modules/dashboard/media/LyricsAndSelector.qml
sudo cp $REPO_DIR/fork/shell/services/Players.qml /etc/xdg/quickshell/caelestia/services/Players.qml
sudo cp $REPO_DIR/fork/shell/components/images/FadeImage.qml /etc/xdg/quickshell/caelestia/components/images/FadeImage.qml
sudo cp $REPO_DIR/fork/shell/components/widgets/CoverArt.qml /etc/xdg/quickshell/caelestia/components/widgets/CoverArt.qml
sudo cp $REPO_DIR/fork/shell/modules/lock/Media.qml /etc/xdg/quickshell/caelestia/modules/lock/Media.qml
# System (propio, sudo)
echo "Deploying system (sudo)..."
sudo cp $REPO_DIR/system/sddm.conf /etc/sddm.conf
sudo cp $REPO_DIR/system/keyd/default.conf /etc/keyd/default.conf
sudo cp $REPO_DIR/system/pipewire/pipewire.conf.d/fix-audio.conf /etc/pipewire/pipewire.conf.d/fix-audio.conf
sudo mkdir -p /etc/modprobe.d
sudo cp $REPO_DIR/system/modprobe.d/*.conf /etc/modprobe.d/
sudo cp $REPO_DIR/system/firmware/alc294-asus-fix.fw /lib/firmware/alc294-asus-fix.fw
# NOTE: /etc/mkinitcpio.conf FILES=() debe incluir alc294-asus-fix.fw para
# que el patch aplique en early boot. Revisar a mano y luego: sudo mkinitcpio -P
sudo mkdir -p /etc/asusd
# Preservar límite de batería vivo (asusctl/EC) para que el deploy no lo pise:
# el patch trae 80, pero si el usuario está en 100 lo restauramos tras copiar.
set SAVED_LIMIT (asusctl battery info 2>/dev/null | grep -oE '[0-9]+%' | tr -d '%' | tail -n 1)
if test -z "$SAVED_LIMIT"
    set SAVED_LIMIT 80
end
echo "Battery limit vivo: $SAVED_LIMIT% (se restaurará tras deploy)"
sudo cp $REPO_DIR/system/asusd/asusd.ron /etc/asusd/asusd.ron
sudo systemctl try-restart asusd
sleep 2
asusctl battery limit $SAVED_LIMIT 2>/dev/null; or true
echo "Battery limit restaurado a: "(asusctl battery info 2>/dev/null | grep -oE '[0-9]+%' | tail -n 1)

# Turbo guard: no_turbo=1 con bateria + perfil de ahorro, por eventos (D-Bus + udev)
sudo install -Dm755 $REPO_DIR/system/asus-turbo-guard/asus-turbo-guard.sh /usr/local/bin/asus-turbo-guard.sh
sudo install -Dm644 $REPO_DIR/system/asus-turbo-guard/asus-turbo-guard.service /etc/systemd/system/asus-turbo-guard.service
sudo systemctl daemon-reload
sudo systemctl enable --now asus-turbo-guard.service

# Reiniciar servidor de audio si cambió
systemctl --user try-restart pipewire wireplumber
