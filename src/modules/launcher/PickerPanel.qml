pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"
import "../../services"
import "../../config"

Item {
    id: root
    property var picker: PickerService
    readonly property real radius: Theme.tooltipRadius
    readonly property PickerPanelBase panel: content.item as PickerPanelBase
    implicitWidth: panel?.implicitWidth ?? Theme.pickerWidth
    implicitHeight: panel?.implicitHeight ?? 0

    function focusSearch() { panel?.focusSearch() }

    Loader {
        id: content
        anchors.fill: parent
        sourceComponent: root.picker.mode === "clipboard" ? clipboardPanel
            : root.picker.multiple ? multiSelectPanel : standardPanel
    }

    Component {
        id: standardPanel
        PickerPanelBase {
            picker: root.picker
            minimumListRows: root.picker.mode === "apps" ? Config.pickerMaxRows : 1
        }
    }
    Component {
        id: clipboardPanel
        ClipboardPickerPanel { picker: root.picker }
    }
    Component {
        id: multiSelectPanel
        MultiSelectPickerPanel { picker: root.picker }
    }
}
