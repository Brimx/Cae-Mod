pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Blobs
import Caelestia.Config
import qs.utils
import qs.services
import qs.components

Item {
    id: root

    required property bool shown
    property var monitors: []
    property int selectedIndex: -1
    property bool applying: false

    readonly property string helperPath: Quickshell.env("HOME") + "/.config/quickshell/widgets/displays/displays-helper.py"

    signal closeRequested()

    onSelectedIndexChanged: syncComboBoxes()
    onMonitorsChanged: syncComboBoxes()

    function refreshMonitors(): void {
        fetchMonitors.running = true
    }

    function selectedMonitor(): var {
        if (root.selectedIndex >= 0 && root.selectedIndex < root.monitors.length)
            return root.monitors[root.selectedIndex]
        return null
    }

    function syncComboBoxes(): void {
        const m = root.selectedMonitor()
        if (!m) return

        for (let i = 0; i < resCombo.model.length; i++) {
            if (resCombo.model[i].w === m.selWidth && resCombo.model[i].h === m.selHeight) {
                resCombo.currentIndex = i
                break
            }
        }
        for (let i = 0; i < refreshCombo.model.length; i++) {
            if (refreshCombo.model[i].value === m.selRefresh) {
                refreshCombo.currentIndex = i
                break
            }
        }
        for (let i = 0; i < scaleCombo.model.length; i++) {
            if (scaleCombo.model[i].value === m.selScale) {
                scaleCombo.currentIndex = i
                break
            }
        }
        for (let i = 0; i < posCombo.model.length; i++) {
            if (posCombo.model[i].value === m.position) {
                posCombo.currentIndex = i
                break
            }
        }
    }

    function applyChanges(): void {
        if (root.applying) return
        root.applying = true

        let args = [root.helperPath, "--apply"]
        for (const m of root.monitors) {
            args.push("--monitor", m.name,
                      m.disabled ? "disable" : m.selWidth + "x" + m.selHeight + "@" + m.selRefresh.toFixed(2),
                      m.disabled ? "0x0" : m.position,
                      m.disabled ? "1" : m.selScale.toFixed(2),
                      m.disabled ? "0" : "1")
        }

        Quickshell.execDetached(["python"].concat(args))

        statusText = qsTr("Cambios aplicados") + " ✓"
        statusTimer.restart()
        root.applying = false
    }

    property string statusText: ""

    Timer { id: statusTimer; interval: 2500; onTriggered: statusText = "" }

    Process {
        id: fetchMonitors

        command: [root.helperPath, "--get-monitors"]
        running: root.shown

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    const parsed = []
                    for (const m of data) {
                        parsed.push({
                            name: m.name,
                            desc: m.desc,
                            width: m.width,
                            height: m.height,
                            refresh: m.refresh,
                            scale: m.scale,
                            disabled: false,
                            x: m.x,
                            y: m.y,
                            availableModes: m.availableModes,
                            selWidth: m.width,
                            selHeight: m.height,
                            selRefresh: m.refresh,
                            selScale: m.scale,
                            position: m.x + "x" + m.y,
                        })
                    }
                    root.monitors = parsed
                    if (parsed.length > 0) root.selectedIndex = 0
                    syncComboBoxes()
                } catch (e) {
                    console.error("Parse error:", e)
                }
            }
        }
    }

    visible: root.shown
    opacity: root.shown ? 1 : 0

    Behavior on opacity { Anim { type: Anim.DefaultEffects } }

    BlobGroup {
        id: blobGroup
        color: Colours.palette.m3surfaceContainer
        smoothing: Tokens.rounding.medium
    }

    BlobRect {
        anchors.fill: parent
        group: blobGroup
        radius: Tokens.rounding.large
    }

    Item {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        clip: true

        ColumnLayout {
            anchors.fill: parent
            spacing: Tokens.spacing.medium

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    text: qsTr("Display Configuration")
                    font: Tokens.font.headline.small
                    color: Colours.palette.m3onSurface
                    Layout.fillWidth: true
                }

                StyledText {
                    text: root.statusText
                    font: Tokens.font.label.small
                    color: Colours.palette.m3primary
                    visible: root.statusText.length > 0
                    Layout.alignment: Qt.AlignVCenter
                }

                HeaderButton {
                    icon: "close"
                    onClicked: root.closeRequested()
                }
            }

            // Layout presets
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: [
                        { label: qsTr("Extendido"), icon: "grid_view", preset: "extended" },
                        { label: qsTr("Duplicado"), icon: "content_copy", preset: "mirror" },
                        { label: qsTr("Solo Portátil"), icon: "laptop_mac", preset: "laptop-only" },
                        { label: qsTr("Solo Externo"), icon: "desktop_windows", preset: "external-only" },
                    ]

                    delegate: PresetTile {
                        required property var modelData

                        text: modelData.label
                        iconText: modelData.icon
                        onClicked: Quickshell.execDetached(["python", root.helperPath, "--preset", modelData.preset])
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
                text: qsTr("Arrastra para reordenar monitores")
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurfaceVariant
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 110

                RowLayout {
                    id: monitorsRow
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.medium

                    Repeater {
                        id: monitorRepeater

                        model: root.monitors

                        delegate: StyledRect {
                            id: monitorTile

                            required property int index
                            required property var modelData

                            property bool dragging: false
                            property bool hovered: tileSL.containsMouse
                            property bool pressed: tileSL.pressed

                            Layout.preferredWidth: modelData.height / modelData.width > 0.66 ? 170 : 150
                            Layout.preferredHeight: 90
                            radius: pressed ? Tokens.rounding.small : Tokens.rounding.medium
                            color: {
                                if (root.selectedIndex === index) return Colours.palette.m3primaryContainer
                                if (hovered) return Colours.tPalette.m3surfaceContainer
                                return Colours.tPalette.m3surfaceContainerLow
                            }
                            border.color: root.selectedIndex === index ? Colours.palette.m3primary : Colours.tPalette.m3outline
                            border.width: root.selectedIndex === index ? 2 : 1

                            Behavior on radius { Anim { type: Anim.DefaultEffects } }
                            Behavior on color { Anim { type: Anim.DefaultEffects } }

                            DragHandler {
                                onActiveChanged: {
                                    if (active) {
                                        monitorTile.dragging = true
                                        monitorTile.grabToImage(function(result) {})
                                    } else {
                                        monitorTile.dragging = false
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onDropped: {
                                    const from = drag.source.index
                                    const to = monitorTile.index
                                    if (from !== to) {
                                        const arr = root.monitors.slice()
                                        const item = arr.splice(from, 1)[0]
                                        arr.splice(to, 0, item)
                                        root.monitors = arr
                                        root.selectedIndex = to
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: Tokens.spacing.extraSmall

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

                            StateLayer {
                                id: tileSL
                                onClicked: root.selectedIndex = index
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
                    const m = root.selectedMonitor()
                    return m ? qsTr("Monitor: %1").arg(m.name) : qsTr("Selecciona un monitor")
                }
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurface
            }

            GridLayout {
                columns: 2
                columnSpacing: Tokens.spacing.medium
                rowSpacing: Tokens.spacing.small
                Layout.fillWidth: true

                enabled: root.selectedMonitor() !== null

                // Resolution
                StyledText {
                    text: qsTr("Resolución")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                ComboField {
                    id: resCombo
                    Layout.fillWidth: true
                    textRole: "label"
                    valueRole: "value"

                    property var monitor: root.selectedMonitor()

                    model: {
                        const m = root.selectedMonitor()
                        if (!m) return []
                        const seen = new Set()
                        const items = []
                        for (const mode of m.availableModes) {
                            const key = mode.width + "x" + mode.height
                            if (!seen.has(key)) {
                                seen.add(key)
                                const ratio = (mode.width / mode.height).toFixed(2)
                                let label = mode.width + "x" + mode.height
                                if (ratio === "1.78") label += " (16:9)"
                                else if (ratio === "1.60") label += " (16:10)"
                                else if (ratio === "1.33") label += " (4:3)"
                                items.push({ label: label, value: key, w: mode.width, h: mode.height })
                            }
                        }
                        return items
                    }

                    onActivated: {
                        const m = root.selectedMonitor()
                        if (!m) return
                        const item = resCombo.model[currentIndex]
                        m.selWidth = item.w
                        m.selHeight = item.h
                        root.monitors = root.monitors.slice()
                    }
                }

                // Refresh rate
                StyledText {
                    text: qsTr("Frecuencia")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                ComboField {
                    id: refreshCombo
                    Layout.fillWidth: true
                    textRole: "label"
                    valueRole: "value"

                    model: {
                        const m = root.selectedMonitor()
                        if (!m) return []
                        const rates = new Set()
                        for (const mode of m.availableModes) {
                            if (mode.width === m.selWidth && mode.height === m.selHeight)
                                rates.add(mode.refresh)
                        }
                        return [...rates].sort((a, b) => a - b).map(r => ({
                            label: r.toFixed(0) + " Hz",
                            value: r
                        }))
                    }

                    onActivated: {
                        const m = root.selectedMonitor()
                        if (!m) return
                        m.selRefresh = refreshCombo.model[currentIndex].value
                        root.monitors = root.monitors.slice()
                    }
                }

                // Scale
                StyledText {
                    text: qsTr("Escala")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                ComboField {
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
                        const m = root.selectedMonitor()
                        if (!m) return
                        m.selScale = scaleCombo.model[currentIndex].value
                        root.monitors = root.monitors.slice()
                    }
                }

                // Position
                StyledText {
                    text: qsTr("Posición")
                    font: Tokens.font.body.small
                    color: Colours.palette.m3onSurfaceVariant
                }

                ComboField {
                    id: posCombo
                    Layout.fillWidth: true

                    model: {
                        const m = root.selectedMonitor()
                        if (!m) return []
                        const items = [{ label: qsTr("Primario (0x0)"), value: "0x0" }]
                        for (const other of root.monitors) {
                            if (other.name !== m.name && !other.disabled) {
                                items.push({ label: qsTr("Der. de %1").arg(other.name), value: other.width + "x0" })
                                items.push({ label: qsTr("Izq. de %1").arg(other.name), value: "-" + m.width + "x0" })
                            }
                        }
                        return items
                    }

                    onActivated: {
                        const m = root.selectedMonitor()
                        if (!m) return
                        m.position = posCombo.model[currentIndex].value
                        root.monitors = root.monitors.slice()
                    }
                }
            }

            // Empty space
            Item { Layout.fillHeight: true }

            // Apply button
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Item { Layout.fillWidth: true }

                ActionButton {
                    id: applyFullBtn
                    implicitWidth: 180
                    text: qsTr("Aplicar cambios")
                    enabled: !root.applying
                    onClicked: root.applyChanges()
                }
            }
        }
    }

    component ComboField: ComboBox {
        id: combo

        background: StyledRect {
            radius: Tokens.rounding.small
            color: Colours.tPalette.m3surfaceContainerLow
            border.color: Colours.tPalette.m3outline
            border.width: 1
        }

        contentItem: StyledText {
            text: combo.displayText
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.small
            leftPadding: Tokens.padding.small
            verticalAlignment: Text.AlignVCenter
        }

        indicator: MaterialIcon {
            fontStyle: Tokens.font.icon.small
            text: "expand_more"
            color: Colours.palette.m3onSurfaceVariant
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.small
            anchors.verticalCenter: parent.verticalCenter
        }

        delegate: ItemDelegate {
            width: combo.width
            contentItem: StyledText {
                text: model.label
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.small
                leftPadding: Tokens.padding.small
            }
            background: StyledRect {
                color: combo.highlightedIndex === index
                    ? Colours.tPalette.m3surfaceContainerHigh
                    : Colours.tPalette.m3surfaceContainerLow
                radius: Tokens.rounding.small
            }
        }

        popup: Popup {
            y: combo.height + Tokens.spacing.extraSmall
            width: combo.width
            height: Math.min(220, contentItem.implicitHeight)
            contentItem: ListView {
                clip: true
                model: combo.delegateModel
                currentIndex: combo.highlightedIndex
            }
            background: StyledRect {
                color: Colours.tPalette.m3surfaceContainer
                radius: Tokens.rounding.small
                border.color: Colours.tPalette.m3outline
            }
        }
    }

    component PresetTile: StyledRect {
        property string text
        property string iconText
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 36

        property bool hovered: tileSL.containsMouse
        property bool pressed: tileSL.pressed

        radius: pressed ? Tokens.rounding.small : Tokens.rounding.large
        color: hovered ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainerLow
        border.color: pressed ? Colours.palette.m3primary : Colours.tPalette.m3outline
        border.width: 1

        Behavior on radius { Anim { type: Anim.DefaultEffects } }
        Behavior on color { Anim { type: Anim.DefaultEffects } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.small
            anchors.rightMargin: Tokens.padding.small
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                fontStyle: Tokens.font.icon.small
                text: iconText
                color: Colours.palette.m3primary
                fill: 1
            }

            StyledText {
                text: parent.parent.text
                font: Tokens.font.label.small
                color: Colours.palette.m3onSurface
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.fillWidth: true
            }
        }

        StateLayer {
            id: tileSL
            onClicked: parent.clicked()
        }
    }

    component HeaderButton: StyledRect {
        property string icon
        signal clicked()

        implicitWidth: 36
        implicitHeight: 36
        radius: Tokens.rounding.small
        color: closeSL.containsMouse ? Colours.tPalette.m3surfaceContainerHigh : "transparent"

        Behavior on color { Anim { type: Anim.DefaultEffects } }

        MaterialIcon {
            anchors.centerIn: parent
            fontStyle: Tokens.font.icon.small
            text: parent.icon
            color: Colours.palette.m3onSurfaceVariant
        }

        StateLayer {
            id: closeSL
            onClicked: parent.clicked()
        }
    }

    component ActionButton: StyledRect {
        property string text
        property bool enabled: true
        signal clicked()

        implicitHeight: 40

        property bool hovered: btnSL.containsMouse
        property bool pressed: btnSL.pressed

        radius: pressed ? Tokens.rounding.small : Tokens.rounding.medium
        color: enabled ? (hovered ? Colours.palette.m3primary : Colours.tPalette.m3secondaryContainer) : Colours.tPalette.m3surfaceContainerLow

        Behavior on radius { Anim { type: Anim.DefaultEffects } }
        Behavior on color { Anim { type: Anim.DefaultEffects } }

        StyledText {
            anchors.centerIn: parent
            text: parent.text
            font: Tokens.font.label.medium
            color: parent.enabled ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
        }

        StateLayer {
            id: btnSL
            color: Colours.palette.m3onSecondaryContainer
            disabled: !parent.enabled
            onClicked: parent.clicked()
        }
    }
}
