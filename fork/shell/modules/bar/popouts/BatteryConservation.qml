pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Column {
    id: root

    spacing: Tokens.spacing.medium
    width: parent.width

    property int currentLimit: 100
    property bool busy: false

    StyledText {
        text: root.busy ? qsTr("Setting limit…") : qsTr("Charge limit: %1%").arg(root.currentLimit)
        font: Tokens.font.body.small
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Row {
        spacing: Tokens.spacing.small
        anchors.horizontalCenter: parent.horizontalCenter

        IconButton {
            icon: "shield"
            type: root.currentLimit === 80 ? IconButton.Filled : IconButton.Tonal
            enabled: !root.busy && root.currentLimit !== 80
            onClicked: {
                root.busy = true;
                set80.running = true;
            }
        }

        IconButton {
            icon: "rocket_launch"
            type: root.currentLimit === 100 ? IconButton.Filled : IconButton.Tonal
            enabled: !root.busy && root.currentLimit !== 100
            onClicked: {
                root.busy = true;
                set100.running = true;
            }
        }
    }

    Process {
        id: readLimit
        running: true
        command: ["asusctl", "battery", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                // asusctl dice "Current battery charge limit: 80%" — parse estricto,
                // el /(\d+)%/ genérico agarraba cualquier % y flapeaba 80<->100
                const match = text.match(/limit:\s*(\d+)%/);
                if (match)
                    root.currentLimit = parseInt(match[1]);
                root.busy = false;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root.busy = false;
            }
        }
        onExited: root.busy = false
    }

    Process {
        id: set80
        command: ["asusctl", "battery", "limit", "80"]
        stdout: StdioCollector {
            onStreamFinished: {
                readLimit.running = true;
                Toaster.toast(
                    qsTr("Battery limit set"),
                    qsTr("Charge limit set to 80% — baja a 80 descargando, no de golpe"),
                    "power"
                );
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                Toaster.toast(qsTr("Battery limit failed"), text, "power");
            }
        }
        onExited: code => {
            if (code !== 0)
                root.busy = false;
        }
    }

    Process {
        id: set100
        command: ["asusctl", "battery", "limit", "100"]
        stdout: StdioCollector {
            onStreamFinished: {
                readLimit.running = true;
                Toaster.toast(
                    qsTr("Battery limit set"),
                    qsTr("Charge limit set to 100%"),
                    "power"
                );
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                Toaster.toast(qsTr("Battery limit failed"), text, "power");
            }
        }
        onExited: code => {
            if (code !== 0)
                root.busy = false;
        }
    }

    Timer {
        interval: 10000
        repeat: true
        onTriggered: readLimit.running = true
    }
}
