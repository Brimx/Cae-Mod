pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// SearchBar del shell con contador y modo borrar (API del SearchBar de
// clip-picker sobre el SearchBar real de Caelestia): icono y placeholder
// en rojo en deleteMode, contador "mostrados/total" a la izquierda del
// botón limpiar.
Item {
    id: root

    property alias text: search.text
    property alias input: search
    property string counter
    property bool deleteMode
    property string placeholder: qsTr("Search clipboard")

    implicitHeight: search.implicitHeight
    implicitWidth: search.implicitWidth

    function clear(): void {
        search.clear();
    }

    SearchBar {
        id: search

        anchors.fill: parent
        font: Tokens.font.body.medium
        placeholderText: root.deleteMode ? qsTr("Mark entries to delete") : root.placeholder

        Binding {
            target: search.searchIcon
            property: "text"
            value: root.deleteMode ? "delete" : "search"
        }

        Binding {
            target: search.searchIcon
            property: "color"
            value: root.deleteMode ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
        }

        Binding {
            target: search
            property: "placeholderTextColor"
            value: root.deleteMode ? Qt.alpha(Colours.palette.m3error, 0.8) : Colours.palette.m3outline
        }
    }

    // A la izquierda del botón limpiar (hermano: anclar al borde del
    // search, no al clearIcon nieto — anclar a nietos es ilegal en QML).
    StyledText {
        anchors.right: search.right
        anchors.rightMargin: search.clearIcon.width + search.clearIcon.anchors.rightMargin + Tokens.spacing.small
        anchors.verticalCenter: parent.verticalCenter
        text: root.counter
        color: Colours.palette.m3outline
        font: Tokens.font.body.small
    }
}
