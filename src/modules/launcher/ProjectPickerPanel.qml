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
    objectName: "projectPickerPanel"
    property var picker: PickerService
    property bool backgroundVisible: true
    property string sourceKind: "folder"
    property string sourceCategory: "personal"
    property bool adding: false
    readonly property bool showAddForm: adding || ProjectService.sources.length === 0
    property alias folderPicker: sourcePath.folderPicker
    readonly property bool nativeDialogOpen: sourcePath.nativeDialogOpen
    function matchesManagement(text) {
        return !manageSearch.text.trim() || root.picker.filter([{title:text}],manageSearch.text).length > 0
    }
    function projectsForSource(source) {
        const projects = ProjectService.projects.filter(project => project.sourcePaths.includes(source.path))
        return matchesManagement(source.path) ? projects
            : projects.filter(project => matchesManagement(project.name + " " + project.path))
    }
    readonly property var managedSources: ProjectService.sources.filter(source => matchesManagement(source.path) || projectsForSource(source).length > 0)
    implicitWidth: Theme.pickerWidth
    implicitHeight: header.height + Theme.controlSpacing + (ProjectService.managing
        ? manage.implicitHeight + (manageFooter.visible ? manageFooter.height + Theme.controlSpacing : 0) : list.implicitHeight)
    function focusSearch() {
        if (!root.picker.visible) return
        if (ProjectService.managing) {
            if (root.showAddForm && !ProjectService.draft) sourcePath.focusInput()
            else if (!ProjectService.draft) manageSearch.forceActiveFocus()
        }
        else list.focusSearch()
    }
    function cancelAdd() { adding = false; sourcePath.clear(); Qt.callLater(root.focusSearch) }
    function beginAdd() { ProjectService.setManaging(true); adding = true; Qt.callLater(root.focusSearch) }
    function handleAddKey(event, activate) {
        if (!addShortcut.enabled || addShortcut.portableText !== "Ctrl+A" || !event.matches(StandardKey.SelectAll)) return false
        if (activate) beginAdd()
        return true
    }
    function handlePickerKey(event, activate) {
        if (!ProjectService.urls || !(event.modifiers & Qt.ControlModifier) || event.key !== Qt.Key_A) return false
        if (activate) {
            if (event.modifiers & Qt.ShiftModifier) root.picker.deselectAll()
            else root.picker.toggleVisibleSelection()
        }
        return true
    }
    function management(value) {
        if (!value) cancelAdd()
        ProjectService.setManaging(value)
        Qt.callLater(root.focusSearch)
    }
    Connections {
        target: ProjectService
        function onSourceAdded() { root.cancelAdd() }
    }
    Connections {
        target: root.picker
        function onVisibleChanged() {
            if (!root.picker.visible) {
                root.adding = false
                sourcePath.clear()
                manageSearch.clear()
            }
        }
    }
    Shortcut {
        id: addShortcut
        sequence: Config.projectAddShortcut
        enabled: root.visible && root.picker.visible && root.picker.mode === "projects"
            && ProjectService.managing && !ProjectService.busy && !ProjectService.draft && !root.showAddForm && !root.nativeDialogOpen
        onActivated: root.beginAdd()
    }
    Shortcut {
        sequence: Config.projectShowAllShortcut
        enabled: root.visible && root.picker.visible && root.picker.mode === "projects" && !ProjectService.managing
        onActivated: ProjectService.toggleShowAll()
    }
    Shortcut {
        sequence: Config.projectManageShortcut
        enabled: root.visible && root.picker.visible && root.picker.mode === "projects"
        onActivated: root.management(!ProjectService.managing)
    }
    Keys.onEscapePressed: {
        if (ProjectService.draft) { ProjectService.cancelDraft(); root.cancelAdd() }
        else if (root.adding) root.cancelAdd()
        else root.picker.close()
    }
    RowLayout {
        id: header
        width: parent.width
        spacing: Theme.controlSpacing
        UI.TabBar {
            objectName: "projectTabs"
            labels: ["Projects", "Manage"]
            currentIndex: ProjectService.managing ? 1 : 0
            Layout.fillWidth: true
            onTabClicked: index => root.management(index === 1)
        }
        UI.ActionButton {
            visible: !ProjectService.managing && !!ProjectService.projectPath
            glyph: Theme.upIcon
            hint: "back to projects"
            onClicked: ProjectService.back()
        }
        UI.ActionButton {
            objectName: "refreshProjects"
            visible: ProjectService.managing
            glyph: Theme.refreshIcon
            hint: "refresh all folders"
            enabled: !ProjectService.busy && !ProjectService.draft && ProjectService.sources.length > 0
            onClicked: ProjectService.refresh()
        }
    }
    PickerPanelBase {
        id: list
        anchors.top: header.bottom
        anchors.topMargin: Theme.controlSpacing
        width: parent.width
        height: parent.height - header.height - Theme.controlSpacing
        picker: root.picker
        backgroundVisible: root.backgroundVisible
        visible: !ProjectService.managing
        searchPlaceholder: ProjectService.urls ? "Search repository URLs" : "Search projects"
        searchKeyHandler: root.handlePickerKey
        footerHint: (ProjectService.showAll ? "All projects" : "By status") + " · " + Config.projectShowAllShortcut
            + (ProjectService.showAll ? ": by status" : ": all projects") + " · " + Config.projectManageShortcut + ": manage"
            + (ProjectService.urls ? "\n" + root.picker.selectedIds.length + " selected · Ctrl+A: select visible / clear all" : "")
            + " · Enter: select · Esc: close"
    }
    QC.ScrollView {
        id: manage
        anchors.top: header.bottom
        anchors.topMargin: Theme.controlSpacing
        width: parent.width
        height: Math.max(0,parent.height - header.height - Theme.controlSpacing
            - (manageFooter.visible ? manageFooter.height + Theme.controlSpacing : 0))
        implicitHeight: Math.min(content.implicitHeight + Theme.projectManagePadding * 2, Theme.pickerRowHeight * Config.pickerMaxRows)
        visible: ProjectService.managing
        clip: true
        contentWidth: availableWidth
        contentHeight: content.implicitHeight + Theme.projectManagePadding * 2
        QC.ScrollBar.horizontal.policy: QC.ScrollBar.AlwaysOff
        QC.ScrollBar.vertical: UI.ScrollBar {}
        Column {
            id: content
            x: Theme.projectManagePadding
            y: Theme.projectManagePadding
            width: Math.max(0,manage.availableWidth - Theme.projectManagePadding * 2)
            spacing: Theme.projectManageSectionSpacing
            UI.ColumnText {
                text: ProjectService.busy ? "Scanning…" : ProjectService.error
                visible: !!text
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.urgent
            }
            Column {
                width: parent.width
                spacing: Theme.projectManageSectionSpacing
                visible: !ProjectService.draft
                UI.SearchField {
                    id: manageSearch
                    objectName: "projectManageSearch"
                    width: parent.width
                    visible: ProjectService.sources.length > 0
                    placeholderText: "Filter paths and repositories"
                    pauseTooltipDismissal: false
                    resetWithTooltip: false
                    handleEscape: false
                    Keys.onShortcutOverride: event => {
                        if (root.handleAddKey(event,false)) event.accepted = true
                    }
                    Keys.onPressed: event => {
                        if (root.handleAddKey(event,true)) event.accepted = true
                    }
                }
                UI.ColumnText {
                    text: "No sources yet. Add a folder to get started."
                    visible: ProjectService.sources.length === 0
                    color: Theme.inactive
                }
                UI.ColumnText {
                    text: "No matching paths or repositories."
                    visible: ProjectService.sources.length > 0 && root.managedSources.length === 0
                    color: Theme.inactive
                }
                Repeater {
                    model: root.managedSources
                    delegate: Rectangle {
                        id: sourceRow
                        required property var modelData
                        readonly property var projects: root.projectsForSource(modelData)
                        objectName: "projectSource_" + modelData.path
                        width: content.width
                        implicitHeight: sourceContent.implicitHeight + Theme.projectManagePadding * 2
                        color: "transparent"
                        radius: Theme.iconButtonRadius
                        border.width: 1
                        border.color: Theme.empty
                        Column {
                            id: sourceContent
                            x: Theme.projectManagePadding
                            y: Theme.projectManagePadding
                            width: parent.width - Theme.projectManagePadding * 2
                            spacing: Theme.controlSpacing
                            RowLayout {
                                width: parent.width
                                UI.ColumnText {
                                    text: sourceRow.modelData.path
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                    UI.HoverTooltip { text: parent.text }
                                }
                                UI.ActionButton {
                                    objectName: "refreshSource_" + sourceRow.modelData.path
                                    glyph: Theme.refreshIcon
                                    hint: "refresh this folder"
                                    enabled: !ProjectService.busy && !ProjectService.draft
                                    onClicked: ProjectService.refresh(sourceRow.modelData.path)
                                }
                                UI.ActionButton {
                                    objectName: "editSource_" + sourceRow.modelData.path
                                    glyph: Theme.editIcon
                                    hint: "edit folder and workspaces"
                                    enabled: !ProjectService.busy
                                    onClicked: ProjectService.editSource(sourceRow.modelData.path)
                                }
                                UI.ActionButton {
                                    glyph: Theme.deleteIcon
                                    hint: "remove source"
                                    fillColor: Theme.urgent
                                    enabled: !ProjectService.busy
                                    onClicked: ProjectService.removeSource(sourceRow.modelData.path)
                                }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: Theme.controlSpacing
                                UI.ColumnText {
                                    text: (sourceRow.modelData.kind === "root" ? "Repositories root" : "Single folder") + " ·"
                                    color: Theme.inactive
                                }
                                UI.ColumnText {
                                    text: sourceRow.modelData.category === "work" ? "Work" : "Personal"
                                    color: sourceRow.modelData.category === "work" ? Theme.accent : Theme.active
                                    Layout.fillWidth: true
                                }
                            }
                            UI.ColumnText {
                                width: parent.width
                                text: sourceRow.modelData.error
                                visible: !!text
                                color: Theme.urgent
                                wrapMode: Text.Wrap
                            }
                            Repeater {
                                model: sourceRow.modelData.kind === "root" ? sourceRow.projects : []
                                delegate: UI.ManagementRow {
                                    id: projectRow
                                    required property var modelData
                                    objectName: "managedProject_" + modelData.path
                                    width: sourceContent.width
                                    UI.ColumnText {
                                        objectName: "managedProjectName_" + projectRow.modelData.path
                                        text: projectRow.modelData.name
                                        elide: Text.ElideMiddle
                                        Layout.fillWidth: true
                                        UI.HoverTooltip { text: projectRow.modelData.path }
                                    }
                                    UI.ActionButton {
                                        objectName: "editProject_" + projectRow.modelData.path
                                        glyph: Theme.editIcon
                                        hint: "edit workspaces"
                                        visible: projectRow.modelData.workspaces.length > 0
                                        enabled: !ProjectService.busy
                                        onClicked: ProjectService.editProject(projectRow.modelData.path)
                                    }
                                }
                            }
                            UI.ColumnText {
                                text: "No repositories found."
                                visible: sourceRow.modelData.kind === "root" && sourceRow.projects.length === 0
                                color: Theme.inactive
                            }
                        }
                    }
                }
            }
            Column {
                width: parent.width
                spacing: Theme.projectManageSectionSpacing
                visible: !!ProjectService.draft
                UI.ColumnText {
                    text: ProjectService.draft?.review ? "New workspaces found. Choose which to include."
                        : ProjectService.editingSource ? "Edit folder" : ProjectService.editingProject ? "Choose workspaces to include" : "Choose workspaces before adding"
                }
                RowLayout {
                    width: parent.width
                    visible: !!ProjectService.editingSource
                    UI.ColumnText {
                        text: ProjectService.editingSource
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                        UI.HoverTooltip { text: parent.text }
                    }
                    UI.ActionButton {
                        objectName: "editSourceCategory"
                        label: ProjectService.draft?.category === "work" ? "Work" : "Personal"
                        foreground: ProjectService.draft?.category === "work" ? Theme.accent : Theme.active
                        Layout.preferredWidth: Theme.projectOptionButtonWidth
                        hint: "switch category"
                        onClicked: ProjectService.setDraftCategory(ProjectService.draft.category === "work" ? "personal" : "work")
                    }
                }
                Repeater {
                    model: ProjectService.draft?.projects ?? []
                    delegate: Column {
                        id: projectDraft
                        required property var modelData
                        visible: modelData.workspaces.length > 0
                        width: content.width
                        spacing: Theme.controlSpacing
                        UI.ColumnText {
                            text: projectDraft.modelData.path
                            width: parent.width
                            elide: Text.ElideMiddle
                            UI.HoverTooltip { text: parent.text }
                        }
                        Repeater {
                            model: projectDraft.modelData.workspaces
                            delegate: RowLayout {
                                id: workspaceRow
                                required property var modelData
                                width: content.width
                                UI.ActionButton {
                                    objectName: "projectWorkspace_" + workspaceRow.modelData.path
                                    glyph: workspaceRow.modelData.included ? Theme.checkIcon : Theme.addIcon
                                    hint: workspaceRow.modelData.included ? "exclude workspace" : "include workspace"
                                    fillColor: workspaceRow.modelData.included ? Theme.accent : Theme.alternateBackground
                                    onClicked: ProjectService.setIncluded(projectDraft.modelData.path,workspaceRow.modelData.path,!workspaceRow.modelData.included)
                                }
                                UI.ColumnText {
                                    text: workspaceRow.modelData.name + " · " + workspaceRow.modelData.path
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                    UI.HoverTooltip { text: parent.text }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Item {
        id: manageFooter
        anchors.bottom: parent.bottom
        width: parent.width
        height: footerDivider.height + Theme.controlSpacing
            + (!ProjectService.draft && root.showAddForm ? addForm.implicitHeight : Theme.controlHeight)
            + Theme.controlSpacing + manageHints.implicitHeight + Theme.projectManagePadding
        visible: ProjectService.managing
        Rectangle {
            id: footerDivider
            x: Theme.projectManagePadding
            width: Math.max(0,parent.width - Theme.projectManagePadding * 2)
            height: 1
            color: Theme.empty
        }
        Column {
            id: addForm
            x: Theme.projectManagePadding
            y: footerDivider.height + Theme.controlSpacing
            objectName: "projectAddForm"
            width: Math.max(0,parent.width - Theme.projectManagePadding * 2)
            spacing: Theme.controlSpacing
            visible: !ProjectService.draft && root.showAddForm
            Row {
                width: parent.width
                spacing: Theme.controlSpacing
                UI.FolderPathField {
                    id: sourcePath
                    inputObjectName: "projectSourcePath"
                    browseObjectName: "browseProjectSource"
                    width: Math.max(0,parent.width - editorActions.width - parent.spacing)
                    placeholderText: root.sourceKind === "root" ? "Repositories root folder" : "Project folder"
                    dialogTitle: root.sourceKind === "root" ? "Choose repositories root" : "Choose project folder"
                    enabled: !ProjectService.busy
                    onAccepted: if (text.trim()) ProjectService.addSource(text,root.sourceKind,root.sourceCategory)
                }
                UI.EditorActions {
                    id: editorActions
                    cancelObjectName: "cancelAddProjectSource"
                    submitObjectName: "addProjectSource"
                    submitGlyph: Theme.addIcon
                    submitHint: "scan folder before adding"
                    cancelEnabled: !ProjectService.busy
                    submitEnabled: !ProjectService.busy && !!sourcePath.text.trim()
                    onCancelled: root.cancelAdd()
                    onSubmitted: ProjectService.addSource(sourcePath.text,root.sourceKind,root.sourceCategory)
                }
            }
            Row {
                spacing: Theme.projectManageSectionSpacing
                UI.ActionButton {
                    objectName: "projectSourceKind"
                    label: root.sourceKind === "root" ? "Repositories root" : "Single folder"
                    width: Theme.projectOptionButtonWidth
                    hint: "switch folder type"
                    enabled: !ProjectService.busy
                    onClicked: root.sourceKind = root.sourceKind === "root" ? "folder" : "root"
                }
                UI.ActionButton {
                    objectName: "projectSourceCategory"
                    label: root.sourceCategory === "work" ? "Work" : "Personal"
                    foreground: root.sourceCategory === "work" ? Theme.accent : Theme.active
                    width: Theme.projectOptionButtonWidth
                    hint: "switch category"
                    enabled: !ProjectService.busy
                    onClicked: root.sourceCategory = root.sourceCategory === "work" ? "personal" : "work"
                }
            }
        }
        UI.ActionButton {
            objectName: "beginAddProjectSource"
            y: footerDivider.height + Theme.controlSpacing
            visible: !ProjectService.draft && !root.showAddForm
            anchors.right: parent.right
            anchors.rightMargin: Theme.projectManagePadding
            glyph: Theme.addIcon
            hint: "add folder (" + Config.projectAddShortcut + ")"
            enabled: !ProjectService.busy
            onClicked: root.beginAdd()
        }
        UI.EditorActions {
            y: footerDivider.height + Theme.controlSpacing
            anchors.right: parent.right
            anchors.rightMargin: Theme.projectManagePadding
            visible: !!ProjectService.draft
            cancelObjectName: "cancelProjectDraft"
            submitObjectName: "saveProjectDraft"
            cancelHint: ProjectService.draft?.review ? "Cancel refresh" : "Cancel"
            submitHint: ProjectService.draft?.review ? "Apply refresh" : "Save"
            submitEnabled: !ProjectService.busy
            onCancelled: { ProjectService.cancelDraft(); root.cancelAdd() }
            onSubmitted: { if (ProjectService.saveDraft()) root.cancelAdd() }
        }
        UI.Text {
            id: manageHints
            objectName: "projectManageHints"
            centerVertical: false
            x: Theme.projectManagePadding
            width: Math.max(0,parent.width - Theme.projectManagePadding * 2)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.projectManagePadding
            font.pixelSize: Theme.fontSize - 1
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: Theme.inactive
            text: Config.projectManageShortcut + ": projects"
                + (!root.showAddForm && !ProjectService.draft ? " · " + Config.projectAddShortcut + ": add folder" : "")
                + " · Esc: " + (root.adding || ProjectService.draft ? "cancel" : "close")
        }
    }
}
