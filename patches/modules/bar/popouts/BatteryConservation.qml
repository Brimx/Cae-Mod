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

    StyledText {
        text: qsTr("Charge limit: %1%").arg(root.currentLimit)
        font: Tokens.font.body.small
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Row {
        spacing: Tokens.spacing.small
        anchors.horizontalCenter: parent.horizontalCenter

        IconButton {
            icon: "shield"
            type: root.currentLimit === 80 ? IconButton.Filled : IconButton.Tonal
            onClicked: {
                root.currentLimit = 80;
                set80.running = true;
            }
        }

        IconButton {
            icon: "rocket_launch"
            type: root.currentLimit === 100 ? IconButton.Filled : IconButton.Tonal
            onClicked: {
                root.currentLimit = 100;
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
                const match = text.match(/(\d+)%/);
                if (match) root.currentLimit = parseInt(match[1]);
            }
        }
    }

    Process {
        id: set80
        command: ["asusctl", "battery", "limit", "80"]
        stdout: StdioCollector {
            onStreamFinished: {
                readLimit.running = true;
                Toaster.toast(
                    qsTr("Battery limit set"),
                    qsTr("Charge limit set to 80%"),
                    "power"
                );
            }
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
    }

    Timer {
        interval: 10000
        repeat: true
        onTriggered: readLimit.running = true
    }
}
