pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import "../../theme"
import "../../ui" as UI
import "../../services"

Column {
    id: root
    property bool adding: false
    readonly property bool validTitle: title.text.trim().length > 0
    signal copyRequested(string value)
    function clear() {
        title.clear()
        username.clear()
        password.clear()
        password.revealed = false
        urls.clear()
        folder.clear()
    }
    function focusNew() { title.forceActiveFocus() }
    function loadEntry(entry) {
        password.text = entry.data?.password ?? ""
        Qt.callLater(() => password.forceActiveFocus())
    }
    function setPassword(value) { password.text = value }
    function draft(entryId) {
        return {id: entryId, name: title.text, username: username.text,
            password: password.text, notes: entryId ? RbwService.detail?.notes ?? "" : "", folder: folder.text,
            uris: urls.text.split("\n").map(value => value.trim()).filter(Boolean)}
    }
    spacing: Theme.controlSpacing
    UI.InputField { id: title; objectName: "vaultTitle"; width: parent.width; visible: root.adding; placeholderText: Translations.text("vault.fields.title"); retainPanelWhileEditing: false }
    UI.TextArea { id: urls; width: parent.width; visible: root.adding; placeholderText: Translations.text("vault.fields.websites") }
    UI.InputField { id: username; width: parent.width; visible: root.adding; placeholderText: Translations.text("vault.fields.username"); retainPanelWhileEditing: false }
    Item {
        width: parent.width
        height: Theme.controlHeight
        visible: password.visible
        UI.Text {
            anchors.left: parent.left
            anchors.right: length.left
            anchors.rightMargin: Theme.controlSpacing
            text: Translations.text("common.fields.password")
            color: Theme.inactive
            elide: Text.ElideRight
        }
        UI.InputField {
            id: length
            anchors.right: passwordActions.left
            anchors.rightMargin: Theme.controlSpacing
            width: 60
            text: "24"
            placeholderText: Translations.text("vault.password.length")
            Accessible.name: Translations.text("vault.password.lengthAccessibleName")
            retainPanelWhileEditing: false
            validator: IntValidator { bottom: 8; top: 128 }
        }
        Row {
            id: passwordActions
            anchors.right: parent.right
            spacing: Theme.controlSpacing
            UI.ActionButton { glyph: Theme.retryIcon; hint: Translations.text("secrets.actions.generatePassword"); onClicked: RbwService.generate(Number(length.text)) }
            UI.ActionButton { glyph: Theme.copyIcon; hint: Translations.text("secrets.actions.copyPassword"); onClicked: root.copyRequested(password.text) }
        }
    }
    UI.SecretField { revealObjectName: "vaultEye"; id: password; objectName: "vaultPassword"; width: parent.width; visible: root.adding || RbwService.detail?.data !== null; placeholderText: Translations.text("common.fields.password") }
    UI.InputField { id: folder; width: parent.width; visible: root.adding; placeholderText: Translations.text("vault.fields.folder"); retainPanelWhileEditing: false }
    UI.ComboSelector { width: parent.width; visible: root.adding && RbwService.folders.length > 0; compact: true; options: RbwService.folders.map(value => ({name: value, description: value})); selectedName: folder.text; placeholder: Translations.text("vault.fields.folderHint"); onSelected: name => folder.text = name }
}
