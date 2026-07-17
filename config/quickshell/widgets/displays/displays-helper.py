#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys

MONITORS_LUA = os.path.expanduser("~/.config/hypr/hyprland/monitors.lua")

# ── Presets ──────────────────────────────────────────────────────────
PRESETS = {
    "extended": [
        {"output": "eDP-1", "mode": "1920x1200@60", "pos": "0x0",     "scale": 1, "enable": True},
        {"output": "DP-1",  "mode": "1920x1080@120","pos": "1920x0",   "scale": 1, "enable": True},
    ],
    "mirror": [
        {"output": "eDP-1", "mode": "1920x1200@60", "pos": "0x0",     "scale": 1, "enable": True},
        {"output": "DP-1",  "mode": "1920x1080@120","pos": "0x0",      "scale": 1, "enable": True},
    ],
    "laptop-only": [
        {"output": "eDP-1", "mode": "1920x1200@60", "pos": "0x0",     "scale": 1, "enable": True},
        {"output": "DP-1",  "enable": False},
    ],
    "external-only": [
        {"output": "eDP-1", "enable": False},
        {"output": "DP-1",  "mode": "1920x1080@120","pos": "0x0",     "scale": 1, "enable": True},
    ],
}

# ── Helpers ──────────────────────────────────────────────────────────

def hyprctl_monitors():
    raw = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
    return json.loads(raw)

def parse_modes(raw_modes):
    modes = []
    for ms in raw_modes:
        m = re.match(r"^(\d+)x(\d+)@([\d.]+)Hz$", ms)
        if m:
            modes.append({
                "width": int(m.group(1)),
                "height": int(m.group(2)),
                "refresh": float(m.group(3)),
            })
    return modes

def build_monitor_config(monitors):
    lines = []
    for m in monitors:
        lines.append(f"hl.monitor({{")
        lines.append(f'    output   = "{m["output"]}",')
        if m.get("enable") is False:
            lines.append("    disabled = true,")
        else:
            lines.append(f'    mode     = "{m["mode"]}",')
            lines.append(f'    position = "{m["pos"]}",')
            lines.append(f'    scale    = {m["scale"]},')
            lines.append("    disabled = false,")
        lines.append("})")
    return "\n".join(lines) + "\n"

def write_monitors_lua(content):
    os.makedirs(os.path.dirname(MONITORS_LUA), exist_ok=True)
    with open(MONITORS_LUA, "w") as f:
        f.write(content)

# ── Commands ─────────────────────────────────────────────────────────

def cmd_get_monitors():
    data = hyprctl_monitors()
    out = []
    for m in data:
        out.append({
            "name": m["name"],
            "desc": m.get("description", ""),
            "width": m["width"],
            "height": m["height"],
            "refresh": m["refreshRate"],
            "scale": m["scale"],
            "x": m["x"],
            "y": m["y"],
            "disabled": m.get("disabled", False),
            "availableModes": parse_modes(m.get("availableModes", [])),
        })
    print(json.dumps(out))

def cmd_apply(monitors):
    # 1. hyprctl keyword (instant)
    for m in monitors:
        name = m["output"]
        if m.get("enable") is False:
            subprocess.run(["hyprctl", "keyword", "monitor", f"{name},disable"],
                           capture_output=True)
        else:
            spec = f"{name},{m['mode']},{m['pos']},{m['scale']}"
            subprocess.run(["hyprctl", "keyword", "monitor", spec],
                           capture_output=True)

    # 2. write monitors.lua (persistence)
    lua = build_monitor_config(monitors)
    write_monitors_lua(lua)

    # 3. reload hyprland (async)
    subprocess.Popen(["hyprctl", "reload"],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def cmd_preset(name):
    monitors = PRESETS.get(name)
    if not monitors:
        print(f"Unknown preset: {name}", file=sys.stderr)
        sys.exit(1)
    cmd_apply(monitors)

# ── CLI ──────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Display helper for Caelestia widgets")
    parser.add_argument("--get-monitors", action="store_true", help="List monitors as JSON")
    parser.add_argument("--preset", choices=list(PRESETS.keys()), help="Apply a preset")

    args, remaining = parser.parse_known_args()

    if args.get_monitors:
        cmd_get_monitors()
    elif args.preset:
        cmd_preset(args.preset)
    else:
        # --apply with manual monitor args
        parser2 = argparse.ArgumentParser()
        parser2.add_argument("--apply", action="store_true")
        parser2.add_argument("--monitor", action="append", nargs=5,
                             metavar=("NAME","MODE","POS","SCALE","ENABLE"),
                             help="Monitor config: NAME MODE POS SCALE 1|0")
        parsed = parser2.parse_args(remaining)

        if not parsed.apply or not parsed.monitor:
            parser.print_help()
            sys.exit(1)

        monitors = []
        for m in parsed.monitor:
            name, mode, pos, scale, enable = m
            monitors.append({
                "output": name,
                "mode": mode,
                "pos": pos,
                "scale": float(scale),
                "enable": enable == "1",
            })
        cmd_apply(monitors)

if __name__ == "__main__":
    main()
