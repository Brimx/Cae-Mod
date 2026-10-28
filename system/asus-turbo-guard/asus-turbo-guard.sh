#!/bin/sh
# asus-turbo-guard — sin sondeo: reacciona a eventos.
#   Escucha power-profiles-daemon (D-Bus, lo que usa Caelestia) y cambios de corriente
#   (udev, power_supply). Recalcula y fija no_turbo:
#     bateria + perfil de ahorro -> 1 (turbo off)
#     enchufado o perfil balanced/performance -> 0
#   El valor queda persistido en el kernel hasta el siguiente evento.
set -u

NO_TURBO=${NO_TURBO:-/sys/devices/system/cpu/intel_pstate/no_turbo}
PLATFORM=${PLATFORM:-/sys/firmware/acpi/platform_profile}
POWER_SUPPLY=${POWER_SUPPLY:-/sys/class/power_supply}
DEBOUNCE=${DEBOUNCE:-1}

log() { logger -t asus-turbo-guard "$*"; }

profile() {
    # D-Bus directo (~4 ms) en vez de powerprofilesctl (~240 ms, script Python)
    if command -v busctl >/dev/null 2>&1; then
        p=$(busctl get-property net.hadess.PowerProfiles /net/hadess/PowerProfiles \
            net.hadess.PowerProfiles ActiveProfile 2>/dev/null)
        p=${p#*\"}
        p=${p%\"*}
        [ -n "$p" ] && { echo "$p"; return; }
    fi
    if command -v powerprofilesctl >/dev/null 2>&1; then
        p=$(powerprofilesctl get 2>/dev/null) && [ -n "$p" ] && { echo "$p"; return; }
    fi
    cat "$PLATFORM" 2>/dev/null
}

is_low() {
    case "$1" in
        power-saver|quiet|low-power) return 0 ;;
    esac
    return 1
}

# 0 = con bateria, 1 = enchufado (si no hay fuente Mains, se asume enchufado)
on_ac() {
    for s in "$POWER_SUPPLY"/*; do
        [ -r "$s/type" ] || continue
        [ "$(cat "$s/type" 2>/dev/null)" = "Mains" ] || continue
        [ "$(cat "$s/online" 2>/dev/null)" = "1" ] && return 0
    done
    return 1
}

last=
apply() {
    prof=$(profile)
    plat=$(cat "$PLATFORM" 2>/dev/null)
    if on_ac; then ac=1; else ac=0; fi
    if [ "$ac" = 0 ] && { is_low "$prof" || is_low "$plat"; }; then want=1; else want=0; fi
    [ "$want" = "$last" ] && return 0
    if echo "$want" > "$NO_TURBO"; then
        log "ac=$ac perfil=$prof platform=$plat -> no_turbo=$want"
        last=$want
    else
        log "fallo escribiendo no_turbo=$want"
    fi
}

if [ ! -w "$NO_TURBO" ]; then
    log "sin acceso a $NO_TURBO, salgo"
    exit 1
fi

fifo=$(mktemp -u /tmp/asus-turbo-guard.XXXXXX)
mkfifo "$fifo" || exit 1
trap 'rm -f "$fifo"' EXIT INT TERM

# Estado inicial (arranque / reinicio del servicio)
apply

busctl monitor net.hadess.PowerProfiles --json=short >"$fifo" 2>/dev/null &
udevadm monitor --subsystem-match=power_supply --udev >"$fifo" 2>/dev/null &

while read -r _; do
    sleep "$DEBOUNCE"
    apply
done <"$fifo"

log "fuentes de eventos cerradas, salgo"
exit 0
