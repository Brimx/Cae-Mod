import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
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

    Behavior on offsetScale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    StyledRect {
        anchors.fill: parent
        topLeftRadius: Tokens.rounding.extraLarge
        topRightRadius: 0
        bottomLeftRadius: 0
        bottomRightRadius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer
    }

    Column {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        StyledText {
            text: "Display Layout"
            font: Tokens.font.title.small
            color: Colours.palette.m3onSurface
        }

        Item {
            width: parent.width
            height: 48

            StyledRect {
                anchors.fill: parent
                radius: btn1.containsMouse ? Tokens.rounding.small : Tokens.rounding.large
                color: btn1.containsMouse ? Colours.tPalette.m3surfaceContainer : Colours.tPalette.m3surfaceContainerLow
                Behavior on radius { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            StyledText {
                anchors.left: parent.left; anchors.leftMargin: Tokens.padding.medium
                anchors.verticalCenter: parent.verticalCenter
                text: "Extendido"
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurface
            }

            MouseArea {
                id: btn1
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["notify-send", "Test", "Extendido clicked"])
            }
        }

        Item {
            width: parent.width
            height: 48

            StyledRect {
                anchors.fill: parent
                radius: btn2.containsMouse ? Tokens.rounding.small : Tokens.rounding.large
                color: btn2.containsMouse ? Colours.tPalette.m3surfaceContainer : Colours.tPalette.m3surfaceContainerLow
                Behavior on radius { NumberAnimation { duration: 100 } }
                Behavior on color { ColorAnimation { duration: 100 } }
            }

            StyledText {
                anchors.left: parent.left; anchors.leftMargin: Tokens.padding.medium
                anchors.verticalCenter: parent.verticalCenter
                text: "Configuración completa"
                font: Tokens.font.body.medium
                color: Colours.palette.m3onSurface
            }

            MouseArea {
                id: btn2
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["qs", "-c", "widgets", "ipc", "call", "displays", "full"])
            }
        }
    }
}
