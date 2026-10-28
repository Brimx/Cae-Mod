#!/usr/bin/env bash
# OCR: selecciona región con slurp, reconoce con tesseract (spa+eng),
# copia al clipboard y notifica. Bind: SUPER + ALT + O.
set -u

region="$(slurp)" || exit 0
[ -z "${region:-}" ] && exit 0

text="$(grim -g "$region" - 2>/dev/null | tesseract stdin stdout -l spa+eng 2>/dev/null)"
# Trim espacios extremos
text="$(printf '%s' "$text" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [ -z "$text" ]; then
    notify-send -u low -a 'OCR' 'OCR' 'Sin texto reconocido'
    exit 0
fi

printf '%s' "$text" | wl-copy
notify-send -a 'OCR' 'OCR copiado' "$text"
