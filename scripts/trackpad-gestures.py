#!/usr/bin/env python3
"""trackpad-gestures.py — daemon unificado de gestos de bordes + taps.

Reemplaza a bezel (solo swipe discreto, sin slide) y a los daemons
anteriores (trackpad-edges.py frágil + taps-center.py atado al virtual
de bezel). Lee el touchpad FÍSICO directo, sin grab exclusivo.

- Bordes izq/der: SLIDE vertical continuo (cada STEP px = ±5%).
  Mantener deslizado sigue subiendo/bajando (volumen/brillo).
- Borde sup: slide horizontal continuo (seek ±5s por STEP).
- Borde inf: swipe horizontal discreto al soltar (prev/next).
- Taps 1 dedo en borde (<200ms, sin moverse): izq=mute, sup=overview,
  inf=play-pause.
- Tap 4 dedos centro (<600ms, conteo por solape): play-pause.
  Tap 3 dedos = clic central vía libinput (tap_button_map=lrm en
  config/hypr/input.lua), no se toca acá.

Zonas 5% contra disparos de palma. Sin notificaciones.
Rutas absolutas: systemd tiene PATH mínimo (causa raíz del viejo
"Device lost ... reconnecting" cuando faltaba playerctl).
"""
import glob
import libevdev
import signal
import subprocess
import sys
import time

EDGE = 0.05
STEP = 75              # px por paso de slide
TAP_MAX_MS = 200       # tap 1 dedo en borde
TAP4_MAX_MS = 600      # tap 4 dedos centro
MOVE_TOL = 0.04        # fracción del rango: más que esto no es tap
DEBOUNCE_TAP_MS = 300
DEBOUNCE_TAP4_MS = 800
BOTTOM_SWIPE_PX = 150  # umbral discreto prev/next al soltar
SLIDE_DEADZONE = 40    # px iniciales ignorados: el slide "engancha" después
DIR_RATIO = 2.0        # direction-lock: el eje principal debe dominar 2:1,
                       # si no, es diagonal/roce y NO dispara slide

WPCTL = "/usr/bin/wpctl"
QS = "/usr/bin/qs"
BRIGHT = "/usr/bin/brightnessctl"
PLAYERCTL = "/usr/bin/playerctl"
UDEVADM = "/usr/bin/udevadm"
SINK = "@DEFAULT_AUDIO_SINK@"


def log(*args):
    print(*args, file=sys.stderr, flush=True)


def find_touchpad():
    for ev in glob.glob("/dev/input/event*"):
        try:
            info = subprocess.run(
                [UDEVADM, "info", "--query=property", "--name=" + ev],
                capture_output=True, text=True, timeout=5,
            )
            if ("ID_INPUT_TOUCHPAD=1" in info.stdout
                    and "Bezel" not in info.stdout
                    and "keyd" not in info.stdout):
                return ev
        except Exception:  # noqa: BLE001
            pass
    return None


def run(*args):
    try:
        r = subprocess.run(list(args), capture_output=True, timeout=10)
        if r.returncode != 0:
            log(f"cmd rc={r.returncode}: {' '.join(args)} {r.stderr.decode()[:200]}")
    except FileNotFoundError:
        log(f"binario ausente (no se tumba el device): {args[0]}")
    except Exception as e:  # noqa: BLE001
        log(f"error ejecutando {' '.join(args)}: {e}")


def vol(up):
    run(WPCTL, "set-volume", "-l", "1.0", SINK, f"5%{'+' if up else '-'}")


def bright(up):
    val = "+5%" if up else "5%-"
    try:
        r = subprocess.run([QS, "ipc", "-c", "caelestia", "call",
                            "brightness", "setFor", "active", val],
                           capture_output=True, timeout=10)
        if r.returncode != 0:
            run(BRIGHT, "s", f"5%{'+' if up else '-'}")
    except FileNotFoundError:
        log(f"binario ausente (no se tumba el device): {QS}")
    except Exception as e:  # noqa: BLE001
        log(f"error brillo: {e}")


