pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QC
import "../../theme"
import "../../theme/ui" as UI
import "../../services"
import "../../config"

ManagedPickerFrame {
    id: root
    objectName: "directoryPickerPanel"
    property string category: "personal"
    readonly property bool editing: !!DirectoryService.draft
    readonly property bool showForm: adding || editing || DirectoryService.directories.length === 0
    nativeDialogOpen: folderForm.nativeDialogOpen
    property alias folderPicker: folderForm.folderPicker
    readonly property var managedDirectories: picker.filter(DirectoryService.directories.map(entry => Object.assign({title:entry.name,search:entry.name + " " + entry.path},entry)),manageSearch.text)

    pickerMode: PickerService.Mode.Directories
    managing: DirectoryService.managing
    addSequence: Config.directoryAddShortcut
    manageSequence: Config.directoryManageShortcut
    showAllSequence: Config.directoryShowAllShortcut
    addAllowed: managing && !root.showForm && !DirectoryService.busy && !nativeDialogOpen
    headerItem: header
    listItem: list
    manageItem: manage
    footerItem: footer
    managementSearch: manageSearch
    managementFocusTarget: showForm ? folderForm : manageSearch
    onAddRequested: adding = true
    onManagementRequested: value => { DirectoryService.setManaging(value); if (!value) resetForm() }
    onShowAllRequested: DirectoryService.toggleShowAll()
    onSessionClosed: { DirectoryService.cancel(); root.resetForm() }

    function resetForm() {
        adding = false; folderForm.clear(); category = "personal"
        if (root.sessionActive) Qt.callLater(root.focusSearch)
    }

    function edit(entry) {
        DirectoryService.edit(entry)
        folderForm.text = entry.path; folderForm.displayName = entry.name; category = entry.category
        Qt.callLater(root.focusSearch)
    }
    function cancel() { DirectoryService.cancel(); resetForm() }
    function save() { DirectoryService.save(folderForm.text,folderForm.displayName,category) }

    onEscapeRequested: {
        if (root.adding || root.editing) root.cancel()
        else root.picker.close()
    }
    Connections { target: DirectoryService; function onSaved() { root.resetForm() } }

    UI.TabBar {
        id: header
        objectName: "directoryTabs"
        width: parent.width
        labels: [Translations.text("directories.title"), Translations.text("common.tabs.manage")]
        currentIndex: DirectoryService.managing ? 1 : 0
        onTabClicked: index => root.management(index === 1)
    }
    PickerPanelBase {
        id: list
        y: root.contentTop
        width: parent.width
        height: root.listHeight
        picker: root.picker
        backgroundVisible: root.backgroundVisible
        visible: !DirectoryService.managing
        searchPlaceholder: Translations.text("directories.search.placeholder")
        footerHint: StatusService.filterHint(Config.directoryShowAllShortcut,DirectoryService.showAll) + Config.directoryManageShortcut
            + Translations.text("directories.shortcuts.primary")
    }
    QC.ScrollView {
        id: manage
        y: root.contentTop
        width: parent.width
        height: root.manageHeight
        implicitHeight: Math.min(content.implicitHeight + Theme.projectManagePadding * 2,Theme.pickerRowHeight * Config.pickerMaxRows)
        visible: DirectoryService.managing
        clip: true
        contentWidth: availableWidth
        contentHeight: content.implicitHeight + Theme.projectManagePadding * 2
        Column {
            id: content
            x: Theme.projectManagePadding
            y: Theme.projectManagePadding
            width: Math.max(0,manage.availableWidth - Theme.projectManagePadding * 2)
            spacing: Theme.controlSpacing
            UI.ColumnText {
                width: parent.width
                text: DirectoryService.error
                visible: !!text
                color: Theme.urgent
                wrapMode: Text.Wrap
            }
            UI.SearchField {
                id: manageSearch
                objectName: "directoryManageSearch"
                width: parent.width
                placeholderText: Translations.text("directories.manage.searchPlaceholder")
                visible: DirectoryService.directories.length > 0
                retainPanelWhileEditing: false
                Keys.onShortcutOverride: event => { if (root.handleAddKey(event,false)) event.accepted = true }
                Keys.onPressed: event => { if (root.handleAddKey(event,true)) event.accepted = true }
            }
            Repeater {
                model: root.managedDirectories
                delegate: UI.ManagementRow {
                    id: entryRow
                    required property var modelData
                    objectName: "managedDirectory_" + modelData.path
                    width: content.width
                    Column {
                        Layout.fillWidth: true
                        spacing: Theme.controlSpacing
                        UI.ColumnText { text: entryRow.modelData.name; width: parent.width; elide: Text.ElideMiddle }
                        RowLayout {
                            width: parent.width
                            UI.ColumnText {
                                text: entryRow.modelData.path
                                elide: Text.ElideMiddle
                                color: Theme.inactive
                                Layout.fillWidth: true
                                UI.HoverTooltip { text: entryRow.modelData.path }
                            }
                            UI.ColumnText {
                                visible: StatusService.enabled
                                    text: Translations.text(entryRow.modelData.category === "work" ? "status.modes.work" : "status.modes.personal")
                                color: entryRow.modelData.category === "work" ? Theme.accent : Theme.active
                            }
                        }
                        UI.ColumnText {
                            objectName: "directoryPathWarning_" + entryRow.modelData.path
                            width: parent.width
                            text: Translations.text(DirectoryService.pathStates[entryRow.modelData.path]?.message ?? "")
                            visible: !!text
                            color: DirectoryService.pathStates[entryRow.modelData.path]?.status === "unavailable" ? Theme.warning : Theme.inactive
                            wrapMode: Text.Wrap
                        }
                    }
                    UI.ManagementActions {
                        path: entryRow.modelData.path
                        copyObjectName: "copyDirectoryPath_" + path
                        editObjectName: "editDirectory_" + path
                        removeObjectName: "removeDirectory_" + path
                        editHint: Translations.text("directories.actions.editHint")
                        editEnabled: !DirectoryService.busy
                        removeEnabled: !DirectoryService.busy
                        onEditRequested: root.edit(entryRow.modelData)
                        onRemoveRequested: {
                            if (DirectoryService.draft?.path === path) root.cancel()
                            DirectoryService.remove(path)
                        }
                    }
                }
            }
            UI.ColumnText {
                text: Translations.text(DirectoryService.directories.length ? "directories.empty.filtered" : "directories.empty.initial")
                visible: root.managedDirectories.length === 0
                color: Theme.inactive
            }
        }
    }
    Column {
        id: footer
        anchors.bottom: parent.bottom
        width: parent.width
        visible: DirectoryService.managing
        spacing: Theme.controlSpacing
        Rectangle { x: Theme.projectManagePadding; width: parent.width - Theme.projectManagePadding * 2; height: 1; color: Theme.empty }
        Column {
            objectName: "directoryForm"
            x: Theme.projectManagePadding
            width: parent.width - Theme.projectManagePadding * 2
            visible: root.showForm
            spacing: Theme.controlSpacing
            UI.FolderForm {
            showCategory: StatusService.enabled
                id: folderForm
                width: parent.width
                inputObjectName: "directoryPath"
                browseObjectName: "browseDirectory"
                nameObjectName: "directoryName"
                categoryObjectName: "directoryCategory"
                placeholderText: Translations.text("directories.path.placeholder")
                enabled: !DirectoryService.busy
                showName: true
                category: root.category
                onCategoryRequested: category => root.category = category
                onAccepted: root.save()
            }
            UI.EditorActions {
                anchors.right: parent.right
                submitObjectName: "saveDirectory"
                cancelObjectName: "cancelDirectory"
                submitGlyph: root.editing ? Theme.checkIcon : Theme.addIcon
                submitHint: Translations.text(root.editing ? "directories.actions.saveHint" : "directories.actions.addHint")
                submitEnabled: !DirectoryService.busy && !!folderForm.text.trim()
                onSubmitted: root.save()
                onCancelled: root.cancel()
            }
        }
        UI.ActionButton {
            objectName: "beginAddDirectory"
            anchors.right: parent.right
            anchors.rightMargin: Theme.projectManagePadding
            visible: !root.showForm
            glyph: Theme.addIcon
            hint: Translations.text("directories.actions.addShortcutHint",[Config.directoryAddShortcut])
            enabled: !DirectoryService.busy
            onClicked: root.beginAdd()
        }
        UI.ShortcutHints {
            objectName: "directoryManageHints"
            width: parent.width
            hints: Translations.text("directories.shortcuts.manage",[Config.directoryManageShortcut])
                + (!root.showForm ? " · " + Translations.text("common.shortcuts.addFolder",[Config.directoryAddShortcut]) : "")
                + " · Esc: " + (root.adding || root.editing ? "cancel" : "close")
        }
        Item { width: 1; height: Theme.projectManagePadding }
    }
}
