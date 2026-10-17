pragma ComponentBehavior: Bound
import "../../i18n"
import "../../services"
import "../../ui" as UI

PreviewPickerPanel {
    id: root
    previewKind: "wallpaper"
    previewRequired: true
    searchPlaceholder: Translations.text("images.search.placeholder")
    showThumbnails: false
    panelError: picker.error || ClipboardService.error
    footerHint: Translations.text("picker.shortcuts.list", [picker.acceptLabel.toLowerCase()])
        + (UI.Keybinds.sequence("copy") ? " · "
            + UI.Keybinds.describe("copy", Translations.text("images.actions.copy")) : "")
    function copyCurrentImage() {
        if (picker.currentItem?.image) ClipboardService.copyImage(picker.currentItem.image)
    }
    searchKeyHandler: (event, activate) => {
        if (!UI.Keybinds.matches(event, "copy")) return false
        if (activate) root.copyCurrentImage()
        return true
    }
    UI.PanelShortcut {
        owner: root
        action: "copy"
        actionEnabled: !!root.picker.currentItem?.image
        onActivated: root.copyCurrentImage()
    }
}