def seek(fwd):
    run(PLAYERCTL, "position", f"{'+' if fwd else '-'}5")


def zone_of(x, y, xmin, xmax, ymin, ymax):
    w, h = xmax - xmin, ymax - ymin
    nx, ny = (x - xmin) / w, (y - ymin) / h
    if nx < EDGE:
        return "left"
    if nx > 1 - EDGE:
        return "right"
    if ny < EDGE:
        return "top"
    if ny > 1 - EDGE:
        return "bottom"
    return None


class Session:
    """Una sesión = desde que apoya el 1er dedo hasta soltar todos."""

    def __init__(self, xmin, xmax, ymin, ymax):
        self.xmin, self.xmax, self.ymin, self.ymax = xmin, xmax, ymin, ymax
        self.xr = max(1, xmax - xmin)
        self.yr = max(1, ymax - ymin)
        self.t0 = time.monotonic()
        self.count = 0          # dedos activos ahora
        self.max_seen = 0       # solape: máximo simultáneo visto
        self.x0 = self.y0 = None
        self.x = self.y = None
        self.zone = None        # zona del punto inicial (1 dedo)
        self.acc = 0            # acumulador slide (px desde x0/y0)
        self.slide_ok = True    # direction-lock: False = diagonal/roce
        self.engaged = False    # True cuando supera el deadzone inicial

    def feed_pos(self, x, y):
        if x is not None:
            self.x = x
            if self.x0 is None:
                self.x0 = x
        if y is not None:
            self.y = y
            if self.y0 is None:
                self.y0 = y
        if self.zone is None and self.x0 is not None and self.y0 is not None:
            self.zone = zone_of(self.x0, self.y0,
                                self.xmin, self.xmax, self.ymin, self.ymax)

    @property
    def elapsed_ms(self):
        return (time.monotonic() - self.t0) * 1000

    def displacement(self):
        """(dx, dy) totales en px desde el punto inicial (None si falta dato)."""
        if None in (self.x0, self.y0, self.x, self.y):
            return None, None
        return self.x - self.x0, self.y - self.y0

    def check_direction(self, axis):
        """Direction-lock: si el eje secundario compite con el principal
        (ratio peor que DIR_RATIO con mínimo 20px), invalida el slide de
        la sesión. axis='y' para bordes izq/der, 'x' para sup."""
        dx, dy = self.displacement()
        if dx is None:
            return
        if axis == "y":
            prim, sec = abs(dy), abs(dx)
        else:
            prim, sec = abs(dx), abs(dy)
        if sec > 20 and sec * DIR_RATIO > prim:
            self.slide_ok = False

    def engage(self, axis):
        """El slide solo engancha tras SLIDE_DEADZONE px en el eje.
        Al enganchar, acc salta al punto actual (sin disparo inicial)."""
        dx, dy = self.displacement()
        if dx is None:
            return False
        raw = dy if axis == "y" else dx
        if not self.engaged and abs(raw) >= SLIDE_DEADZONE:
            self.engaged = True
            self.acc = raw
        return self.engaged

    def moved_frac(self):
        if None in (self.x0, self.y0, self.x, self.y):
            return 0.0
        dx = abs(self.x - self.x0) / self.xr
        dy = abs(self.y - self.y0) / self.yr
        return max(dx, dy)


