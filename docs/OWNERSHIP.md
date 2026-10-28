# Qué es propio y qué es upstream

Regla única: si `pacman -Ql caelestia-shell` o `~/.local/state/caelestia/dots/`
lo contienen, es upstream y va en `fork/`. Todo lo demás va en `home/` o `system/`.

## home/ → `$HOME` (solo archivos propios)

| Path en repo | Destino | Origen |
|---|---|---|
| `home/bezel/config.toml` | `~/.config/bezel/` | propio (bezel no es caelestia) |
| `home/caelestia/shell.json` | `~/.config/caelestia/shell.json` | propio (user config) |
| `home/fish/config.fish` | `~/.config/fish/config.fish` | ⚠️ copia de upstream + 9 líneas (paths). Migrar a `~/.config/caelestia/user-config.fish` y eliminar |
| `home/quickshell/overview/` | `~/.config/quickshell/overview/` | propio (no existe upstream) |
| `home/systemd/user/` | `~/.config/systemd/user/` | propio (servicios trackpad/audio/monitor) |
| `home/wireplumber/` | `~/.config/wireplumber/` | propio (upstream `pipewire` no tiene entries) |
| `scripts/*` | `~/.local/bin/` | propio |

Drift conocido: `home/caelestia/shell.json` está desactualizado vs deployed
(transparency, idle inhibitors, `gpuType`). Reconciliar con `diff ~/.config/caelestia/shell.json home/caelestia/shell.json`.

## system/ → `/etc`, `/lib/firmware` (solo archivos propios, requieren sudo)

| Path en repo | Destino |
|---|---|
| `system/sddm.conf` | `/etc/sddm.conf` |
| `system/keyd/` | `/etc/keyd/` |
| `system/pipewire/` | `/etc/pipewire/` |
| `system/modprobe.d/` | `/etc/modprobe.d/` |
| `system/firmware/` | `/lib/firmware/` (+ `FILES=` en mkinitcpio.conf a mano) |
| `system/asusd/` | `/etc/asusd/` (preserva límite vivo en apply) |

Nada de `system/` pisa paquetes pacman salvo `sddm.conf`/`asusd.ron` que son
configs de servicio, no código versionado.

## fork/ → NO deployar como propio (ver `fork/README.md`)

- `fork/shell/`: 15 QML modificados + nuevos propios (emoji, BatteryConservation) + drawer clipboard porteado de clip-picker (backup del simple anterior en `fork/shell/modules.clipboard-simple-backup/`, no se deploya).
  Deploy actual a `/etc/xdg/quickshell/caelestia/` vía sudo (frágil, sobrevive
  hasta crear `Brimx/shell` y clonar a `~/.config/quickshell/caelestia/` que
  tiene precedencia XDG).
- `fork/dots-hypr/`: 16 lua de `caelestia-dots/caelestia`. Migrar a
  `home/caelestia/hypr-user.lua` + `hypr-vars.lua` y eliminar.
