pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.clipboard.services
import "scripts/fzf.js" as Fzf

// Contenido del panel (lista+preview+buscador). La animación open/close vive
// en el Wrapper (como Launcher.Wrapper); aquí solo sizing y altura animada
// al filtrar (como ContentList del launcher).
Item {
    id: root

    required property ScreenState screenState
    // Techo disponible ya calculado por el Wrapper (como el launcher:
    // alto de pantalla menos dashboard). Aquí solo se reparte.
    required property real maxHeight

    property int selectedIndex: 0
    // Gate de transiciones por-item durante el filtrado (molde AppList
    // enabled: !root.state; aqui no hay estados, el flag se baja con
    // callLater tras asignar el modelo).
    property bool filtering: false
    // Modo borrar (SUPER+ALT+V via clipboardDeleteMode en ScreenState):
    // Enter/Delete borra en vez de pegar y el drawer queda abierto.
    readonly property bool deleteMode: screenState.clipboardDeleteMode
    property bool previewVisible: false
    // Hay contenido listo para mostrar (imagen/binario en memoria o texto
    // ya decodificado). La caja solo se abre con contenido: nunca vacía.
    property bool previewHasContent: false
    property string previewId: ""
    property string previewImagePath: ""
    property var visibleItems: []
    onSelectedIndexChanged: previewDebounce.restart()

    // Inset del contenido (como Content del launcher: padding = padding.large).
    readonly property int padding: Tokens.padding.large
    // previewHeight no tiene token C++: const nombrada y documentada.
    readonly property int previewHeight: 170
    // Gate anti-decode: solo se decodifica automáticamente texto corto;
    // imagen y binario no necesitan decode (thumb/preview ya en memoria).
    readonly property int previewDecodeLimit: 4000
    // Altura de fila real (delegate + spacing): misma fuente que el delegate
    // (ClipboardItem.implicitHeight) y que la lista (spacing).
    readonly property int rowH: Tokens.sizes.launcher.itemHeight + Tokens.spacing.small
    // Altura del estado vacío (como ContentList: alto del Row "No results").
    readonly property int emptyH: Tokens.sizes.launcher.itemHeight + Tokens.padding.large * 2
    // Altura de la zona de lista (fuente única: la lista la lee de aquí).
    readonly property int maxRows: ClipboardConfig.maxRows
    readonly property int rowsH: visibleItems.length === 0 ? emptyH : (Math.min(maxRows, visibleItems.length) * rowH - Tokens.spacing.small)
    // Presupuesto de lista: lo que queda tras reservar search + preview.
    // Math.max(0, ...) evita implicitHeight negativo con dashboard abierto.
    readonly property int listBudget: maxHeight - search.height - (previewVisible ? previewHeight + Tokens.spacing.medium : 0) - Tokens.spacing.medium - padding * 2
    readonly property int listH: Math.min(rowsH, Math.max(0, listBudget))

    implicitWidth: Tokens.sizes.launcher.itemWidth
    // Derivada de los componentes (filosofía launcher/Content.qml:22):
    // search + lista + preview + padding. Sin números mágicos.
    implicitHeight: listH + (previewVisible ? previewHeight + Tokens.spacing.medium : 0) + search.height + Tokens.spacing.medium + padding * 2
    width: implicitWidth
    height: implicitHeight

    // Debounce del preview automático: dispara 250ms tras reposo de la
    // selección; se cancela si la selección cambia de nuevo.
    Timer {
        id: previewDebounce

        interval: 250
        onTriggered: root.syncPreview()
    }

    // Anima el cambio de altura al filtrar (como ContentList: Behavior on implicitHeight).
    Behavior on implicitHeight {
        enabled: screenState.clipboard
        Anim {}
    }

    // Mismo motor del launcher (fzf-for-js, BSD). Con try/catch para que un
    // fallo del import nunca deje la lista vacía en silencio.
    function fuzzyFind(items, query) {
        query = query.trim().replace(/\s+/g, " ");
        if (!query)
            return items.slice();
        try {
            const finder = new Fzf.Finder(items, { selector: item => item.preview });
            return finder.find(query).sort((x, y) => {
                if (x.score === y.score)
                    return x.item.preview.trim().length - y.item.preview.trim().length;
                return y.score - x.score;
            }).map(r => r.item);
        } catch (e) {
            console.warn("clipboard: fuzzyFind falló, usando lista sin filtrar:", e);
            return items.slice();
        }
    }

    function updateFilter() {
        filtering = true;
        visibleItems = fuzzyFind(Cliphist.items, search.text);
        selectedIndex = Math.max(0, Math.min(selectedIndex, visibleItems.length - 1));
        Qt.callLater(() => filtering = false);
        previewDebounce.restart();
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
        clipList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    // Preview automático con gate: imagen y binario no necesitan decode
    // (thumb/preview ya están en memoria) y abren al instante; el texto
    // largo muestra su preview corto sin decodificar; el texto corto se
    // decodifica y la caja se abre al llegar el contenido (nunca vacía).
    function showPreviewGated(item) {
        previewId = item.id;
        if (item.image) {
            previewImage.opacity = 0;
            previewImagePath = item.image;
            previewHasContent = true;
            previewVisible = true;
            Cliphist.contents = "";
        } else if (item.preview.startsWith("[[ binary data")) {
            previewImagePath = "";
            previewHasContent = true;
            previewVisible = true;
            Cliphist.contents = item.preview;
        } else if (item.preview.length <= previewDecodeLimit) {
            previewImagePath = "";
            previewHasContent = false;
            previewVisible = false;
            Cliphist.decode(item.id);
        } else {
            previewImagePath = "";
            previewHasContent = true;
            previewVisible = true;
            Cliphist.contents = item.preview;
        }
    }

    function syncPreview() {
        const item = selectedItem();
        if (!item) {
            previewVisible = false;
            previewHasContent = false;
            return;
        }
        if (item.id === previewId) {
            previewVisible = previewHasContent;
            return;
        }
        showPreviewGated(item);
    }

    function activate() {
        const item = selectedItem();
        if (!item)
            return;
        if (root.deleteMode) {
            removeSelected();
            return;
        }
        Cliphist.paste(item.id);
        screenState.clipboard = false;
    }

    function removeAt(idx) {
        if (idx < 0 || idx >= visibleItems.length)
            return;
        Cliphist.remove(visibleItems[idx].id);
    }

    function removeSelected() {
        removeAt(Math.min(selectedIndex, visibleItems.length - 1));
    }

    function open() {
        ClipboardConfig.load();
        search.clear();
        updateFilter();
        selectedIndex = 0;
        previewVisible = false;
        previewHasContent = false;
        previewId = "";
        previewImagePath = "";
        Cliphist.refresh();
        search.forceActiveFocus(Qt.TabFocusReason);
    }

    // El Loader crea este Content cuando ya está abierto: sin cambio de
    // clipboard no hay onClipboardChanged, hay que sincronizar al crear
    // (como AppList: displayText = search.text).
    Component.onCompleted: {
        if (screenState.clipboard)
            root.open();
    }

    Connections {
        target: root.screenState
        function onClipboardChanged() {
            if (root.screenState.clipboard)
                root.open();
            else {
                search.clear();
                // Sin persistencia del modo: cerrar siempre vuelve a normal.
                root.screenState.clipboardDeleteMode = false;
            }
        }
    }

    Connections {
        target: Cliphist
        function onItemsChanged() {
            root.updateFilter();
        }
        // El decode terminó: abrir la caja solo si sigue siendo el item
        // seleccionado (si falló, no hay onContentsChanged y no se abre).
        function onContentsChanged() {
            if (Cliphist.contentsId === root.previewId && !root.previewHasContent) {
                root.previewHasContent = true;
                root.previewVisible = true;
            }
        }
    }

    // Sin caja propia: el fondo lo pone el PanelBg blob (como el launcher,
    // cuyo Content es un Item desnudo). Solo insets con tokens.
    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Tokens.spacing.medium

            // Lista arriba (como ContentList sobre el SearchBar)
            ClipboardList {
                id: clipList
                content: root
            }

            // Full content
            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: root.previewVisible ? root.previewHeight : 0
                Layout.leftMargin: root.padding
                Layout.rightMargin: root.padding
                radius: Tokens.rounding.large
                color: Colours.palette.m3surface
                clip: true
                // Booleano (no height > 0): exclusión del layout determinista,
                // sin depender del estado de la animación de preferredHeight.
                visible: root.previewVisible

                Behavior on Layout.preferredHeight {
                    Anim {}
                }

                Text {
                    id: previewHeader
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.topMargin: Tokens.padding.small
                    text: "Full content"
                    color: Colours.palette.m3primary
                    font: Tokens.font.body.small
                }

                Flickable {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: previewHeader.bottom
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    anchors.topMargin: Tokens.padding.small
                    anchors.bottomMargin: Tokens.padding.small
                    visible: !root.previewImagePath
                    contentWidth: width
                    contentHeight: Math.max(height, fullText.implicitHeight)
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    // StyledText con animate:true: funde opacity al cambiar el
                    // texto (igual que el filtrado de la búsqueda), sin cableado.
                    StyledText {
                        id: fullText
                        width: parent.width
                        animate: true
                        text: Cliphist.contentsLoading ? "Loading…" : Cliphist.contents
                        wrapMode: Text.Wrap
                    }
                }

                Image {
                    id: previewImage
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: previewHeader.bottom
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.rightMargin: Tokens.padding.medium
                    anchors.topMargin: Tokens.padding.small
                    anchors.bottomMargin: Tokens.padding.small
                    visible: !!root.previewImagePath
                    source: root.previewImagePath
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    // Fundido al cambiar de imagen (showPreviewGated baja a 0
                    // al cambiar source; al estar lista vuelve a 1).
                    Behavior on opacity {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                    onStatusChanged: {
                        if (status === Image.Ready)
                            previewImage.opacity = 1;
                    }
                    // No decodificar de más: la caja mide previewHeight.
                    sourceSize.height: root.previewHeight * 2
                }
            }

            // Buscador abajo: SearchBar real del launcher (no imitación).
            // Márgenes en los 4 lados como launcher/Content.qml:52-56
            // (anchors.margins: padding); aquí vía Layout + spacing arriba.
            SearchBar {
                id: search

                objectName: "clipboardSearch"
                Layout.fillWidth: true
                Layout.leftMargin: root.padding
                Layout.rightMargin: root.padding
                Layout.bottomMargin: root.padding

                topPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
                bottomPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)

                placeholderText: root.deleteMode ? qsTr("Delete mode — Enter erases…") : qsTr("Search clipboard history…")

                onAccepted: root.activate()
                onTextChanged: {
                    root.updateFilter();
                    root.selectedIndex = 0;
                }

                Keys.onDownPressed: root.moveSelection(1)
                Keys.onUpPressed: root.moveSelection(-1)
                Keys.onEscapePressed: root.screenState.clipboard = false
                Keys.onPressed: event => {
                    // Delete solo en modo borrar (SUPER+ALT+V): el drawer
                    // normal no tiene ninguna via de borrado.
                    if (event.key === Qt.Key_Delete && root.deleteMode) {
                        root.removeSelected();
                        event.accepted = true;
                    } else if (event.modifiers & Qt.ControlModifier) {
                        if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                            root.moveSelection(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                            root.moveSelection(-1);
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
