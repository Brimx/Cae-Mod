#!/bin/sh
# asus-turbo-guard — sin sondeo: reacciona a eventos.
#   Escucha power-profiles-daemon (D-Bus, lo que usa Caelestia) y cambios de corriente
#   (udev, power_supply). Reafirma las palancas que asusd pisa al cambiar de perfil:
#     no_turbo: 1 solo con bateria Y perfil de ahorro
#     EPP:      power / balance_power / performance segun perfil
#   El valor queda persistido en el kernel hasta el siguiente evento; ademas un tick
#   lento (SAFETY_INTERVAL) reafirma por si un tercero lo pisa sin avisar.
set -u

NO_TURBO=${NO_TURBO:-/sys/devices/system/cpu/intel_pstate/no_turbo}
PLATFORM=${PLATFORM:-/sys/firmware/acpi/platform_profile}
POWER_SUPPLY=${POWER_SUPPLY:-/sys/class/power_supply}
EPP_GLOB=${EPP_GLOB:-/sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference}
DEBOUNCE=${DEBOUNCE:-2}
# Reafirmacion periodica de seguridad, en segundos. No es sondeo por evento: existe
# porque el estado (EPP/no_turbo) puede quedar pisado en silencio por un tercero sin
# emitir ninguna senal. 0 lo desactiva.
SAFETY_INTERVAL=${SAFETY_INTERVAL:-30}
# Perfil por fuente. ppd sigue siendo el dueno: aqui solo se le pide por D-Bus
# el perfil que corresponde a AC/bateria. SWITCH_PROFILE=0 respeta la eleccion manual.
SWITCH_PROFILE=${SWITCH_PROFILE:-1}
PROFILE_AC=${PROFILE_AC:-performance}
PROFILE_BAT=${PROFILE_BAT:-power-saver}

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

set_profile() {
    [ "$SWITCH_PROFILE" = 1 ] || return 0
    [ "$1" = "$prof" ] && return 0
    if busctl set-property net.hadess.PowerProfiles /net/hadess/PowerProfiles \
        net.hadess.PowerProfiles ActiveProfile s "$1" 2>/dev/null; then
        log "perfil $prof -> $1 (fuente ac=$ac)"
        prof=$1
    else
        log "no se pudo pedir el perfil $1 a ppd"
    fi
}

last=
last_ac=
apply() {
    prof=$(profile)
    if on_ac; then ac=1; else ac=0; fi
    # Solo en transiciones de fuente (enchufar/desenchufar): asi no se pisa la
    # eleccion manual del perfil mientras la fuente no cambie.
    if [ "$ac" != "$last_ac" ]; then
        if [ "$ac" = 1 ]; then set_profile "$PROFILE_AC"; else set_profile "$PROFILE_BAT"; fi
        last_ac=$ac
    fi
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
mon_pids=

# Salida limpia: matar los monitores (udevadm ignora SIGTERM, hay que forzarlo) y
# salir. Sin el exit explicito, SIGTERM deja el read bloqueado y systemd espera 90 s.
cleanup() {
    trap - EXIT INT TERM
    for p in $mon_pids; do kill -TERM "$p" 2>/dev/null; done
    sleep 1
    for p in $mon_pids; do kill -KILL "$p" 2>/dev/null; done
    rm -f "$fifo"
    exit 0
}
trap cleanup EXIT INT TERM

# Estado inicial (arranque / reinicio del servicio)
apply

# Solo las SENALES de ppd. `busctl monitor <servicio>` a secas es una trampa: como el
# servicio corre como root, se lleva el bus ENTERO (eavesdrop) y ademas reentra con sus
# propias consultas, asi que el fifo acumula decenas de miles de eventos (medido: 4,3%
# de lo capturado tenia que ver con ppd) y el guard quema ~2% de un core de forma
# permanente. El --match acota la suscripcion a lo unico que importa: que cambie el perfil.
busctl monitor --match='type=signal,interface=net.hadess.PowerProfiles' --json=short >"$fifo" 2>/dev/null &
mon_pids="$mon_pids $!"
udevadm monitor --subsystem-match=power_supply --udev >"$fifo" 2>/dev/null &
mon_pids="$mon_pids $!"
if [ "$SAFETY_INTERVAL" -gt 0 ]; then
    ( while :; do sleep "$SAFETY_INTERVAL"; echo tick; done ) >"$fifo" 2>/dev/null &
    mon_pids="$mon_pids $!"
fi

while read -r _; do
    sleep "$DEBOUNCE"
    apply
done <"$fifo"

log "fuentes de eventos cerradas, salgo"
exit 0
