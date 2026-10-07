import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI

Column {
    id: root
    required property string label
    property alias text: input.text
    readonly property int value: Number(input.text) || 0
    readonly property bool acceptableInput: input.text.length === 0 || input.acceptableInput
    signal accepted()
    spacing: Theme.controlSpacing
    UI.Text { centerVertical: false; text: root.label; color: Theme.inactive }
    UI.InputField {
        id: input
        width: root.width
        text: "0"
        selectByMouse: true
        inputMethodHints: Qt.ImhDigitsOnly
        validator: IntValidator { bottom: 0; top: 999999 }
        Accessible.name: root.label
        onAccepted: root.accepted()
        onActiveFocusChanged: if (activeFocus) selectAll()
    }
}
