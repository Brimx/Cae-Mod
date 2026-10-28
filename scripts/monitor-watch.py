#!/usr/bin/env python3
"""Recupera monitores atorados en 0x0 (bug conocido de Hyprland 0.56).

Hyprland a veces crea un output con width==0 (EDID sin modos, hotplug sin
regla, standby) y nunca lo renegocia: ni reload manual lo arregla solo si
nadie lo pide. Este watcher detecta monitores habilitados con width == 0
y lanza `hyprctl reload` para forzar la renegociación.

Anti-bucle: cooldown entre reloads y backoff — si tras 3 reloads seguidos
el monitor sigue en 0x0, deja de recargar y solo avisa en el log hasta que
el set de monitores cambie (replug) o el 0x0 desaparezca.
"""
import json
import subprocess
import sys
import time

POLL_SEC = 3
COOLDOWN_SEC = 15
MAX_TRIES = 3


def run(*args):
    return subprocess.run(args, capture_output=True, text=True)


def stuck_monitors():
    """Nombres de monitores habilitados con width == 0."""
    try:
        monitors = json.loads(run("hyprctl", "monitors", "-j").stdout or "[]")
    except json.JSONDecodeError:
        return []
    return [
        m["name"]
        for m in monitors
        if not m.get("disabled") and m.get("width", -1) == 0
    ]


def signature():
    """Huella del set actual (para resetear el backoff al cambiar algo)."""
    try:
        monitors = json.loads(run("hyprctl", "monitors", "-j").stdout or "[]")
    except json.JSONDecodeError:
        return ""
    return ",".join(sorted(m.get("name", "?") for m in monitors))


def main():
    tries = 0
    last_sig = ""
    gave_up = False
    while True:
        try:
            sig = signature()
            if sig != last_sig:
                last_sig = sig
                tries = 0
                gave_up = False
            stuck = stuck_monitors()
            if stuck and not gave_up:
                if tries < MAX_TRIES:
                    tries += 1
                    print(f"0x0 detectado en {stuck}, reload ({tries}/{MAX_TRIES})", flush=True)
                    run("hyprctl", "reload")
                    time.sleep(COOLDOWN_SEC)
                    continue
                print(f"0x0 persiste en {stuck}, backoff hasta replug", flush=True)
                gave_up = True
        except Exception as e:  # noqa: BLE001 - el daemon no debe morir
            print(f"error: {e}", file=sys.stderr)
        time.sleep(POLL_SEC)


if __name__ == "__main__":
    main()
