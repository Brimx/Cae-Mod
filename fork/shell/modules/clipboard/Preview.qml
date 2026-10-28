pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

// La entrada destacada en completo (porte de clip-picker/Preview.qml):
// texto scrolleable y seleccionable, o la imagen. Decodifica con settle de
// 60ms y un proceso propio por entrada taggeado con su id: un decode lento
// nunca pinta sobre una selección más nueva.
StyledRect {
    id: root

    property var entry: null
    readonly property string cacheDir: `${Quickshell.env("XDG_RUNTIME_DIR")}/clip-picker`
    readonly property int maxChars: 20000

    property string textBody
    property int textLength
    property string imagePath
    property bool loading

    radius: Tokens.rounding.large
    color: Colours.tPalette.m3surfaceContainer
    clip: true

    // Slots separados por tipo: al cambiar de tipo se suelta el contenido
    // anterior de golpe (texto -> imagen -> texto no flashea el primer texto
    // mientras decodifica el segundo). Dentro del mismo tipo el contenido
    // viejo queda atenuado hasta que llega el nuevo.
    onEntryChanged: {
        if (entry?.image) {
            textBody = "";
            textLength = 0;
        } else {
            imagePath = "";
        }
        loading = true;
        settle.restart();
    }

    Timer {
        id: settle

        interval: 60
        onTriggered: root.decode()
    }

    function decode(): void {
        const e = entry;
        if (!e) {
            loading = false;
            return;
        }
        if (e.image) {
            const file = `${cacheDir}/${e.id}.${e.image.format}`;
            job.createObject(root, {
                entryId: e.id,
                command: ["sh", "-c", 'mkdir -p "$(dirname "$2")"; [ -s "$2" ] || printf "%s" "$1" | cliphist decode > "$2"', "sh", e.line, file],
                callback: () => {
                    imagePath = `file://${file}`;
                    loading = false;
                }
            });
        } else {
            // Primera línea: largo total; después como mucho maxChars.
            job.createObject(root, {
                entryId: e.id,
                command: ["sh", "-c", 'c=$(printf "%s" "$1" | cliphist decode); printf "%s\\n" "${#c}"; printf "%s" "$c" | head -c "$2"', "sh", e.line, String(maxChars)],
                callback: out => {
                    const nl = out.indexOf("\n");
                    textLength = parseInt(out.slice(0, nl)) || 0;
                    textBody = out.slice(nl + 1);
                    loading = false;
                }
            });
        }
    }

    Component {
        id: job

        Process {
            id: proc

            property string entryId
            property var callback

            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    if (root.entry && root.entry.id === proc.entryId)
                        proc.callback(text);
                    proc.destroy();
                }
            }
        }
    }

    // Header: qué es esto.
    Row {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.entry?.icon ?? "content_paste"
            fontStyle: Tokens.font.icon.medium
            color: Colours.palette.m3primary
        }

        StyledText {
            id: summary

            anchors.verticalCenter: parent.verticalCenter
            text: !root.entry ? "" : root.entry.image ? root.entry.detail : root.textSummary()
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
        }
    }

    function textSummary(): string {
        if (loading && !textBody)
            return "";
        const lines = textBody ? textBody.split("\n").length : 0;
        const chars = textLength.toLocaleString(Qt.locale(), "f", 0);
        const more = textLength > maxChars ? qsTr(" · preview cut at %1").arg(maxChars.toLocaleString(Qt.locale(), "f", 0)) : "";
        return qsTr("%1 · %2 characters · %3 %4").arg(entry.detail).arg(chars).arg(lines).arg(lines === 1 ? qsTr("line") : qsTr("lines")) + more;
    }

    Item {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.margins: Tokens.padding.large
        anchors.topMargin: Tokens.spacing.medium

        opacity: root.loading ? 0.4 : 1

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Flickable {
            id: flick

            anchors.fill: parent
            visible: root.entry && !root.entry.image
            contentHeight: textView.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            TextEdit {
                id: textView

                width: flick.width
                text: root.textBody
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                color: Colours.palette.m3onSurface
                selectionColor: Qt.alpha(Colours.palette.m3primary, 0.4)
                selectedTextColor: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
                renderType: Text.NativeRendering
            }
        }

        Image {
            anchors.fill: parent
            visible: root.entry?.image ?? false
            source: visible ? root.imagePath : ""
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            smooth: true
            mipmap: true
        }
    }
}
