pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import Quickshell
import "../../theme"
import ".." as UI

Row {
    id: root
    property string path: ""
    property bool showEdit: true
    property bool showRefresh: false
    property bool showRemove: true
    property bool editEnabled: true
    property bool refreshEnabled: true
    property bool removeEnabled: true
    property string editHint: Translations.text("folders.actions.editHint")
    property string removeHint: Translations.text("folders.actions.removeHint")
    property color removeColor: Theme.alternateBackground
    property alias copyObjectName: copyButton.objectName
    property alias editObjectName: editButton.objectName
    property alias refreshObjectName: refreshButton.objectName
    property alias removeObjectName: removeButton.objectName
    signal editRequested()
    signal refreshRequested()
    signal removeRequested()
    spacing: Theme.controlSpacing

    UI.CopyButton {
        id: copyButton
        copyContext: root.path
        copyHint: Translations.text("folders.actions.copyPathHint")
        copyAction: completed => { Quickshell.clipboardText = root.path; completed(true) }
    }
    UI.ActionButton {
        id: editButton
        glyph: Theme.editIcon
        hint: root.editHint
        visible: root.showEdit
        enabled: root.editEnabled
        onClicked: root.editRequested()
    }
    UI.ActionButton {
        id: refreshButton
        glyph: Theme.refreshIcon
        hint: Translations.text("folders.actions.refreshHint")
        visible: root.showRefresh
        enabled: root.refreshEnabled
        onClicked: root.refreshRequested()
    }
    UI.ActionButton {
        id: removeButton
        glyph: Theme.deleteIcon
        hint: root.removeHint
        fillColor: root.removeColor
        visible: root.showRemove
        enabled: root.removeEnabled
        onClicked: root.removeRequested()
    }
}
