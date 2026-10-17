pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import "../../theme"
import "../../ui" as UI
import "../../config"
import "../../services"

// Shared two-pane Manage view; feature services retain ownership of drafts and writes.
ManagedPickerFrame {
    id: root
    required property var service
    required property string collectionName
    property Component listActionButtons: null
    property string listHintPanel: "default"
    property var listHintActions: []
    property var canRemoveEntry: entry => true
    property var managementTypes: []
    property bool filterBrowser: false
    required property var entryForm
    readonly property bool showForm: !!service.draft
    readonly property var selectedEntry: manage.selectedEntry
    readonly property var managedEntries: manage.filteredEntries
    managing: service.managing
    addSequence: Config.pickerAddShortcut
    manageSequence: Config.pickerManageShortcut
    showAllSequence: Config.pickerShowAllShortcut
    addAllowed: managing && !showForm && !service.busy
    headerItem: header
    listItem: list
    manageItem: manage
    managementView: manage
    footerItem: footer
    managementSearch: manage.searchField
    managementFocusTarget: showForm ? entryForm : manage
    managementScroll: manage.detailScroll
    onAddRequested: { service.newEntry(); entryForm.load(service.draft) }
    onManagementRequested: value => service.setManaging(value)
    onShowAllRequested: service.toggleShowAll()
    onSessionClosed: service.cancel()
    onEscapeRequested: {
        if (showForm) { service.cancel(); Qt.callLater(root.focusSearch) }
        else picker.close()
    }
    function edit(entry) {
        manage.select(entry.id)
        service.edit(entry)
        entryForm.load(service.draft)
        Qt.callLater(root.focusSearch)
    }
    function submit() {
        const value = entryForm.value()
        if (!value) return
        service.save(value)
        if (!showForm) {
            manage.selectSaved(service.entries.find(entry => entry.name === value.name.trim())?.id ?? manage.selectedId)
            Qt.callLater(root.focusSearch)
        }
    }
    function loadDetails() {
        if (!showForm && selectedEntry) entryForm.load(selectedEntry)
    }
    onSelectedEntryChanged: loadDetails()
    onShowFormChanged: loadDetails()
    Component.onCompleted: {
        entryForm.parent = formHolder
        entryForm.width = Qt.binding(() => formHolder.width)
        entryForm.readOnly = Qt.binding(() => !root.showForm)
        loadDetails()
    }
    Connections { target: root.entryForm; function onAccepted() { if (root.showForm) root.submit() } }
    UI.TabBar {
        id: header
        width: parent.width
        labels: [root.collectionName,Translations.text("common.tabs.manage")]
        currentIndex: root.managing ? 1 : 0
        onTabClicked: index => root.management(index === 1)
    }
    PickerPanelBase {
        id: list
        y: root.contentTop; width: parent.width; height: root.listHeight
        picker: root.picker
        backgroundVisible: root.backgroundVisible
        visible: !root.managing
        actionButtons: root.listActionButtons
        searchPlaceholder: Translations.text("collections.search", [root.collectionName.toLowerCase()])
        hintOverrides: ({manage: {sequence: Config.pickerManageShortcut}, workFilter: {sequence: Config.pickerShowAllShortcut}})
        hintPanel: root.listHintPanel
        hintActions: ["manage", "search"].concat(StatusService.enabled ? ["workFilter"] : []).concat(root.listHintActions)
    }
    UI.ManagementView {
        id: manage
        y: root.contentTop; width: parent.width; height: root.manageHeight
        visible: root.managing
        entries: root.service.entries.map(entry => Object.assign({},entry,{title:entry.name,subtitle:entry.url ?? entry.endpoint ?? '',search:entry.name + ' ' + (entry.url ?? entry.endpoint ?? '')}))
        searchEntries: (entries, query) => root.picker.filter(entries,query)
        editing: root.showForm
        busy: root.service.busy
        showCategory: StatusService.enabled
        filterEnabled: true
        browserOptions: root.filterBrowser ? Config.webappBrowsers.map(browser => ({name:browser.id,description:browser.name})) : []
        typeOptions: root.managementTypes
        searchObjectName: 'collectionManageSearch'
        hintOverrides: ({add: {sequence: Config.pickerAddShortcut}, manage: {sequence: Config.pickerManageShortcut, label: Translations.text("hints.list")}})
        addObjectName: 'addCollectionEntry'
        searchPlaceholder: Translations.text("collections.manage.search",[root.collectionName.toLowerCase()])
        addHint: Translations.text("collections.actions.addHint",[Config.pickerAddShortcut])
        message: root.service.error
        onEditRequested: root.edit(root.selectedEntry)
        onAddRequested: root.beginAdd()
        detailContent: [
            Item {
                id: formHolder
                width: parent.width
                visible: root.showForm || !!root.selectedEntry
                implicitHeight: root.entryForm.implicitHeight
            }
        ]
        actionContent: [
            Row {
                visible: !root.showForm && !!root.selectedEntry
                spacing: Theme.controlSpacing
                UI.ActionButton { glyph: Theme.editIcon; hintAction: "edit"; hint: Translations.text("collections.actions.editHint"); enabled: !root.service.busy; onClicked: root.edit(root.selectedEntry) }
                UI.ActionButton {
                    glyph: Theme.deleteIcon; hint: Translations.text("collections.actions.removeHint"); fillColor: Theme.urgent
                    enabled: !root.service.busy && !!root.selectedEntry && root.canRemoveEntry(root.selectedEntry)
                    onClicked: root.service.remove(root.selectedEntry.id)
                }
            },
            UI.EditorActions {
                visible: root.showForm
                submitEnabled: !root.service.busy
                cancelEnabled: !root.service.busy
                submitHint: Translations.text("collections.actions.saveHint")
                cancelHint: Translations.text("common.actions.cancelEditHint")
                onSubmitted: root.submit()
                onCancelled: { root.service.cancel(); Qt.callLater(root.focusSearch) }
            }
        ]
    }
    Item { id: footer; visible: false }
}
