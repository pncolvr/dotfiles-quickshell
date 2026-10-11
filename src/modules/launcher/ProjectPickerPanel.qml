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
    property alias folderPicker: sourceForm.folderPicker
    readonly property bool nativeDialogOpen: sourceForm.nativeDialogOpen
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
            if (root.showAddForm && !ProjectService.draft) sourceForm.focusInput()
            else if (!ProjectService.draft) manageSearch.forceActiveFocus()
        }
        else list.focusSearch()
    }
    function editSource(path) {
        ProjectService.editSource(path)
        if (ProjectService.draft?.previousPath) {
            sourceForm.text = ProjectService.draft.path
            root.sourceKind = ProjectService.draft.kind
            root.sourceCategory = ProjectService.draft.category
            Qt.callLater(sourceForm.focusInput)
        }
    }
    function submitForm() {
        if (ProjectService.draft) root.saveDraft()
        else if (sourceForm.text.trim()) ProjectService.addSource(sourceForm.text,root.sourceKind,root.sourceCategory)
    }
    function saveDraft() {
        if (ProjectService.draft?.previousPath) {
            ProjectService.setDraftPath(sourceForm.text)
            ProjectService.setDraftKind(root.sourceKind)
            ProjectService.setDraftCategory(root.sourceCategory)
        }
        if (ProjectService.saveDraft()) root.cancelAdd()
    }
    function cancelAdd() { adding = false; sourceForm.clear(); Qt.callLater(root.focusSearch) }
    function beginAdd() { ProjectService.setManaging(true); adding = true; Qt.callLater(root.focusSearch) }
    function handleAddKey(event, activate) {
        if (!addShortcut.enabled || addShortcut.portableText !== "Ctrl+A" || !event.matches(StandardKey.SelectAll)) return false
        if (activate) beginAdd()
        return true
    }
    function handlePickerKey(event, activate) {
        return ProjectService.urls && list.handleSelectionKey(event,activate)
    }
    Keys.onPressed: event => { event.accepted = !ProjectService.managing && root.handlePickerKey(event,true) }
    function management(value) {
        if (!value) cancelAdd()
        ProjectService.setManaging(value)
        Qt.callLater(root.focusSearch)
    }
    Connections {
        target: ProjectService
        function onSourceAdded() { root.cancelAdd() }
        function onSourcePathResolved(path: string) { sourceForm.text = path }
    }
    Connections {
        target: root.picker
        function onVisibleChanged() {
            if (!root.picker.visible) {
                root.adding = false
                sourceForm.clear()
                manageSearch.clear()
            }
        }
    }
    Shortcut {
        id: addShortcut
        sequence: Config.projectAddShortcut
        enabled: root.visible && root.picker.visible && root.picker.mode === PickerService.Mode.Projects
            && ProjectService.managing && !ProjectService.busy && !ProjectService.draft && !root.showAddForm && !root.nativeDialogOpen
        onActivated: root.beginAdd()
    }
    Shortcut {
        sequence: Config.projectShowAllShortcut
        enabled: root.visible && root.picker.visible && root.picker.mode === PickerService.Mode.Projects && !ProjectService.managing
        onActivated: ProjectService.toggleShowAll()
    }
    Shortcut {
        sequence: Config.projectManageShortcut
        enabled: root.visible && root.picker.visible && root.picker.mode === PickerService.Mode.Projects
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
            + (ProjectService.showAll ? ": status" : ": all") + " · " + Config.projectManageShortcut + ": manage"
            + (ProjectService.urls ? " · Esc: close\n" + root.picker.selectedIds.length + " selected · Shift+Space: toggle + next\nCtrl+A: all / clear · Enter: open"
                : " · Enter: open · Esc: close")
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
                                UI.ManagementActions {
                                    path: sourceRow.modelData.path
                                    copyObjectName: "copySourcePath_" + path
                                    editObjectName: "editSource_" + path
                                    refreshObjectName: "refreshSource_" + path
                                    editHint: "edit folder and workspaces"
                                    removeHint: "remove source"
                                    removeColor: Theme.urgent
                                    showRefresh: true
                                    editEnabled: !ProjectService.busy && !ProjectService.draft
                                    refreshEnabled: !ProjectService.busy && !ProjectService.draft
                                    removeEnabled: !ProjectService.busy
                                    onEditRequested: root.editSource(path)
                                    onRefreshRequested: ProjectService.refresh(path)
                                    onRemoveRequested: ProjectService.removeSource(path)
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
                                    UI.ManagementActions {
                                        path: projectRow.modelData.path
                                        copyObjectName: "copyProjectPath_" + path
                                        editObjectName: "editProject_" + path
                                        editHint: "edit workspaces"
                                        showEdit: projectRow.modelData.workspaces.length > 0
                                        showRemove: false
                                        editEnabled: !ProjectService.busy && !ProjectService.draft
                                        onEditRequested: ProjectService.editProject(path)
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

        }
    }
    Item {
        id: manageFooter
        anchors.bottom: parent.bottom
        width: parent.width
        height: footerDivider.height + Theme.controlSpacing
            + (sourceForm.visible ? sourceForm.implicitHeight + Theme.controlSpacing : 0)
            + (draftScroll.visible ? draftScroll.height + Theme.controlSpacing : 0)
            + Theme.controlHeight
            + Theme.controlSpacing + manageHints.implicitHeight + Theme.projectManagePadding
        visible: ProjectService.managing
        Rectangle {
            id: footerDivider
            x: Theme.projectManagePadding
            width: Math.max(0,parent.width - Theme.projectManagePadding * 2)
            height: 1
            color: Theme.empty
        }
        UI.FolderForm {
            id: sourceForm
            objectName: "projectAddForm"
            x: Theme.projectManagePadding
            y: footerDivider.height + Theme.controlSpacing
            width: Math.max(0,parent.width - Theme.projectManagePadding * 2)
            visible: !!ProjectService.draft?.previousPath || (!ProjectService.draft && root.showAddForm)
            enabled: !ProjectService.busy
            inputObjectName: ProjectService.draft?.previousPath ? "editProjectSourcePath" : "projectSourcePath"
            browseObjectName: ProjectService.draft?.previousPath ? "browseEditProjectSource" : "browseProjectSource"
            categoryObjectName: ProjectService.draft?.previousPath ? "editSourceCategory" : "projectSourceCategory"
            kindObjectName: "projectSourceKind"
            placeholderText: root.sourceKind === "root" ? "Repositories root folder" : "Project folder"
            dialogTitle: root.sourceKind === "root" ? "Choose repositories root" : "Choose project folder"
            showKind: true
            kind: root.sourceKind
            category: root.sourceCategory
            onKindRequested: kind => root.sourceKind = kind
            onCategoryRequested: category => root.sourceCategory = category
            onAccepted: root.submitForm()
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
        QC.ScrollView {
            id: draftScroll
            x: Theme.projectManagePadding
            y: footerDivider.height + Theme.controlSpacing + (sourceForm.visible ? sourceForm.implicitHeight + Theme.controlSpacing : 0)
            width: parent.width - Theme.projectManagePadding * 2
            height: visible ? Math.min(draftContent.implicitHeight, Theme.pickerRowHeight * 4) : 0
            contentWidth: availableWidth
            contentHeight: draftContent.implicitHeight
            visible: !!ProjectService.draft
            clip: true
            Column {
                id: draftContent
                width: draftScroll.availableWidth
                spacing: Theme.projectManageSectionSpacing
                visible: !!ProjectService.draft
                UI.ColumnText {
                    visible: !!text
                    text: ProjectService.draft?.previousPath ? ""
                        : ProjectService.draft?.review ? "New workspaces found. Choose which to include."
                        : ProjectService.draft?.workspaceEdit ? "Choose workspaces to include" : "Choose workspaces before adding"
                }
                Repeater {
                    model: ProjectService.draft?.projects ?? []
                    delegate: Column {
                        id: projectDraft
                        required property var modelData
                        visible: modelData.workspaces.length > 0
                        width: draftContent.width
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
                                width: draftContent.width
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
        UI.EditorActions {
            y: draftScroll.y + draftScroll.height + Theme.controlSpacing
            anchors.right: parent.right
            anchors.rightMargin: Theme.projectManagePadding
            visible: !!ProjectService.draft || sourceForm.visible
            cancelObjectName: ProjectService.draft ? "cancelProjectDraft" : "cancelAddProjectSource"
            submitObjectName: ProjectService.draft ? "saveProjectDraft" : "addProjectSource"
            submitGlyph: ProjectService.draft ? Theme.checkIcon : Theme.addIcon
            cancelHint: ProjectService.draft?.review ? "Cancel refresh" : "Cancel"
            submitHint: ProjectService.draft?.review ? "Apply refresh" : ProjectService.draft ? "Save" : "scan folder before adding"
            submitEnabled: !ProjectService.busy && (!sourceForm.visible || !!sourceForm.text.trim())
            cancelEnabled: !ProjectService.busy
            onCancelled: { ProjectService.cancelDraft(); root.cancelAdd() }
            onSubmitted: root.submitForm()
        }
        UI.ShortcutHints {
            id: manageHints
            objectName: "projectManageHints"
            x: Theme.projectManagePadding
            width: Math.max(0,parent.width - Theme.projectManagePadding * 2)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.projectManagePadding
            hints: Config.projectManageShortcut + ": projects"
                + (!root.showAddForm && !ProjectService.draft ? " · " + Config.projectAddShortcut + ": add folder" : "")
                + " · Esc: " + (root.adding || ProjectService.draft ? "cancel" : "close")
        }
    }
}
