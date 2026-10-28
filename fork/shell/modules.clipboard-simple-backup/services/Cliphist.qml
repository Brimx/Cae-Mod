pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string helperBin: "$HOME/.local/bin/clipboard-actions.sh"
    property var items: []
    property string contents: ""
    property string contentsId: ""
    property bool contentsLoading: false

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
    }

    function decode(id) {
        contents = "";
        contentsId = String(id);
        contentsLoading = true;
        decodeProc.exec(["sh", "-c", root.helperBin + " decode " + String(id)]);
    }

    function paste(id) {
        pasteProc.exec(["sh", "-c", root.helperBin + " paste " + String(id)]);
    }

    function remove(id) {
        delProc.exec(["sh", "-c", root.helperBin + " delete " + String(id)]);
    }

    Process {
        id: listProc
        command: ["sh", "-c", root.helperBin + " list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.items = text.trim().split("\n").filter(line => line.length > 0).map(line => {
                    const sep = line.indexOf("\t");
                    const rest = sep < 0 ? "" : line.slice(sep + 1);
                    const sep2 = rest.indexOf("\t");
                    return {
                        id: sep < 0 ? line : line.slice(0, sep),
                        preview: sep2 < 0 ? rest : rest.slice(0, sep2),
                        image: sep2 < 0 ? "" : rest.slice(sep2 + 1)
                    };
                });
            }
        }
    }

    Process {
        id: decodeProc
        stdout: StdioCollector {
            onStreamFinished: root.contents = text
        }
        onExited: root.contentsLoading = false
    }

    Process {
        id: pasteProc
        onExited: (code) => {
            if (code !== 0)
                console.warn("clipboard paste falló:", code);
        }
    }

    Process {
        id: delProc
        onExited: root.refresh()
    }
}
