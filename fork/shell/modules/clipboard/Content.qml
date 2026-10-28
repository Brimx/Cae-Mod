pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.modules.clipboard.services
import "scripts/fzf.js" as Fzf

// Drawer del historial (porte de clip-picker a drawer Caelestia + tokens):
// lista con matches resaltados + preview lateral, search abajo con contador
// y ayuda en keycaps. La animación open/close vive en el Wrapper (como el
// launcher); aquí solo sizing y lógica. Ver shot de referencia en discusión
// caelestia-dots/shell#2108.
Item {
    id: root

    required property ScreenState screenState
    // Techo disponible ya calculado por el Wrapper (alto de pantalla menos
    // dashboard). La lista muestra maxShown filas fijas como el picker.
    required property real maxHeight

    // Gate de transiciones por-item durante el filtrado (molde AppList).
    property bool filtering: false
    // Modo borrar: Enter/Delete borra y el drawer queda abierto. Se entra
    // con el atajo global (clipboardDelete) o Ctrl+Shift+D adentro; se sale
    // con Esc o tras borrar en lote.
    property bool deleteMode: false
    property bool showHelp: false
    // id -> true; se reemplaza, nunca se muta, para que los bindings avisen.
    property var marked: ({})
    readonly property int markedCount: Object.keys(marked).length

    property var finder: null

    readonly property var results: {
        const q = search.text.trim();
        if (!finder)
            return [];
        // Sets no sobreviven al delegate como modelData; arrays sí.
        return finder.find(q).map(r => ({ item: r.item, positions: Array.from(r.positions) }));
    }

    readonly property var current: clipList.currentItem?.entry ?? null

    // Inset del contenido (como Content del launcher).
    readonly property int padding: Tokens.padding.large
    // Sin token C++: consts nombradas del picker (listWidth 600,
    // previewWidth 520, 7 filas visibles, fila 57 como el launcher).
    readonly property int listW: 600
    readonly property int previewW: 520
    readonly property int maxShown: 7
    readonly property int rowH: Tokens.sizes.launcher.itemHeight + Tokens.spacing.small
    readonly property int listH: maxShown * rowH - Tokens.spacing.small

    implicitWidth: listW + Tokens.spacing.medium + previewW + padding * 2
    implicitHeight: layout.implicitHeight + padding * 2
    width: implicitWidth
    height: implicitHeight

    // Anima el cambio de altura al filtrar (como ContentList).
    Behavior on implicitHeight {
        enabled: screenState.clipboard
        Anim {}
    }

    function load(): void {
        Cliphist.refresh();
    }

    function copy(entry: var): void {
        if (!entry)
            return;
        Cliphist.copy(entry);
        closeDrawer();
    }

    // Ctrl+O. cliphist corta a 100 chars: se decodifica primero; si es un
    // solo path se abre; si no se juntan los links (en orden, únicos, sin
    // puntuación final): uno abre directo, varios levantan el menú.
    function open(entry: var): void {
        if (!entry || entry.image || linkFinder.running)
            return;
        linkFinder.command = ["sh", "-c", `
            t=$(printf "%s" "$1" | cliphist decode)
            s=$(printf "%s" "$t" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            case $s in
                "~" | "~/"* | /*)
                    if [ "$(printf "%s" "$s" | wc -l)" -eq 0 ]; then
                        printf 'path\t%s\n' "$s"
                        exit 0
                    fi ;;
            esac
            printf "%s" "$t" | grep -oE '(https?|ftp|file)://[^[:space:]<>"]+' |
                sed -E 's/[].,;:!?)}>]+$//' | awk '!seen[$0]++' | sed 's/^/url\t/'`, "sh", entry.line];
        linkFinder.running = true;
    }

    function foundLinks(out: string): void {
        const found = out.split("\n").filter(l => l.includes("\t")).map(l => {
            const tab = l.indexOf("\t");
            return { kind: l.slice(0, tab), target: l.slice(tab + 1) };
        });
        if (!found.length)
            Quickshell.execDetached(["notify-send", "-a", "Clipboard", "Nothing to open", "No link or path in this entry"]);
        else if (found.length === 1)
            openTarget(found[0].kind, found[0].target);
        else
            linkMenu.links = found.map(f => f.target);
    }

    // Links directo a xdg-open; paths (~ expandida) solo si existen, con
    // notificación en vez del fallo silencioso de xdg-open.
    function openTarget(kind: string, target: string): void {
        Quickshell.execDetached(["sh", "-c", `
            t=$1
            case $t in "~" | "~/"*) t="$HOME\${t#"~"}" ;; esac
            if [ "$2" = path ] && [ ! -e "$t" ]; then
                notify-send -a Clipboard "Nothing to open" "$t does not exist"
                exit 1
            fi
            exec xdg-open "$t"`, "sh", target, kind]);
        closeDrawer();
    }

    // Copia descartable afuera: imágenes a swappy, texto a $VISUAL/$EDITOR
    // en kitty. La entrada no se toca ("send", no "edit"): la versión
    // cambiada se guarda desde swappy o el editor. El script espera el
    // cierre y borra el temporal, así que va detached y el drawer cierra.
    function sendToEditor(entry: var): void {
        if (!entry)
            return;
        const ext = entry.image ? entry.image.format : "txt";
        const open = entry.image
            ? 'swappy -f "$f"'
            : 'kitty --class clip-picker-editor -e ${VISUAL:-${EDITOR:-nvim}} "$f"';
        Quickshell.execDetached(["sh", "-c", `
            f=$(mktemp -p "\${XDG_RUNTIME_DIR:-/tmp}" --suffix=".$2" clip-picker-copy.XXXXXX) || exit 1
            trap 'rm -f "$f"' EXIT
            printf "%s" "$1" | cliphist decode >"$f"
            ${open}`, "sh", entry.line, ext]);
        closeDrawer();
    }

    function removeEntries(entries: var): void {
        const lines = entries.filter(e => e).map(e => e.line);
        if (!lines.length)
            return;
        keepIndex = clipList.currentIndex;
        Cliphist.removeLines(lines);
    }

    function toggleMark(entry: var): void {
        if (!entry)
            return;
        const next = Object.assign({}, marked);
        if (next[entry.id])
            delete next[entry.id];
        else
            next[entry.id] = true;
        marked = next;
    }

    // Ctrl+A: marca todo lo visible, o limpia si ya está todo marcado.
    function markAllShown(): void {
        const shown = results.map(r => r.item);
        const all = shown.length && shown.every(e => marked[e.id]);
        const next = Object.assign({}, marked);
        for (const e of shown) {
            if (all)
                delete next[e.id];
            else
                next[e.id] = true;
        }
        marked = next;
    }

    function setDeleteMode(on: bool): void {
        deleteMode = on;
        screenState.clipboardDeleteMode = on;
        marked = {};
    }

    function closeDrawer(): void {
        screenState.clipboard = false;
    }

    function activate(): void {
        if (!current)
            return;
        if (deleteMode)
            removeEntries([current]);
        else
            copy(current);
    }

    function moveSelection(offset: int): void {
        if (!results.length)
            return;
        clipList.currentIndex = Math.max(0, Math.min(results.length - 1, clipList.currentIndex + offset));
    }

    function openDrawer(): void {
        ClipboardConfig.load();
        finder = null;
        marked = {};
        showHelp = false;
        linkMenu.dismiss();
        deleteMode = screenState.clipboardDeleteMode;
        search.clear();
        load();
        search.input.forceActiveFocus(Qt.TabFocusReason);
    }

    property int keepIndex: 0

    // El Loader crea este Content cuando ya está abierto: sin cambio de
    // clipboard no hay onClipboardChanged, hay que sincronizar al crear.
    Component.onCompleted: {
        if (screenState.clipboard)
            root.openDrawer();
    }

    Connections {
        target: root.screenState
        function onClipboardChanged() {
            if (root.screenState.clipboard)
                root.openDrawer();
            else {
                search.clear();
                // Sin persistencia del modo: cerrar siempre vuelve a normal.
                root.screenState.clipboardDeleteMode = false;
                root.deleteMode = false;
            }
        }
    }

    Connections {
        target: Cliphist
        function onLoaded() {
            root.finder = new Fzf.Finder(Cliphist.items, {
                selector: e => e.text,
                match: Fzf.extendedMatch,
                fuzzy: "v2",
                casing: "smart-case"
            });
        }
        // Tras borrar: se sale del modo lote, se recarga y se restaura el índice.
        function onEmptied() {
            const keep = root.keepIndex;
            root.setDeleteMode(false);
            root.load();
            clipList.currentIndex = Math.max(0, Math.min(keep, clipList.count - 1));
        }
    }

    // Sin caja propia: el fondo lo pone el PanelBg blob (como el launcher,
    // cuyo Content es un Item desnudo). Solo insets con tokens.
    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.padding
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            ClipboardList {
                id: clipList

                content: root
                Layout.preferredWidth: root.listW
                Layout.preferredHeight: root.listH
            }

            Preview {
                Layout.preferredWidth: root.previewW
                Layout.preferredHeight: root.listH
                entry: root.current
            }
        }

        PickerSearchBar {
            id: search

            Layout.fillWidth: true
            deleteMode: root.deleteMode
            counter: {
                if (!Cliphist.items.length)
                    return "";
                const shown = `${clipList.count}/${Cliphist.items.length}`;
                return root.deleteMode ? qsTr("%1 marked · %2").arg(root.markedCount).arg(shown) : shown;
            }

            // Enter lo maneja input.Keys de abajo; sin onAccepted para no
            // activar dos veces (el Keys acepta el evento antes).
            onTextChanged: {
                root.filtering = true;
                Qt.callLater(() => root.filtering = false);
            }

            input.Keys.onPressed: event => {
                const ctrl = event.modifiers & Qt.ControlModifier;
                const shift = event.modifiers & Qt.ShiftModifier;
                const key = event.key;
                const enter = key === Qt.Key_Return || key === Qt.Key_Enter;

                // El menú de links, abierto, toma todas las teclas.
                if (linkMenu.shown) {
                    linkMenu.handleKey(event);
                    event.accepted = true;
                    return;
                }

                if (key === Qt.Key_Down || ctrl && (key === Qt.Key_J || key === Qt.Key_N))
                    root.moveSelection(1);
                else if (key === Qt.Key_Up || ctrl && (key === Qt.Key_K || key === Qt.Key_P))
                    root.moveSelection(-1);
                else if (key === Qt.Key_PageDown)
                    root.moveSelection(root.maxShown);
                else if (key === Qt.Key_PageUp)
                    root.moveSelection(-root.maxShown);
                else if (key === Qt.Key_Escape && search.text)
                    search.input.clear(); // Esc: primero el search, después el modo, después el drawer
                else if (key === Qt.Key_Escape && root.deleteMode)
                    root.setDeleteMode(false);
                else if (key === Qt.Key_Escape)
                    root.closeDrawer();
                else if (ctrl && key === Qt.Key_H)
                    root.showHelp = !root.showHelp;
                else if (ctrl && shift && key === Qt.Key_D)
                    root.setDeleteMode(!root.deleteMode);
                else if (root.deleteMode && key === Qt.Key_Tab) {
                    root.toggleMark(root.current);
                    root.moveSelection(1);
                } else if (root.deleteMode && key === Qt.Key_Backtab) {
                    root.toggleMark(root.current);
                    root.moveSelection(-1);
                } else if (root.deleteMode && ctrl && key === Qt.Key_A)
                    root.markAllShown();
                else if (root.deleteMode && enter)
                    root.removeEntries(root.markedCount ? Cliphist.items.filter(e => root.marked[e.id]) : [root.current]);
                else if (key === Qt.Key_Tab)
                    root.moveSelection(1);
                else if (key === Qt.Key_Backtab)
                    root.moveSelection(-1);
                else if (enter)
                    root.activate();
                else if (ctrl && key === Qt.Key_E)
                    root.sendToEditor(root.current);
                else if (ctrl && key === Qt.Key_O)
                    root.open(root.current);
                else if (ctrl && key === Qt.Key_D)
                    root.removeEntries([root.current]);
                else
                    return;
                event.accepted = true;
            }

            Component.onCompleted: input.forceActiveFocus()

            Connections {
                function onSessionChanged(): void {
                    if (!root.screenState.session)
                        search.input.forceActiveFocus();
                }

                target: root.screenState
            }
        }

        // La ayuda crece y se funde en vez de aparecer. Con preferredHeight
        // (no height explícito): dentro de un Layout el alto explícito lo
        // pisa el layout y la animación pelea subiendo y bajando.
        Item {
            id: helpBox

            Layout.fillWidth: true
            Layout.preferredHeight: root.showHelp ? helpBar.implicitHeight + Tokens.padding.large : 0
            opacity: root.showHelp ? 1 : 0
            clip: true

            Behavior on Layout.preferredHeight {
                Anim {}
            }

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            HelpBar {
                id: helpBar

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                maxWidth: search.width - Tokens.padding.large * 2
                items: root.deleteMode ? [
                    { keys: ["Tab"], label: qsTr("mark") },
                    { keys: ["Ctrl", "A"], label: qsTr("mark all shown") },
                    { keys: ["Enter"], label: root.markedCount ? qsTr("delete %1 marked").arg(root.markedCount) : qsTr("delete highlighted") },
                    { keys: ["Esc"], label: qsTr("back") },
                    { keys: ["Ctrl", "H"], label: qsTr("hide help") }
                ] : [
                    { keys: ["Enter"], label: qsTr("copy") },
                    { keys: ["Ctrl", "O"], label: qsTr("open link or path") },
                    { keys: ["Ctrl", "E"], label: root.current?.image ? qsTr("send to swappy") : qsTr("send to editor") },
                    { keys: ["Ctrl", "D"], label: qsTr("delete") },
                    { keys: ["Ctrl", "Shift", "D"], label: qsTr("delete several") },
                    { keys: ["Esc"], label: qsTr("close") },
                    { keys: ["Ctrl", "H"], label: qsTr("hide help") }
                ]
            }
        }
    }

    LinkMenu {
        id: linkMenu

        anchors.fill: parent
        returnFocusTo: search
        showHelp: root.showHelp
        onChosen: url => root.openTarget("url", url)
        onHelpToggled: root.showHelp = !root.showHelp
    }
}
