#!/usr/bin/env bash
# Menú de terminal para configurar y controlar el backup de rclone.
#
#   rclone-sync            menú interactivo
#   rclone-sync status     estado (no interactivo)
#
# Lo que escribe va a ~/.config/rclone-backup/config (remote, carpetas, ancho de
# banda) y, para la frecuencia, a un drop-in del timer de systemd.
set -uo pipefail

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rclone-backup"
CONFIG="$CONFIG_DIR/config"
BACKUP_BIN="$HOME/.local/bin/rclone-backup.sh"
DRIVE_BIN="$HOME/.local/bin/rclone-drive"
SERVICE="rclone-backup.service"
TIMER="rclone-backup.timer"
DRIVE_SERVICE="rclone-drive.service"
DROPIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/$TIMER.d"
DROPIN="$DROPIN_DIR/override.conf"

DEFAULT_DIRS=(Documentos Imágenes Música Vídeos Videos Escritorio Plantillas Público)
EXTRA_DIRS=(Descargas Proyectos)

BACKUP_REMOTE="Santi:Backup"
BACKUP_BWLIMIT="08:00,4M 00:00,off"
DIRS=()
CANDIDATES=()

# --- utilidades -------------------------------------------------------------

sys() { systemctl --user "$@"; }

# systemd de usuario disponible y hablable. Sin esto, las consultas de estado
# devuelven vacío; no queremos que el menú se caiga por eso.
has_systemd() {
  command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1
}

# Comparación dentro de una lista; soporta nombres con espacios porque compara
# elemento a elemento, nunca con `[[ $lista == *" $x "* ]]` sobre un string.
_in_list() {
  local needle="$1" x
  shift
  for x in "$@"; do
    [[ "$x" == "$needle" ]] && return 0
  done
  return 1
}

join_dirs() {
  local out="" d
  for d in "${DIRS[@]}"; do
    out+="${out:+, }$d"
  done
  printf '%s\n' "$out"
}

