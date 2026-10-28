import Quickshell

PersistentProperties {
    required property ShellScreen modelData

    // Drawer visibilities
    property bool bar
    property bool osd
    property bool session
    property bool launcher
    property bool clipboard
    // Abre el drawer clipboard en modo borrar (SUPER+ALT+V). Se resetea al
    // cerrar; el atajo normal lo pone en false.
    property bool clipboardDeleteMode
    property bool emoji
    property bool dashboard
    property bool utilities
    property bool sidebar

    // Dashboard state
    property int dashboardTab
    property date dashboardDate: new Date()
}
