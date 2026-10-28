pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.modules.emoji.items

// Grid (molde ClipboardList.qml para highlight/estado vacio + FolderContents
// GridView para la cuadricula virtualizada). Modelo via ScriptModel.
GridView {
    id: root

    required property var content

    Layout.fillWidth: true
    Layout.topMargin: root.content.padding
    Layout.leftMargin: root.content.padding
    Layout.rightMargin: root.content.padding
    Layout.preferredHeight: root.content.listH
    clip: true
    model: ScriptModel {
        values: root.content.visibleItems
    }
    currentIndex: root.content.selectedIndex
    highlightFollowsCurrentItem: false
    // Sin esto el follow-scroll salta de golpe (causa del scroll brusco:
    // ClipboardList.qml:34-36 si lo define).
    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: GridView.ApplyRange

    cellWidth: root.content.cellWH
    cellHeight: root.content.cellWH

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    add: Transition {
        enabled: !root.content.filtering
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            from: 0
            to: 1
        }
    }
    remove: Transition {
        enabled: !root.content.filtering
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            from: 1
            to: 0
        }
    }
    // "x,y" junto no lo anima (propiedad invalida): van separados,
    // igual que ClipboardList.qml:72-81.
    move: Transition {
        Anim {
            property: "x"
        }
        Anim {
            property: "y"
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }
    displaced: Transition {
        Anim {
            property: "x"
        }
        Anim {
            property: "y"
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }
    // Como AppList.qml addDisplaced (StandardSmall), en 2 ejes por ser grid.
    addDisplaced: Transition {
        Anim {
            property: "x"
            type: Anim.StandardSmall
        }
        Anim {
            property: "y"
            type: Anim.StandardSmall
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    // Estado vacio (ClipboardList.qml:105).
    Row {
        id: empty

        opacity: root.count === 0 ? 1 : 0
        scale: root.count === 0 ? 1 : 0.5

        spacing: Tokens.spacing.medium
        padding: Tokens.padding.large

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        MaterialIcon {
            text: "mood_bad"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.extraLarge

            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: qsTr("No results")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.large.weight(Font.Medium).build()
            }

            StyledText {
                text: qsTr("Try searching for something else")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.medium
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }
    }

    delegate: EmojiCell {
        grid: root
    }
}
