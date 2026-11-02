#!/usr/bin/env bash
# dgit — Sincronización selectiva e inteligente con Google Drive mediante rclone y Git
# Uso: dgit [status | push | sync | add [rutas...] | reset | sync-all | pull [rutas...] | purge-drive]

set -e

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    PROJECT_NAME="$(basename "$REPO_ROOT")"
    IN_GIT=true
else
    REPO_ROOT="$PWD"
    PROJECT_NAME="$(basename "$PWD")"
    IN_GIT=false
fi

STAGE_FILE="$REPO_ROOT/.drive_stage"
LAST_SYNC_FILE="$REPO_ROOT/.drive_last_sync"
# Remote por defecto. Si tu remote de rclone tiene otro nombre, exporta DRIVE_REMOTE en tu shell o cámbialo aquí.
REMOTE="${DRIVE_REMOTE:-Santi:Proyectos/$PROJECT_NAME}"

is_ignored() {
    local target="$1"
    case "$target" in
        .git|*/.git|*/.git/*|.git/*|.drive_*|*/.drive_*)
            return 0
            ;;
    esac
    if [ "$IN_GIT" = true ]; then
        local rel="$target"
        if [[ "$target" = /* ]]; then
            rel="$(realpath --relative-to="$REPO_ROOT" "$target" 2>/dev/null || echo "$target")"
        fi
        git -C "$REPO_ROOT" check-ignore -q "$rel" 2>/dev/null && return 0
    fi
    return 1
}

upload_sync_info() {
    if [ "$IN_GIT" = true ]; then
        local branch commit subject date_now info_file
        branch="$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo "detached")"
        commit="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "none")"
        subject="$(git -C "$REPO_ROOT" log -1 --format=%s 2>/dev/null || echo "")"
        date_now="$(date '+%Y-%m-%d %H:%M:%S %z')"

        info_file="$REPO_ROOT/.drive_sync_info"
        {
            echo "Proyecto: $PROJECT_NAME"
            echo "Rama: $branch"
            echo "Commit: $commit ($subject)"
            echo "Sincronizado: $date_now"
        } > "$info_file"

        rclone copyto "$info_file" "$REMOTE/.drive_sync_info" 2>/dev/null || true
        rm -f "$info_file"
        git -C "$REPO_ROOT" rev-parse HEAD > "$LAST_SYNC_FILE" 2>/dev/null || true
    fi
}

get_git_changes() {
    TO_UPLOAD=()
    TO_DELETE=()
    [ "$IN_GIT" = false ] && return 0

    local -a files_up=() files_del=()
    local last_sync=""
    if [ -f "$LAST_SYNC_FILE" ]; then
        last_sync="$(cat "$LAST_SYNC_FILE" 2>/dev/null || true)"
    fi

    # 1. Cambios en commits realizados después de la última sincronización
    if [ -n "$last_sync" ] && git -C "$REPO_ROOT" cat-file -e "$last_sync^{commit}" >/dev/null 2>&1; then
        while IFS= read -r f; do
            [ -n "$f" ] && files_up+=("$f")
        done < <(git -C "$REPO_ROOT" diff --name-only --diff-filter=ACMR "$last_sync" HEAD 2>/dev/null || true)

        while IFS= read -r f; do
            [ -n "$f" ] && files_del+=("$f")
        done < <(git -C "$REPO_ROOT" diff --name-only --diff-filter=D "$last_sync" HEAD 2>/dev/null || true)
    fi

    # 2. Modificaciones activas en el working tree (no commiteadas)
    while IFS= read -r f; do
        [ -n "$f" ] && files_up+=("$f")
    done < <(git -C "$REPO_ROOT" diff --name-only --diff-filter=ACMR 2>/dev/null || true)

    # 3. Archivos nuevos sin rastrear (respetando .gitignore)
    while IFS= read -r f; do
        [ -n "$f" ] && ! is_ignored "$f" && files_up+=("$f")
    done < <(git -C "$REPO_ROOT" ls-files --others --exclude-standard 2>/dev/null || true)

    # 4. Archivos eliminados en el working tree
    while IFS= read -r f; do
        [ -n "$f" ] && files_del+=("$f")
    done < <(git -C "$REPO_ROOT" ls-files -d 2>/dev/null || true)

    # Filtrar ignorados, existencia y duplicados
    if [ ${#files_up[@]} -gt 0 ]; then
        while IFS= read -r f; do
            if [ -n "$f" ] && [ -f "$REPO_ROOT/$f" ] && ! is_ignored "$f"; then
                TO_UPLOAD+=("$f")
            fi
        done < <(printf "%s\n" "${files_up[@]}" | sort -u)
    fi

    if [ ${#files_del[@]} -gt 0 ]; then
        while IFS= read -r f; do
            if [ -n "$f" ] && [ ! -e "$REPO_ROOT/$f" ] && ! is_ignored "$f"; then
                TO_DELETE+=("$f")
            fi
        done < <(printf "%s\n" "${files_del[@]}" | sort -u)
    fi
}

show_help() {
    echo "Uso: dgit <comando> [opciones]"
    echo ""
    echo "Comandos principales:"
    echo "  status           Muestra cambios detectados por Git (modificados, nuevos, borrados) y cola"
    echo "  push, sync [-y]  Sincroniza cambios hacia Drive con confirmación previa"
    echo "  sync-all [-y]    Sube todos los archivos limpios del repositorio (respetando .gitignore)"
    echo "  pull [rutas...]  Descarga lo nuevo/modificado de Drive a local (respeta tus archivos más nuevos)"
    echo ""
    echo "Control granular / staging manual:"
    echo "  add [rutas...]   Encola manualmente rutas específicas en .drive_stage (omite ignorados por Git)"
    echo "  reset            Limpia la cola manual (.drive_stage)"
    echo ""
    echo "Mantenimiento:"
    echo "  purge-drive      Busca y borra carpetas bin/ y obj/ en Drive dinámicamente"
}

case "$1" in
    status)
        echo "=== Sincronización Google Drive ($PROJECT_NAME) ==="
        echo "Destino remoto: $REMOTE"
        if [ "$IN_GIT" = true ]; then
            branch="$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo "detached")"
            commit="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "none")"
            echo "Rama local:     $branch ($commit)"
        fi
        echo ""

        if [ -s "$STAGE_FILE" ]; then
            total=$(wc -l < "$STAGE_FILE" | tr -d ' ')
            echo "Archivos en cola manual ($total) [listos para 'dgit push']:"
            sed 's/^/  + /' "$STAGE_FILE"
            exit 0
        fi

        if [ "$IN_GIT" = true ]; then
            get_git_changes

            if [ ${#TO_UPLOAD[@]} -eq 0 ] && [ ${#TO_DELETE[@]} -eq 0 ]; then
                echo "Todo sincronizado con Google Drive respecto a Git. Nada pendiente."
                echo "(Usa 'dgit sync-all' si deseas resincronizar el repositorio completo)."
                exit 0
            fi

            if [ ${#TO_UPLOAD[@]} -gt 0 ]; then
                echo "Modificados o nuevos detectados por Git (${#TO_UPLOAD[@]}):"
                printf "  + %s\n" "${TO_UPLOAD[@]}"
            fi

            if [ ${#TO_DELETE[@]} -gt 0 ]; then
                echo "Eliminados localmente pendientes de borrar en Drive (${#TO_DELETE[@]}):"
                printf "  - %s\n" "${TO_DELETE[@]}"
            fi
            echo ""
            echo "Ejecuta 'dgit push' o 'dgit sync' para sincronizar estos cambios."
        else
            echo "Fuera de un repositorio Git. Usa 'dgit add <rutas>' para encolar archivos."
        fi
        ;;

    push|sync)
        shift
        assume_yes=false
        while [ "$#" -gt 0 ]; do
            case "$1" in
                -y|--yes) assume_yes=true; shift ;;
                *) break ;;
            esac
        done

        if [ -s "$STAGE_FILE" ]; then
            total=$(wc -l < "$STAGE_FILE" | tr -d ' ')
            echo "Archivos en cola manual ($total) listos para subir a $REMOTE:"
            sed 's/^/  + /' "$STAGE_FILE"

            if [ "$assume_yes" = false ] && [ -t 0 ]; then
                read -r -p "¿Confirmas la subida a Google Drive? [S/n] " ans
                case "$ans" in
                    [nN]*) echo "Operación cancelada."; exit 0 ;;
                esac
            fi

            echo "Subiendo $total archivo(s) a $REMOTE..."
            rclone copy "$REPO_ROOT" "$REMOTE" --files-from "$STAGE_FILE" --progress
            rm -f "$STAGE_FILE"
            upload_sync_info
            echo "Push completado exitosamente."
            exit 0
        fi

        if [ "$IN_GIT" = false ]; then
            echo "Error: fuera de Git necesitas usar 'dgit add <rutas>' primero." >&2
            exit 1
        fi

        get_git_changes

        if [ ${#TO_UPLOAD[@]} -eq 0 ] && [ ${#TO_DELETE[@]} -eq 0 ]; then
            echo "Nada pendiente por sincronizar (el árbol de trabajo está limpio)."
            echo "Usa 'dgit sync-all' si deseas sincronizar el repositorio completo."
            exit 0
        fi

        echo "Cambios detectados para sincronizar con $REMOTE:"
        if [ ${#TO_UPLOAD[@]} -gt 0 ]; then
            echo "Archivos a subir / actualizar (${#TO_UPLOAD[@]}):"
            printf "  + %s\n" "${TO_UPLOAD[@]}"
        fi
        if [ ${#TO_DELETE[@]} -gt 0 ]; then
            echo "Archivos a eliminar en Drive (${#TO_DELETE[@]}):"
            printf "  - %s\n" "${TO_DELETE[@]}"
        fi

        if [ "$assume_yes" = false ] && [ -t 0 ]; then
            read -r -p "¿Proceder con la sincronización hacia Google Drive? [S/n] " ans
            case "$ans" in
                [nN]*) echo "Sincronización cancelada."; exit 0 ;;
            esac
        fi

        if [ ${#TO_UPLOAD[@]} -gt 0 ]; then
            echo "Subiendo archivos modificados y nuevos a $REMOTE..."
            printf "%s\n" "${TO_UPLOAD[@]}" | rclone copy "$REPO_ROOT" "$REMOTE" --files-from - --progress
        fi

        if [ ${#TO_DELETE[@]} -gt 0 ]; then
            echo "Eliminando archivos borrados en $REMOTE..."
            for file in "${TO_DELETE[@]}"; do
                echo "  Eliminando en Drive: $file"
                rclone deletefile "$REMOTE/$file" 2>/dev/null || true
            done
        fi

        upload_sync_info
        echo "Sincronización completada exitosamente."
        ;;

    sync-all|sync-clean)
        shift
        assume_yes=false
        while [ "$#" -gt 0 ]; do
            case "$1" in
                -y|--yes) assume_yes=true; shift ;;
                *) break ;;
            esac
        done

        if [ "$IN_GIT" = false ]; then
            echo "Error: este comando requiere estar dentro de un repositorio Git." >&2
            exit 1
        fi

        mapfile -t all_files < <(git -C "$REPO_ROOT" ls-files -c -o --exclude-standard)
        total="${#all_files[@]}"

        echo "Se sincronizarán todos los archivos válidos del repositorio ($total archivos) a $REMOTE."
        if [ "$assume_yes" = false ] && [ -t 0 ]; then
            read -r -p "¿Confirmas la subida completa a Google Drive? [S/n] " ans
            case "$ans" in
                [nN]*) echo "Operación cancelada."; exit 0 ;;
            esac
        fi

        echo "Subiendo $total archivo(s) limpios a $REMOTE..."
        printf "%s\n" "${all_files[@]}" | rclone copy "$REPO_ROOT" "$REMOTE" --files-from - --progress
        upload_sync_info
        echo "Sincronización completa finalizada."
        ;;

    add)
        shift
        if [ "$#" -eq 0 ]; then
            if [ "$IN_GIT" = false ]; then
                echo "Error: no estás en un repositorio Git. Especifica rutas: dgit add <carpeta o archivo>" >&2
                exit 1
            fi
            get_git_changes
            for file in "${TO_UPLOAD[@]}"; do
                echo "$file" >> "$STAGE_FILE"
            done
        else
            for target in "$@"; do
                if [ -e "$target" ]; then
                    rel_target="$(realpath --relative-to="$REPO_ROOT" "$target")"
                else
                    rel_target="$target"
                fi

                if [ -f "$REPO_ROOT/$rel_target" ]; then
                    if ! is_ignored "$rel_target"; then
                        echo "$rel_target" >> "$STAGE_FILE"
                    fi
                elif [ -d "$REPO_ROOT/$rel_target" ]; then
                    find "$REPO_ROOT/$rel_target" -type f | while IFS= read -r f; do
                        rel_f="$(realpath --relative-to="$REPO_ROOT" "$f")"
                        if ! is_ignored "$rel_f"; then
                            echo "$rel_f" >> "$STAGE_FILE"
                        fi
                    done
                else
                    echo "Aviso: '$target' no existe, omitiendo." >&2
                fi
            done
        fi

        if [ -f "$STAGE_FILE" ]; then
            sort -u "$STAGE_FILE" -o "$STAGE_FILE"
            total=$(wc -l < "$STAGE_FILE" | tr -d ' ')
            echo "Staged $total archivo(s) en cola para subir a $REMOTE:"
            sed 's/^/  + /' "$STAGE_FILE"
        fi
        ;;

    reset)
        rm -f "$STAGE_FILE"
        echo "Cola manual reiniciada (.drive_stage eliminado)."
        ;;

    pull)
        shift
        echo "Descargando actualizaciones desde $REMOTE hacia tu máquina local..."
        if [ "$#" -eq 0 ]; then
            rclone copy "$REMOTE" "$REPO_ROOT" \
                --update \
                --exclude '*/bin/**' \
                --exclude '*/obj/**' \
                --exclude '*/.git/**' \
                --exclude '*/.vs/**' \
                --exclude '*/.idea/**' \
                --exclude '*.db*' \
                --exclude '.drive_*' \
                --progress
        else
            for target in "$@"; do
                if [ -e "$target" ]; then
                    rel_target="$(realpath --relative-to="$REPO_ROOT" "$target")"
                else
                    rel_target="$target"
                fi
                if [ -d "$REPO_ROOT/$rel_target" ] || [ -d "$target" ]; then
                    rclone copy "$REMOTE/$rel_target" "$REPO_ROOT/$rel_target" --update --progress
                else
                    rclone copyto "$REMOTE/$rel_target" "$REPO_ROOT/$rel_target" --update --progress
                fi
            done
        fi
        echo ""
        echo "Pull completado. Usa 'git status' o 'git diff' para revisar lo que cambió."
        ;;

    purge-drive)
        echo "Buscando y eliminando carpetas bin/ y obj/ en $REMOTE..."
        # 1. Elimina todos los archivos dentro de cualquier carpeta bin/ u obj/ en cualquier nivel y quita directorios vacíos
        rclone delete "$REMOTE" \
            --include "**/bin/**" \
            --include "**/obj/**" \
            --include "bin/**" \
            --include "obj/**" \
            --rmdirs \
            --progress

        # 2. Por seguridad adicional, descubrir carpetas de proyectos y asegurar purga en Drive
        if [ -d "$REPO_ROOT" ]; then
            while IFS= read -r proj_dir; do
                rel="$(realpath --relative-to="$REPO_ROOT" "$proj_dir")"
                if [ "$rel" != "." ] && ! is_ignored "$rel"; then
                    rclone purge "$REMOTE/$rel/bin" 2>/dev/null || true
                    rclone purge "$REMOTE/$rel/obj" 2>/dev/null || true
                fi
            done < <(find "$REPO_ROOT" -maxdepth 3 \( -name "*.*proj" -o -type d \( -name "bin" -o -name "obj" \) \) -not -path "*/.*" -exec dirname {} \; 2>/dev/null | sort -u)
        fi
        rclone purge "$REMOTE/bin" 2>/dev/null || true
        rclone purge "$REMOTE/obj" 2>/dev/null || true

        echo "Limpieza remota terminada."
        ;;

    help|-h|--help|"")
        show_help
        ;;

    *)
        show_help
        exit 1
        ;;
esac
