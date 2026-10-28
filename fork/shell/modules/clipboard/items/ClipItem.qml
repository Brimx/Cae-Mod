pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import "../scripts/markup.js" as Markup
import qs.services

// Una fila del historial (porte de clip-picker/ClipItem.qml a tokens
// Caelestia): badge con icono, texto con matches de fzf resaltados y línea
// tenue debajo. En modo borrar el icono es checkbox y lo marcado va en rojo.
Item {
    id: root

    required property var modelData
    required property int index
    required property ListView list

    readonly property var entry: modelData.item
    readonly property var positions: modelData.positions ?? []

    property bool deleteMode: false
    property bool marked: false

    signal activated

    implicitWidth: list.width
    implicitHeight: Tokens.sizes.launcher.itemHeight

    Rectangle {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: root.marked ? Colours.palette.m3error : Colours.palette.m3onSurface
        opacity: root.marked ? 0.12 : hover.containsMouse ? 0.08 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Rectangle {
        id: badge

        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.medium
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Math.round(root.implicitHeight * 0.7)
        implicitHeight: implicitWidth
        radius: Tokens.rounding.medium
        color: root.marked ? Colours.palette.m3errorContainer : Qt.alpha(Colours.palette.m3secondaryContainer, 0.6)

        Behavior on color {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: !root.deleteMode ? root.entry.icon : root.marked ? "check_box" : "check_box_outline_blank"
            fill: root.marked ? 1 : 0
            fontStyle: Tokens.font.icon.medium
            color: root.marked ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
        }
    }

    Column {
        anchors.left: badge.right
        anchors.leftMargin: Tokens.spacing.medium
        anchors.right: openHint.visible ? openHint.left : parent.right
        anchors.rightMargin: Tokens.padding.medium
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            width: parent.width
            text: root.entry.image ? root.entry.title : Markup.highlighted(root.entry.text, root.positions, Colours.palette.m3primary)
            textFormat: root.entry.image ? Text.PlainText : Text.StyledText
            // Sin `font:` completo: ya asignado abajo por partes, QML no
            // permite ambas formas (error "already assigned").
            font.family: Tokens.font.body.medium.family
            font.pointSize: Tokens.font.body.medium.pointSize
            font.weight: Tokens.font.body.medium.weight
            font.strikeout: root.marked
            opacity: root.marked ? 0.7 : 1
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        StyledText {
            width: parent.width
            text: root.entry.detail
            color: root.marked ? Colours.palette.m3error : Colours.palette.m3outline
            font: Tokens.font.body.small
            elide: Text.ElideRight
        }
    }

    // Links y paths se abren con Ctrl+O.
    MaterialIcon {
        id: openHint

        anchors.right: parent.right
        anchors.rightMargin: Tokens.padding.medium
        anchors.verticalCenter: parent.verticalCenter
        visible: root.entry.openable && !root.deleteMode
        text: "open_in_new"
        fontStyle: Tokens.font.icon.medium
        color: Colours.palette.m3outline
    }
}
