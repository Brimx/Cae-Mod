# fork/ — código que NO es tuyo, modificado por vos

Regla: si el archivo existe en upstream, vive acá hasta migrarse al fork.
`home/` y `system/` son solo archivos propios (no existen upstream).

## fork/shell/ → `Brimx/shell` branch `cae-mod`

Base: `caelestia-dots/shell` @ pacman `caelestia-shell 2.5.0-1` (ver `../shell.lock`).

### Archivos MODIFICADOS (existen upstream, van como commit en el fork)

```
components/ScreenState.qml
components/images/FadeImage.qml
components/widgets/CoverArt.qml
modules/Shortcuts.qml
modules/drawers/Panels.qml
modules/drawers/ContentWindow.qml
modules/drawers/Regions.qml
modules/bar/popouts/Battery.qml
modules/dashboard/dash/Media.qml
modules/dashboard/media/CoverVisualiser.qml
modules/dashboard/media/Details.qml
modules/lock/Media.qml
services/Players.qml
```

Migración: 1 commit por feature con prefijo `cae:`, ej:
`cae: battery conservation toggle`, `cae: media cover art`, `cae: clipboard drawer`.
Verificar cada uno con `diff` contra `/etc/xdg/quickshell/caelestia/<mismo path>`
antes de commitear al fork (ese path hoy ya tiene tus patches aplicados).

Notas de rebase (2026-10-30):

- `dashboard/Media.qml` y `dashboard/media/LyricsAndSelector.qml` eran idénticos a
  upstream 2.5.0 (sin delta propio): **quitados del fork** el 2026-10-30.
- `modules/Shortcuts.qml` (parche clipboard/emoji/sidebar) upstream `main` lo movió a
  `daemons/Shortcuts.qml` (commit `29794ec`); al salir la próxima release hay que
  re-aplicar el parche en la ruta nueva.
- Del resto, upstream `main` solo cambió 4 archivos de esta lista
  (`ContentWindow`, `dashboard/dash/Media`, `media/CoverVisualiser`, `lock/Media`)
  y los mergea limpio (verificado con `git merge-file` contra `v2.5.0`).

### Archivos NUEVOS (no existen upstream, eventualmente propios)

```
modules/bar/popouts/BatteryConservation.qml
modules/emoji/** (5 archivos + fzf.js copiado de clipboard)
```

Más el drawer simple propio anterior, movido a `modules.clipboard-simple-backup/`
(7 archivos). **Reemplazado, no se deploya**: el drawer vivo es el port de
clip-picker (`riadloukili/dotfiles` rev d25ba94, pin en `../shell.lock`):
lista con matches resaltados + preview lateral + search con contador + ayuda
en keycaps + menú de links, con tokens/colores/animaciones de Caelestia
(`Tokens`, `Colours`, `Anim`, `StyledText`, `MaterialIcon`, `SearchBar` real).
`scripts/fzf.js` del port trae 2 fixes Qt (trimLeft/trimRight, defaultOpts)
que también usa emoji (su copia se genera desde aquí).

Estos sí son tuyos, pero dependen de los MODIFICADOS (Panels/Shortcuts los cargan),
así que se mudan juntos al fork. No los muevas a `home/` hasta que el fork
exponga punto de extensión.

## fork/dots-hypr/ → hooks en `home/caelestia/`

Base: `caelestia-dots/caelestia` rev `d4c24f8` (rebasado 2026-10-30; ver `../shell.lock`).
Cada archivo es upstream-base + delta propio (verificado con `git merge-file`).

Archivos con delta propio (9):
```
hyprland.lua      → require("hyprland.monitors") + quita monitor default
variables.lua     → editor code, gaps, Vimix-cursors, kbOcr, kbOverview
execs.lua         → qs -c overview, trackpad-gestures (resto = upstream)
keybinds.lua      → SUPER+SPACE layout, SUPER+TAB overview, SUPER+G, clipboard/emoji drawers
rules.lua         → idle_inhibit (stremio/firefox/calls/wine), nmtui, steam rounding, game_tag
env.lua           → CAELESTIA_*_DIR, DXVK_ASYNC, ANV_ALLOW_GPL
input.lua         → kb_layout us,latam + taps/tap_button_map + hl.device overrides
gestures.lua      → 3 dedos media (prev/next) y mute en vez de suspend
monitors.lua      → nuevo (upstream no lo tiene)
```

Ya **no** se copian (sin delta propio, los gestiona upstream):
`animations.lua`, `decoration.lua`, `general.lua`, `group.lua`, `misc.lua`,
`utils/functions.lua`, `utils/json.lua`. Tenían copias obsoletas (jun–jul 2026)
que al re-aplicarse retrocedían fixes de upstream (p.ej. el resizer de `functions.lua`).

Objetivo: vaciar este dir migrando tus deltas a los hooks oficiales:
- `~/.config/caelestia/hypr-vars.lua` (`return { ... }`, override de `variables.lua`)
- `~/.config/caelestia/hypr-user.lua` (requires extra, keybinds, reglas)

Excepción: `monitors.lua` es nuevo tuyo → pasará a `home/caelestia/hypr-user.lua`
o a `home/hypr/` cuando se complete la migración.

## Workflow de update

```fish
caelestia update
cat ~/.local/state/caelestia/dots-state.json | grep applied_rev  # nuevo dots_rev → shell.lock
pacman -Q caelestia-shell  # nueva versión → shell.lock
# en el fork:
git fetch upstream; git rebase upstream/main  # resolver conflictos QML
./scripts/apply.fish  # re-aplica home/ + system/ + fork/shell/
```
