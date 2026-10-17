pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QC
import "../../theme"
import "../../theme/ui" as UI
import "../../services"
import "../../config"
import "../../services/launcher/Search.mjs" as Search

ManagedPickerFrame {
    id: root
    objectName: "projectPickerPanel"
    property string sourceKind: "folder"
    property string sourceCategory: "personal"
    readonly property bool showAddForm: adding || ProjectService.sources.length === 0
    property alias folderPicker: sourceForm.folderPicker
    nativeDialogOpen: sourceForm.nativeDialogOpen
    pickerMode: PickerService.Mode.Projects
    managing: ProjectService.managing
    addSequence: Config.projectAddShortcut
    manageSequence: Config.projectManageShortcut
    showAllSequence: Config.projectShowAllShortcut
    addAllowed: managing && !ProjectService.busy && !ProjectService.draft && !root.showAddForm && !nativeDialogOpen
    manageDuringDialog: true
    headerItem: header
    listItem: list
    manageItem: manage
    footerItem: manageFooter
    managementSearch: manageSearch
    managementScroll: manage.contentItem
    managementFocusTarget: root.showAddForm && !ProjectService.draft ? sourceForm : !ProjectService.draft ? manageSearch : null
    onAddRequested: { ProjectService.setManaging(true); adding = true }
    onManagementRequested: value => { if (!value) cancelAdd(); ProjectService.setManaging(value) }
    onShowAllRequested: ProjectService.toggleShowAll()
    onSessionClosed: { root.adding = false; sourceForm.clear() }

    function matchesManagement(text) {
        return !manageSearch.text.trim() || root.picker.filter([{title:text}],manageSearch.text).length > 0
    }
    function highlighted(text) {
        return Search.highlight(text, root.picker.searchPattern(manageSearch.text), Config.pickerFuzzySearch, Theme.accent)
    }
    function projectsForSource(source) {
        const projects = ProjectService.projects.filter(project => project.sourcePaths.includes(source.path))
        return matchesManagement(source.path) ? projects
            : projects.filter(project => matchesManagement(project.name + " " + project.path + " "
                + project.workspaces.map(workspace => ProjectService.fileLabel(workspace) + " " + workspace.path).join(" ")))
    }
    function matchingWorkspaces(project) {
        const repository = project.name + " " + project.path
        if (!manageSearch.text.trim() || matchesManagement(repository)) return []
        return project.workspaces.filter(workspace => matchesManagement(repository + " " + ProjectService.fileLabel(workspace) + " " + workspace.path))
    }
    readonly property var managedSources: ProjectService.sources.filter(source => matchesManagement(source.path) || projectsForSource(source).length > 0)

    function editSource(path) {
        root.preserveManagementScroll(() => ProjectService.editSource(path))
        if (ProjectService.draft?.previousPath) {
            sourceForm.text = ProjectService.draft.path
            root.sourceKind = ProjectService.draft.kind
            root.sourceCategory = ProjectService.draft.category
            Qt.callLater(sourceForm.focusInput)
        }
    }
    function editProject(path) { root.preserveManagementScroll(() => ProjectService.editProject(path)) }
    function setIncluded(project,workspace,included) {
        root.preserveScroll(() => ProjectService.setIncluded(project,workspace,included),draftScroll.contentItem)
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
        root.preserveManagementScroll(() => { if (ProjectService.saveDraft()) root.cancelAdd() })
    }
    function cancelAdd() { root.preserveManagementScroll(() => { adding = false; sourceForm.clear(); Qt.callLater(root.focusSearch) }) }
    function cancelDraft() { root.preserveManagementScroll(() => { ProjectService.cancelDraft(); root.cancelAdd() }) }

    function handlePickerKey(event, activate) {
        return ProjectService.urls && list.handleSelectionKey(event,activate)
    }
    Keys.onPressed: event => { event.accepted = !ProjectService.managing && root.handlePickerKey(event,true) }

    Connections {
        target: ProjectService
        function onSourceAdded() { root.cancelAdd() }
        function onSourcePathResolved(path: string) { sourceForm.text = path }
    }

    onEscapeRequested: {
        if (ProjectService.draft) root.cancelDraft()
        else if (root.adding) root.cancelAdd()
        else root.picker.close()
    }
    RowLayout {
        id: header
        width: parent.width
        spacing: Theme.controlSpacing
        UI.TabBar {
            objectName: "projectTabs"
            labels: [Translations.text("projects.title"), Translations.text("common.tabs.manage")]
            currentIndex: ProjectService.managing ? 1 : 0
            Layout.fillWidth: true
            onTabClicked: index => root.management(index === 1)
        }
        UI.ActionButton {
            visible: !ProjectService.managing && !!ProjectService.projectPath
            glyph: Theme.upIcon
            hint: Translations.text("projects.actions.backHint")
            onClicked: ProjectService.back()
        }
        UI.ActionButton {
            objectName: "refreshProjects"
            visible: ProjectService.managing
            glyph: Theme.refreshIcon
            hint: Translations.text("projects.actions.refreshHint")
            enabled: !ProjectService.busy && !ProjectService.draft && ProjectService.sources.length > 0
            onClicked: ProjectService.refresh()
        }
    }
    PickerPanelBase {
        id: list
        y: root.contentTop
        width: parent.width
        height: root.listHeight
        picker: root.picker
        backgroundVisible: root.backgroundVisible
        visible: !ProjectService.managing
        searchPlaceholder: Translations.text(ProjectService.urls ? "projects.urls.searchPlaceholder" : "projects.search.placeholder")
        searchKeyHandler: root.handlePickerKey
        footerHint: StatusService.filterHint(Config.projectShowAllShortcut,ProjectService.showAll) + Translations.text(ProjectService.urls ? "projects.shortcuts.urls" : "projects.shortcuts.list",[Config.projectManageShortcut,root.picker.selectedIds.length])
    }
    QC.ScrollView {
        id: manage
        objectName: "projectManageScroll"
        y: root.contentTop
        width: parent.width
        height: root.manageHeight
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
                text: ProjectService.busy ? Translations.text("projects.status.scanning") : ProjectService.error
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
                    placeholderText: Translations.text("projects.manage.searchPlaceholder")
                    retainPanelWhileEditing: false
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
                    text: Translations.text("projects.empty.sources")
                    visible: ProjectService.sources.length === 0
                    color: Theme.inactive
                }
                UI.ColumnText {
                    text: Translations.text("projects.empty.filtered")
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
                                    objectName: "managedSourcePath_" + sourceRow.modelData.path
                                    text: root.highlighted(sourceRow.modelData.path)
                                    textFormat: Text.StyledText
                                    Accessible.name: sourceRow.modelData.path
                                    elide: Text.ElideMiddle
                                    Layout.fillWidth: true
                                    UI.HoverTooltip { text: sourceRow.modelData.path }
                                }
                                UI.ManagementActions {
                                    path: sourceRow.modelData.path
                                    copyObjectName: "copySourcePath_" + path
                                    editObjectName: "editSource_" + path
                                    refreshObjectName: "refreshSource_" + path
                                    editHint: Translations.text("projects.actions.editSourceHint")
                                    removeHint: Translations.text("projects.actions.removeSourceHint")
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
                                    text: (Translations.text(sourceRow.modelData.kind === "root" ? "projects.source.repositoryRoot" : "projects.source.singleFolder")) + " ·"
                                    color: Theme.inactive
                                }
                                UI.ColumnText {
                                    visible: StatusService.enabled
                                    text: Translations.text(sourceRow.modelData.category === "work" ? "status.modes.work" : "status.modes.personal")
                                    color: sourceRow.modelData.category === "work" ? Theme.accent : Theme.active
                                    Layout.fillWidth: true
                                }
                            }
                            UI.ColumnText {
                                width: parent.width
                                text: Translations.message(sourceRow.modelData.error)
                                visible: !!text
                                color: Theme.urgent
                                wrapMode: Text.Wrap
                            }
                            UI.ColumnText {
                                objectName: "sourcePathWarning_" + sourceRow.modelData.path
                                width: parent.width
                                text: ProjectService.pathWarning(sourceRow.modelData.path,
                                    sourceRow.modelData.kind === "folder" ? sourceRow.projects.reduce((rows,project) => rows.concat(project.workspaces),[]) : [])
                                visible: !!text
                                color: ProjectService.pathStates[sourceRow.modelData.path]?.status === "unchecked" ? Theme.inactive : Theme.warning
                                wrapMode: Text.Wrap
                            }
                            Repeater {
                                model: sourceRow.modelData.kind === "root" || (manageSearch.text.trim() && !root.matchesManagement(sourceRow.modelData.path)) ? sourceRow.projects : []
                                delegate: UI.ManagementRow {
                                    id: projectRow
                                    required property var modelData
                                    objectName: "managedProject_" + modelData.path
                                    width: sourceContent.width
                                    Column {
                                        id: projectText
                                        Layout.fillWidth: true
                                        spacing: Theme.controlSpacing
                                        UI.ColumnText {
                                            objectName: "managedProjectName_" + projectRow.modelData.path
                                            width: parent.width
                                            text: root.highlighted(projectRow.modelData.name)
                                            textFormat: Text.StyledText
                                            Accessible.name: projectRow.modelData.name
                                            elide: Text.ElideMiddle
                                            UI.HoverTooltip { text: projectRow.modelData.path }
                                        }
                                        UI.ColumnText {
                                            objectName: "managedProjectPath_" + projectRow.modelData.path
                                            width: parent.width
                                            visible: !!manageSearch.text.trim() && !root.matchesManagement(projectRow.modelData.name)
                                            text: root.highlighted(projectRow.modelData.path)
                                            textFormat: Text.StyledText
                                            Accessible.name: projectRow.modelData.path
                                            color: Theme.inactive
                                            elide: Text.ElideMiddle
                                            UI.HoverTooltip { text: projectRow.modelData.path }
                                        }
                                        UI.ColumnText {
                                            objectName: "projectPathWarning_" + projectRow.modelData.path
                                            width: parent.width
                                            text: ProjectService.pathWarning(projectRow.modelData.path,projectRow.modelData.workspaces)
                                            visible: !!text
                                            color: ProjectService.pathStates[projectRow.modelData.path]?.status === "unchecked" ? Theme.inactive : Theme.warning
                                            wrapMode: Text.Wrap
                                        }
                                        Repeater {
                                            model: root.matchingWorkspaces(projectRow.modelData)
                                            delegate: UI.ColumnText {
                                                id: matchedWorkspaceText
                                                required property var modelData
                                                objectName: "matchedWorkspace_" + modelData.path
                                                width: projectText.width
                                                text: root.highlighted(modelData.name + " · " + modelData.path)
                                                    + (ProjectService.pathStates[modelData.path]?.message ? " · " + Translations.text(ProjectService.pathStates[modelData.path].message) : "")
                                                textFormat: Text.StyledText
                                                Accessible.name: modelData.name + " · " + modelData.path
                                                color: ProjectService.pathStates[modelData.path]?.status === "unavailable" ? Theme.warning : Theme.inactive
                                                elide: Text.ElideMiddle
                                                UI.HoverTooltip { text: matchedWorkspaceText.modelData.path }
                                            }
                                        }
                                    }
                                    UI.ManagementActions {
                                        path: projectRow.modelData.path
                                        copyObjectName: "copyProjectPath_" + path
                                        editObjectName: "editProject_" + path
                                        editHint: Translations.text("projects.actions.editFilesHint")
                                        showEdit: projectRow.modelData.workspaces.length > 0
                                        showRemove: false
                                        editEnabled: !ProjectService.busy && !ProjectService.draft
                                        onEditRequested: root.editProject(path)
                                    }
                                }
                            }
                            UI.ColumnText {
                                text: Translations.text("projects.empty.repositories")
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
            + footerRow.implicitHeight + Theme.projectManagePadding
        visible: ProjectService.managing
        Rectangle {
            id: footerDivider
            x: Theme.projectManagePadding
            width: Math.max(0,parent.width - Theme.projectManagePadding * 2)
            height: 1
            color: Theme.empty
        }
        UI.FolderForm {
            showCategory: StatusService.enabled
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
            placeholderText: Translations.text(root.sourceKind === "root" ? "projects.source.rootLabel" : "projects.source.folderLabel")
            dialogTitle: Translations.text(root.sourceKind === "root" ? "projects.dialog.chooseRoot" : "projects.dialog.chooseFolder")
            showKind: true
            kind: root.sourceKind
            category: root.sourceCategory
            onKindRequested: kind => root.sourceKind = kind
            onCategoryRequested: category => root.sourceCategory = category
            onAccepted: root.submitForm()
        }
        QC.ScrollView {
            id: draftScroll
            objectName: "projectWorkspaceScroll"
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
                        : ProjectService.draft?.review ? Translations.text("projects.files.newFound")
                        : Translations.text(ProjectService.draft?.workspaceEdit ? "projects.files.choose" : "projects.files.chooseBeforeAdding")
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
                            text: root.highlighted(projectDraft.modelData.path)
                            textFormat: Text.StyledText
                            Accessible.name: projectDraft.modelData.path
                            width: parent.width
                            elide: Text.ElideMiddle
                            UI.HoverTooltip { text: projectDraft.modelData.path }
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
                                    hint: Translations.text(workspaceRow.modelData.included ? "projects.files.excludeHint" : "projects.files.includeHint")
                                    fillColor: workspaceRow.modelData.included ? Theme.accent : Theme.alternateBackground
                                    onClicked: root.setIncluded(projectDraft.modelData.path,workspaceRow.modelData.path,!workspaceRow.modelData.included)
                                }
                                Column {
                                    Layout.fillWidth: true
                                    spacing: Theme.controlSpacing
                                    UI.ColumnText {
                                        objectName: "managedWorkspace_" + workspaceRow.modelData.path
                                        width: parent.width
                                        text: root.highlighted(ProjectService.fileLabel(workspaceRow.modelData) + " · " + workspaceRow.modelData.path)
                                        textFormat: Text.StyledText
                                        Accessible.name: ProjectService.fileLabel(workspaceRow.modelData) + " · " + workspaceRow.modelData.path
                                        elide: Text.ElideMiddle
                                        UI.HoverTooltip { text: workspaceRow.modelData.path }
                                    }
                                    UI.ColumnText {
                                        objectName: "workspacePathWarning_" + workspaceRow.modelData.path
                                        width: parent.width
                                        text: Translations.text(ProjectService.pathStates[workspaceRow.modelData.path]?.message ?? "")
                                        visible: !!text
                                        color: ProjectService.pathStates[workspaceRow.modelData.path]?.status === "unavailable" ? Theme.warning : Theme.inactive
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        RowLayout {
            id: footerRow
            x: Theme.projectManagePadding
            width: Math.max(0,parent.width - Theme.projectManagePadding * 2)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.projectManagePadding
            spacing: Theme.controlSpacing
            UI.ShortcutHints {
                objectName: "projectManageHints"
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
                hints: Translations.text("projects.shortcuts.manage",[Config.projectManageShortcut])
                    + (!root.showAddForm && !ProjectService.draft ? " · " + Translations.text("common.shortcuts.addFolder",[Config.projectAddShortcut]) : "")
                    + " · Esc: " + (root.adding || ProjectService.draft ? "cancel" : "close")
            }
            UI.ActionButton {
                objectName: "beginAddProjectSource"
                glyph: Theme.addIcon
                hint: Translations.text("projects.actions.addHint",[Config.projectAddShortcut])
                enabled: root.addAllowed
                onClicked: root.beginAdd()
            }
            UI.EditorActions {
                visible: !!ProjectService.draft || sourceForm.visible
                cancelObjectName: ProjectService.draft ? "cancelProjectDraft" : "cancelAddProjectSource"
                submitObjectName: ProjectService.draft ? "saveProjectDraft" : "addProjectSource"
                submitGlyph: ProjectService.draft ? Theme.checkIcon : Theme.addIcon
                cancelHint: Translations.text(ProjectService.draft?.review ? "projects.actions.cancelRefresh" : "common.actions.cancel")
                submitHint: ProjectService.draft?.review ? Translations.text("projects.actions.applyRefresh") : Translations.text(ProjectService.draft ? "common.actions.save" : "projects.actions.scanBeforeAddingHint")
                submitEnabled: !ProjectService.busy && (!sourceForm.visible || !!sourceForm.text.trim())
                cancelEnabled: !ProjectService.busy
                onCancelled: root.cancelDraft()
                onSubmitted: root.submitForm()
            }
        }
    }
}
