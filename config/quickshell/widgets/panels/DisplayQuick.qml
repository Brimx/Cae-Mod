import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.services
import qs.components

PanelWindow {
    id: quickPanel

    signal fullConfigRequested()

    anchors {
        top: true
        right: true
    }

    implicitWidth: 220
    implicitHeight: 340

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.large

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            StyledText {
                text: "Display Layout"
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurface
                Layout.bottomMargin: 4
            }

            Repeater {
                model: [
                    { label: "Extendido", icon: "grid_view" },
                    { label: "Duplicado", icon: "content_copy" },
                    { label: "Solo Portátil", icon: "laptop_mac" },
                    { label: "Solo Externo", icon: "desktop_windows" },
                ]

                delegate: Button {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44

                    background: StyledRect {
                        color: hovered ? Colours.tPalette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainerLow
                        radius: Tokens.rounding.medium
                        border.color: pressed ? Colours.palette.m3primary : Colours.tPalette.m3outline
                        border.width: 1
                    }

                    contentItem: RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        MaterialIcon {
                            fontStyle: Tokens.font.icon.small
                            text: modelData.icon
                            color: Colours.palette.m3primary
                            fill: 1
                        }

                        StyledText {
                            text: modelData.label
                            font: Tokens.font.body.medium
                            color: Colours.palette.m3onSurface
                            verticalAlignment: Text.AlignVCenter
                            Layout.fillWidth: true
                        }

                        MaterialIcon {
                            fontStyle: Tokens.font.icon.small
                            text: "chevron_right"
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    onClicked: {
                        switch (index) {
                            case 0: applyExtended(); break;
                            case 1: applyDuplicated(); break;
                            case 2: applyOnlyLaptop(); break;
                            case 3: applyOnlyExternal(); break;
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 40

                background: StyledRect {
                    color: parent.hovered ? Colours.palette.m3primaryContainer : Colours.palette.m3secondaryContainer
                    radius: Tokens.rounding.medium
                }

                contentItem: StyledText {
                    text: "Configuración completa"
                    font: Tokens.font.label.medium
                    color: Colours.palette.m3onPrimaryContainer
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    quickPanel.fullConfigRequested();
                }
            }
        }
    }

    function writeMonitors(configs: string): void {
        const home = Quickshell.env("HOME");
        const file = home + "/.config/hypr/hyprland/monitors.lua";
        Quickshell.execDetached(["bash", "-c",
            `cat > "${file}" << 'MONEOF'\n${configs}\nMONEOF`
        ]);
    }

    function applyExtended(): void {
        const config = `hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1200@60",
    position = "0x0",
    scale    = 1,
    disabled = false,
})
hl.monitor({
    output   = "DP-1",
    mode     = "1920x1080@120",
    position = "1920x0",
    scale    = 1,
    disabled = false,
})`;
        applyAndPersist(config);
    }

    function applyDuplicated(): void {
        const config = `hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1200@60",
    position = "0x0",
    scale    = 1,
    disabled = false,
})
hl.monitor({
    output   = "DP-1",
    mode     = "1920x1080@120",
    position = "0x0",
    scale    = 1,
    disabled = false,
})`;
        applyAndPersist(config);
    }

    function applyOnlyLaptop(): void {
        const config = `hl.monitor({
    output   = "eDP-1",
    mode     = "1920x1200@60",
    position = "0x0",
    scale    = 1,
    disabled = false,
})
hl.monitor({
    output   = "DP-1",
    disabled = true,
})`;
        applyAndPersist(config);
    }

    function applyOnlyExternal(): void {
        const config = `hl.monitor({
    output   = "eDP-1",
    disabled = true,
})
hl.monitor({
    output   = "DP-1",
    mode     = "1920x1080@120",
    position = "0x0",
    scale    = 1,
    disabled = false,
})`;
        applyAndPersist(config);
    }

    function applyAndPersist(config: string): void {
        writeMonitors(config);

        const lines = config.split("\n");
        const re = /output\s*=\s*"([^"]+)"/;
        const reDisabled = /disabled\s*=\s*true/;

        let block = "";
        for (const line of lines) {
            block += line + "\n";
            if (line === "})") {
                const m = block.match(re);
                const disabled = reDisabled.test(block);
                if (m) {
                    const name = m[1];
                    if (disabled) {
                        Quickshell.execDetached(["hyprctl", "keyword", "monitor", name + ",disable"]);
                    } else {
                        const modeM = block.match(/mode\s*=\s*"([^"]+)"/);
                        const posM = block.match(/position\s*=\s*"([^"]+)"/);
                        const scaleM = block.match(/scale\s*=\s*([\d.]+)/);
                        const mode = modeM ? modeM[1] : "1920x1080@60";
                        const pos = posM ? posM[1] : "0x0";
                        const scale = scaleM ? scaleM[1] : "1";
                        Quickshell.execDetached([
                            "hyprctl", "keyword", "monitor",
                            name + "," + mode + "," + pos + "," + scale
                        ]);
                    }
                }
                block = "";
            }
        }
    }
}
