pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import "../../theme"
import "../../theme/ui" as UI
import "../../services"

Column {
    id: root
    property var statusService: StatusService
    readonly property bool nativeDialogOpen: folders.nativeDialogOpen
    property string savedDirectories: ''
    property string savedPatterns: ''
    readonly property bool dirty: folders.text !== savedDirectories || patterns.text !== savedPatterns
    spacing: Theme.controlSpacing

    function load() {
        savedDirectories = (statusService.rules?.workDirectories ?? []).join('\n');
        savedPatterns = (statusService.rules?.processes ?? []).join('\n');
        folders.text = savedDirectories;
        patterns.text = savedPatterns;
    }
    function focusInput() {
        folders.focusInput();
    }
    onVisibleChanged: if (visible) {
        if (!dirty)
            load();
        Qt.callLater(root.focusInput);
    }

    UI.LineListField {
        id: folders
        objectName: 'statusWorkFoldersList'
        width: parent.width
        label: Translations.text("status.rules.foldersLabel")
        inputObjectName: 'statusWorkDirectories'
        chooseFolders: true
        browseObjectName: 'addStatusWorkFolder'
        browseHint: Translations.text("status.rules.addFolder")
        dialogTitle: Translations.text("status.rules.addFolder")
    }
    UI.LineListField {
        id: patterns
        width: parent.width
        label: Translations.text("status.rules.processesLabel")
        inputObjectName: 'statusProcessPatterns'
    }
    UI.ColumnText {
        width: parent.width
        text: root.statusService.rulesError ?? ''
        visible: !!text
        color: Theme.urgent
        wrapMode: Text.Wrap
    }
    UI.EditorActions {
        objectName: 'statusRulesActions'
        anchors.right: parent.right
        submitHint: Translations.text("status.rules.saveHint")
        cancelHint: Translations.text("status.rules.resetHint")
        onSubmitted: if (root.statusService.saveRules({
            workDirectories: folders.values(),
            processes: patterns.values()
        }))
            root.load()
        onCancelled: root.load()
    }
}
