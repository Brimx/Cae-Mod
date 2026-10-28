pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.clipboard.items

// Lista (como AppList/ContentList del launcher): ScriptModel con diff
// incremental (las transiciones add/remove/move sí se reproducen), highlight
// deslizante y estado vacío animado.
StyledListView {
    id: root

    required property var content

    Layout.fillWidth: true
    Layout.topMargin: root.content.padding
    Layout.leftMargin: root.content.padding
    Layout.rightMargin: root.content.padding
    Layout.preferredHeight: root.content.listH
    spacing: Tokens.spacing.small
    clip: true
    model: ScriptModel {
        values: root.content.visibleItems
    }
    currentIndex: root.content.selectedIndex
    highlightFollowsCurrentItem: false
    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: ListView.ApplyRange

    // Highlight que se desliza (AppList: StyledRect + CAnim en color)
    highlight: StyledRect {
        implicitWidth: root.width
        implicitHeight: root.currentItem?.height ?? 0
        y: root.currentItem?.y ?? 0
        radius: Tokens.rounding.large
        color: Colours.palette.m3onSurface
        opacity: 0.08

        Behavior on y {
            Anim {}
        }
    }

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    // Transiciones de items (AppList). add/remove gateados durante el
    // filtrado (solo move/displaced corren ahi, como upstream).
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
    move: Transition {
        Anim {
            property: "y"
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }
    addDisplaced: Transition {
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
    displaced: Transition {
        Anim {
            property: "y"
        }
        Anim {
            type: Anim.DefaultEffects
            property: "opacity"
            to: 1
        }
    }

    // Estado vacío (ContentList): icono + dos líneas, fade+scale.
    Row {
        id: empty

        opacity: root.count === 0 ? 1 : 0
        scale: root.count === 0 ? 1 : 0.5

        spacing: Tokens.spacing.medium
        padding: Tokens.padding.large

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        MaterialIcon {
            text: "manage_search"
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

    // NOTA: no se pasa modelData/index explícitos (como AppItem del launcher):
    // el contexto del delegate los rellena; `modelData: modelData` sería
    // auto-referencia y dejaría modelData en undefined.
    delegate: ClipboardItem {
        list: root
    }
}
