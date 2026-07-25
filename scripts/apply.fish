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

# Scripts
cp $REPO_DIR/scripts/trackpad-edges.py ~/.local/bin/trackpad-edges.py

# Patches (sudo)
echo "Deploying system patches (sudo)..."
sudo cp $REPO_DIR/patches/modules/IdleMonitors.qml /etc/xdg/quickshell/caelestia/modules/IdleMonitors.qml
sudo cp $REPO_DIR/patches/modules/bar/popouts/BatteryConservation.qml /etc/xdg/quickshell/caelestia/modules/bar/popouts/BatteryConservation.qml
sudo cp $REPO_DIR/patches/modules/bar/popouts/Battery.qml /etc/xdg/quickshell/caelestia/modules/bar/popouts/Battery.qml
sudo cp $REPO_DIR/patches/sddm.conf /etc/sddm.conf
sudo cp $REPO_DIR/patches/keyd/default.conf /etc/keyd/default.conf

# Quickshell widgets
cp -r $REPO_DIR/config/quickshell/widgets/* ~/.config/quickshell/widgets/

# GPU plugin fix (Intel Arc xe driver)
echo "Do you want to build and install the GPU xe driver fix? (y/N)"
read -l answer
if test "$answer" = y -o "$answer" = Y
    $REPO_DIR/scripts/build-gpu-plugin.fish
end

echo "Done."
