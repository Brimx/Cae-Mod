pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import "scripts/fzf.js" as Fzf
import "scripts/markup.js" as Markup
import qs.services

// "¿Abrir qué link?": overlay cuando Ctrl+O encuentra varios links en una
// entrada (porte de clip-picker/LinkMenu.qml a tokens Caelestia). Se comporta
// como la lista: mismo highlight, hover, scroll y teclas de movimiento, con
// sus propias teclas (handleKey) alimentadas por el search del drawer, o por
// el suyo una vez que "/" abre su búsqueda. Matching con fzf.js, con matches
// resaltados.
Item {
    id: root

    property var links: []
    property PickerSearchBar returnFocusTo // el search del drawer, recupera foco al salir
    property bool showHelp // su propio footer; Ctrl+H alterna ambos
    readonly property bool shown: links.length > 0

    property bool searching
    readonly property string query: field.text.trim()
    readonly property var results: {
        if (!finder)
            return [];
        return finder.find(query).map(r => ({ url: r.item, positions: Array.from(r.positions) }));
    }
    property var finder: null
    property int current: 0

    signal chosen(url: string)
    signal helpToggled

    // Nueve filas, una por atajo numérico; PgUp/PgDn mueven una pantalla,
    // como en la lista principal. Filas algo más bajas para que entren
    // nueve aun con la búsqueda abierta.
    readonly property int shownRows: 9
    readonly property int rowHeight: 40

    function next(): void {
        current = Math.min(results.length - 1, current + 1);
    }

    function previous(): void {
        current = Math.max(0, current - 1);
    }

    function pageDown(): void {
        current = Math.min(results.length - 1, current + shownRows);
    }

    function pageUp(): void {
        current = Math.max(0, current - shownRows);
    }

    function accept(index: int): void {
        if (index >= 0 && index < results.length)
            chosen(results[index].url);
    }

    function openSearch(): void {
        searching = true;
        field.input.forceActiveFocus();
    }

    function closeSearch(): void {
        searching = false;
        field.input.clear();
        returnFocusTo?.input.forceActiveFocus();
    }

    function dismiss(): void {
        links = [];
    }

    // Cada tecla con el menú abierto. Solo devuelve false lo que el search
    // debe tipear. Esc retrocede como en el drawer: texto, búsqueda, menú.
    function handleKey(event): bool {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const key = event.key;

        if (key === Qt.Key_Down || key === Qt.Key_Tab || ctrl && (key === Qt.Key_J || key === Qt.Key_N))
            next();
        else if (key === Qt.Key_Up || key === Qt.Key_Backtab || ctrl && (key === Qt.Key_K || key === Qt.Key_P))
            previous();
        else if (key === Qt.Key_PageDown)
            pageDown();
        else if (key === Qt.Key_PageUp)
            pageUp();
        else if (key === Qt.Key_Return || key === Qt.Key_Enter)
            accept(current);
        else if (ctrl && key === Qt.Key_H)
            helpToggled();
        else if (key === Qt.Key_Escape && field.text)
            field.input.clear();
        else if (key === Qt.Key_Escape && searching)
            closeSearch();
        else if (key === Qt.Key_Escape)
            dismiss();
        else if (searching)
            return false; // lo tipea el search
        else if (event.text === "/")
            openSearch();
        else if (key >= Qt.Key_1 && key <= Qt.Key_9)
            accept(key - Qt.Key_1);
        return true;
    }

    onLinksChanged: {
        finder = new Fzf.Finder(links, { selector: url => url, match: Fzf.extendedMatch, fuzzy: "v2", casing: "smart-case" });
        if (!links.length) {
            searching = false;
            field.input.clear();
            returnFocusTo?.input.forceActiveFocus();
        }
        current = 0;
    }
    onResultsChanged: current = 0

    visible: opacity > 0
    opacity: shown ? 1 : 0

    Behavior on opacity {
        Anim {
            type: Anim.DefaultEffects
        }
    }

    // Vela sobre el drawer; el click vuelve. Toma hover y rueda para que la
    // lista de abajo ni brille ni scrollee con el menú abierto.
    Rectangle {
        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        color: Qt.alpha(Colours.palette.m3surface, 0.6)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.dismiss()
            onWheel: wheel => wheel.accepted = true
        }
    }

    Rectangle {
        id: card

        anchors.centerIn: parent
        width: Math.min(680, parent.width - Tokens.padding.large * 4)
        height: column.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer
        scale: root.shown ? 1 : 0.9

        Behavior on scale {
            Anim {}
        }

        // Tragar clicks, hover y rueda: ni al scrim que cierra ni a la
        // lista de abajo (la lista de links scrollea encima).
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onWheel: wheel => wheel.accepted = true
        }

        Column {
            id: column

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.large

            Row {
                spacing: Tokens.spacing.small
                leftPadding: Tokens.padding.small

                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "link"
                    fontStyle: Tokens.font.icon.medium
                    color: Colours.palette.m3primary
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Open which link?")
                    font: Tokens.font.body.builders.large.weight(Font.Medium).build()
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("%1 found").arg(root.links.length)
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.small
                }
            }

            // La búsqueda, que se desliza con "/" igual que la ayuda.
            Item {
                width: parent.width
                height: root.searching ? field.implicitHeight + Tokens.spacing.medium : 0
                opacity: root.searching ? 1 : 0
                clip: true

                Behavior on height {
                    Anim {}
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                PickerSearchBar {
                    id: field

                    anchors.bottom: parent.bottom
                    width: parent.width
                    placeholder: qsTr("Search links")
                    counter: `${root.results.length}/${root.links.length}`
                    input.focus: false
                    input.Keys.onPressed: event => event.accepted = root.handleKey(event)
                }
            }

            Item {
                width: parent.width
                height: Tokens.spacing.medium
            }

            ListView {
                id: list

                readonly property int rows: Math.max(1, Math.min(root.links.length, root.shownRows))

                width: parent.width
                // Dimensionada por los links, no por los matches: buscar no
                // hace saltar la tarjeta.
                height: rows * root.rowHeight + (rows - 1) * spacing
                clip: true
                spacing: 4
                model: root.results
                currentIndex: root.current
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false
                highlightFollowsCurrentItem: false
                highlightRangeMode: ListView.ApplyRange
                preferredHighlightBegin: 0
                preferredHighlightEnd: height

                highlight: Rectangle {
                    radius: Tokens.rounding.large
                    color: Colours.palette.m3onSurface
                    opacity: 0.08
                    y: list.currentItem?.y ?? 0
                    width: list.width
                    height: list.currentItem?.height ?? 0

                    Behavior on y {
                        Anim {}
                    }
                }

                delegate: Item {
                    required property var modelData
                    required property int index

                    width: list.width
                    height: root.rowHeight

                    // Como en la lista principal: el hover solo ilumina, la
                    // selección se mueve con teclas y el click abre.
                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.rounding.large
                        color: Colours.palette.m3onSurface
                        opacity: hover.containsMouse ? 0.08 : 0

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
                        onClicked: root.accept(index)
                    }

                    // Numerados sin buscar, cuando 1-9 eligen directo.
                    KeyCap {
                        id: number

                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: !root.searching && index < 9 ? 1 : 0
                        text: String(index + 1)

                        Behavior on opacity {
                            Anim {
                                type: Anim.DefaultEffects
                            }
                        }
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.padding.medium + number.implicitWidth + Tokens.spacing.medium
                        anchors.right: parent.right
                        anchors.rightMargin: Tokens.padding.medium
                        anchors.verticalCenter: parent.verticalCenter
                        text: Markup.highlighted(modelData.url, modelData.positions, Colours.palette.m3primary)
                        textFormat: Text.StyledText
                        font: Tokens.font.body.medium
                        elide: Text.ElideMiddle
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: qsTr("No matching links")
                    color: Colours.palette.m3outline
                }
            }

            // Atajos del menú, con la ayuda del drawer (Ctrl+H) y el mismo
            // deslizamiento; el footer del drawer keeps lo suyo. Ctrl+H solo
            // se lista ahí, porque alterna ambos.
            Item {
                width: parent.width
                height: root.showHelp ? menuHelp.implicitHeight + Tokens.padding.large : 0
                opacity: root.showHelp ? 1 : 0
                clip: true

                Behavior on height {
                    Anim {}
                }

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                HelpBar {
                    id: menuHelp

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    maxWidth: parent.width
                    items: root.searching ? [
                        { keys: ["Enter"], label: qsTr("open") },
                        { keys: ["Esc"], label: root.query ? qsTr("clear search") : qsTr("close search") }
                    ] : [
                        { keys: ["Enter"], label: qsTr("open") },
                        { keys: ["1–9"], label: qsTr("open by number") },
                        { keys: ["/"], label: qsTr("search") },
                        { keys: ["Esc"], label: qsTr("back") }
                    ]
                }
            }
        }
    }
}
