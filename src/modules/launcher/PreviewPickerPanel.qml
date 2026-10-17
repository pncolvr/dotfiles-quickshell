pragma ComponentBehavior: Bound
import QtQuick
import "../../i18n"
import "../../config"
import "../../theme/ui" as UI

// One preview toggle/default policy; presentation is owned by the companion window.
PickerPanelBase {
    id: root
    required property string previewKind
    property bool previewRequired: false
    readonly property bool initialPreviewEnabled: previewRequired || (typeof Config.pickerPreviewDefaults[previewKind] === "boolean"
        ? Config.pickerPreviewDefaults[previewKind] : Config.pickerPreviewEnabled)
    property bool previewEnabled: initialPreviewEnabled
    property bool previewShortcut: !previewRequired
    maximumListRows: previewEnabled ? Math.max(1, Math.min(Config.pickerMaxRows, Config.pickerPreviewMaxRows)) : Config.pickerMaxRows
    uniformRows: previewEnabled
    readonly property bool floatingPreviewRequested: previewEnabled && picker.visible
    footerHint: Translations.text("picker.shortcuts.list",[picker.acceptLabel.toLowerCase()])
        + (previewShortcut && UI.Keybinds.sequence("preview") ? " · "
            + UI.Keybinds.describe("preview",Translations.text("common.actions.preview")) : "")
    readonly property Component floatingPreviewComponent: Component {
        PickerPreviewContent { picker: root.picker; windowPreview: root.previewKind === "windows" }
    }
    UI.PanelShortcut {
        owner: root
        action: "preview"
        actionEnabled: root.previewShortcut
        onActivated: root.previewEnabled = !root.previewEnabled
    }
    Connections {
        target: root.picker
        function onVisibleChanged() { if (root.picker.visible) root.previewEnabled = root.initialPreviewEnabled }
    }
}
