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
        sourceComponent: {
            switch (root.picker.mode) {
                case PickerService.Mode.Projects: return projectPanel
                case PickerService.Mode.Directories: return directoryPanel
                case PickerService.Mode.Clipboard: return clipboardPanel
                default: return root.picker.multiple ? multiSelectPanel : standardPanel
            }
        }
    }
    Component {
        id: projectPanel
        ProjectPickerPanel { picker: root.picker; backgroundVisible: root.backgroundVisible }
    }

    Component {
        id: directoryPanel
        DirectoryPickerPanel { picker: root.picker; backgroundVisible: root.backgroundVisible }
    }
    Component {
        id: standardPanel
        PickerPanelBase {
            picker: root.picker
            backgroundVisible: root.backgroundVisible
            minimumListRows: root.picker.mode === PickerService.Mode.Apps ? Config.pickerMaxRows : 1
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
