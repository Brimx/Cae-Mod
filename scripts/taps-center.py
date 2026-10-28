#!/usr/bin/env python3
"""taps-center.py — tap 4 dedos (centro) -> play/pause, timing tolerante.

Lee el "Bezel Virtual Trackpad" (bezel hace grab exclusivo del físico y
re-emite limpio, incluyendo BTN_TOOL_* correctos). Solo cuenta dedos en la
zona CENTRAL (fuera de los bordes de bezel) para no duplicar los taps por
zona de bezel (left.tap=mute, bottom.tap=play/pause, top.tap=overview).

Diferencias vs el viejo trackpad-edges.py:
- Ventana 600ms (no 300) + conteo por SOLAPE (max dedos vistos, no
  simultaneidad exacta de apoyo/liberación).
- Umbral de movimiento: si algún dedo se mueve > MOVE_TOL se cancela.
- Rutas absolutas + FileNotFoundError manejado (el viejo caía en
  "Device lost ... reconnecting" cada vez que faltaba playerctl).
- EventsDroppedException resetea estado en vez de crashear el servicio.
- Ignora <=3 dedos (el tap 3 dedos = clic central lo maneja libinput con
  tap_button_map=lrm en config/hypr/input.lua) e ignora >=5.
"""
import glob
import libevdev
import signal
import subprocess
import sys
import time

# Bezel usa zonas de 5%: ignorar toques que empiecen en bordes.
EDGE = 0.05
TAP_FINGERS = 4
TAP_MAX_MS = 600
MOVE_TOL = 0.04  # fracción del rango total
DEBOUNCE_MS = 800

PLAYERCTL = "/usr/bin/playerctl"


def log(*args):
    print(*args, file=sys.stderr, flush=True)


def find_virtual():
    for ev in glob.glob("/dev/input/event*"):
        try:
            with open(ev, "rb") as fd:
                dev = libevdev.Device(fd)
                if dev.name == "Bezel Virtual Trackpad":
                    return ev
        except OSError:
            pass
    return None


def run(cmd):
    try:
        r = subprocess.run(cmd, capture_output=True, timeout=10)
        if r.returncode != 0:
            log(f"cmd falló ({r.returncode}): {' '.join(cmd)} {r.stderr.decode()[:200]}")
    except FileNotFoundError:
        log(f"binario ausente, no se reintenta device por esto: {cmd[0]}")
    except Exception as e:  # noqa: BLE001
        log(f"error ejecutando {' '.join(cmd)}: {e}")


def main():
    last_fire = 0.0
    while True:
        device = find_virtual()
        if not device:
            log("Sin Bezel Virtual Trackpad, reintento en 3s (¿bezel.service activo?)")
            time.sleep(3)
            continue
        try:
            fd = open(device, "rb")
            dev = libevdev.Device(fd)
        except OSError as e:
            log(f"No se pudo abrir {device}: {e}")
            time.sleep(3)
            continue

        try:
            ax = dev.absinfo[libevdev.EV_ABS.ABS_MT_POSITION_X]
            ay = dev.absinfo[libevdev.EV_ABS.ABS_MT_POSITION_Y]
            xmin, xmax, ymin, ymax = ax.minimum, ax.maximum, ay.minimum, ay.maximum
            xr, yr = max(1, xmax - xmin), max(1, ymax - ymin)
        except Exception as e:  # noqa: BLE001
            log(f"Sin ejes MT en {device}: {e}")
            time.sleep(3)
            continue

        log(f"Leyendo {device} ({dev.name})")
        slots = {}          # slot -> dict(x0,y0,x,y)
        first_down = None
        max_seen = 0
        moved = False
        invalid = False   # True si algún dedo empezó en borde bezel

        try:
            for e in dev.events():
                if e.matches(libevdev.EV_ABS.ABS_MT_TRACKING_ID):
                    slot = e.slot if hasattr(e, "slot") else 0
                    if e.value >= 0:
                        if slot not in slots:
                            slots[slot] = {"x0": None, "y0": None,
                                           "x": None, "y": None}
                        if first_down is None:
                            first_down = time.monotonic()
                            max_seen = 0
                            moved = False
                            invalid = False
                        max_seen = max(max_seen, len(slots))
                    else:
                        slots.pop(slot, None)
                        if not slots:
                            if first_down is not None:
                                elapsed = (time.monotonic() - first_down) * 1000
                                if (max_seen == TAP_FINGERS and elapsed < TAP_MAX_MS
                                        and not moved and not invalid):
                                    now = time.monotonic() * 1000
                                    if now - last_fire > DEBOUNCE_MS:
                                        last_fire = now
                                        log(f"tap 4 dedos ({elapsed:.0f}ms) -> play-pause")
                                        run([PLAYERCTL, "play-pause"])
                            first_down = None
                    continue
                if e.matches(libevdev.EV_ABS.ABS_MT_POSITION_X):
                    slot = e.slot if hasattr(e, "slot") else 0
                    s = slots.get(slot)
                    if s is None:
                        continue
                    s["x"] = e.value
                    if s["x0"] is None:
                        s["x0"] = e.value
                    elif abs(e.value - s["x0"]) / xr > MOVE_TOL:
                        moved = True
                elif e.matches(libevdev.EV_ABS.ABS_MT_POSITION_Y):
                    slot = e.slot if hasattr(e, "slot") else 0
                    s = slots.get(slot)
                    if s is None:
                        continue
                    s["y"] = e.value
                    if s["y0"] is None:
                        s["y0"] = e.value
                        ny = (e.value - ymin) / yr
                        nx = ((s["x"] if s["x"] is not None else xmin) - xmin) / xr
                        if ny < EDGE or ny > 1 - EDGE or nx < EDGE or nx > 1 - EDGE:
                            # Empezó en borde bezel: ese gesto es de bezel,
                            # no contar como tap central.
                            invalid = True
                    elif abs(e.value - s["y0"]) / yr > MOVE_TOL:
                        moved = True
                elif e.matches(libevdev.EV_KEY.BTN_TOUCH):
                    if e.value == 0:
                        slots.clear()
                        first_down = None
        except libevdev.device.EventsDroppedException:
            log("SYN_DROPPED: reseteo estado (sin crash)")
            slots.clear()
            first_down = None
            continue
        except OSError as e:
            log(f"Device perdido: {e}, reconexión en 2s")
            try:
                fd.close()
            except Exception:  # noqa: BLE001
                pass
            time.sleep(2)
            continue


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    main()
