#!/usr/bin/env bash
# Control del mount de Google Drive (Santi:) en ~/Drive.
#
# El mount NO arranca solo: se levanta cuando hace falta y se apaga al terminar.
# Motivo: mantenerlo montado gasta cuota de la API de Drive y hace que Thunar se
# bloquee al abrir el bookmark (listar una carpeta grande de Drive puede tardar
# >30 s). Desmontado, ~/Drive es una carpeta vacía y Thunar abre al instante.
#
# Uso:
#   rclone-drive on       montar
#   rclone-drive off      desmontar
#   rclone-drive status   ver si está montado
set -euo pipefail

mountpoint_path="${HOME}/Drive"

case "${1:-status}" in
  on)
    systemctl --user start rclone-drive.service
    sleep 1
    "$0" status
    ;;
  off)
    systemctl --user stop rclone-drive.service
    echo "Drive desmontado"
    ;;
  status)
    if systemctl --user -q is-active rclone-drive.service; then
      echo "Drive montado en ${mountpoint_path}"
    else
      echo "Drive NO montado (usa: rclone-drive on)"
    fi
    ;;
  *)
    echo "uso: rclone-drive [on|off|status]" >&2
    exit 1
    ;;
esac
