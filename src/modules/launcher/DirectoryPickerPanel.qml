pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QC
import "../../theme"
import "../../theme/ui" as UI
import "../../services"
import "../../config"

Item {
    id: root
    objectName: "directoryPickerPanel"
    property var picker: PickerService
    property bool backgroundVisible: true
    property bool adding: false
    property string category: "personal"
    readonly property bool editing: !!DirectoryService.draft
    readonly property bool showForm: adding || editing || DirectoryService.directories.length === 0
    readonly property bool nativeDialogOpen: pathField.nativeDialogOpen
    property alias folderPicker: pathField.folderPicker
    readonly property var managedDirectories: picker.filter(DirectoryService.directories.map(entry => Object.assign({title:entry.name,search:entry.name + " " + entry.path},entry)),manageSearch.text)
    implicitWidth: Theme.pickerWidth
    implicitHeight: header.height + Theme.controlSpacing + (DirectoryService.managing
        ? manage.implicitHeight + footer.height + Theme.controlSpacing : list.implicitHeight)
    function focusSearch() {
        if (!picker.visible) return
        if (!DirectoryService.managing) list.focusSearch()
        else if (showForm) pathField.focusInput()
        else manageSearch.forceActiveFocus()
    }
    function resetForm() {
        adding = false; pathField.clear(); nameField.clear(); category = "personal"
        Qt.callLater(root.focusSearch)
    }
    function management(value) {
        DirectoryService.setManaging(value)
        if (!value) resetForm()
        Qt.callLater(root.focusSearch)
    }
    function beginAdd() { adding = true; Qt.callLater(root.focusSearch) }
    function edit(entry) {
        DirectoryService.edit(entry)
        pathField.text = entry.path; nameField.text = entry.name; category = entry.category
        Qt.callLater(root.focusSearch)
    }
    function cancel() { DirectoryService.cancel(); resetForm() }
    function save() { DirectoryService.save(pathField.text,nameField.text,category) }
    function handleAddKey(event, activate) {
        if (!addShortcut.enabled || addShortcut.portableText !== "Ctrl+A" || !event.matches(StandardKey.SelectAll)) return false
        if (activate) beginAdd()
        return true
    }
    Shortcut {
        sequence: Config.directoryManageShortcut
        enabled: root.visible && root.picker.visible && root.picker.mode === "directories" && !root.nativeDialogOpen
        onActivated: root.management(!DirectoryService.managing)
    }
    Shortcut {
        id: addShortcut
        sequence: Config.directoryAddShortcut
        enabled: root.visible && root.picker.visible && root.picker.mode === "directories"
            && DirectoryService.managing && !root.showForm && !DirectoryService.busy && !root.nativeDialogOpen
        onActivated: root.beginAdd()
    }
    Shortcut {
        sequence: Config.directoryShowAllShortcut
        enabled: root.visible && root.picker.visible && root.picker.mode === "directories" && !DirectoryService.managing
        onActivated: DirectoryService.toggleShowAll()
    }
    Keys.onEscapePressed: {
        if (root.adding || root.editing) root.cancel()
        else root.picker.close()
    }
    Connections { target: DirectoryService; function onSaved() { root.resetForm() } }
    Connections {
        target: root.picker
        function onVisibleChanged() {
            if (!root.picker.visible) { DirectoryService.cancel(); root.resetForm(); manageSearch.clear() }
        }
    }
    UI.TabBar {
        id: header
        objectName: "directoryTabs"
        width: parent.width
        labels: ["Directories", "Manage"]
        currentIndex: DirectoryService.managing ? 1 : 0
        onTabClicked: index => root.management(index === 1)
    }
    PickerPanelBase {
        id: list
        anchors.top: header.bottom
        anchors.topMargin: Theme.controlSpacing
        width: parent.width
        height: parent.height - header.height - Theme.controlSpacing
        picker: root.picker
        backgroundVisible: root.backgroundVisible
        visible: !DirectoryService.managing
        searchPlaceholder: "Search directories"
        footerHint: (DirectoryService.showAll ? "All directories" : "By status") + " · " + Config.directoryShowAllShortcut
            + (DirectoryService.showAll ? ": by status" : ": all directories") + " · " + Config.directoryManageShortcut
            + ": manage · Enter: open · Esc: close"
    }
    QC.ScrollView {
        id: manage
        anchors.top: header.bottom
        anchors.topMargin: Theme.controlSpacing
        width: parent.width
        height: Math.max(0,parent.height - header.height - footer.height - Theme.controlSpacing * 2)
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
                placeholderText: "Filter directories"
                visible: DirectoryService.directories.length > 0
                pauseTooltipDismissal: false
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
                                text: entryRow.modelData.category === "work" ? "Work" : "Personal"
                                color: entryRow.modelData.category === "work" ? Theme.accent : Theme.active
                            }
                        }
                    }
                    UI.ActionButton {
                        objectName: "editDirectory_" + entryRow.modelData.path
                        glyph: Theme.editIcon
                        hint: "edit directory"
                        enabled: !DirectoryService.busy
                        onClicked: root.edit(entryRow.modelData)
                    }
                    UI.ActionButton {
                        objectName: "removeDirectory_" + entryRow.modelData.path
                        glyph: Theme.deleteIcon
                        hint: "remove from picker"
                        enabled: !DirectoryService.busy
                        onClicked: {
                            if (DirectoryService.draft?.path === entryRow.modelData.path) root.cancel()
                            DirectoryService.remove(entryRow.modelData.path)
                        }
                    }
                }
            }
            UI.ColumnText {
                text: DirectoryService.directories.length ? "No matching directories." : "No directories yet. Add a folder to get started."
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
            UI.FolderPathField {
                id: pathField
                width: parent.width
                inputObjectName: "directoryPath"
                browseObjectName: "browseDirectory"
                placeholderText: "Folder path or location (trash:///...)"
                enabled: !DirectoryService.busy
                onAccepted: root.save()
            }
            RowLayout {
                width: parent.width
                UI.InputField {
                    id: nameField
                    objectName: "directoryName"
                    Layout.fillWidth: true
                    placeholderText: "Name (optional)"
                    enabled: !DirectoryService.busy
                    pauseTooltipDismissal: false
                    onAccepted: root.save()
                }
                UI.ActionButton {
                    objectName: "directoryCategory"
                    label: root.category === "work" ? "Work" : "Personal"
                    foreground: root.category === "work" ? Theme.accent : Theme.active
                    Layout.preferredWidth: Theme.projectOptionButtonWidth
                    hint: "switch category"
                    enabled: !DirectoryService.busy
                    onClicked: root.category = root.category === "work" ? "personal" : "work"
                }
            }
            UI.EditorActions {
                anchors.right: parent.right
                submitObjectName: "saveDirectory"
                cancelObjectName: "cancelDirectory"
                submitGlyph: root.editing ? Theme.checkIcon : Theme.addIcon
                submitHint: root.editing ? "save directory" : "add directory"
                submitEnabled: !DirectoryService.busy && !!pathField.text.trim()
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
            hint: "add directory (" + Config.directoryAddShortcut + ")"
            enabled: !DirectoryService.busy
            onClicked: root.beginAdd()
        }
        UI.Text {
            objectName: "directoryManageHints"
            width: parent.width
            centerVertical: false
            horizontalAlignment: Text.AlignHCenter
            color: Theme.inactive
            font.pixelSize: Theme.fontSize - 1
            wrapMode: Text.Wrap
            text: Config.directoryManageShortcut + ": directories"
                + (!root.showForm ? " · " + Config.directoryAddShortcut + ": add folder" : "")
                + " · Esc: " + (root.adding || root.editing ? "cancel" : "close")
        }
        Item { width: 1; height: Theme.projectManagePadding }
    }
}
