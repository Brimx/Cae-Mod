# Cae-Mod

A dots-file for Hyprland with Quickshell, based on [Caelestia](https://github.com/caelestia-dots/shell).

> Personalización overlay sobre caelestia-shell v2.5.0 / dots rev d4c24f8 (ver `shell.lock`).
> Inspirado por [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
> e [ilyamiro/nixos-configuration](https://github.com/ilyamiro/nixos-configuration).

## Estructura

Regla: solo archivos propios en `home/` y `system/`. Lo modificado de upstream vive en `fork/` hasta migrarse al fork. Detalle en `docs/OWNERSHIP.md`.

```
Cae-Mod/
├── home/            Solo propio → $HOME (bezel, caelestia/shell.json, fish, quickshell/overview, systemd, wireplumber)
├── system/          Solo propio → /etc, /lib/firmware (requiere sudo: sddm, keyd, asusd, modprobe.d, firmware, pipewire)
├── fork/            Upstream modificado (NO es propio): shell/ → Brimx/shell branch cae-mod, dots-hypr/ → hooks hypr-user.lua
├── scripts/         Scripts de deploy y utilidades (propios → ~/.local/bin), incl. rclone-backup.sh
├── docs/            Documentación (OWNERSHIP.md)
└── shell.lock       Pin de versiones upstream
```

## Deploy

```fish
git clone https://github.com/<tu-user>/Cae-Mod.git
cd Cae-Mod
./scripts/apply.fish
```

### Post-actualización de caelestia

```fish
caelestia update        # actualiza caelestia-shell (no existe "upgrade")
# actualizar shell.lock: dots_rev desde ~/.local/state/caelestia/dots-state.json, shell_pkg desde pacman -Q caelestia-shell
git pull                # trae los últimos cambios de Cae-Mod
./scripts/apply.fish    # re-aplica home/ + system/ + fork/
```

> ⚠️ `fork/` es version-específico. Si el release nuevo de
> caelestia cambia la estructura de los QML, los archivos pueden romper el shell.
> Tras cada `caelestia update`, verifica que el shell arranca sin errores
> (`qs -c caelestia -n -d`) y revisa los diffs antes de re-aplicar.
> Objetivo: mover `fork/shell/` a `Brimx/shell` branch `cae-mod` y `fork/dots-hypr/`
> a `hypr-user.lua`/`hypr-vars.lua` (ver `fork/README.md`).

## Qué incluye

- **Idle fix**: Debounce de 5s en detección de reproducción + reset del idle monitor al detener contenido
- **OLED**: Bordes de ventana planos (rounding 0, thickness 0)
- **SDDM**: SilentSDDM con teclado virtual
- **keyd**: Fix para tecla backslash dañada por sulfatación
- **Trackpad edges**: Gestos en bordes (volumen, brillo, seek media)
- **KB Layout**: Switcher US/Latam con SUPER + SPACE
- **Drive (rclone)**: mount de Google Drive **bajo demanda** en `~/Drive` (`rclone-drive on|off|status`, `vfs-cache-mode writes`, 10G) + backup diario de carpetas de usuario a `Santi:Backup/` (timer systemd, `rclone copy` unidireccional, `--bwlimit 3M` para no bloquear el explorador). Configuración y control con el menú `rclone-sync` (`~/.config/rclone-backup/config`)
- **Intel Arc Xe2**: Variables de entorno DXVK_ASYNC y ANV_ALLOW_GPL
- **GPU fix (xe driver)**: Utilización de GPU via fdinfo para Intel Arc B580/Battlemage (driver xe)
- **Cursor**: Vimix cursors
- **Workspace Overview**: Vista general de workspaces con previews cacheadas (modo event), drag & drop, special workspaces (Super+Tab)
- **Battery Conservation**: Toggle 80%/100% con asusctl en el popout de batería
- **Power profiles (Asus Vivobook S14 / Lunar Lake)**: `Quiet` en batería sin turbo (`bat_command`/`ac_command` en `asusd.ron` desactiva `intel_pstate/no_turbo`) para bajar de ~10W a ~6-7W, `Performance` en AC
- **Audio fixes (Asus Vivobook S14 / ALC294 + SOF)**: Anti-stutter (suspensión OFF + quantum 2048 fijo) y auto-switch de audífonos por jack (`split-enable=false`)

## Features planeadas

- [ ] AI sidebar (inspirado en end-4)
- [ ] Glassmorphism / gradientes (inspirado en ilyamiro)
- [ ] Módulos QML propios

## Licencia

MIT