# BACKUP_DIRS llega como string con una carpeta por línea (formato actual) o con
# carpetas separadas por espacios (formato viejo, sin soporte de espacios en el
# nombre). Detecta cuál es y llena DIRS sin depender de un número fijo.
parse_dirs() {
  local raw="${BACKUP_DIRS:-}" line
  DIRS=()
  [[ -z "$raw" ]] && return 0
  if [[ "$raw" == *$'\n'* ]]; then
    while IFS= read -r line; do
      if [[ -n "$line" ]]; then DIRS+=("$line"); fi
    done <<< "$raw"
  else
    local -a parts=()
    read -r -a parts <<< "$raw"
    if (( ${#parts[@]} )); then DIRS=("${parts[@]}"); fi
  fi
}

save_config() {
  mkdir -p "$CONFIG_DIR"
  {
    printf '# Configuración del backup de rclone. Editar con `rclone-sync`.\n'
    printf '# BACKUP_DIRS: una carpeta por línea (permite nombres con espacios).\n'
    printf 'BACKUP_REMOTE="%s"\n' "$BACKUP_REMOTE"
    printf 'BACKUP_BWLIMIT="%s"\n' "$BACKUP_BWLIMIT"
    printf 'BACKUP_DIRS="%s"\n' "$(printf '%s\n' "${DIRS[@]}")"
  } > "$CONFIG"
  echo "Guardado en $CONFIG"
}

timer_state() {
  local en next
  if ! has_systemd; then
    echo "desconocido (sin systemd de usuario)"
    return 0
  fi
  en=$(sys is-enabled "$TIMER" 2>/dev/null || true)
  next=$(sys list-timers "$TIMER" --no-pager 2>/dev/null | sed -n 2p | awk '{print $1" "$2" "$3}')
  if [[ "$en" == "enabled" ]]; then
    echo "activo (próxima: ${next:-?})"
  elif [[ -z "$en" ]]; then
    echo "desconocido"
  else
    echo "pausado ($en)"
  fi
}

backup_state() {
  if ! has_systemd; then
    echo "desconocido"
    return 0
  fi
  sys is-active "$SERVICE" 2>/dev/null || true
}

drive_state() {
  if [[ ! -x "$DRIVE_BIN" ]]; then
    echo "rclone-drive no instalado"
    return 0
  fi
  "$DRIVE_BIN" status 2>/dev/null || echo "sin respuesta de rclone-drive"
}

# Alterna el mount preguntando a systemd, no leyendo el texto que imprime
# rclone-drive (antes se comparaba con "NO montado" y cualquier cambio de copy
# invertía la acción).
drive_toggle() {
  if [[ ! -x "$DRIVE_BIN" ]]; then
    echo "rclone-drive no está instalado en $DRIVE_BIN" >&2
    return 1
  fi
  if has_systemd && sys -q is-active "$DRIVE_SERVICE" 2>/dev/null; then
    "$DRIVE_BIN" off
  elif has_systemd; then
    "$DRIVE_BIN" on
  else
    echo "sin systemd de usuario no puedo manejar el mount" >&2
    return 1
  fi
}

show_status() {
  echo "Remote:         $BACKUP_REMOTE"
  echo "Ancho de banda: $BACKUP_BWLIMIT"
  echo "Carpetas:       $(join_dirs)"
  echo "Backup ahora:   $(backup_state)"
  echo "Programación:   $(timer_state)"
  echo "Drive:          $(drive_state)"
}

# Candidatas = carpetas conocidas que existan + cualquier otra carpeta de $HOME.
# Un glob y un for: no hay lista fija ni separación por espacios de por medio.
build_candidates() {
  local -a home_dirs=()
  local d p
  CANDIDATES=()
  for d in "${DEFAULT_DIRS[@]}" "${EXTRA_DIRS[@]}"; do
    if [[ -d "$HOME/$d" ]]; then CANDIDATES+=("$d"); fi
  done
  shopt -s nullglob
  home_dirs=("$HOME"/*/)
  shopt -u nullglob
  for p in "${home_dirs[@]}"; do
    d="${p%/}"
    d="${d##*/}"
    if [[ -n "$d" ]] && ! _in_list "$d" "${CANDIDATES[@]}"; then
      CANDIDATES+=("$d")
    fi
  done
}

toggle_dirs() {
  local -a chosen=() result=()
  local i n d
  build_candidates
  if (( ${#CANDIDATES[@]} == 0 )); then
    echo "No hay carpetas en $HOME"
    return 0
  fi
  echo "Carpetas en ~:"
  i=1
  for d in "${CANDIDATES[@]}"; do
    if _in_list "$d" "${DIRS[@]}"; then
      printf '  %2d) [x] %s\n' "$i" "$d"
    else
      printf '  %2d) [ ] %s\n' "$i" "$d"
    fi
    i=$((i+1))
  done
  echo
  printf 'Números a alternar (ej: 1 3, vacío cancela): '
  read -r sel || return 0
  [[ -z "$sel" ]] && return 0
  for n in $sel; do
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    (( n >= 1 && n <= ${#CANDIDATES[@]} )) || continue
    chosen+=("${CANDIDATES[$((n-1))]}")
  done
  if (( ${#chosen[@]} == 0 )); then
    echo "Nada seleccionado"
    return 0
  fi
  for d in "${DIRS[@]}"; do
    _in_list "$d" "${chosen[@]}" || result+=("$d")
  done
  for d in "${chosen[@]}"; do
    _in_list "$d" "${DIRS[@]}" || result+=("$d")
  done
  if (( ${#result[@]} == 0 )); then
    echo "La lista quedaría vacía; no cambio nada"
    return 0
  fi
  DIRS=("${result[@]}")
  save_config
}

# El límite es lo único que separa "backup rápido" de "backup invisible".
# rclone acepta un valor fijo ("4M"), "off", o una tabla por franjas en hora
# local: lo que venga de una franja vale hasta la siguiente, y la tabla da la
# vuelta al día. Con la tabla, el backup usa todo el enlace de noche y sólo un
# tercio durante el día, cuando la navegación sí compite por la subida.
set_bwlimit() {
  cat <<'EOF'
 1) Franja horaria: 4M de día, sin tope de 00:00 a 08:00 (recomendado)
 2) 2M fijo: el backup casi no se nota
 3) 6M fijo
 4) Sin tope (off), todo el día
 5) Personalizado (valor simple o tabla)
 6) Cancelar
EOF
  printf 'Opción: '
  read -r opt || return 0
  local v=""
  case "$opt" in
    1) v="08:00,4M 00:00,off" ;;
    2) v="2M" ;;
    3) v="6M" ;;
    4) v="off" ;;
    5) printf 'Valor (ej: 5M, off, "08:00,2M 00:00,off"): '
       read -r v || return 0 ;;
    *) return 0 ;;
  esac
  [[ -z "$v" ]] && return 0
  BACKUP_BWLIMIT="$v"
  save_config
}

set_frequency() {
  if ! has_systemd; then
    echo "sin systemd de usuario no puedo cambiar la programación" >&2
    return 1
  fi
  cat <<'EOF'
 1) Diario a medianoche (default)
 2) Dos veces al día (00:00 y 12:00)
 3) Semanal (domingo 03:00)
 4) Manual: sin programación
 5) Cancelar
