#!/bin/sh
# asus-turbo-guard — sin sondeo: reacciona a eventos.
#   Escucha power-profiles-daemon (D-Bus, lo que usa Caelestia) y cambios de corriente
#   (udev, power_supply). Reafirma las palancas que asusd pisa al cambiar de perfil:
#     no_turbo: 1 solo con bateria Y perfil de ahorro
#     EPP:      power / balance_power / performance segun perfil
#   El valor queda persistido en el kernel hasta el siguiente evento.
set -u

NO_TURBO=${NO_TURBO:-/sys/devices/system/cpu/intel_pstate/no_turbo}
PLATFORM=${PLATFORM:-/sys/firmware/acpi/platform_profile}
POWER_SUPPLY=${POWER_SUPPLY:-/sys/class/power_supply}
EPP_GLOB=${EPP_GLOB:-/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference}
DEBOUNCE=${DEBOUNCE:-2}

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

epp_for() {
    case "$1" in
        power-saver|quiet|low-power) echo power ;;
        balanced) echo balance_power ;;
        performance) echo performance ;;
    esac
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
    if on_ac; then ac=1; else ac=0; fi
    state="ac=$ac perfil=$prof"

    if [ "$ac" = 0 ] && is_low "$prof"; then want=1; else want=0; fi
    if [ "$want" != "$last" ]; then
        if echo "$want" > "$NO_TURBO"; then
            log "$state -> no_turbo=$want"
            last=$want
        else
            log "fallo escribiendo no_turbo=$want"
        fi
    fi

    epp=$(epp_for "$prof")
    [ -n "$epp" ] || return 0
    changed=
    for f in $EPP_GLOB; do
        [ -r "$f" ] || continue
        [ "$(cat "$f" 2>/dev/null)" = "$epp" ] && continue
        echo "$epp" > "$f" 2>/dev/null && changed=1
    done
    [ -n "$changed" ] && log "$state -> epp=$epp"
    return 0
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
