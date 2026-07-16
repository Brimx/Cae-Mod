import QtQuick
import Quickshell
import Quickshell.Io
import "panels" as Panels

ShellRoot {
    id: root

    property bool quickVisible: false

    Panels.DisplayQuick {
        id: quickPanel
        visible: root.quickVisible

        Behavior on visible {
            NumberAnimation { duration: 100 }
        }
    }

    FloatingWindow {
        id: fullWindow

        implicitWidth: 560
        implicitHeight: 620
        title: "Display Configuration"
        visible: false
        color: "transparent"

        Panels.DisplayFull {
            id: fullPanel
            anchors.fill: parent
            shown: fullWindow.visible

            onCloseRequested: {
                fullWindow.visible = false;
            }
        }

        onVisibleChanged: {
            if (visible) fullPanel.refreshMonitors();
        }
    }

    Component.onCompleted: {
        quickPanel.fullConfigRequested.connect(function() {
            root.quickVisible = false;
            fullWindow.visible = true;
            fullWindow.requestActivate();
        });
    }

    IpcHandler {
        function toggle(): void {
            if (fullWindow.visible) {
                fullWindow.visible = false;
            } else {
                root.quickVisible = !root.quickVisible;
            }
        }

        target: "displays"
    }
}
