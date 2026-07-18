# Cae-Mod

A dots-file for Hyprland with Quickshell, based on [Caelestia](https://github.com/caelestia-dots/shell).

> Personalización overlay sobre caelestia-shell v2.1.0.
> Inspirado por [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
> e [ilyamiro/nixos-configuration](https://github.com/ilyamiro/nixos-configuration).

## Estructura

```
Cae-Mod/
├── config/          Dotfiles planos (sin sudo)
├── patches/         Archivos que van en /etc/ (requieren sudo)
├── scripts/         Scripts de deploy y utilidades
└── docs/            Documentación
```

## Deploy

```fish
git clone https://github.com/<tu-user>/Cae-Mod.git
cd Cae-Mod
./scripts/apply.fish
```

### Post-actualización AUR

```fish
git pull
./scripts/apply.fish
```

## Qué incluye

- **Idle fix**: Debounce de 5s en detección de reproducción + reset del idle monitor al detener contenido
- **OLED**: Bordes de ventana planos (rounding 0, thickness 0)
- **SDDM**: SilentSDDM con teclado virtual
- **keyd**: Fix para tecla backslash dañada por sulfatación
- **Trackpad edges**: Gestos en bordes (volumen, brillo, seek media)
- **KB Layout**: Switcher US/Latam con SUPER + SPACE
- **OCR**: Screenshot + reconocimiento de texto con tesseract
- **Intel Arc Xe2**: Variables de entorno DXVK_ASYNC y ANV_ALLOW_GPL
- **GPU fix (xe driver)**: Utilización de GPU via fdinfo para Intel Arc B580/Battlemage (driver xe)
- **Displays widget**: Panel Quickshell para configurar monitores
- **Cursor**: Vimix cursors

## Features planeadas

- [ ] Widget de batería con toggle 80%/100%
- [ ] AI sidebar (inspirado en end-4)
- [ ] Glassmorphism / gradientes (inspirado en ilyamiro)
- [ ] Módulos QML propios

## Licencia

MIT
