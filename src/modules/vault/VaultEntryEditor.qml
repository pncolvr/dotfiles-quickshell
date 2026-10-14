pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../theme/ui" as UI
import "../../services"

Column {
    id: root
    property bool adding: false
    property bool notesRevealed: false
    readonly property bool validTitle: title.text.trim().length > 0
    signal copyRequested(string value)
    function clear() {
        notesRevealed = false
        title.clear()
        username.clear()
        password.clear()
        password.revealed = false
        urls.clear()
        folder.clear()
        notes.clear()
    }
    function focusNew() { title.forceActiveFocus() }
    function loadEntry(entry) {
        password.text = entry.data?.password ?? ""
        notes.text = entry.notes ?? ""
        Qt.callLater(() => RbwService.detail?.data === null ? notes.forceActiveFocus() : password.forceActiveFocus())
    }
    function setPassword(value) { password.text = value }
    function draft(entryId) {
        return {id: entryId, name: title.text, username: username.text,
            password: password.text, notes: notes.text, folder: folder.text,
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
    UI.Text { centerVertical: false; text: "Notes"; color: Theme.inactive }
    UI.TextArea {
        id: notes
        objectName: "vaultNotes"
        width: parent.width
        implicitHeight: root.notesRevealed ? Math.max(Theme.controlHeight * 3, contentHeight + topPadding + bottomPadding) : Theme.controlHeight * 3
        rightPadding: notesEye.width + Theme.controlFieldPadding * 2
        placeholderText: root.notesRevealed ? "Notes (optional)" : ""
        selectionColor: Theme.accent
        selectedTextColor: Theme.text
        color: root.notesRevealed ? Theme.text : "transparent"
        readOnly: !root.notesRevealed
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
        focusBorder: true
        UI.Text { objectName: "vaultNotesMask"; centerVertical: false; anchors.fill: parent; anchors.margins: Theme.controlFieldPadding; anchors.rightMargin: notes.rightPadding; visible: !root.notesRevealed; text: notes.text.length ? "••••••••" : "Notes (optional)"; color: notes.text.length ? Theme.text : Theme.inactive }
        UI.ActionButton {
            id: notesEye
            objectName: "vaultNotesEye"
            anchors.right: parent.right
            anchors.rightMargin: Theme.controlFieldPadding
            y: 2
            implicitWidth: Theme.controlHeight
            implicitHeight: Theme.controlHeight - 4
            glyph: root.notesRevealed ? Theme.eyeSlashIcon : Theme.eyeIcon
            hint: root.notesRevealed ? "Hide notes" : "Reveal notes to edit"
            checkable: true
            checked: root.notesRevealed
            onClicked: { root.notesRevealed = !root.notesRevealed; notes.forceActiveFocus() }
        }
        Keys.onShortcutOverride: event => { if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) event.accepted = true }
        Keys.onPressed: event => { if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) event.accepted = true }
    }
}
