#!/usr/bin/env python3
import libevdev, os, subprocess, sys, signal, glob

LEFT_ZONE  = 0.12
RIGHT_ZONE = 0.12
TOP_ZONE   = 0.08
STEP       = 100
VOL_STEP   = "5%"
BRIGHT_STEP = "5%"
MEDIA_SEEK = 5

def find_touchpad():
    for ev in glob.glob("/dev/input/event*"):
        try:
            info = subprocess.run(
                ["udevadm", "info", "--query=property", "--name=" + ev],
                capture_output=True, text=True
            )
            if "ID_INPUT_TOUCHPAD=1" in info.stdout:
                return ev
        except: pass
    return None

def bounds(dev):
    ax = dev.absinfo[libevdev.EV_ABS.ABS_MT_POSITION_X]
    ay = dev.absinfo[libevdev.EV_ABS.ABS_MT_POSITION_Y]
    return ax.minimum, ax.maximum, ay.minimum, ay.maximum

def zone(x, y, xmin, xmax, ymin, ymax):
    w, h = xmax - xmin, ymax - ymin
    if y < ymin + h * TOP_ZONE:  return "top"
    if x < xmin + w * LEFT_ZONE: return "left"
    if x > xmax - w * RIGHT_ZONE: return "right"
    return None

def run(*args):
    subprocess.run(args, capture_output=True)

def main():
    device = find_touchpad()
    if not device:
        print("No touchpad found", file=sys.stderr)
        sys.exit(1)

    fd = open(device, "rb")
    dev = libevdev.Device(fd)
    xmin, xmax, ymin, ymax = bounds(dev)

    cur_x = cur_y = None
    active = None
    acc = 0

    for e in dev.events():
        if e.matches(libevdev.EV_ABS.ABS_MT_POSITION_X):
            cur_x = e.value
        elif e.matches(libevdev.EV_ABS.ABS_MT_POSITION_Y):
            cur_y = e.value
        elif e.matches(libevdev.EV_ABS.ABS_MT_TRACKING_ID):
            if e.value == -1:
                active = None; acc = 0
            continue
        elif e.matches(libevdev.EV_KEY.BTN_TOUCH):
            if e.value == 0:
                active = None; acc = 0
            continue
        else:
            continue
        if None in (cur_x, cur_y): continue

        if active is None:
            active = zone(cur_x, cur_y, xmin, xmax, ymin, ymax) or "none"
            acc = cur_y if active in ("left", "right") else cur_x
            continue
        if active == "none": continue

        pos = cur_y if active in ("left", "right") else cur_x
        delta = pos - acc
        if abs(delta) < STEP: continue
        d = 1 if delta > 0 else -1
        if active == "left":
            run("wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{VOL_STEP}{'+' if d < 0 else '-'}")
        elif active == "right":
            run("brightnessctl", "set", f"{BRIGHT_STEP}{'+' if d < 0 else '-'}")
        elif active == "top":
            run("playerctl", "position", f"{'+' if d > 0 else '-'}{MEDIA_SEEK}")
        acc = pos

if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    main()
