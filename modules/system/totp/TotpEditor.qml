pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QC
import "../../../theme"

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
        nameField.text = name
        tokenField.text = token
        nameField.forceActiveFocus()
    }

    function submit() {
        if (!busy && nameField.text.trim() && tokenField.text.trim())
            submitted(nameField.text, tokenField.text)
    }

    function clear() { nameField.clear(); tokenField.clear() }
    Component.onDestruction: { destroying = true; clear() }

    TotpField {
        id: nameField
        objectName: "totpNameField"
        Layout.preferredWidth: root.nameWidth
        Layout.minimumWidth: 0
        placeholderText: "name"
        maximumLength: 128
        enabled: !root.busy
        Accessible.name: "TOTP name"
        onAccepted: tokenField.forceActiveFocus()
        onTextChanged: if (!root.destroying) root.draftChanged(text, tokenField.text)
        Keys.onEscapePressed: root.cancelled()
    }

    TotpField {
        id: tokenField
        objectName: "totpTokenField"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        placeholderText: "secret or otpauth URI"
        maximumLength: 4096
        echoMode: QC.TextField.Password
        enabled: !root.busy
        Accessible.name: "TOTP secret or URI"
        onAccepted: root.submit()
        onTextChanged: if (!root.destroying) root.draftChanged(nameField.text, text)
        Keys.onEscapePressed: root.cancelled()
    }

    TotpButton {
        glyph: Theme.totpCancelIcon
        hint: "cancel"
        enabled: !root.busy
        onClicked: root.cancelled()
    }

    TotpButton {
        glyph: root.adding ? Theme.totpAddIcon : Theme.totpSaveIcon
        hint: root.adding ? "add token" : "save changes"
        enabled: !root.busy && nameField.text.trim().length > 0 && tokenField.text.trim().length > 0
        fillColor: Theme.accent
        onClicked: root.submit()
    }
}
