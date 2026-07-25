pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Column {
    id: root

    spacing: Tokens.spacing.medium
    width: parent.width

    // Estado actual del límite de carga
    property int currentLimit: 100

    // Texto descriptivo
    StyledText {
        text: qsTr("Charge limit: %1%").arg(root.currentLimit)
        font: Tokens.font.body.small
    }

    // Botones de toggle
    Row {
        id: buttonRow
        spacing: Tokens.spacing.small

        // Botón 80% (modo conservación)
        IconButton {
            id: conservationBtn
            icon: "shield"
            type: root.currentLimit === 80 ? IconButton.Filled : IconButton.Tonal
            checked: root.currentLimit === 80
            isToggle: true

            onClicked: root.setLimit(80)
        }

        // Botón 100% (carga completa)
        IconButton {
            id: fullChargeBtn
            icon: "rocket_launch"
            type: root.currentLimit === 100 ? IconButton.Filled : IconButton.Tonal
            checked: root.currentLimit === 100
            isToggle: true

            onClicked: root.setLimit(100)
        }
    }

    // Proceso para leer el límite actual
    Process {
        id: readLimit
        command: ["asusctl", "battery", "info"]
        stdout: (data) => {
            const match = data.match(/(\d+)%/);
            root.currentLimit = match ? parseInt(match[1]) : 100;
        }
    }

    // Función para establecer el límite
    function setLimit(limit: int) {
        const proc = Qt.createQmlObject('import Quickshell.Io; Process { }', root);
        proc.command = ["asusctl", "battery", "limit", limit.toString()];
        proc.onExited.connect(() => {
            readLimit.start();
            Toaster.toast(
                qsTr("Battery limit set"),
                qsTr("Charge limit set to %1%").arg(limit),
                "power"
            );
            proc.destroy();
        });
        proc.start();
    }

    // Timer de refresco (30s)
    Timer {
        interval: 30000
        repeat: true
        onTriggered: readLimit.start()
    }

    // Inicializar al crear
    Component.onCompleted: readLimit.start()
}
