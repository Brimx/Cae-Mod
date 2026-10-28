pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Fila (como AppItem del launcher: StateLayer + icono + dos líneas).
Item {
    id: root

    required property var modelData
    required property int index
    required property ListView list

    implicitWidth: list.width
    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.large
        // Sin hover-select (como AppItem del launcher): el highlight de
        // teclado queda fijo y el hover solo muestra el StateLayer atenuado.
        // El preview automático sigue a la selección de teclado vía debounce.
        onClicked: {
            root.list.content.selectedIndex = root.index;
            root.list.content.activate();
        }
    }

    Item {
        anchors.fill: parent
        // NOTA: anchors.margins pisa las 4 caras al evaluarse (los left/right
        // medium quedan muertos, efectivo small en todo). Copiado literal de
        // AppItem.qml:31-33 para paridad exacta con el render del launcher
        // (reportar upstream aparte, no corregir aquí).
        anchors.leftMargin: Tokens.padding.medium
        anchors.rightMargin: Tokens.padding.medium
        anchors.margins: Tokens.padding.small

        Image {
            id: thumb
            asynchronous: true
            source: root.modelData?.image || ""
            visible: !!root.modelData?.image
            width: parent.height * 0.8
            height: parent.height * 0.8
            anchors.verticalCenter: parent.verticalCenter
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 80
            sourceSize.height: 80
        }

        Item {
            anchors.left: thumb.visible ? thumb.right : parent.left
            anchors.leftMargin: thumb.visible ? Tokens.spacing.medium : 0
            // Sin hueco fantasma: con boton oculto el texto llega al borde.
            anchors.right: delBtn.visible ? delBtn.left : parent.right
            anchors.rightMargin: delBtn.visible ? Tokens.spacing.small : 0
            anchors.verticalCenter: thumb.visible ? thumb.verticalCenter : parent.verticalCenter

            implicitWidth: parent.width - (thumb.visible ? thumb.width + Tokens.spacing.medium : 0)
            implicitHeight: titleText.implicitHeight + metaText.implicitHeight

            StyledText {
                id: titleText
                text: root.modelData?.image ? "Image" : (root.modelData?.preview ?? "")
                elide: Text.ElideRight
                width: parent.width
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.medium
            }

            StyledText {
                id: metaText
                text: root.modelData?.image ? root.modelData.preview.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "") : "#" + (root.modelData?.id ?? "") + " · " + (root.modelData?.preview.length ?? 0) + " chars"
                elide: Text.ElideRight
                width: parent.width
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
                anchors.top: titleText.bottom
            }
        }

        // Borrado por fila SOLO en modo borrar (SUPER+ALT+V): en el drawer
        // normal no se muestra nada. Fundido animado, por encima del
        // StateLayer para interceptar el click.
        IconButton {
            id: delBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool showDel: root.list.content.deleteMode
            visible: showDel || opacity > 0
            opacity: showDel ? 1 : 0
            enabled: showDel
            icon: "delete"
            type: IconButton.Tonal
            onClicked: root.list.content.removeAt(root.index)

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }
    }
}
