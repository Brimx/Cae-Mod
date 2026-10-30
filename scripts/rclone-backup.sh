#!/usr/bin/env bash
# Backup de carpetas de usuario a Santi:Backup/<Carpeta> con `rclone copy`.
#
# Unidireccional a propósito: un borrado en local NO borra en Drive. `rclone
# bisync` propaga borrados en ambos sentidos y necesita --resync manual cuando
# se desincroniza; no se usa aquí. Si se quiere bidireccional, hacerlo como
# segunda unidad aparte y con historial de versiones en Drive.
#
# Uso: rclone-backup.sh            backup real
#      RCLONE_BACKUP_DRY_RUN=1 rclone-backup.sh   solo lista lo que haría
#      RCLONE_BACKUP_REMOTE=Rclone:Otro rclone-backup.sh  destino alterno
set -euo pipefail

REMOTE="${RCLONE_BACKUP_REMOTE:-Santi:Backup}"

# Carpetas relativas a $HOME. Añadir aquí lo que se quiera respaldar.
DIRS=(Documentos Imágenes Música Vídeos Videos Escritorio Plantillas Público)
# Fuera del backup por defecto: Descargas (transitorio) y Proyectos (repos con
# node_modules/.venv; los repos tienen su propio remoto git).

# Config de usuario: ~/.config/rclone-backup/config (la edita `rclone-sync`).
# Las variables de entorno RCLONE_BACKUP_* siguen teniendo prioridad.
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/rclone-backup/config"
if [[ -r "$CONFIG" ]]; then
  . "$CONFIG"
  REMOTE="${RCLONE_BACKUP_REMOTE:-${BACKUP_REMOTE:-$REMOTE}}"
  BACKUP_BWLIMIT="${RCLONE_BACKUP_BWLIMIT:-${BACKUP_BWLIMIT:-08:00,4M 00:00,off}}"
  # BACKUP_DIRS trae una carpeta por línea (formato actual, admite espacios en el
  # nombre) o separadas por espacios (formato viejo). El env RCLONE_BACKUP_DIRS
  # sigue siendo una lista separada por espacios.
  raw_dirs="${RCLONE_BACKUP_DIRS:-${BACKUP_DIRS:-}}"
  if [[ "$raw_dirs" == *$'\n'* ]]; then
    DIRS=()
    while IFS= read -r line; do
      if [[ -n "$line" ]]; then DIRS+=("$line"); fi
    done <<< "$raw_dirs"
  elif [[ -n "$raw_dirs" ]]; then
    read -r -a DIRS <<< "$raw_dirs"
  fi
else
  BACKUP_BWLIMIT="${RCLONE_BACKUP_BWLIMIT:-08:00,4M 00:00,off}"
fi

# Nada de lo excluido se borra en el destino: `copy` nunca elimina.
# Los `**/` son necesarios: rclone no aplica el patrón a subdirectorios anidados.
# `.cache/**` evita subir basura de sandboxes y cachés (p. ej. un j.bin de 300M
# en Documentos/deepseek-harness/... que Drive rechazaba en bucle).
EXCLUDES=(
  --exclude "**/.git/**"
  --exclude "**/node_modules/**"
  --exclude "**/.venv/**"
  --exclude "**/__pycache__/**"
  --exclude "**/.cache/**"
  --exclude "**/obj/**"
  --exclude "**/target/**"
  --exclude "**/.stfolder/**"
)

# Medido en esta máquina contra Santi:Backup (100 MB por prueba, oct-2026):
#   transfers 2, tpslimit 10, bwlimit 3M   -> 0.82 MB/s   (6.5 Mbit/s)
#   transfers 8, tpslimit 50, sin bwlimit  -> 11.8 MB/s   (94 Mbit/s)
#   un archivo de 80M, chunk 64M           -> 5.9-13.2 s  (6-13 MB/s)
#   un archivo de 80M, chunk 128M          -> 4.8-5.3 s   (15-17 MB/s)
# Los valores viejos venían de un wifi que daba ~1 MB/s; con el enlace nuevo
# eran el cuello de botella real, no la red.
# --transfers manda cuando hay muchos archivos; con un solo archivo grande el
# tope es la conexión con Drive (~4 MB/s por archivo).
# --tpslimit: no acaparar la cuota de API de Drive; si se agota, el mount del
# mismo remote se queda esperando y Thunar aparenta colgarse.
# --bwlimit: admite una tabla por franjas en hora local, que es lo que se usa
# aquí: de 08:00 a 00:00 va a 4M (~32 Mbit/s, un tercio del enlace medido) para
# que navegar, videollamadas y el mount de ~/Drive no lo noten; de 00:00 a 08:00
# sin tope. "off" dentro de la tabla es válido en rclone. Un valor simple ("6M")
# y "off" también se aceptan, desde el menú o editando el config.
# --drive-chunk-size 128M: menos llamadas por archivo y el doble de rápido en
# archivos grandes que con 64M. No afecta a los pequeños (van en una sola
# petición) ni al listado. Coste: hasta 128M de RAM por transfer activo, de ahí
# el MemoryMax de la unidad.
BWLIMIT="${BACKUP_BWLIMIT:-08:00,4M 00:00,off}"

EXTRA=()
if [[ -n "${RCLONE_BACKUP_DRY_RUN:-}" ]]; then
  EXTRA+=(--dry-run -v)
fi

command -v rclone >/dev/null || { echo "rclone no está instalado" >&2; exit 1; }

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/rclone-backup.lock"
flock -n 9 || { echo "Ya hay un backup en curso, salgo"; exit 0; }

rc=0
for d in "${DIRS[@]}"; do
  src="$HOME/$d"
  [[ -d "$src" ]] || { echo "skip: ~/$d no existe"; continue; }
  echo "==> $d -> $REMOTE/$d"
  if ! rclone copy "$src" "$REMOTE/$d" \
      --update --create-empty-src-dirs \
      --transfers 8 --checkers 16 \
      --tpslimit 50 --tpslimit-burst 100 \
      --bwlimit "$BWLIMIT" \
      --drive-chunk-size 128M \
      "${EXCLUDES[@]}" "${EXTRA[@]}"; then
    echo "ERROR: falló el backup de $d" >&2
    rc=1
  fi
done

exit "$rc"
