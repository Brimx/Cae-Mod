pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.emoji.services
import "scripts/fzf.js" as Fzf

// Contenido del drawer emoji (molde clipboard/Content.qml: mismo slot
// inferior, SearchBar abajo, altura derivada; la lista se cambia por
// CategoryRow + GridView, sin caja de preview).
Item {
    id: root

    required property ScreenState screenState
    required property real maxHeight

    property int selectedIndex: 0
    // Gate de transiciones por-item durante filtrado/cambio de categoria
    // (igual que clipboard/Content.qml).
    property bool filtering: false
    // -1 todo, -2 recientes, resto = id de grupo emojibase/glyphs/texto.
    property int activeGroup: -1
    property var visibleItems: []

    readonly property int padding: Tokens.padding.large
    readonly property int columns: 10
    readonly property int cellWH: Math.max(44, Math.floor((Tokens.sizes.launcher.itemWidth - padding * 2) / columns))
    readonly property int maxVisible: 300
    // Altura FIJA (como el launcher: ContentList capa por maxHeight y
    // scrollea dentro). Nunca crece con la categoria.
    readonly property int gridRows: 5
    readonly property int rowH: cellWH
    readonly property int emptyH: Tokens.sizes.launcher.itemHeight + Tokens.padding.large * 2
    readonly property int rowsH: visibleItems.length === 0 ? emptyH : gridRows * rowH
    readonly property int listBudget: maxHeight - search.height - catRow.height - Tokens.spacing.medium * 2 - padding * 2
    readonly property int listH: Math.min(rowsH, Math.max(0, listBudget))

    implicitWidth: Tokens.sizes.launcher.itemWidth
    implicitHeight: catRow.height + listH + search.height + Tokens.spacing.medium * 2 + padding * 2
    width: implicitWidth
    height: implicitHeight

    Behavior on implicitHeight {
        enabled: screenState.emoji
        Anim {}
    }

    // Mapa char -> item para resolver recientes sin barrer 12k cada vez.
    property var charIndex: ({})
    function rebuildIndex() {
        const map = {};
        for (const item of Emoji.items)
            if (!(item.c in map))
                map[item.c] = item;
        charIndex = map;
    }

    function baseItems() {
        if (root.activeGroup === -2)
            return Emoji.recents.map(c => charIndex[c] ?? { c: c, label: "", tags: "", g: -2, o: 0 });
        if (root.activeGroup === -1)
            return Emoji.items.slice();
        return Emoji.items.filter(item => item.g === root.activeGroup);
    }

    // Mismo motor fzf del clipboard; selector = char + label + tags.
    function fuzzyFind(items, query) {
        query = query.trim().replace(/\s+/g, " ");
        if (!query)
            return items.slice(0, root.maxVisible);
        try {
            const finder = new Fzf.Finder(items, { selector: item => (item.c + " " + item.label + " " + item.tags) });
            return finder.find(query).map(r => r.item).slice(0, root.maxVisible);
        } catch (e) {
            console.warn("emoji: fuzzyFind fallo, usando lista sin filtrar:", e);
            return items.slice(0, root.maxVisible);
        }
    }

    function updateFilter() {
        // Con texto se busca en todo (como el picker fuzzel); sin texto
        // manda la categoria activa.
        filtering = true;
        const query = search.text.trim();
        const base = query ? Emoji.items.slice() : baseItems();
        visibleItems = fuzzyFind(base, query);
        Qt.callLater(() => filtering = false);
    }

    function selectedItem() {
        if (visibleItems.length === 0)
            return null;
        return visibleItems[Math.min(selectedIndex, visibleItems.length - 1)];
    }

    function moveSelection(offset) {
        const count = visibleItems.length;
        if (count === 0)
            return;
        selectedIndex = Math.max(0, Math.min(count - 1, selectedIndex + offset));
        emojiGrid.positionViewAtIndex(selectedIndex, GridView.Contain);
    }

    function activate() {
        const item = selectedItem();
        if (!item)
            return;
        Emoji.copy(item.c);
        Toaster.toast(qsTr("Copied to clipboard"), item.c, "content_copy", Toast.Info);
        screenState.emoji = false;
    }

    function open() {
        Emoji.load();
        search.clear();
        activeGroup = Emoji.recents.length > 0 ? -2 : -1;
        updateFilter();
        selectedIndex = 0;
        search.forceActiveFocus(Qt.TabFocusReason);
    }

    Component.onCompleted: {
        if (screenState.emoji)
            root.open();
    }

    Connections {
        target: root.screenState
        function onEmojiChanged() {
            if (root.screenState.emoji)
                root.open();
            else
                search.clear();
        }
    }

    Connections {
        target: Emoji
        function onItemsChanged() {
            root.rebuildIndex();
            root.updateFilter();
        }
        function onRecentsChanged() {
            if (!search.text.trim())
                root.updateFilter();
        }
        function onGroupsChanged() {
            root.updateFilter();
        }
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Tokens.spacing.medium

        // Categorias (chips como WallpaperSelect ButtonRow + IconTextButton,
        // pero con TextButton: solo texto, sin icono vacio).
        Flickable {
            id: catRow
            Layout.fillWidth: true
            Layout.topMargin: root.padding
            Layout.leftMargin: root.padding
            Layout.rightMargin: root.padding
            Layout.preferredHeight: catContent.height
            contentWidth: catContent.width
            contentHeight: catContent.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            Row {
                id: catContent
                spacing: Tokens.spacing.small

                TextButton {
                    text: qsTr("All")
                    type: root.activeGroup === -1 ? TextButton.Filled : TextButton.Text
                    onClicked: {
                        root.activeGroup = -1;
                        root.selectedIndex = 0;
                        root.updateFilter();
                    }
                }

                TextButton {
                    visible: Emoji.recents.length > 0
                    text: qsTr("Recent")
                    type: root.activeGroup === -2 ? TextButton.Filled : TextButton.Text
                    onClicked: {
                        root.activeGroup = -2;
                        root.selectedIndex = 0;
                        root.updateFilter();
                    }
                }

                Repeater {
                    model: Emoji.groups
                    TextButton {
                        required property var modelData
                        text: modelData.name
                        type: root.activeGroup === modelData.id ? TextButton.Filled : TextButton.Text
                        onClicked: {
                            root.activeGroup = modelData.id;
                            root.selectedIndex = 0;
                            root.updateFilter();
                        }
                    }
                }
            }
        }

        EmojiGrid {
            id: emojiGrid
            content: root
        }

        SearchBar {
            id: search

            objectName: "emojiSearch"
            Layout.fillWidth: true
            Layout.leftMargin: root.padding
            Layout.rightMargin: root.padding
            Layout.bottomMargin: root.padding

            topPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
            bottomPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)

            placeholderText: qsTr("Search emojis and glyphs…")

            onAccepted: root.activate()
            onTextChanged: {
                root.updateFilter();
                root.selectedIndex = 0;
            }

            Keys.onLeftPressed: root.moveSelection(-1)
            Keys.onRightPressed: root.moveSelection(1)
            Keys.onUpPressed: root.moveSelection(-root.columns)
            Keys.onDownPressed: root.moveSelection(root.columns)
            Keys.onEscapePressed: root.screenState.emoji = false
            Keys.onPressed: event => {
                if (event.modifiers & Qt.ControlModifier) {
                    if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                        root.moveSelection(root.columns);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                        root.moveSelection(-root.columns);
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Tab) {
                    root.moveSelection(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                    root.moveSelection(-1);
                    event.accepted = true;
                }
            }

            Component.onCompleted: forceActiveFocus()

            Connections {
                function onSessionChanged(): void {
                    if (!root.screenState.session)
                        search.forceActiveFocus();
                }

                target: root.screenState
            }
        }
    }
}
