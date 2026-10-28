#!/usr/bin/env bash
# Helper cliphist para el módulo quickshell clipboard.
#   list            -> "<id>\t<preview>\t<file://thumb o vacío>" (últimas N, nuevas primero)
#   decode <id>     -> bytes crudos a stdout
#   paste <id>      -> decode | wl-copy
#   delete <id>     -> borra una entrada
set -u
MAX_ITEMS="${CLIP_MAX_ITEMS:-150}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell-clipboard"

case "${1:-}" in
  list)
    mkdir -p "$CACHE_DIR"
    cliphist list 2>/dev/null | head -n "$MAX_ITEMS" | while IFS=$'\t' read -r id preview; do
      thumb=""
      # Cualquier bitmap (no solo PNG): el preview dice "[[ binary data"
      # con formato variable según versión de cliphist (png/jpeg/webp...).
      if [[ "$preview" == "[[ binary data"* ]]; then
        # Reutilizar caché existente en cualquier extensión conocida.
        for ext in png jpg jpeg webp gif bmp; do
          if [[ -f "$CACHE_DIR/$id.$ext" ]]; then thumb="file://$CACHE_DIR/$id.$ext"; break; fi
        done
        if [[ -z "$thumb" ]]; then
          tmp="$(mktemp)"
          if cliphist decode "$id" 2>/dev/null > "$tmp"; then
            case "$(file -b --mime-type "$tmp" 2>/dev/null)" in
              image/png) ext=png ;;
              image/jpeg) ext=jpg ;;
              image/webp) ext=webp ;;
              image/gif) ext=gif ;;
              image/bmp) ext=bmp ;;
              *) ext="" ;;
            esac
            if [[ -n "$ext" ]]; then
              thumb="$CACHE_DIR/$id.$ext"
              mv -f "$tmp" "$thumb" 2>/dev/null || cp -f "$tmp" "$thumb"
              thumb="file://$thumb"
            else
              rm -f "$tmp"
            fi
          else
            rm -f "$tmp"
          fi
        fi
      fi
      printf '%s\t%s\t%s\n' "$id" "$preview" "$thumb"
    done
    ;;
  decode) cliphist decode "$2" ;;
  paste) cliphist decode "$2" | wl-copy ;;
  # delete NO acepta id por argv (exit 0 silencioso sin borrar): la entrada
  # va por stdin, igual que en `caelestia clipboard -d` (clipboard.py).
  delete) cliphist list 2>/dev/null | awk -F'\t' -v id="$2" '$1==id' | cliphist delete ;;
  *) echo "uso: $0 {list|decode|paste|delete} [id]" >&2; exit 1 ;;
esac
