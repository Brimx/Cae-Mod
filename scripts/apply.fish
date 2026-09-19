#!/usr/bin/env fish
set REPO_DIR (dirname (status dirname))

echo "Deploying configs..."

# Hyprland
cp $REPO_DIR/config/hypr/variables.lua ~/.config/hypr/variables.lua
cp $REPO_DIR/config/hypr/animations.lua ~/.config/hypr/hyprland/animations.lua
cp $REPO_DIR/config/hypr/decoration.lua ~/.config/hypr/hyprland/decoration.lua
cp $REPO_DIR/config/hypr/env.lua ~/.config/hypr/hyprland/env.lua
cp $REPO_DIR/config/hypr/execs.lua ~/.config/hypr/hyprland/execs.lua
cp $REPO_DIR/config/hypr/general.lua ~/.config/hypr/hyprland/general.lua
cp $REPO_DIR/config/hypr/gestures.lua ~/.config/hypr/hyprland/gestures.lua
cp $REPO_DIR/config/hypr/group.lua ~/.config/hypr/hyprland/group.lua
cp $REPO_DIR/config/hypr/input.lua ~/.config/hypr/hyprland/input.lua
cp $REPO_DIR/config/hypr/keybinds.lua ~/.config/hypr/hyprland/keybinds.lua
cp $REPO_DIR/config/hypr/misc.lua ~/.config/hypr/hyprland/misc.lua
cp $REPO_DIR/config/hypr/monitors.lua ~/.config/hypr/hyprland/monitors.lua
cp $REPO_DIR/config/hypr/rules.lua ~/.config/hypr/hyprland/rules.lua
cp $REPO_DIR/config/hypr/utils/functions.lua ~/.config/hypr/utils/functions.lua
cp $REPO_DIR/config/hypr/utils/json.lua ~/.config/hypr/utils/json.lua

# Caelestia
cp $REPO_DIR/config/caelestia/shell.json ~/.config/caelestia/shell.json

# Fish
cp $REPO_DIR/config/fish/config.fish ~/.config/fish/config.fish

# Systemd user
cp $REPO_DIR/config/systemd/user/trackpad-edges.service ~/.config/systemd/user/trackpad-edges.service

# Audio (WirePlumber: anti-stutter + auto-switch jack)
mkdir -p ~/.config/wireplumber/wireplumber.conf.d
cp $REPO_DIR/config/wireplumber/wireplumber.conf.d/*.conf ~/.config/wireplumber/wireplumber.conf.d/

# Scripts
cp -r $REPO_DIR/config/quickshell/overview ~/.config/quickshell/overview
cp $REPO_DIR/scripts/trackpad-edges.py ~/.local/bin/trackpad-edges.py

# Patches (sudo)
echo "Deploying system patches (sudo)..."
sudo cp $REPO_DIR/patches/components/ScreenState.qml /etc/xdg/quickshell/caelestia/components/ScreenState.qml
sudo cp $REPO_DIR/patches/modules/Shortcuts.qml /etc/xdg/quickshell/caelestia/modules/Shortcuts.qml
sudo cp $REPO_DIR/patches/modules/drawers/Panels.qml /etc/xdg/quickshell/caelestia/modules/drawers/Panels.qml
sudo cp $REPO_DIR/patches/modules/bar/popouts/BatteryConservation.qml /etc/xdg/quickshell/caelestia/modules/bar/popouts/BatteryConservation.qml
sudo cp $REPO_DIR/patches/modules/bar/popouts/Battery.qml /etc/xdg/quickshell/caelestia/modules/bar/popouts/Battery.qml
sudo cp $REPO_DIR/patches/modules/dashboard/dash/Media.qml /etc/xdg/quickshell/caelestia/modules/dashboard/dash/Media.qml
sudo cp $REPO_DIR/patches/modules/dashboard/Media.qml /etc/xdg/quickshell/caelestia/modules/dashboard/Media.qml
sudo cp $REPO_DIR/patches/modules/dashboard/media/CoverVisualiser.qml /etc/xdg/quickshell/caelestia/modules/dashboard/media/CoverVisualiser.qml
sudo cp $REPO_DIR/patches/modules/dashboard/media/LyricsAndSelector.qml /etc/xdg/quickshell/caelestia/modules/dashboard/media/LyricsAndSelector.qml
sudo cp $REPO_DIR/patches/services/Players.qml /etc/xdg/quickshell/caelestia/services/Players.qml
sudo cp $REPO_DIR/patches/components/images/FadeImage.qml /etc/xdg/quickshell/caelestia/components/images/FadeImage.qml
sudo cp $REPO_DIR/patches/components/widgets/CoverArt.qml /etc/xdg/quickshell/caelestia/components/widgets/CoverArt.qml
sudo cp $REPO_DIR/patches/modules/lock/Media.qml /etc/xdg/quickshell/caelestia/modules/lock/Media.qml
sudo cp $REPO_DIR/patches/sddm.conf /etc/sddm.conf
sudo cp $REPO_DIR/patches/keyd/default.conf /etc/keyd/default.conf
sudo cp $REPO_DIR/patches/pipewire/pipewire.conf.d/fix-audio.conf /etc/pipewire/pipewire.conf.d/fix-audio.conf
sudo mkdir -p /etc/modprobe.d
sudo cp $REPO_DIR/patches/modprobe.d/*.conf /etc/modprobe.d/
sudo cp $REPO_DIR/patches/firmware/alc294-asus-fix.fw /lib/firmware/alc294-asus-fix.fw
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
sudo cp $REPO_DIR/patches/asusd/asusd.ron /etc/asusd/asusd.ron
sudo systemctl try-restart asusd
sleep 2
asusctl battery limit $SAVED_LIMIT 2>/dev/null; or true
echo "Battery limit restaurado a: "(asusctl battery info 2>/dev/null | grep -oE '[0-9]+%' | tail -n 1)

# Reiniciar servidor de audio si cambió
systemctl --user try-restart pipewire wireplumber


