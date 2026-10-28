import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Una tecla de un atajo, dibujada como keycap: cara redondeada sobre una
// base apenas más oscura que asoma debajo, como el costado de la tecla
// (porte de clip-picker/KeyCap.qml a tokens Caelestia).
Item {
    id: root

    property alias text: label.text

    implicitWidth: Math.max(implicitHeight, label.implicitWidth + Tokens.padding.small * 1.5)
    implicitHeight: label.implicitHeight + 6 + depth

    readonly property int depth: 2

    Rectangle {
        anchors.fill: parent
        radius: Tokens.rounding.small - 2
        color: Colours.palette.m3outlineVariant
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height - root.depth
        radius: Tokens.rounding.small - 2
        color: Colours.palette.m3surfaceContainerHigh

        StyledText {
            id: label

            anchors.centerIn: parent
            color: Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.builders.small.weight(Font.Medium).build()
        }
    }
}
