pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"
import "../../services"
import "../../config"

Item {
    id: root
    property var picker: PickerService
    property bool backgroundVisible: true
    property real availableContentWidth: Theme.pickerWidth
    property real availableContentHeight: 800
    readonly property bool transitioning: panel?.transitioning ?? false
    readonly property real radius: Theme.tooltipRadius
    readonly property var panel: content.item
    readonly property bool moduleFocusSearch: true
    readonly property var modulePointerTarget: panel?.modulePointerTarget ?? panel ?? root
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
                case PickerService.Mode.Secret: return secretPanel
                default: return root.picker.imageOnly ? imageViewer : root.picker.previewImages ? imagePanel : root.picker.multiple ? multiSelectPanel : standardPanel
            }
        }
    }
    Component {
        id: secretPanel
        SecretPickerPanel { picker: root.picker; backgroundVisible: root.backgroundVisible }
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
        id: imageViewer
        ImageViewerPanel {
            picker: root.picker
            backgroundVisible: root.backgroundVisible
            availableContentHeight: root.availableContentHeight
        }
    }
    Component {
        id: imagePanel
        ImagePickerPanel {
            picker: root.picker
            backgroundVisible: root.backgroundVisible
            availableContentWidth: root.availableContentWidth
            availableContentHeight: root.availableContentHeight
        }
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
        ClipboardPickerPanel { picker: root.picker; backgroundVisible: root.backgroundVisible; availableContentWidth: root.availableContentWidth; availableContentHeight: root.availableContentHeight }
    }
    Component {
        id: multiSelectPanel
        MultiSelectPickerPanel { picker: root.picker; backgroundVisible: root.backgroundVisible }
    }
}
