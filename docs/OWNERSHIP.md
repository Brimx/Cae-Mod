# Qué es propio y qué es upstream

Regla única: si `pacman -Ql caelestia-shell` o `~/.local/state/caelestia/dots/`
lo contienen, es upstream y va en `fork/`. Todo lo demás va en `home/` o `system/`.

## home/ → `$HOME` (solo archivos propios)

| Path en repo | Destino | Origen |
|---|---|---|
| `home/bezel/config.toml` | `~/.config/bezel/` | propio (bezel no es caelestia) |
| `home/caelestia/shell.json` | `~/.config/caelestia/shell.json` | propio (user config) |
| `home/fish/config.fish` | `~/.config/fish/config.fish` | ⚠️ copia de upstream + 9 líneas (paths). Migrar a `~/.config/caelestia/user-config.fish` y eliminar |
| `home/hyprmoncfg/profiles/` | `~/.config/hyprmoncfg/profiles/` | propio (perfiles de monitores) |
| `home/quickshell/overview/` | `~/.config/quickshell/overview/` | propio (no existe upstream) |
| `home/systemd/user/` | `~/.config/systemd/user/` | propio (servicios trackpad/audio/monitor) |
| `home/wireplumber/` | `~/.config/wireplumber/` | propio (upstream `pipewire` no tiene entries) |
| `scripts/*` | `~/.local/bin/` | propio |

Drift conocido: `home/caelestia/shell.json` está desactualizado vs deployed
(transparency, idle inhibitors, `gpuType`). Reconciliar con `diff ~/.config/caelestia/shell.json home/caelestia/shell.json`.

### Monitores (hyprmoncfg)

`hyprmoncfg` es el dueño de la configuración de monitores: aplica el perfil que
corresponde al set conectado y escribe `~/.config/hypr/hyprmoncfg-monitors.lua`
(salida suya, **no** un stray: no borrarla) más un include al final de
`~/.config/hypr/hyprland.lua`. Como `apply.fish` copia `hyprland.lua` desde
`fork/dots-hypr/`, el include desaparece en cada deploy: por eso `apply.fish`
corre `hyprmoncfg manage` después del cp. Ese include es el único drift esperado
en el `hyprland.lua` desplegado.

Los perfiles de `home/hyprmoncfg/profiles/` cubren los cuatro sets que se usan:
panel solo (`solo-laptop`), panel + BOE (`monitor-120hz-casa`), panel + TV
(`tv-de-casa`) y panel + proyector (`mirror`). `hyprmoncfg` puntúa por
coincidencia (100 por salida completa): sin el del panel solo, los tres perfiles
de dos salidas empatan en 70 y el desempate puede elegir `mirror`, que exige el
proyector y deja el panel sin salida. Ver la Wiki del proyecto en el vault.

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
- `fork/dots-hypr/`: 9 lua con delta propio (base `caelestia-dots/caelestia`
  rev `d4c24f8`). Migrar a `home/caelestia/hypr-user.lua` + `hypr-vars.lua` y
  eliminar. El resto de `hypr/*.lua` lo gestiona upstream (no se copia).
