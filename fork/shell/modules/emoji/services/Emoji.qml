pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Fuente de datos del drawer emoji (molde Cliphist.qml: todo IO via helper
// shell + Process; el QML solo parsea). Recientes en memoria + persistidos
// como lineas en ~/.config/caelestia/emoji.json (no JSON: un char por linea).
Singleton {
    id: root

    readonly property string helperBin: "$HOME/.local/bin/emoji-actions.sh"
    // Grupos tal cual los genera build-emoji-json.py (id 0-11, sin el 2).
    property var groups: []
    property var items: []
    property var recents: []
    property bool loaded: false

    function load() {
        if (!loaded) {
            dataProc.running = true;
            recentsProc.running = true;
        }
    }

    function copy(char) {
        const c = String(char ?? "");
        if (!c)
            return;
        copyProc.exec(["sh", "-c", root.helperBin + " copy \"$1\"", "--", c]);
        touch(c);
    }

    function touch(char) {
        const c = String(char ?? "");
        if (!c)
            return;
        const next = [c].concat(recents.filter(x => x !== c).slice(0, 23));
        recents = next;
        touchProc.exec(["sh", "-c", root.helperBin + " touch \"$1\"", "--", c]);
    }

    Process {
        id: dataProc
        command: ["sh", "-c", root.helperBin + " data"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text);
                    root.groups = payload.groups ?? [];
                    root.items = payload.items ?? [];
                } catch (e) {
                    console.warn("emoji: emoji-categorized.json invalido:", e);
                }
                root.loaded = true;
            }
        }
    }

    Process {
        id: recentsProc
        command: ["sh", "-c", root.helperBin + " recents"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.recents = text.split("\n").filter(line => line.length > 0);
            }
        }
    }

    Process {
        id: copyProc
        onExited: (code) => {
            if (code !== 0)
                console.warn("emoji copy fallo:", code);
        }
    }

    Process {
        id: touchProc
    }
}
