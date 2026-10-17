pragma ComponentBehavior: Bound
import QtQuick
import "../../"
import "../" as UI
Column {
    id: root
    property string label: ""
    property alias text: input.text
    property alias placeholderText: input.placeholderText
    property alias inputObjectName: input.objectName
    property alias readOnly: input.readOnly
    property alias echoMode: input.echoMode
    signal accepted()
    spacing: Theme.controlSpacing
    function focusInput() { input.forceActiveFocus(); input.selectAll() }
    UI.ColumnText { text: root.label; color: Theme.inactive }
    UI.InputField {
        id: input
        width: parent.width
        retainPanelWhileEditing: false
        passwordMaskDelay: 0
        Accessible.name: root.label
        onAccepted: root.accepted()
    }
}
