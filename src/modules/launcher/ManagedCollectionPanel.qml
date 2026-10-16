pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QC
import "../../theme"
import "../../theme/ui" as UI
import "../../config"
import "../../services"

// Collection list/Manage lifecycle; feature forms and launch semantics stay feature-owned.
ManagedPickerFrame {
    id: root
    required property var service
    required property string collectionName
    property Component listActionButtons: null
    property var canRemoveEntry: entry => true
    required property var entryForm
    readonly property bool showForm: !!service.draft
    readonly property var managedEntries: picker.filter(service.entries.map(entry =>
        Object.assign({title:entry.name,search:entry.name + ' ' + (entry.url ?? entry.endpoint ?? '')},entry)),manageSearch.text)
    managing: service.managing
    addSequence: Config.pickerAddShortcut
    manageSequence: Config.pickerManageShortcut
    showAllSequence: Config.pickerShowAllShortcut
    addAllowed: managing && !showForm && !service.busy
    headerItem: header
    listItem: list
    manageItem: manage
    footerItem: footer
    managementSearch: manageSearch
    managementFocusTarget: showForm ? entryForm : manageSearch
    managementScroll: manage.contentItem
    onAddRequested: { service.newEntry(); entryForm.load(service.draft) }
    onManagementRequested: value => service.setManaging(value)
    onShowAllRequested: service.toggleShowAll()
    onSessionClosed: service.cancel()
    onEscapeRequested: {
        if (showForm) { service.cancel(); Qt.callLater(root.focusSearch) }
        else picker.close()
    }
    function edit(entry) { service.edit(entry); entryForm.load(service.draft); Qt.callLater(root.focusSearch) }
    function submit() {
        const value=entryForm.value()
        if (!value) return
        service.save(value)
        if (!showForm) Qt.callLater(root.focusSearch)
    }
    Component.onCompleted: { entryForm.parent=formHolder; entryForm.width=Qt.binding(() => formHolder.width) }
    Connections {
        target: root.entryForm
        function onAccepted() { root.submit() }
    }
    UI.TabBar {
        id: header
        width: parent.width
        labels: [root.collectionName,'Manage']
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
        searchPlaceholder: 'Search ' + root.collectionName.toLowerCase()
        footerHint: StatusService.filterHint(Config.pickerShowAllShortcut,root.service.showAll) + Config.pickerManageShortcut + ': manage · Enter: ' + root.picker.acceptLabel.toLowerCase() + ' · Esc: close'
    }
    QC.ScrollView {
        id: manage
        y: root.contentTop; width: parent.width; height: root.manageHeight
        implicitHeight: Math.min(content.implicitHeight + Theme.projectManagePadding*2,Theme.pickerRowHeight*Config.pickerMaxRows)
        visible: root.managing
        clip: true
        contentWidth: availableWidth
        contentHeight: content.implicitHeight + Theme.projectManagePadding*2
        Column {
            id: content
            x: Theme.projectManagePadding; y: Theme.projectManagePadding
            width: Math.max(0,manage.availableWidth-Theme.projectManagePadding*2)
            spacing: Theme.controlSpacing
            UI.ColumnText {
                width: parent.width; text: root.service.error
                visible: !!text; color: Theme.urgent; wrapMode: Text.Wrap
            }
            Item {
                id: formHolder
                width: parent.width
                visible: root.showForm
                implicitHeight: root.entryForm.implicitHeight
            }
            Column {
                width: parent.width
                visible: !root.showForm
                spacing: Theme.controlSpacing
                UI.SearchField {
                    id: manageSearch
                    objectName: 'collectionManageSearch'
                    width: parent.width
                    placeholderText: 'Filter ' + root.collectionName.toLowerCase()
                    retainPanelWhileEditing: false
                    Keys.onShortcutOverride: event => { if (root.handleAddKey(event,false)) event.accepted=true }
                    Keys.onPressed: event => { if (root.handleAddKey(event,true)) event.accepted=true }
                }
                Repeater {
                    model: root.managedEntries
                    delegate: UI.ManagementRow {
                        id: row
                        required property var modelData
                        width: content.width
                        Column {
                            Layout.fillWidth: true
                            UI.ColumnText { text: row.modelData.name; width: parent.width; elide: Text.ElideRight }
                            UI.ColumnText {
                                text: (row.modelData.enabled ? '' : 'Disabled · ') + (row.modelData.url ?? row.modelData.endpoint ?? '')
                                color: Theme.inactive; width: parent.width; elide: Text.ElideMiddle
                            }
                        }
                        UI.ActionButton { glyph: Theme.editIcon; hint: 'edit entry'; enabled: !root.service.busy; onClicked: root.edit(row.modelData) }
                        UI.ActionButton {
                            glyph: Theme.deleteIcon; hint: 'remove entry'; fillColor: Theme.urgent
                            enabled: !root.service.busy && root.canRemoveEntry(row.modelData); onClicked: root.service.remove(row.modelData.id)
                        }
                    }
                }
                UI.ColumnText { text: 'No matching entries.'; visible: !root.managedEntries.length; color: Theme.inactive }
            }
        }
    }
    Column {
        id: footer
        width: parent.width; anchors.bottom: parent.bottom
        visible: root.managing
        spacing: Theme.controlSpacing
        UI.EditorActions {
            anchors.right: parent.right; anchors.rightMargin: Theme.projectManagePadding
            visible: root.showForm
            submitEnabled: !root.service.busy
            submitHint: 'save entry'; cancelHint: 'cancel edit'
            onSubmitted: root.submit()
            onCancelled: { root.service.cancel(); Qt.callLater(root.focusSearch) }
        }
        UI.ActionButton {
            objectName: 'addCollectionEntry'
            anchors.right: parent.right; anchors.rightMargin: Theme.projectManagePadding
            visible: !root.showForm
            glyph: Theme.addIcon; hint: 'add entry (' + Config.pickerAddShortcut + ')'
            enabled: !root.service.busy
            onClicked: { root.beginAdd(); Qt.callLater(root.focusSearch) }
        }
        UI.ShortcutHints { width: parent.width; hints: Config.pickerManageShortcut + ': list · Esc: cancel/close' }
        Item { width: 1; height: Theme.projectManagePadding }
    }
}
