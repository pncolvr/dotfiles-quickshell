pragma ComponentBehavior: Bound
import "../../i18n"
import "../../services"
import "../../ui" as UI

PreviewPickerPanel {
    id: root
    previewKind: "wallpaper"
    previewRequired: true
    searchPlaceholder: PickerPrompts.text(root.picker.promptKey || "images", "images.search.placeholder")
    showThumbnails: false
    panelError: picker.error || ClipboardService.error
    hintPanel: "wallpaper"
    hintOverrides: ({copy: {label: Translations.text("images.actions.copy")}})
    hintActions: ["copy"]
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
