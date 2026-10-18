pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import ".." as UI

Column {
    id: field
    required property string label
    property string hint: ''
    property alias text: input.text
    property alias inputObjectName: input.objectName
    property alias readOnly: input.readOnly
    property alias folderPicker: dialog
    property alias headerActions: headerActions.data
    property bool chooseFolders: false
    property string browseObjectName: ''
    property string browseHint: Translations.text("folders.actions.add")
    property string dialogTitle: Translations.text("folders.actions.add")
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
            width: Math.max(0,parent.width - (browse.visible ? browse.width + parent.spacing : 0)
                - (headerActions.visible ? headerActions.width + parent.spacing : 0))
            anchors.verticalCenter: parent.verticalCenter
            text: field.label
            color: Theme.inactive
            elide: Text.ElideRight
            UI.HoverTooltip { text: field.hint; textFormat: Text.PlainText }
        }
        UI.ActionButton {
            id: browse
            objectName: field.browseObjectName
            visible: field.chooseFolders
            enabled: !field.readOnly
            glyph: Theme.folderOpenIcon
            hint: field.browseHint
            onClicked: dialog.open()
        }
        Row {
            id: headerActions
            visible: children.length > 0
            spacing: Theme.controlSpacing
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
