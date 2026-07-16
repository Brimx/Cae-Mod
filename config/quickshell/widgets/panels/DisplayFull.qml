import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.components

Item {
    id: root

    required property bool shown
    property var monitors: []
    property int selectedIndex: -1
    property bool applying: false

    signal closeRequested()

    function refreshMonitors(): void {
        fetchMonitors.running = true;
    }

    function selectedMonitor(): var {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.monitors.length)
            return root.monitors[root.selectedIndex];
        return null;
    }

    function writeMonitorsFile(monitorsConfig: string): void {
        Quickshell.execDetached(["bash", "-c",
            `cat > "${Quickshell.env("HOME")}/.config/hypr/hyprland/monitors.lua" << 'MONEOF'\n${monitorsConfig}\nMONEOF`
        ]);
    }

    function buildMonitorConfig(): string {
        let lines = [];
        for (const m of root.monitors) {
            let entry = `hl.monitor({\n    output   = "${m.name}",`;
            if (m.disabled) {
                entry += `\n    disabled = true,`;
            } else {
                entry += `\n    mode     = "${m.selWidth}x${m.selHeight}@${m.selRefresh.toFixed(2)}",`;
                entry += `\n    position = "${m.position}",`;
                entry += `\n    scale    = ${m.selScale.toFixed(2)},`;
                entry += `\n    disabled = false,`;
            }
            entry += `\n})`;
            lines.push(entry);
        }
        return lines.join("\n");
    }

    function applyChanges(): void {
        if (root.applying) return;
        root.applying = true;

        const config = buildMonitorConfig();
        writeMonitorsFile(config);

        for (const m of root.monitors) {
            if (m.disabled) {
                Quickshell.execDetached(["hyprctl", "keyword", "monitor", m.name + ",disable"]);
            } else {
                const res = m.selWidth + "x" + m.selHeight;
                const ref = m.selRefresh.toFixed(2);
                const cmd = m.name + "," + res + "@" + ref + "," + m.position + "," + m.selScale.toFixed(2);
                Quickshell.execDetached(["hyprctl", "keyword", "monitor", cmd]);
            }
        }

        statusText = "Cambios aplicados ✓";
        statusTimer.restart();
        root.applying = false;
    }

    property string statusText: ""

    Timer { id: statusTimer; interval: 2500; onTriggered: statusText = "" }

    Process {
        id: fetchMonitors

        command: ["hyprctl", "monitors", "-j"]
        running: root.shown

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const parsed = [];
                    for (const m of data) {
                        const modes = [];
                        for (const ms of m.availableModes) {
                            const match = ms.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
                            if (match) {
                                modes.push({
                                    width: parseInt(match[1]),
                                    height: parseInt(match[2]),
                                    refresh: parseFloat(match[3])
                                });
                            }
                        }
                        parsed.push({
                            name: m.name,
                            desc: m.description,
                            width: m.width,
                            height: m.height,
                            refresh: m.refreshRate,
                            scale: m.scale,
                            disabled: m.disabled,
                            x: m.x,
                            y: m.y,
                            availableModes: modes,
                            selWidth: m.width,
                            selHeight: m.height,
                            selRefresh: m.refreshRate,
                            selScale: m.scale,
                            position: m.x + "x" + m.y,
                            disabled: false
                        });
                    }
                    root.monitors = parsed;
                    if (parsed.length > 0) root.selectedIndex = 0;
                } catch (e) {
                    console.error("Parse error:", e);
                }
            }
        }
    }

    visible: root.shown
    opacity: root.shown ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 150 } }

    StyledRect {
        anchors.fill: parent
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.large

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                StyledText {
                    text: "Display Configuration"
                    font: Tokens.font.headline.small
                    color: Colours.palette.m3onSurface
                    Layout.fillWidth: true
                }

                StyledText {
                    text: root.statusText
                    font: Tokens.font.label.small
                    color: Colours.palette.m3success
                    visible: root.statusText.length > 0
                    Layout.alignment: Qt.AlignVCenter
                }

                Button {
                    implicitWidth: 36
                    implicitHeight: 36

                    background: StyledRect {
                        color: parent.hovered ? Colours.tPalette.m3surfaceContainerHigh : "transparent"
                        radius: Tokens.rounding.small
                    }

                    contentItem: MaterialIcon {
                        fontStyle: Tokens.font.icon.small
                        text: "close"
                        color: Colours.palette.m3onSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: root.closeRequested()
                }
            }

            // Layout presets
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { label: "Extendido", icon: "grid_view" },
                        { label: "Duplicado", icon: "content_copy" },
                        { label: "Solo Portátil", icon: "laptop_mac" },
                        { label: "Solo Externo", icon: "desktop_windows" },
                    ]

                    delegate: Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36

                        background: StyledRect {
                            color: parent.hovered ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainerLow
                            radius: Tokens.rounding.small
                            border.color: parent.pressed ? Colours.palette.m3primary : Colours.tPalette.m3outline
                            border.width: 1
                        }

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            MaterialIcon {
                                fontStyle: Tokens.font.icon.small
                                text: modelData.icon
                                color: Colours.palette.m3primary
                                fill: 1
                            }

                            StyledText {
                                text: modelData.label
                                font: Tokens.font.label.small
                                color: Colours.palette.m3onSurface
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                Layout.fillWidth: true
                            }
                        }

                        onClicked: {
                            switch (index) {
                                case 0: presetExtended(); break;
                                case 1: presetDuplicated(); break;
                                case 2: presetOnlyLaptop(); break;
                                case 3: presetOnlyExternal(); break;
                            }
                        }
                    }
                }
            }

            // Separator
            StyledRect {
                Layout.fillWidth: true
                height: 1
                color: Colours.tPalette.m3outline
            }

            // Monitor drag area
            StyledText {
                text: "Arrastra para reordenar monitores"
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 110

                RowLayout {
                    id: monitorsRow
                    anchors.centerIn: parent
                    spacing: 14

                    Repeater {
                        id: monitorRepeater

                        model: root.monitors

                        delegate: StyledRect {
                            id: monitorTile

                            required property int index
                            required property var modelData

                            property bool dragging: false

                            Layout.preferredWidth: modelData.height / modelData.width > 0.66 ? 170 : 150
                            Layout.preferredHeight: 90
                            radius: Tokens.rounding.medium
                            color: root.selectedIndex === index ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerLow
                            border.color: root.selectedIndex === index ? Colours.palette.m3primary : Colours.tPalette.m3outline
                            border.width: root.selectedIndex === index ? 2 : 1

                            DragHandler {
                                onActiveChanged: {
                                    if (active) {
                                        monitorTile.dragging = true;
                                        monitorTile.grabToImage(function(result) {});
                                    } else {
                                        monitorTile.dragging = false;
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onDropped: {
                                    const from = drag.source.index;
                                    const to = monitorTile.index;
                                    if (from !== to) {
                                        const arr = root.monitors.slice();
                                        const item = arr.splice(from, 1)[0];
                                        arr.splice(to, 0, item);
                                        root.monitors = arr;
                                        root.selectedIndex = to;
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.selectedIndex = index
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3

                                StyledText {
                                    text: modelData.name
                                    font: Tokens.font.title.small
                                    color: root.selectedIndex === index ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                    horizontalAlignment: Text.AlignHCenter
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: modelData.selWidth + "x" + modelData.selHeight
                                    font: Tokens.font.body.small
                                    color: root.selectedIndex === index ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                    horizontalAlignment: Text.AlignHCenter
                                    Layout.fillWidth: true
                                }

                                StyledText {
                                    text: modelData.selRefresh.toFixed(0) + "Hz"
                                    font: Tokens.font.label.small
                                    color: root.selectedIndex === index ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                    horizontalAlignment: Text.AlignHCenter
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }

            // Separator
            StyledRect {
                Layout.fillWidth: true
                height: 1
                color: Colours.tPalette.m3outline
            }

            // Controls for selected monitor
            StyledText {
                text: {
                    const m = root.selectedMonitor();
                    return m ? "Monitor: " + m.name : "Selecciona un monitor";
                }
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurface
            }

            GridLayout {
                columns: 2
                columnSpacing: 14
                rowSpacing: 10
                Layout.fillWidth: true

                enabled: root.selectedMonitor() !== null

                // Resolution
                StyledText {
                    text: "Resolución"
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                ComboBox {
                    id: resCombo
                    Layout.fillWidth: true
                    textRole: "label"
                    valueRole: "value"

                    property var monitor: root.selectedMonitor()

                    model: {
                        const m = root.selectedMonitor();
                        if (!m) return [];
                        const seen = new Set();
                        const items = [];
                        for (const mode of m.availableModes) {
                            const key = mode.width + "x" + mode.height;
                            if (!seen.has(key)) {
                                seen.add(key);
                                const ratio = (mode.width / mode.height).toFixed(2);
                                let label = mode.width + "x" + mode.height;
                                if (ratio === "1.78") label += " (16:9)";
                                else if (ratio === "1.60") label += " (16:10)";
                                else if (ratio === "1.33") label += " (4:3)";
                                items.push({ label: label, value: key, w: mode.width, h: mode.height });
                            }
                        }
                        return items;
                    }

                    onActivated: {
                        const m = root.selectedMonitor();
                        if (!m) return;
                        const item = resCombo.model[currentIndex];
                        m.selWidth = item.w;
                        m.selHeight = item.h;
                        root.monitors = root.monitors.slice();
                    }

                    background: StyledRect { radius: Tokens.rounding.small; color: Colours.tPalette.m3surfaceContainerLow; border.color: Colours.tPalette.m3outline; border.width: 1 }
                    contentItem: StyledText {
                        text: resCombo.displayText; color: Colours.palette.m3onSurface; font: Tokens.font.body.small
                        leftPadding: 10; verticalAlignment: Text.AlignVCenter
                    }
                    indicator: MaterialIcon {
                        fontStyle: Tokens.font.icon.small
                        text: "expand_more"
                        color: Colours.palette.m3onSurfaceVariant
                        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    }
                    delegate: ItemDelegate {
                        width: resCombo.width
                        contentItem: StyledText { text: model.label; color: Colours.palette.m3onSurface; font: Tokens.font.body.small; leftPadding: 10 }
                        background: StyledRect {
                            color: resCombo.highlightedIndex === index ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainerLow
                            radius: Tokens.rounding.small
                        }
                    }
                    popup: Popup {
                        y: resCombo.height + 4; width: resCombo.width
                        height: Math.min(220, contentItem.implicitHeight)
                        contentItem: ListView { clip: true; model: resCombo.delegateModel; currentIndex: resCombo.highlightedIndex }
                        background: StyledRect { color: Colours.tPalette.m3surfaceContainer; radius: Tokens.rounding.small; border.color: Colours.tPalette.m3outline }
                    }
                }

                // Refresh rate
                StyledText {
                    text: "Frecuencia"
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                ComboBox {
                    id: refreshCombo
                    Layout.fillWidth: true
                    textRole: "label"
                    valueRole: "value"

                    model: {
                        const m = root.selectedMonitor();
                        if (!m) return [];
                        const rates = new Set();
                        for (const mode of m.availableModes) {
                            if (mode.width === m.selWidth && mode.height === m.selHeight)
                                rates.add(mode.refresh);
                        }
                        return [...rates].sort((a, b) => a - b).map(r => ({
                            label: r.toFixed(0) + " Hz",
                            value: r
                        }));
                    }

                    onActivated: {
                        const m = root.selectedMonitor();
                        if (!m) return;
                        m.selRefresh = refreshCombo.model[currentIndex].value;
                        root.monitors = root.monitors.slice();
                    }

                    background: StyledRect { radius: Tokens.rounding.small; color: Colours.tPalette.m3surfaceContainerLow; border.color: Colours.tPalette.m3outline; border.width: 1 }
                    contentItem: StyledText {
                        text: refreshCombo.displayText; color: Colours.palette.m3onSurface; font: Tokens.font.body.small
                        leftPadding: 10; verticalAlignment: Text.AlignVCenter
                    }
                    indicator: MaterialIcon {
                        fontStyle: Tokens.font.icon.small
                        text: "expand_more"
                        color: Colours.palette.m3onSurfaceVariant
                        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    }
                    delegate: ItemDelegate {
                        width: refreshCombo.width
                        contentItem: StyledText { text: model.label; color: Colours.palette.m3onSurface; font: Tokens.font.body.small; leftPadding: 10 }
                        background: StyledRect {
                            color: refreshCombo.highlightedIndex === index ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainerLow
                            radius: Tokens.rounding.small
                        }
                    }
                    popup: Popup {
                        y: refreshCombo.height + 4; width: refreshCombo.width
                        height: Math.min(220, contentItem.implicitHeight)
                        contentItem: ListView { clip: true; model: refreshCombo.delegateModel; currentIndex: refreshCombo.highlightedIndex }
                        background: StyledRect { color: Colours.tPalette.m3surfaceContainer; radius: Tokens.rounding.small; border.color: Colours.tPalette.m3outline }
                    }
                }

                // Scale
                StyledText {
                    text: "Escala"
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                ComboBox {
                    id: scaleCombo
                    Layout.fillWidth: true

                    model: [
                        { label: "0.75x", value: 0.75 },
                        { label: "1.00x", value: 1.00 },
                        { label: "1.25x", value: 1.25 },
                        { label: "1.50x", value: 1.50 },
                        { label: "2.00x", value: 2.00 },
                    ]
                    textRole: "label"
                    valueRole: "value"

                    onActivated: {
                        const m = root.selectedMonitor();
                        if (!m) return;
                        m.selScale = scaleCombo.model[currentIndex].value;
                        root.monitors = root.monitors.slice();
                    }

                    background: StyledRect { radius: Tokens.rounding.small; color: Colours.tPalette.m3surfaceContainerLow; border.color: Colours.tPalette.m3outline; border.width: 1 }
                    contentItem: StyledText {
                        text: scaleCombo.displayText; color: Colours.palette.m3onSurface; font: Tokens.font.body.small
                        leftPadding: 10; verticalAlignment: Text.AlignVCenter
                    }
                    indicator: MaterialIcon {
                        fontStyle: Tokens.font.icon.small
                        text: "expand_more"
                        color: Colours.palette.m3onSurfaceVariant
                        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    }
                    delegate: ItemDelegate {
                        width: scaleCombo.width
                        contentItem: StyledText { text: model.label; color: Colours.palette.m3onSurface; font: Tokens.font.body.small; leftPadding: 10 }
                        background: StyledRect {
                            color: scaleCombo.highlightedIndex === index ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainerLow
                            radius: Tokens.rounding.small
                        }
                    }
                    popup: Popup {
                        y: scaleCombo.height + 4; width: scaleCombo.width
                        height: Math.min(220, contentItem.implicitHeight)
                        contentItem: ListView { clip: true; model: scaleCombo.delegateModel; currentIndex: scaleCombo.highlightedIndex }
                        background: StyledRect { color: Colours.tPalette.m3surfaceContainer; radius: Tokens.rounding.small; border.color: Colours.tPalette.m3outline }
                    }
                }

                // Position
                StyledText {
                    text: "Posición"
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                ComboBox {
                    id: posCombo
                    Layout.fillWidth: true

                    model: {
                        const m = root.selectedMonitor();
                        if (!m) return [];
                        const items = [{ label: "Primario (0x0)", value: "0x0" }];
                        for (const other of root.monitors) {
                            if (other.name !== m.name && !other.disabled) {
                                items.push({ label: "Der. de " + other.name, value: other.width + "x0" });
                                items.push({ label: "Izq. de " + other.name, value: "-" + m.width + "x0" });
                            }
                        }
                        return items;
                    }

                    onActivated: {
                        const m = root.selectedMonitor();
                        if (!m) return;
                        m.position = posCombo.model[currentIndex].value;
                        root.monitors = root.monitors.slice();
                    }

                    background: StyledRect { radius: Tokens.rounding.small; color: Colours.tPalette.m3surfaceContainerLow; border.color: Colours.tPalette.m3outline; border.width: 1 }
                    contentItem: StyledText {
                        text: posCombo.displayText; color: Colours.palette.m3onSurface; font: Tokens.font.body.small
                        leftPadding: 10; verticalAlignment: Text.AlignVCenter
                    }
                    indicator: MaterialIcon {
                        fontStyle: Tokens.font.icon.small
                        text: "expand_more"
                        color: Colours.palette.m3onSurfaceVariant
                        anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                    }
                    delegate: ItemDelegate {
                        width: posCombo.width
                        contentItem: StyledText { text: model.label; color: Colours.palette.m3onSurface; font: Tokens.font.body.small; leftPadding: 10 }
                        background: StyledRect {
                            color: posCombo.highlightedIndex === index ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainerLow
                            radius: Tokens.rounding.small
                        }
                    }
                    popup: Popup {
                        y: posCombo.height + 4; width: posCombo.width
                        height: Math.min(220, contentItem.implicitHeight)
                        contentItem: ListView { clip: true; model: posCombo.delegateModel; currentIndex: posCombo.highlightedIndex }
                        background: StyledRect { color: Colours.tPalette.m3surfaceContainer; radius: Tokens.rounding.small; border.color: Colours.tPalette.m3outline }
                    }
                }
            }

            // Empty space
            Item { Layout.fillHeight: true }

            // Apply button
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }

                Button {
                    id: applyFullBtn
                    text: "Aplicar cambios"
                    implicitWidth: 180
                    implicitHeight: 40
                    enabled: !root.applying

                    background: StyledRect {
                        radius: Tokens.rounding.medium
                        color: applyFullBtn.enabled ? (applyFullBtn.hovered ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer) : Colours.tPalette.m3surfaceContainerLow
                    }

                    contentItem: StyledText {
                        text: applyFullBtn.text
                        font: Tokens.font.label.medium
                        color: applyFullBtn.enabled ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: root.applyChanges()
                }
            }
        }
    }

    // Preset functions
    function presetExtended(): void {
        const w1 = root.monitors.find(m => m.name === "eDP-1");
        const w2 = root.monitors.find(m => m.name === "DP-1");
        if (!w1 || !w2) return;

        w1.disabled = false;
        w1.position = "0x0";
        w1.selWidth = 1920; w1.selHeight = 1200; w1.selRefresh = 60;

        w2.disabled = false;
        w2.position = "1920x0";
        w2.selWidth = 1920; w2.selHeight = 1080; w2.selRefresh = 120;

        root.monitors = root.monitors.slice();
        root.applyChanges();
    }

    function presetDuplicated(): void {
        const w1 = root.monitors.find(m => m.name === "eDP-1");
        const w2 = root.monitors.find(m => m.name === "DP-1");
        if (!w1 || !w2) return;

        w1.disabled = false;
        w1.position = "0x0";
        w1.selWidth = 1920; w1.selHeight = 1200; w1.selRefresh = 60;

        w2.disabled = false;
        w2.position = "0x0";
        w2.selWidth = 1920; w2.selHeight = 1080; w2.selRefresh = 120;

        root.monitors = root.monitors.slice();
        root.applyChanges();
    }

    function presetOnlyLaptop(): void {
        const w1 = root.monitors.find(m => m.name === "eDP-1");
        const w2 = root.monitors.find(m => m.name === "DP-1");
        if (!w1 || !w2) return;

        w1.disabled = false;
        w1.position = "0x0";
        w1.selWidth = 1920; w1.selHeight = 1200; w1.selRefresh = 60;

        w2.disabled = true;

        root.monitors = root.monitors.slice();
        root.applyChanges();
    }

    function presetOnlyExternal(): void {
        const w1 = root.monitors.find(m => m.name === "eDP-1");
        const w2 = root.monitors.find(m => m.name === "DP-1");
        if (!w1 || !w2) return;

        w1.disabled = true;

        w2.disabled = false;
        w2.position = "0x0";
        w2.selWidth = 1920; w2.selHeight = 1080; w2.selRefresh = 120;

        root.monitors = root.monitors.slice();
        root.applyChanges();
    }
}
