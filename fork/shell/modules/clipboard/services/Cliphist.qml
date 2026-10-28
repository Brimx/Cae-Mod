pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Fuente de datos del drawer (porte de clip-picker/shell.qml: parse/load).
// Llama a `cliphist list` directo y conserva la línea cruda por entrada:
// decode/copy/delete/open la necesitan completa (`cliphist list` corta el
// texto a 100 chars). Sin helpers shell.
Singleton {
    id: root

    property var items: []

    signal loaded
    signal emptied

    // "[[ binary data 18 KiB png 498x73 ]]" en imágenes, texto si no.
    // cliphist corta a 100 chars: lo que actúa sobre la entrada entera
    // la decodifica primero (copy/open/decode).
    function parse(line: string): var {
        const tab = line.indexOf("\t");
        const id = line.slice(0, tab);
        const text = line.slice(tab + 1);
        const img = text.match(/^\[\[ binary data (.+?) (\w+) (\d+)x(\d+) \]\]$/);
        if (img)
            return {
                id, line, text,
                image: { size: img[1], format: img[2] },
                openable: false,
                icon: "image",
                title: qsTr("%1 image").arg(img[2].toUpperCase()),
                detail: `${img[2].toUpperCase()} · ${img[3]}×${img[4]} · ${img[1]}`
            };
        const link = /^\s*(https?|ftp|file):\/\/\S+\s*$/.test(text);
        const path = /^\s*(~|\/)\S*\s*$/.test(text);
        return {
            id, line, text,
            image: null,
            openable: link || path || /(https?|ftp|file):\/\/\S/.test(text),
            icon: link ? "link" : path ? "folder" : "notes",
            detail: link ? qsTr("Link") : path ? qsTr("Path") : qsTr("Text")
        };
    }

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    // Siempre con tipo explícito: sin él wl-copy adivina el contenido y
    // puede etiquetar texto como otra cosa (una fuente, una vez), que nada pega.
    function copy(entry: var): void {
        if (!entry)
            return;
        const type = entry.image ? `image/${entry.image.format}` : "text/plain;charset=utf-8";
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist decode | wl-copy --type "$2"', "sh", entry.line, type]);
    }

    // Borra líneas crudas por stdin (igual que `cliphist delete`).
    function removeLines(lines: list<string>): void {
        const targets = lines.filter(l => l);
        if (!targets.length || deleter.running)
            return;
        deleter.command = ["sh", "-c", 'printf "%s\\n" "$@" | cliphist delete', "sh", ...targets];
        deleter.running = true;
    }

    Process {
        id: listProc

        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.items = text.split("\n").filter(l => l.includes("\t")).map(root.parse);
                root.loaded();
            }
        }
    }

    Process {
        id: deleter

        onExited: root.emptied()
    }
}
