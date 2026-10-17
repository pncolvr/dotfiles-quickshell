pragma ComponentBehavior: Bound

import QtQuick
import "../../theme"
import "../../services"
import "../../config"

Item {
    id: root
    property var picker: PickerService
    property bool hideForCapture: panel?.hideForCapture ?? false
    property bool backgroundVisible: true
    property real availableContentWidth: Theme.pickerWidth
    property real availableContentHeight: 800
    readonly property bool focusReady: !!panel
    readonly property bool transitioning: panel?.transitioning ?? false
    readonly property real radius: Theme.tooltipRadius
    readonly property var panel: content.item
    readonly property bool moduleFocusSearch: true
    readonly property var modulePointerTarget: panel?.modulePointerTarget ?? panel ?? root
    readonly property bool nativeDialogOpen: panel?.nativeDialogOpen ?? false
    readonly property real placementWidth: panel?.placementWidth ?? implicitWidth
    implicitWidth: panel?.implicitWidth ?? Theme.pickerWidth
    implicitHeight: panel?.implicitHeight ?? 0

    function focusSearch() { panel?.focusSearch() }

    Loader {
        id: content
        anchors.fill: parent
        sourceComponent: {
            switch (root.picker.mode) {
                case PickerService.Mode.Projects: return projectPanel
                case PickerService.Mode.Webapps: return webappPanel
                case PickerService.Mode.N8n: return n8nPanel
                case PickerService.Mode.Remotes: return remotePanel
                case PickerService.Mode.Directories: return directoryPanel
                case PickerService.Mode.Clipboard: return clipboardPanel
                case PickerService.Mode.Secret: return secretPanel
            }
            switch (true) {
                case root.picker.imageOnly: return imageViewer
                case root.picker.previewImages: return imagePanel
                case root.picker.multiple: return multiSelectPanel
                default: return standardPanel
            }
        }
    }
    Component {
        id: n8nPanel
        N8nPickerPanel { picker:root.picker; backgroundVisible:root.backgroundVisible }
    }
    Component {
        id: remotePanel
        RemotePickerPanel { picker: root.picker; backgroundVisible: root.backgroundVisible }
    }
    Component {
        id: webappPanel
        WebappPickerPanel { picker: root.picker; backgroundVisible: root.backgroundVisible }
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
