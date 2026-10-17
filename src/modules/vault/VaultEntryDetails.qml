pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import "../../theme/ui" as UI
import "../../services"

Column {
    id: root
    required property var fields
    signal copyRequested(string value)
    spacing: Theme.controlSpacing
    Repeater {
        model: root.fields
        Column {
            id: valueRow
            required property var modelData
            width: parent.width
            spacing: 4
            UI.Text { centerVertical: false; width: parent.width; text: valueRow.modelData.label; textFormat: Text.PlainText; color: Theme.inactive }
            Row {
                width: parent.width
                spacing: Theme.controlSpacing
                UI.SecretField {
                    revealObjectName: "vaultEye"
                    id: valueField
                    objectName: "vaultDetailField-" + valueRow.modelData.label
                    visible: valueRow.modelData.multiline !== true
                    width: parent.width - (Theme.actionButtonWidth + Theme.controlSpacing) * (valueRow.modelData.totp ? 2 : 1)
                    readOnly: true
                    text: valueRow.modelData.value
                    revealed: !valueRow.modelData.secret
                    Connections {
                        target: RbwService
                        function onSelectedIdChanged() { valueField.revealed = !valueRow.modelData.secret }
                    }
                }
                UI.TextArea {
                    id: notesField
                    objectName: valueRow.modelData.multiline ? "vaultDetailNotes" : ""
                    visible: valueRow.modelData.multiline === true
                    property bool revealed: false
                    width: parent.width - Theme.actionButtonWidth - Theme.controlSpacing
                    implicitHeight: revealed ? Math.max(Theme.controlHeight * 6, contentHeight + topPadding + bottomPadding) : Theme.controlHeight * 6
                    text: visible ? valueRow.modelData.value : ""
                    readOnly: true
                    color: revealed ? Theme.text : "transparent"
                    rightPadding: notesEye.width + Theme.controlFieldPadding * 2
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.selectionText
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    focusBorder: true
                    Accessible.name: valueRow.modelData.label
                    onVisibleChanged: if (!visible) revealed = false
                    Connections {
                        target: RbwService
                        function onSelectedIdChanged() { notesField.revealed = false }
                    }
                    UI.Text {
                        objectName: valueRow.modelData.multiline ? "vaultDetailNotesMask" : ""
                        centerVertical: false
                        anchors.fill: parent
                        anchors.margins: Theme.controlFieldPadding
                        anchors.rightMargin: notesField.rightPadding
                        visible: !notesField.revealed
                        text: "••••••••"
                    }
                    UI.ActionButton {
                        id: notesEye
                        objectName: valueRow.modelData.multiline ? "vaultDetailNotesEye" : ""
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.controlFieldPadding
                        y: 2
                        implicitWidth: Theme.controlHeight
                        implicitHeight: Theme.controlHeight - 4
                        glyph: notesField.revealed ? Theme.eyeSlashIcon : Theme.eyeIcon
                        hint: notesField.revealed ? "Hide notes" : "Show notes"
                        checkable: true
                        checked: notesField.revealed
                        onClicked: { notesField.revealed = !notesField.revealed; notesField.forceActiveFocus() }
                    }
                    Keys.onShortcutOverride: event => { if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) event.accepted = true }
                    Keys.onPressed: event => { if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)) event.accepted = true }
                }
                UI.ActionButton {
                    objectName: valueRow.modelData.totp ? "vaultCopyTotpSecret" : ""
                    glyph: Theme.copyIcon
                    hint: "Copy " + valueRow.modelData.label
                    onClicked: root.copyRequested(valueRow.modelData.value)
                }
                UI.ActionButton {
                    objectName: valueRow.modelData.totp ? "vaultCopyTotp" : ""
                    visible: valueRow.modelData.totp === true
                    glyph: Theme.totpIcon
                    hint: "Copy current TOTP token"
                    enabled: !RbwService.busy
                    onClicked: RbwService.copyTotp()
                }
            }
        }
    }
}
