#!/usr/bin/env bash
# Helper emoji para el drawer quickshell emoji.
#   data            -> emoji-categorized.json a stdout
#   recents         -> chars recientes (uno por linea, max 24)
#   touch <char>    -> prepend <char> a recientes (dedupe, cap 24)
#   copy <char>     -> <char> a wl-copy (argv, sin quoting shell)
set -u
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/caelestia/emoji-categorized.json"
RECENT_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/emoji.json"
MAX_RECENT=24

case "${1:-}" in
  data) cat "$DATA" ;;
  recents)
    if [[ -r "$RECENT_CFG" ]]; then head -n "$MAX_RECENT" "$RECENT_CFG"; fi
    ;;
  touch)
    c="${2:-}"
    [[ -z "$c" ]] && exit 0
    mkdir -p "$(dirname "$RECENT_CFG")"
    tmp="$(mktemp)"
    {
      printf '%s\n' "$c"
      if [[ -r "$RECENT_CFG" ]]; then grep -vxF -- "$c" "$RECENT_CFG" 2>/dev/null; fi
    } | head -n "$MAX_RECENT" > "$tmp"
    mv -f "$tmp" "$RECENT_CFG"
    ;;
  copy) printf '%s' "${2:-}" | wl-copy ;;
  *) echo "uso: $0 {data|recents|touch|copy} [char]" >&2; exit 1 ;;
esac
