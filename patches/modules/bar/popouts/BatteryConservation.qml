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
    }

    Row {
        spacing: Tokens.spacing.small

        IconButton {
            icon: "shield"
            type: root.currentLimit === 80 ? IconButton.Filled : IconButton.Tonal
            onClicked: root.setLimit(80)
        }

        IconButton {
            icon: "rocket_launch"
            type: root.currentLimit === 100 ? IconButton.Filled : IconButton.Tonal
            onClicked: root.setLimit(100)
        }
    }

    Process {
        id: readLimit
        running: true
        command: ["asusctl", "battery", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/(\d+)%/);
                root.currentLimit = match ? parseInt(match[1]) : 100;
            }
        }
    }

    Process {
        id: setLimitProc
        stdout: StdioCollector {
            onStreamFinished: {
                readLimit.start();
                Toaster.toast(
                    qsTr("Battery limit set"),
                    qsTr("Charge limit set to %1%").arg(root.currentLimit),
                    "power"
                );
            }
        }
    }

    function setLimit(limit: int) {
        setLimitProc.command = ["asusctl", "battery", "limit", limit.toString()];
        setLimitProc.start();
    }

    Timer {
        interval: 30000
        repeat: true
        onTriggered: readLimit.start()
    }
}
