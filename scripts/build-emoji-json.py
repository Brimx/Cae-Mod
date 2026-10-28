#!/usr/bin/env python3
"""Genera ~/.local/share/caelestia/emoji-categorized.json para el drawer emoji.

Fuentes (igual que `caelestia emoji -f`, pero con grupo para categorizar):
  - emojibase full data (trae group/subgroup/tags/order; compact.raw.json no)
  - nerd-fonts glyphnames.json (bucket por char, nombres nf-*)
  - simbolos hardcodeados de `caelestia/subcommands/emoji.py::fetch_emojis`

Salida: {"groups": [...], "items": [{"c": char, "label": str, "tags": str,
"g": group_id, "o": order}]}. Ids: 0-9 emojibase, 10 glyphs, 11 simbolos.
"recent" se gestiona en QML aparte (~/.config/caelestia/emoji.json).
"""
import json
import sys
from pathlib import Path
from urllib.request import urlopen

EMOJI_URL = "https://cdn.jsdelivr.net/npm/emojibase-data/en/data.json"
GLYPHS_URL = "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/refs/heads/master/glyphnames.json"

GROUP_NAMES = {
    0: "Smileys",
    1: "People",
    2: "Component",
    3: "Nature",
    4: "Food",
    5: "Travel",
    6: "Activity",
    7: "Objects",
    8: "Symbols",
    9: "Flags",
    10: "Glyphs",
    11: "Text",
}

HARDCODED = [
    "¿? question upside down reversed spanish",
    "← left arrow",
    "↑ up arrow",
    "→ right arrow",
    "↓ down arrow",
    "←↑→↓ all directions up down left right arrows",
    "⇇ leftwards paired arrows",
    "⇉ rightwards paired arrows",
    "⇈ upwards paired arrows",
    "⇊ downwards paired arrows",
    "⬱ three leftwards arrows",
    "⇶ three rightwards arrows",
    "• dot circle separator",
    "「」 japanese quote square bracket",
    "¯\\_(ツ)_/¯ shrug idk i dont know",
    "(ง🔥ﾛ🔥)ง person with fire eyes eyes on fire",
    "↵ enter key return",
    "° degrees",
    "™ tm trademark",
    "® registered trademark",
    "© copyright",
    "— em dash",
    "⊞ super windows key",
]


def fetch(url):
    with urlopen(url, timeout=60) as f:
        return json.load(f)


def main():
    out = Path.home() / ".local" / "share" / "caelestia" / "emoji-categorized.json"
    try:
        emojis = fetch(EMOJI_URL)
    except Exception as e:
        print(f"ERROR: no se pudo descargar emojibase: {e}", file=sys.stderr)
        if out.exists():
            print(f"se conserva el JSON existente: {out}")
            return 0
        return 1

    items = []
    for e in emojis:
        if not e.get("emoji"):
            continue
        g = e.get("group", 8)
        if g == 2:  # Component (tonos, ZWJ): se pliega en Symbols
            g = 8
        items.append(
            {
                "c": e["emoji"],
                "label": e.get("label", ""),
                "tags": " ".join(e.get("tags", [])),
                "g": g,
                "o": e.get("order", 9999),
            }
        )

    for order, line in enumerate(HARDCODED):
        parts = line.split(" ", 1)
        items.append({"c": parts[0], "label": parts[1] if len(parts) > 1 else "", "tags": "", "g": 11, "o": order})

    try:
        glyphs = fetch(GLYPHS_URL)
    except Exception as e:
        print(f"AVISO: sin glyphs nerd-fonts ({e}), sigo solo con emojis", file=sys.stderr)
        glyphs = {}

    buckets = {}
    for name, glyph in glyphs.items():
        if name == "METADATA":
            continue
        ch = glyph.get("char")
        if not ch:
            continue
        buckets.setdefault(ch, []).append(f"nf-{name}")
    for order, (ch, names) in enumerate(sorted(buckets.items())):
        items.append({"c": ch, "label": " ".join(names), "tags": "", "g": 10, "o": order})

    groups = [{"id": i, "name": GROUP_NAMES[i]} for i in (0, 1, 3, 4, 5, 6, 7, 8, 9, 11, 10)]

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"groups": groups, "items": items}, ensure_ascii=False))
    print(f"OK: {len(items)} items -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
