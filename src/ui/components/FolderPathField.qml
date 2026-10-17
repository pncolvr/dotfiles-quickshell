pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import "../../theme"
import ".." as UI

Row {
    id: root
    property bool readOnly: false
    property alias text: input.text
    property alias placeholderText: input.placeholderText
    property alias inputObjectName: input.objectName
    property alias browseObjectName: browse.objectName
    property alias folderPicker: dialog
    property string dialogTitle: Translations.text("folders.dialog.title")
    readonly property bool nativeDialogOpen: dialog.nativeDialogOpen
    signal accepted()
    spacing: Theme.controlSpacing
    function focusInput() { if (visible) input.forceActiveFocus() }
    function clear() { input.clear() }
    UI.InputField {
        id: input
        readOnly: root.readOnly
        width: Math.max(0,root.width - (browse.visible ? browse.width + root.spacing : 0))
        retainPanelWhileEditing: false
        onAccepted: root.accepted()
    }
    UI.ActionButton {
        id: browse
        visible: !root.readOnly
        glyph: Theme.folderOpenIcon
        hint: Translations.text("folders.actions.chooseHint")
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
