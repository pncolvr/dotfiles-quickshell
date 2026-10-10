pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs as Dialogs
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
    readonly property bool nativeDialogOpen: dialog.visible
    signal accepted()
    spacing: Theme.controlSpacing
    function focusInput() { if (visible) input.forceActiveFocus() }
    function clear() { input.clear() }
    UI.InputField {
        id: input
        width: Math.max(0,root.width - browse.width - root.spacing)
        pauseTooltipDismissal: false
        onAccepted: root.accepted()
    }
    UI.ActionButton {
        id: browse
        glyph: Theme.folderOpenIcon
        hint: "choose folder"
        onClicked: dialog.open()
    }
    Dialogs.FolderDialog {
        id: dialog
        title: root.dialogTitle
        options: Dialogs.FolderDialog.ReadOnly
        onAccepted: {
            root.text = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\/(?:localhost)?/, ""))
            Qt.callLater(root.focusInput)
        }
        onRejected: Qt.callLater(root.focusInput)
    }
}
