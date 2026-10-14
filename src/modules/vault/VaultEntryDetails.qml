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
                    width: parent.width - Theme.actionButtonWidth - Theme.controlSpacing
                    readOnly: true
                    text: valueRow.modelData.value
                    revealed: !valueRow.modelData.secret
                    Connections {
                        target: RbwService
                        function onSelectedIdChanged() { valueField.revealed = !valueRow.modelData.secret }
                    }
                }
                UI.ActionButton { glyph: Theme.copyIcon; hint: "Copy " + valueRow.modelData.label; onClicked: root.copyRequested(valueRow.modelData.value) }
            }
        }
    }
}
