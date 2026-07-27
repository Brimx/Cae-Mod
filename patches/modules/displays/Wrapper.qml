pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property ScreenState screenState

    readonly property string helperPath: Quickshell.env("HOME") + "/.config/quickshell/widgets/displays/displays-helper.py"
    readonly property bool shouldBeActive: screenState.displays
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    width: 260
    height: 380
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: (-height - 5) * offsetScale
    opacity: 1 - offsetScale

    Behavior on offsetScale { Anim {} }

    StyledClippingRect {
        anchors.fill: parent
        topLeftRadius: Tokens.rounding.extraLarge
        topRightRadius: 0
        bottomLeftRadius: 0
        bottomRightRadius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.medium

            StyledText {
                text: qsTr("Display Layout")
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurface
            }

            IconTextButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                icon: "grid_view"
                text: qsTr("Extendido")
                type: IconTextButton.Tonal
                onClicked: Quickshell.execDetached(["python", root.helperPath, "--preset", "extended"])
            }

            IconTextButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                icon: "content_copy"
                text: qsTr("Duplicado")
                type: IconTextButton.Tonal
                onClicked: Quickshell.execDetached(["python", root.helperPath, "--preset", "mirror"])
            }

            IconTextButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                icon: "laptop_mac"
                text: qsTr("Solo Portátil")
                type: IconTextButton.Tonal
                onClicked: Quickshell.execDetached(["python", root.helperPath, "--preset", "laptop-only"])
            }

            IconTextButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                icon: "desktop_windows"
                text: qsTr("Solo Externo")
                type: IconTextButton.Tonal
                onClicked: Quickshell.execDetached(["python", root.helperPath, "--preset", "external-only"])
            }

            Item { Layout.fillHeight: true }

            TextButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                text: qsTr("Configuración completa")
                type: TextButton.Tonal
                onClicked: Quickshell.execDetached(["qs", "-c", "widgets", "ipc", "call", "displays", "full"])
            }
        }
    }
}
