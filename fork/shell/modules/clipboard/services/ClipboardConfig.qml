pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Config propia del drawer (Config C++ tiene esquema fijo: no existe
// Config.clipboard). Se lee bajo demanda con load() — NUNCA en onCompleted,
// porque el shell corre con -d y el fork rompe los Process de arranque.
Singleton {
    id: root

    property bool enabled: true
    property int maxRows: 8
    property bool loaded: false

    function load() {
        if (!loadProc.running)
            loadProc.running = true;
    }

    Process {
        id: loadProc
        command: ["sh", "-lc", "cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/clipboard.json\"; [ -r \"$cfg\" ] && cat \"$cfg\""]
        stdout: StdioCollector {
            id: collector
            onStreamFinished: {
                const payload = collector.text.trim();
                root.loaded = true;
                if (!payload)
                    return;
                try {
                    const parsed = JSON.parse(payload);
                    if (typeof parsed !== "object" || parsed === null)
                        return;
                    if (typeof parsed.enabled === "boolean")
                        root.enabled = parsed.enabled;
                    if (Number.isInteger(parsed.maxRows) && parsed.maxRows > 0)
                        root.maxRows = parsed.maxRows;
                } catch (e) {
                    console.warn("clipboard: clipboard.json inválido, usando valores por defecto:", e);
                }
            }
        }
    }
}
