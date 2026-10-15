pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../theme/ui" as UI
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
    UI.InputField { id: title; objectName: "vaultTitle"; width: parent.width; visible: root.adding; placeholderText: "Entry title"; pauseTooltipDismissal: false }
    UI.TextArea { id: urls; width: parent.width; visible: root.adding; placeholderText: "Website URLs, one per line" }
    UI.InputField { id: username; width: parent.width; visible: root.adding; placeholderText: "Username / email"; pauseTooltipDismissal: false }
    Item {
        width: parent.width
        height: Theme.controlHeight
        visible: password.visible
        UI.Text {
            anchors.left: parent.left
            anchors.right: length.left
            anchors.rightMargin: Theme.controlSpacing
            text: "Password"
            color: Theme.inactive
            elide: Text.ElideRight
        }
        UI.InputField {
            id: length
            anchors.right: passwordActions.left
            anchors.rightMargin: Theme.controlSpacing
            width: 60
            text: "24"
            placeholderText: "Length"
            Accessible.name: "Generated password length"
            pauseTooltipDismissal: false
            validator: IntValidator { bottom: 8; top: 128 }
        }
        Row {
            id: passwordActions
            anchors.right: parent.right
            spacing: Theme.controlSpacing
            UI.ActionButton { glyph: Theme.retryIcon; hint: "Generate password"; onClicked: RbwService.generate(Number(length.text)) }
            UI.ActionButton { glyph: Theme.copyIcon; hint: "Copy password"; onClicked: root.copyRequested(password.text) }
        }
    }
    UI.SecretField { revealObjectName: "vaultEye"; id: password; objectName: "vaultPassword"; width: parent.width; visible: root.adding || RbwService.detail?.data !== null; placeholderText: "Password" }
    UI.InputField { id: folder; width: parent.width; visible: root.adding; placeholderText: "Folder (optional, existing or new)"; pauseTooltipDismissal: false }
    UI.ComboSelector { width: parent.width; visible: root.adding && RbwService.folders.length > 0; compact: true; options: RbwService.folders.map(value => ({name: value, description: value})); selectedName: folder.text; placeholder: "Choose an existing folder"; onSelected: name => folder.text = name }
}