def main():
    last_tap = 0.0
    last_tap4 = 0.0
    while True:
        device = find_touchpad()
        if not device:
            log("Sin touchpad físico, reintento en 3s")
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
        except Exception as e:  # noqa: BLE001
            log(f"Sin ejes MT en {device}: {e}")
            time.sleep(3)
            continue
        xmin, xmax, ymin, ymax = ax.minimum, ax.maximum, ay.minimum, ay.maximum
        log(f"Leyendo {device} ({dev.name})")

        sess = None
        cur = {}  # slot -> [x, y]
        try:
            for e in dev.events():
                if e.matches(libevdev.EV_ABS.ABS_MT_TRACKING_ID):
                    slot = e.slot if hasattr(e, "slot") else 0
                    if e.value >= 0:
                        cur[slot] = [None, None]
                        if sess is None:
                            sess = Session(xmin, xmax, ymin, ymax)
                        sess.count = len(cur)
                        sess.max_seen = max(sess.max_seen, len(cur))
                    else:
                        cur.pop(slot, None)
                        if sess is not None:
                            sess.count = len(cur)
                            if not cur:
                                now = time.monotonic() * 1000
                                n = sess.max_seen
                                if n == 1 and sess.zone == "bottom":
                                    dx, dy = sess.displacement()
                                    dx = dx or 0
                                    dy = dy or 0
                                    if (abs(dx) >= BOTTOM_SWIPE_PX
                                            and abs(dx) >= DIR_RATIO * abs(dy)):
                                        run(PLAYERCTL,
                                            "next" if dx > 0 else "previous")
                                    elif (sess.elapsed_ms < TAP_MAX_MS
                                            and sess.moved_frac() < MOVE_TOL
                                            and now - last_tap > DEBOUNCE_TAP_MS):
                                        last_tap = now
                                        run(PLAYERCTL, "play-pause")
                                elif (n == 1 and sess.zone in ("left", "right", "top")
                                        and sess.elapsed_ms < TAP_MAX_MS
                                        and sess.moved_frac() < MOVE_TOL
                                        and now - last_tap > DEBOUNCE_TAP_MS):
                                    last_tap = now
                                    if sess.zone == "left":
                                        run(WPCTL, "set-mute", SINK, "toggle")
                                    elif sess.zone == "top":
                                        run(QS, "ipc", "-c", "overview",
                                            "call", "overview", "toggle")
                                elif (n == 4 and sess.zone is None
                                        and sess.elapsed_ms < TAP4_MAX_MS
                                        and sess.moved_frac() < MOVE_TOL
                                        and now - last_tap4 > DEBOUNCE_TAP4_MS):
                                    last_tap4 = now
                                    log(f"tap 4 dedos ({sess.elapsed_ms:.0f}ms)"
                                        " -> play-pause")
                                    run(PLAYERCTL, "play-pause")
                                sess = None
                    continue

                slot = e.slot if hasattr(e, "slot") else 0
                if slot not in cur or sess is None:
                    continue
                if e.matches(libevdev.EV_ABS.ABS_MT_POSITION_X):
                    cur[slot][0] = e.value
                elif e.matches(libevdev.EV_ABS.ABS_MT_POSITION_Y):
                    cur[slot][1] = e.value
                else:
                    continue
                if len(cur) != 1 or sess.max_seen != 1:
                    continue  # slide solo con 1 dedo todo el tiempo
                sess.feed_pos(cur[slot][0], cur[slot][1])
                if not sess.slide_ok:
                    continue
                if sess.zone in ("left", "right"):
                    sess.check_direction("y")
                    if not sess.slide_ok or not sess.engage("y"):
                        continue
                    if sess.zone == "left":
                        while sess.y - sess.y0 - sess.acc <= -STEP:
                            vol(True)
                            sess.acc -= STEP
                        while sess.y - sess.y0 - sess.acc >= STEP:
                            vol(False)
                            sess.acc += STEP
                    else:
                        while sess.y - sess.y0 - sess.acc <= -STEP:
                            bright(True)
                            sess.acc -= STEP
                        while sess.y - sess.y0 - sess.acc >= STEP:
                            bright(False)
                            sess.acc += STEP
                elif sess.zone == "top":
                    sess.check_direction("x")
                    if not sess.slide_ok or not sess.engage("x"):
                        continue
                    while sess.x - sess.x0 - sess.acc >= STEP:
                        seek(True)
                        sess.acc += STEP
                    while sess.x - sess.x0 - sess.acc <= -STEP:
                        seek(False)
                        sess.acc -= STEP
        except libevdev.device.EventsDroppedException:
            log("SYN_DROPPED: reseteo estado (sin crash)")
            sess, cur = None, {}
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
