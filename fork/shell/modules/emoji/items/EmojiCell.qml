pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Celda del grid (molde AppItem.qml: sin fondo por seleccion; el unico
// indicador es el highlight deslizante del grid). Tamano fijo: glifo 26px.
Item {
    id: root

    required property var modelData
    required property int index
    required property GridView grid

    readonly property bool selected: grid.content.selectedIndex === root.index

    // Familia por tipo (verificado con fc-list): emojis -> Noto Color Emoji
    // (la default no la levanta y salen rectangulos), glyphs PUA -> Nerd
    // Font, texto/kaomoji -> default (Qt hace fallback del resto).
    readonly property string glyphFont: root.modelData?.g === 10 ? "JetBrainsMono Nerd Font Mono" : (root.modelData?.g === 11 ? "" : "Noto Color Emoji")

    width: grid.cellWidth
    height: grid.cellHeight

    // Unico indicador de seleccion (E-2): el highlight del grid no renderiza,
    // asi que el fondo de celda vuelve, pero con fade de COLOR (CAnim) para
    // que no popee como antes.
    StyledRect {
        anchors.fill: parent
        anchors.margins: Tokens.spacing.extraSmall
        radius: Tokens.rounding.medium
        color: root.selected ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainer
        opacity: root.selected ? 1 : 0.55

        Behavior on color {
            CAnim {}
        }
        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        text: root.modelData?.c ?? ""
        font.pixelSize: 26
        font.family: root.glyphFont
        color: Colours.palette.m3onSurface
    }

    StateLayer {
        radius: Tokens.rounding.medium
        onClicked: {
            root.grid.content.selectedIndex = root.index;
            root.grid.content.activate();
        }
    }
}
