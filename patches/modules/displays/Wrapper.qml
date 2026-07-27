pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ScreenState screenState

    readonly property string helperPath: Quickshell.env("HOME") + "/.config/quickshell/widgets/displays/displays-helper.py"
    readonly property bool shouldBeActive: screenState.displays
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    width: 260
    height: 380
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: (-height - 5) * offsetScale
    opacity: 1 - offsetScale

    Behavior on offsetScale { Anim {} }

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.extraLarge
        color: Colours.tPalette.m3surfaceContainer
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.medium

        StyledText {
            text: qsTr("Display Layout")
            font: Tokens.font.title.small
            color: Colours.palette.m3onSurface
        }

        Repeater {
            model: [
                { label: qsTr("Extendido"),     icon: "grid_view",      preset: "extended" },
                { label: qsTr("Duplicado"),     icon: "content_copy",   preset: "mirror" },
                { label: qsTr("Solo Portátil"), icon: "laptop_mac",     preset: "laptop-only" },
                { label: qsTr("Solo Externo"),  icon: "desktop_windows",preset: "external-only" },
            ]

            delegate: PresetButton {
                required property var modelData

                text: modelData.label
                iconText: modelData.icon
                onClicked: Quickshell.execDetached(["python", root.helperPath, "--preset", modelData.preset])
            }
        }

        Item { Layout.fillHeight: true }

        ActionButton {
            text: qsTr("Configuración completa")
            onClicked: Quickshell.execDetached(["qs", "-c", "widgets", "ipc", "call", "displays", "full"])
        }
    }

    component PresetButton: StyledRect {
        property string text
        property string iconText
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 48

        property bool hovered: btnSL.containsMouse
        property bool pressed: btnSL.pressed

        radius: pressed ? Tokens.rounding.small : Tokens.rounding.large
        color: hovered ? Colours.tPalette.m3surfaceContainer : Colours.tPalette.m3surfaceContainerLow

        Behavior on radius { Anim { type: Anim.DefaultEffects } }
        Behavior on color { Anim { type: Anim.DefaultEffects } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            spacing: Tokens.spacing.small

            MaterialIcon {
                fontStyle: Tokens.font.icon.small
                text: iconText
                color: Colours.palette.m3primary
                fill: 1
            }

            StyledText {
                text: parent.parent.text
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
            onClicked: parent.clicked()
        }
    }

    component ActionButton: StyledRect {
        property string text
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: 44

        property bool hovered: btnSL.containsMouse
        property bool pressed: btnSL.pressed

        radius: pressed ? Tokens.rounding.small : Tokens.rounding.large
        color: hovered ? Colours.palette.m3primary : Colours.tPalette.m3secondaryContainer

        Behavior on radius { Anim { type: Anim.DefaultEffects } }
        Behavior on color { Anim { type: Anim.DefaultEffects } }

        StyledText {
            anchors.centerIn: parent
            text: parent.text
            font: Tokens.font.label.medium
            color: Colours.palette.m3onSecondaryContainer
        }

        StateLayer {
            id: btnSL
            color: Colours.palette.m3onSecondaryContainer
            onClicked: parent.clicked()
        }
    }
}
