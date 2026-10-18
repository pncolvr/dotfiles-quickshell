pragma ComponentBehavior: Bound
import QtQuick
import "../../theme"
import ".." as UI
Column {
    id: root
    property string label: ""
    property string hint: ""
    property alias text: input.text
    property alias placeholderText: input.placeholderText
    property alias inputObjectName: input.objectName
    property alias readOnly: input.readOnly
    property alias echoMode: input.echoMode
    signal accepted()
    spacing: Theme.controlSpacing
    function focusInput() { input.forceActiveFocus(); input.selectAll() }
    UI.ColumnText {
        text: root.label
        color: Theme.inactive
        UI.HoverTooltip { text: root.hint; textFormat: Text.PlainText }
    }
    UI.InputField {
        id: input
        width: parent.width
        retainPanelWhileEditing: false
        passwordMaskDelay: 0
        Accessible.name: root.label
        onAccepted: root.accepted()
    }
}
