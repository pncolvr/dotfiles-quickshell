pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import "../../theme"
import "../../theme/ui" as UI
import "../../services"
import "../../config"

ManagedPickerFrame {
    id: root
    objectName: "directoryPickerPanel"
    property string category: "personal"
    readonly property bool editing: !!DirectoryService.draft
    readonly property bool showForm: adding || editing
    readonly property var managedDirectories: manage.filteredEntries
    readonly property var selectedEntry: manage.selectedEntry
    nativeDialogOpen: folderForm.nativeDialogOpen
    property alias folderPicker: folderForm.folderPicker
    pickerMode: PickerService.Mode.Directories
    managing: DirectoryService.managing
    addSequence: Config.directoryAddShortcut
    manageSequence: Config.directoryManageShortcut
    showAllSequence: Config.directoryShowAllShortcut
    addAllowed: managing && !showForm && !DirectoryService.busy && !nativeDialogOpen
    headerItem: header
    listItem: list
    manageItem: manage
    managementView: manage
    footerItem: footer
    managementSearch: manage.searchField
    managementFocusTarget: showForm ? folderForm : manage
    managementScroll: manage.detailScroll
    onAddRequested: adding = true
    onManagementRequested: value => { DirectoryService.setManaging(value); if (!value) resetForm() }
    onShowAllRequested: DirectoryService.toggleShowAll()
    onSessionClosed: { DirectoryService.cancel(); root.resetForm() }
    function resetForm() {
        adding = false; folderForm.clear(); category = "personal"
        if (root.sessionActive) Qt.callLater(root.focusSearch)
    }
    function edit(entry) {
        manage.select(entry.path)
        DirectoryService.edit(entry)
        folderForm.text = entry.path; folderForm.displayName = entry.name; category = entry.category
        Qt.callLater(root.focusSearch)
    }
    function cancel() { DirectoryService.cancel(); resetForm() }
    function save() { DirectoryService.save(folderForm.text,folderForm.displayName,category) }
    onEscapeRequested: {
        if (showForm) root.cancel()
        else root.picker.close()
    }
    Connections { target: DirectoryService; function onSaved(path: string) { root.resetForm(); manage.selectSaved(path) } }
    UI.TabBar {
        id: header
        objectName: "directoryTabs"
        width: parent.width
        labels: [Translations.text("directories.title"),Translations.text("common.tabs.manage")]
        currentIndex: root.managing ? 1 : 0
        onTabClicked: index => root.management(index === 1)
    }
    PickerPanelBase {
        id: list
        y: root.contentTop; width: parent.width; height: root.listHeight
        picker: root.picker; backgroundVisible: root.backgroundVisible
        visible: !root.managing
        searchPlaceholder: Translations.text("directories.search.placeholder")
        footerHint: StatusService.filterHint(Config.directoryShowAllShortcut,DirectoryService.showAll) + Config.directoryManageShortcut + Translations.text("directories.shortcuts.primary")
    }
    UI.ManagementView {
        id: manage
        y: root.contentTop; width: parent.width; height: root.manageHeight
        visible: root.managing
        entries: DirectoryService.directories.map(entry => Object.assign({},entry,{id:entry.path,title:entry.name,subtitle:entry.path,
            search:entry.name + " " + entry.path, availability:DirectoryService.pathStates[entry.path]?.status ?? "unchecked"}))
        searchEntries: (entries,query) => root.picker.filter(entries,query)
        editing: root.showForm
        busy: DirectoryService.busy || root.nativeDialogOpen
        showCategory: StatusService.enabled
        filterAvailability: true
        searchObjectName: "directoryManageSearch"
        addObjectName: "beginAddDirectory"
        searchPlaceholder: Translations.text("directories.manage.searchPlaceholder")
        addHint: Translations.text("directories.actions.addShortcutHint",[Config.directoryAddShortcut])
        message: DirectoryService.error
        hints: Translations.text("directories.shortcuts.manage",[Config.directoryManageShortcut])
        onEditRequested: root.edit(root.selectedEntry)
        onAddRequested: root.beginAdd()
        onAddKey: (event,activate) => { if (root.handleAddKey(event,activate)) event.accepted = true }
        detailContent: [
            UI.ColumnText {
                width: parent.width
                visible: !root.showForm && !!root.selectedEntry && text.length > 0
                objectName: "directoryPathWarning_" + (root.selectedEntry?.path ?? "")
                text: Translations.text(DirectoryService.pathStates[root.selectedEntry?.path]?.message ?? "")
                color: DirectoryService.pathStates[root.selectedEntry?.path]?.status === "unavailable" ? Theme.warning : Theme.inactive
                wrapMode: Text.Wrap
            },
            UI.FolderForm {
                width: parent.width
                visible: !root.showForm && !!root.selectedEntry
                readOnly: true
                showCategory: StatusService.enabled
                showName: true
                text: root.selectedEntry?.path ?? ""
                displayName: root.selectedEntry?.name ?? ""
                category: root.selectedEntry?.category ?? "personal"
            },
            UI.FolderForm {
                id: folderForm
                objectName: "directoryForm"
                width: parent.width
                visible: root.showForm
                enabled: !DirectoryService.busy
                showCategory: StatusService.enabled
                showName: true
                inputObjectName: "directoryPath"
                browseObjectName: "browseDirectory"
                nameObjectName: "directoryName"
                categoryObjectName: "directoryCategory"
                placeholderText: Translations.text("directories.path.placeholder")
                category: root.category
                onCategoryRequested: category => root.category = category
                onAccepted: root.save()
            }
        ]
        actionContent: [
            UI.ManagementActions {
                visible: !root.showForm && !!root.selectedEntry
                path: root.selectedEntry?.path ?? ""
                copyObjectName: "copyDirectoryPath_" + path
                editObjectName: "editDirectory_" + path
                removeObjectName: "removeDirectory_" + path
                editHint: Translations.text("directories.actions.editHint")
                editEnabled: !DirectoryService.busy
                removeEnabled: !DirectoryService.busy
                removeColor: Theme.urgent
                onEditRequested: root.edit(root.selectedEntry)
                onRemoveRequested: DirectoryService.remove(path)
            },
            UI.EditorActions {
                visible: root.showForm
                submitObjectName: "saveDirectory"
                cancelObjectName: "cancelDirectory"
                submitGlyph: root.editing ? Theme.checkIcon : Theme.addIcon
                submitHint: Translations.text(root.editing ? "directories.actions.saveHint" : "directories.actions.addHint")
                submitEnabled: !DirectoryService.busy && !!folderForm.text.trim()
                cancelEnabled: !DirectoryService.busy
                onSubmitted: root.save()
                onCancelled: root.cancel()
            }
        ]
    }
    Item { id: footer; visible: false }
}
