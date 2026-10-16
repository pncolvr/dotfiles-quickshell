pragma ComponentBehavior: Bound
import QtQuick
import "../../"
import "../" as UI

Row {
    id: root
    property alias text: input.text
    property alias placeholderText: input.placeholderText
    property alias inputObjectName: input.objectName
    property alias browseObjectName: browse.objectName
    property alias folderPicker: dialog
    property string dialogTitle: "Choose folder"
    readonly property bool nativeDialogOpen: dialog.nativeDialogOpen
    signal accepted()
    spacing: Theme.controlSpacing
    function focusInput() { if (visible) input.forceActiveFocus() }
    function clear() { input.clear() }
    UI.InputField {
        id: input
        width: Math.max(0,root.width - browse.width - root.spacing)
        retainPanelWhileEditing: false
        onAccepted: root.accepted()
    }
    UI.ActionButton {
        id: browse
        glyph: Theme.folderOpenIcon
        hint: "choose folder"
        onClicked: dialog.open()
    }
    UI.FolderDialog {
        id: dialog
        title: root.dialogTitle
        onFolderSelected: path => {
            root.text = path
            Qt.callLater(root.focusInput)
        }
        onRejected: Qt.callLater(root.focusInput)
    }
}