EOF
  printf 'Opción: '
  read -r opt || return 0
  local cal=""
  case "$opt" in
    1) cal="daily" ;;
    2) cal="*-*-* 00,12:00:00" ;;
    3) cal="Sun 03:00" ;;
    4) sys stop "$TIMER" >/dev/null 2>&1; sys disable "$TIMER" >/dev/null 2>&1; echo "Timer desactivado (manual)"; return 0 ;;
    *) return 0 ;;
  esac
  mkdir -p "$DROPIN_DIR"
  {
    printf '[Timer]\n'
    printf 'OnCalendar=\n'
    printf 'OnCalendar=%s\n' "$cal"
  } > "$DROPIN"
  sys daemon-reload
  sys enable "$TIMER" >/dev/null 2>&1
  sys restart "$TIMER" >/dev/null 2>&1
  echo "Frecuencia actualizada: $cal"
}

pause_resume() {
  if ! has_systemd; then
    echo "sin systemd de usuario no puedo pausar el timer" >&2
    return 1
  fi
  if [[ "$(sys is-enabled "$TIMER" 2>/dev/null || true)" == "enabled" ]]; then
    sys stop "$TIMER" >/dev/null 2>&1
    sys disable "$TIMER" >/dev/null 2>&1
    echo "Backup automático pausado"
  else
    sys enable "$TIMER" >/dev/null 2>&1
    sys start "$TIMER" >/dev/null 2>&1
    echo "Backup automático reactivado"
  fi
}

menu() {
  local opt
  while true; do
    echo
    echo "=== Backup rclone — $BACKUP_REMOTE ==="
    echo "Carpetas: $(join_dirs)"
    echo "Límite: $BACKUP_BWLIMIT | $(timer_state)"
    echo "----------------------------------------"
    cat <<'EOF'
 1) Estado completo
 2) Backup ahora (segundo plano)
 3) Probar sin subir (dry-run)
 4) Elegir carpetas
 5) Cambiar ancho de banda
 6) Cambiar frecuencia
 7) Pausar / reanudar automático
 8) Montar / desmontar ~/Drive
 9) Ver log
 0) Salir
EOF
    printf 'Opción: '
    read -r opt || return 0
    case "$opt" in
      1) show_status ;;
      2) if has_systemd; then
           sys start --no-block "$SERVICE" && echo "Backup lanzado (journalctl --user -u $SERVICE -f)"
         else
           echo "sin systemd: ejecuta $BACKUP_BIN" >&2
         fi ;;
      3) if [[ -x "$BACKUP_BIN" ]]; then RCLONE_BACKUP_DRY_RUN=1 "$BACKUP_BIN" 2>&1 | tail -15; else echo "no existe $BACKUP_BIN" >&2; fi ;;
      4) toggle_dirs ;;
      5) set_bwlimit ;;
      6) set_frequency ;;
      7) pause_resume ;;
      8) drive_toggle ;;
      9) if has_systemd; then journalctl --user -u "$SERVICE" -n 25 --no-pager | tail -25; else echo "sin systemd no hay journal" >&2; fi ;;
      0) return 0 ;;
      *) echo "Opción inválida" ;;
    esac
  done
}

# --- carga de configuración -------------------------------------------------

[[ -r "$CONFIG" ]] && . "$CONFIG"
parse_dirs
if (( ${#DIRS[@]} == 0 )); then
  DIRS=("${DEFAULT_DIRS[@]}")
fi

case "${1:-}" in
  status) show_status ;;
  "" ) if [[ -t 0 ]]; then menu; else show_status; fi ;;
  * ) echo "uso: rclone-sync [status]" >&2; exit 1 ;;
esac
