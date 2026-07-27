import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import "displays" as Panels

ShellRoot {
    id: root

    FontLoader {
        source: "file:///etc/xdg/quickshell/caelestia/assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf"
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

    IpcHandler {
        function toggle(): void {
            const ss = ShellState.forActive();
            ss.displays = !ss.displays;
        }

        function full(): void {
            fullWindow.visible = true;
            fullPanel.refreshMonitors();
            fullWindow.requestActivate();
        }

        target: "displays"
    }
}
