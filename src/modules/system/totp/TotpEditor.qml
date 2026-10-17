pragma ComponentBehavior: Bound

import "../../../i18n"
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../theme/ui" as UI

RowLayout {
    id: root
    objectName: "totpEditor"
    spacing: Theme.totpSpacing
    implicitHeight: Theme.totpRowHeight
    property bool adding: false
    property bool busy: false
    property real nameWidth: 150
    property bool destroying: false
    signal submitted(string name, string token)
    signal cancelled()
    signal draftChanged(string name, string token)

    function begin(name, token) {
        tokenField.revealed = false
        nameField.text = name
        tokenField.text = token
        nameField.forceActiveFocus()
    }

    function submit() {
        if (!busy && nameField.text.trim() && tokenField.text.trim())
            submitted(nameField.text, tokenField.text)
    }

    function clear() { nameField.clear(); tokenField.clear(); tokenField.revealed = false }
    Component.onDestruction: { destroying = true; clear() }

    UI.InputField {
        id: nameField
        objectName: "totpNameField"
        Layout.preferredWidth: root.nameWidth
        Layout.minimumWidth: 0
        placeholderText: Translations.text("common.fields.namePlaceholder")
        maximumLength: 128
        enabled: !root.busy
        Accessible.name: Translations.text("totp.fields.name")
        onAccepted: tokenField.forceActiveFocus()
        onTextChanged: if (!root.destroying) root.draftChanged(text, tokenField.text)
        Keys.onEscapePressed: root.cancelled()
    }

    UI.SecretField {
        id: tokenField
        objectName: "totpTokenField"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        placeholderText: Translations.text("totp.fields.secretPlaceholder")
        maximumLength: 4096
        retainPanelWhileEditing: true
        revealHint: Translations.text("totp.actions.revealSecret")
        hideHint: Translations.text("totp.actions.hideSecret")
        enabled: !root.busy
        Accessible.name: Translations.text("totp.fields.secretAccessibleName")
        onAccepted: root.submit()
        onTextChanged: if (!root.destroying) root.draftChanged(nameField.text, text)
        Keys.onEscapePressed: root.cancelled()
    }

    UI.EditorActions {
        spacing: Theme.totpSpacing
        cancelHint: Translations.text("common.actions.cancelHint")
        cancelEnabled: !root.busy
        submitGlyph: root.adding ? Theme.addIcon : Theme.checkIcon
        submitHint: Translations.text(root.adding ? "totp.actions.addHint" : "common.actions.saveChangesHint")
        submitEnabled: !root.busy && nameField.text.trim().length > 0 && tokenField.text.trim().length > 0
        onCancelled: root.cancelled()
        onSubmitted: root.submit()
    }
}
