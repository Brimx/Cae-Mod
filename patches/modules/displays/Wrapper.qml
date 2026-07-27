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

    StyledRect {
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: Tokens.rounding.extraLarge
        bottomLeftRadius: 0
        bottomRightRadius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        StyledText {
            text: qsTr("Display Layout")
            font: Tokens.font.title.small
            color: Colours.palette.m3onSurface
        }

        TextButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            text: qsTr("Extendido")
            type: TextButton.Tonal
            onClicked: Quickshell.execDetached(["python", root.helperPath, "--preset", "extended"])
        }

        TextButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            text: qsTr("Duplicado")
            type: TextButton.Tonal
            onClicked: Quickshell.execDetached(["python", root.helperPath, "--preset", "mirror"])
        }

        TextButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            text: qsTr("Solo Portátil")
            type: TextButton.Tonal
            onClicked: Quickshell.execDetached(["python", root.helperPath, "--preset", "laptop-only"])
        }

        TextButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            text: qsTr("Solo Externo")
            type: TextButton.Tonal
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
