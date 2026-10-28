pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.modules.clipboard.items
import qs.services
import qs.modules.clipboard.services

// Lista del drawer (molde AppList/ContentList del launcher + filas del
// clip-picker): ScriptModel con diff incremental, highlight deslizante y
// estado vacío animado. El modelo son resultados fzf {item, positions}.
StyledListView {
    id: root

    required property var content

    Layout.preferredWidth: root.content.listW
    Layout.preferredHeight: root.content.listH
    spacing: Tokens.spacing.small
    clip: true
    model: ScriptModel {
        values: root.content.results
    }
    highlightFollowsCurrentItem: false
    preferredHighlightBegin: 0
    preferredHighlightEnd: height
    highlightRangeMode: ListView.ApplyRange

    onModelChanged: currentIndex = 0

    // Highlight que se desliza (AppList: StyledRect).
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
    // filtrado (solo move/displaced corren ahí, como upstream).
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

    // Estado vacío: "sin historial" o "sin resultados" (clip-picker).
    Row {
        id: empty

        opacity: root.count === 0 ? 1 : 0
        scale: root.count === 0 ? 1 : 0.5

        spacing: Tokens.spacing.medium
        padding: Tokens.padding.large

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        MaterialIcon {
            text: Cliphist.items.length ? "manage_search" : "content_paste_off"
            color: Colours.palette.m3onSurfaceVariant
            fontStyle: Tokens.font.icon.extraLarge

            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: Cliphist.items.length ? qsTr("No results") : qsTr("Clipboard history is empty")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.builders.large.weight(Font.Medium).build()
            }

            StyledText {
                text: Cliphist.items.length ? qsTr("Try searching for something else") : qsTr("Copy something first")
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
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
    // el contexto del delegate los rellena.
    delegate: ClipItem {
        list: root
        deleteMode: root.content.deleteMode
        marked: root.content.marked[modelData.item.id] === true
        onActivated: {
            if (root.content.deleteMode) {
                root.currentIndex = index;
                root.content.toggleMark(modelData.item);
            } else {
                root.content.copy(modelData.item);
            }
        }
    }
}
