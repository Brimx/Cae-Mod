pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Atajos como keycaps y qué hace cada uno, envueltos en tantas líneas
// centradas como pida maxWidth (porte de clip-picker/HelpBar.qml).
// items: [{ keys: ["Ctrl", "D"], label: "delete" }, ...]
// Flow envuelve pero no centra sus líneas: se miden en una fila oculta y se
// reparten greedy en líneas, cada una un Row centrado; un atajo nunca se
// parte entre líneas.
Column {
    id: root

    property var items: []
    property real maxWidth: 800
    readonly property int gap: Tokens.spacing.medium

    readonly property var lines: {
        measurer.count; // re-split una vez que la fila de medida tiene items
        const out = [];
        let line = [];
        let width = 0;
        for (let i = 0; i < items.length; i++) {
            const w = measurer.itemAt(i)?.implicitWidth ?? 0;
            if (line.length && width + gap + w > maxWidth) {
                out.push(line);
                line = [];
                width = 0;
            }
            width += (line.length ? gap : 0) + w;
            line.push(items[i]);
        }
        if (line.length)
            out.push(line);
        return out;
    }

    spacing: Tokens.spacing.small

    Row {
        visible: false

        Repeater {
            id: measurer

            model: root.items
            delegate: shortcut
        }
    }

    Repeater {
        model: root.lines

        Row {
            required property var modelData

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root.gap

            Repeater {
                model: parent.modelData
                delegate: shortcut
            }
        }
    }

    Component {
        id: shortcut

        Row {
            required property var modelData

            spacing: Tokens.spacing.small

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Repeater {
                    model: modelData.keys

                    KeyCap {
                        required property string modelData

                        text: modelData
                    }
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
            }
        }
    }
}
