import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia
import Caelestia.Blobs
import Caelestia.Config
import qs.utils
import qs.services
import qs.components

PanelWindow {
    id: quickPanel

    signal fullConfigRequested()

    readonly property string helperPath: Quickshell.env("HOME") + "/.config/quickshell/widgets/displays/displays-helper.py"

    WlrLayershell.namespace: "quickshell"

    anchors {
        top: true
        right: true
    }

    implicitWidth: 220
    implicitHeight: 340

    color: "transparent"

    BlobGroup {
        id: blobGroup
        color: Colours.tPalette.m3surfaceContainer
        smoothing: Tokens.rounding.medium
    }

    BlobRect {
        anchors.fill: parent
        anchors.margins: 8
        group: blobGroup
        radius: Tokens.rounding.extraLarge
    }

    Item {
        anchors.fill: parent
        anchors.margins: 8
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            StyledText {
                text: "Display Layout"
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurface
                Layout.bottomMargin: 4
            }

            Repeater {
                model: [
                    { label: "Extendido",     icon: "grid_view",      preset: "extended" },
                    { label: "Duplicado",     icon: "content_copy",   preset: "mirror" },
                    { label: "Solo Portátil", icon: "laptop_mac",     preset: "laptop-only" },
                    { label: "Solo Externo",  icon: "desktop_windows",preset: "external-only" },
                ]

                delegate: StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    property bool hovered: btnSL.containsMouse
                    property bool pressed: btnSL.pressed

                    radius: pressed ? Tokens.rounding.small : Tokens.rounding.large
                    color: hovered ? Colours.tPalette.m3surfaceContainer : Colours.tPalette.m3surfaceContainerLow

                    Behavior on radius { Anim { type: Anim.DefaultEffects } }
                    Behavior on color { CAnim {} }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 12

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

                    StateLayer {
                        id: btnSL
                        onClicked: Quickshell.execDetached(["python", quickPanel.helperPath, "--preset", modelData.preset])
                    }
                }
            }

            Item { Layout.fillHeight: true }

            StyledRect {
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                property bool hovered: fullSL.containsMouse
                property bool pressed: fullSL.pressed

                radius: pressed ? Tokens.rounding.small : Tokens.rounding.large
                color: hovered ? Colours.palette.m3primary : Colours.tPalette.m3secondaryContainer

                Behavior on radius { Anim { type: Anim.DefaultEffects } }
                Behavior on color { CAnim {} }

                StyledText {
                    anchors.centerIn: parent
                    text: "Configuración completa"
                    font: Tokens.font.label.medium
                    color: Colours.palette.m3onSecondaryContainer
                }

                StateLayer {
                    id: fullSL
                    color: Colours.palette.m3onSecondaryContainer
                    onClicked: quickPanel.fullConfigRequested()
                }
            }
        }
    }
}
