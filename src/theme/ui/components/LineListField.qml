pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../"
import "../" as UI

Column {
    id: field
    required property string label
    property alias text: input.text
    property alias inputObjectName: input.objectName
    property alias folderPicker: dialog
    property bool chooseFolders: false
    property string browseObjectName: ''
    property string browseHint: 'Add folder'
    property string dialogTitle: 'Add folder'
    readonly property bool nativeDialogOpen: dialog.nativeDialogOpen
    spacing: Theme.controlSpacing
    function values() {
        return text.split(/\r?\n/).map(value => value.trim()).filter(Boolean);
    }
    function focusInput() {
        if (visible)
            input.forceActiveFocus();
    }
    function appendFolder(path) {
        const entries = values();
        if (!entries.includes(path))
            entries.push(path);
        text = entries.join('\n');
        Qt.callLater(field.focusInput);
    }
    Row {
        width: parent.width
        spacing: Theme.controlSpacing
        UI.ColumnText {
            width: parent.width - (browse.visible ? browse.width + parent.spacing : 0)
            anchors.verticalCenter: parent.verticalCenter
            text: field.label
            color: Theme.inactive
        }
        UI.ActionButton {
            id: browse
            objectName: field.browseObjectName
            visible: field.chooseFolders
            glyph: Theme.folderOpenIcon
            hint: field.browseHint
            onClicked: dialog.open()
        }
    }
    QC.ScrollView {
        width: parent.width
        height: Theme.controlHeight * 4
        contentWidth: availableWidth
        UI.TextArea {
            id: input
            width: parent.width
            focusBorder: true
        }
    }
    UI.FolderDialog {
        id: dialog
        title: field.dialogTitle
        onFolderSelected: path => field.appendFolder(path)
        onRejected: Qt.callLater(field.focusInput)
    }
}
