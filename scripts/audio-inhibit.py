#!/usr/bin/env python3
"""Inhibe idle (lock/dpms/suspend) en ventanas con audio activo.

Vigila PipeWire (sink-inputs = reproducción, source-outputs = mic).
Si el PID de una ventana tiene un stream RUNNING, le aplica
`hyprctl setprop idleinhibit always`; al silenciarse lo revierte a `none`.

Seguridad ante reglas de archivo (rules.lua): nunca toca ventanas que ya
están inhibiendo por regla propia (video, juegos, wine, firefox) — solo
gestiona ventanas cuyo estado natural es `none` y recuerda cuáles tocó.
"""
import json
import re
import subprocess
import sys
import time

POLL_SEC = 2

# Clases cubiertas por rules.lua (idle_inhibit por regla): no tocar.
RULED_CLASSES = re.compile(
    r"^(firefox|com\.stremio\.stremio|stremio|celluloid|mpv|"
    r"steam_app_([a-z]+|[0-9]+)|gamescope|steam_proton|"
    r"com\.usebottles\.bottles|bottles|wine.*|proton.*|.*\.exe)$"
)

# Binarios de sistema: su audio no representa uso del usuario.
SYSTEM_BINARIES = {
    "pipewire", "wireplumber", "pulseaudio", "pipewire-pulse",
    "speech-dispatcher", "mpris-proxy",
}


def run(*args):
    return subprocess.run(args, capture_output=True, text=True)


def running_audio_pids():
    """PIDs con streams activos en PipeWire (vía pactl).

    Nota: pactl sobre PipeWire no muestra `State:`, sino `Corked: yes/no`.
    Activo = Corked:no (sonando o capturando ahora mismo).
    """
    pids = set()
    for section in ("sink-inputs", "source-outputs"):
        out = run("pactl", "list", section).stdout
        corked, pid, binary = None, None, None

        def flush():
            if corked is False and pid and binary not in SYSTEM_BINARIES:
                pids.add(pid)

        for line in out.splitlines():
            s = line.strip()
            if re.match(r"^(Sink Input|Source Output) #\d+", s):
                flush()
                corked, pid, binary = None, None, None
            elif s.startswith("Corked:"):
                corked = s.endswith("yes")
            elif s.startswith("application.process.id"):
                pid = int(s.split("=", 1)[1].strip().strip('"'))
            elif s.startswith("application.process.binary"):
                binary = s.split("=", 1)[1].strip().strip('"')
        flush()
    return pids


def clients():
    out = run("hyprctl", "clients", "-j").stdout
    try:
        return json.loads(out or "[]")
    except json.JSONDecodeError:
        return []


def set_inhibit(address, inhibit):
    """Etiqueta/desetiqueta la ventana vía `hyprctl eval` (setprop no existe
    en este build y `keyword` lo rechaza el parser de Caelestia)."""
    sign = "+" if inhibit else "-"
    action = (
        f'hl.dispatch(hl.dsp.window.tag({{ tag = "{sign}audio_active", '
        f'window = "address:{address}" }}))'
    )
    r = run("hyprctl", "eval", action)
    if r.returncode != 0 or r.stderr.strip().startswith("error:"):
        print(f"tag {address} falló: {r.stderr.strip()}", file=sys.stderr)
        return False
    return True


def main():
    managed = set()  # addresses que inhibimos nosotros
    while True:
        try:
            pids = running_audio_pids()
            wins = clients()
            by_addr = {w["address"]: w for w in wins}

            # Altas: ventanas sonando, sin inhibición propia y no gestionadas
            for w in wins:
                addr = w["address"]
                if (
                    w.get("pid") in pids
                    and not w.get("inhibitingIdle")
                    and addr not in managed
                    and not RULED_CLASSES.match(w.get("class") or "")
                ):
                    if set_inhibit(addr, True):
                        managed.add(addr)
                        print(f"inhibit {w.get('class')}: {addr}", flush=True)

            # Bajas: gestionadas que ya no suenan o desaparecieron
            sounding_addrs = {w["address"] for w in wins if w.get("pid") in pids}
            for addr in list(managed):
                if addr not in sounding_addrs or addr not in by_addr:
                    if addr in by_addr:
                        set_inhibit(addr, False)
                        print(f"release {by_addr[addr].get('class')}: {addr}", flush=True)
                    managed.discard(addr)
        except Exception as e:  # noqa: BLE001 - el daemon no debe morir
            print(f"error: {e}", file=sys.stderr)
        time.sleep(POLL_SEC)


if __name__ == "__main__":
    main()
