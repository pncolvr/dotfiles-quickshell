pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"
import "../../services"
import "../../config"

Item {
    id: root
    property var picker: PickerService
    property bool backgroundVisible: true
    readonly property real radius: Theme.tooltipRadius
    readonly property var panel: content.item
    readonly property bool nativeDialogOpen: panel?.nativeDialogOpen ?? false
    implicitWidth: panel?.implicitWidth ?? Theme.pickerWidth
    implicitHeight: panel?.implicitHeight ?? 0

    function focusSearch() { panel?.focusSearch() }

    Loader {
        id: content
        anchors.fill: parent
        sourceComponent: root.picker.mode === "projects" ? projectPanel
            : root.picker.mode === "clipboard" ? clipboardPanel
            : root.picker.multiple ? multiSelectPanel : standardPanel
    }
    Component {
        id: projectPanel
        ProjectPickerPanel { picker: root.picker; backgroundVisible: root.backgroundVisible }
    }

    Component {
        id: standardPanel
        PickerPanelBase {
            picker: root.picker
            backgroundVisible: root.backgroundVisible
            minimumListRows: root.picker.mode === "apps" ? Config.pickerMaxRows : 1
        }
    }
    Component {
        id: clipboardPanel
        ClipboardPickerPanel { picker: root.picker; backgroundVisible: root.backgroundVisible }
    }
    Component {
        id: multiSelectPanel
        MultiSelectPickerPanel { picker: root.picker; backgroundVisible: root.backgroundVisible }
    }
}
