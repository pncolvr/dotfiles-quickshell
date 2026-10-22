pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QC
import "../../theme"
import "../../ui" as UI
import "../../services"
import "../../config"
import "../../services/launcher/Search.mjs" as Search

ManagedPickerFrame {
    id: root
    objectName: "projectPickerPanel"
    property string sourceKind: "folder"
    property string sourceCategory: "personal"
    readonly property var selectedSource: manage.selectedEntry
    readonly property bool showForm: adding || !!ProjectService.draft
    readonly property bool showAddForm: adding
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
    managementView: manage
    footerItem: footer
    managementSearch: manage.searchField
    managementScroll: manage.listView
    managementFocusTarget: root.showAddForm && !ProjectService.draft ? sourceForm : ProjectService.draft ? draftScroll : manage
    onAddRequested: { ProjectService.setManaging(true); adding = true }
    onManagementRequested: value => { if (!value) cancelAdd(); ProjectService.setManaging(value) }
    onShowAllRequested: ProjectService.toggleShowAll()
    onSessionClosed: { root.adding = false; sourceForm.clear() }

    function matchesManagement(text) {
        return !manage.searchField.text.trim() || root.picker.filter([{title:text}],manage.searchField.text).length > 0
    }
    function highlighted(text) {
        return Search.highlight(text, root.picker.searchPattern(manage.searchField.text), Config.pickerFuzzySearch, Theme.accent)
    }
    function projectsForSource(source) {
        const projects = ProjectService.projects.filter(project => project.sourcePaths.includes(source.path))
        return matchesManagement(source.path) ? projects
            : projects.filter(project => matchesManagement(project.name + " " + project.path + " "
                + project.workspaces.map(workspace => ProjectService.fileLabel(workspace) + " " + workspace.path).join(" ")))
    }
    function matchingWorkspaces(project) {
        const repository = project.name + " " + project.path
        if (!manage.searchField.text.trim() || matchesManagement(repository)) return []
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
    function editProject(path) {
        root.preserveManagementScroll(() => ProjectService.editProject(path))
        Qt.callLater(root.focusSearch)
    }
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
        function onSaved(path: string) { if (path) manage.selectSaved(path) }
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
        hintOverrides: ({manage: {sequence: Config.projectManageShortcut}, workFilter: {sequence: Config.projectShowAllShortcut}})
        hintPanel: "projects"
        hintActions: ["manage", "search"].concat(StatusService.enabled ? ["workFilter"] : [])
            .concat(root.picker.multiple ? ["selection.toggle", "selection.all", "selection.clear"] : [])
    }
    UI.ManagementView {
        id: manage
        objectName: "projectManageView"
        y: root.contentTop; width: parent.width; height: root.manageHeight
        visible: root.managing
        entries: root.managedSources.map(source => Object.assign({},source,{id:source.path,title:source.path,
            subtitle:Translations.text(source.kind === "root" ? "projects.source.repositoryRoot" : "projects.source.singleFolder"),
            type:source.kind,availability:ProjectService.pathStates[source.path]?.status ?? "unchecked"}))
        searchEntries: (entries,query) => entries
        editing: root.showForm
        busy: ProjectService.busy || root.nativeDialogOpen
        showCategory: StatusService.enabled
        filterAvailability: true
        typeOptions: [{name:"folder",description:Translations.text("projects.source.singleFolder")},{name:"root",description:Translations.text("projects.source.repositoryRoot")}]
        searchObjectName: "projectManageSearch"
        listObjectName: "projectManageList"
        refreshHintEnabled: !ProjectService.busy && ProjectService.sources.length > 0
        hintOverrides: ({add: {sequence: Config.projectAddShortcut}, manage: {sequence: Config.projectManageShortcut, label: Translations.text("hints.list")}})
        addObjectName: "beginAddProjectSource"
        searchPlaceholder: Translations.text("projects.manage.searchPlaceholder")
        addHint: Translations.text("projects.actions.addHint",[Config.projectAddShortcut])
        message: ProjectService.busy ? Translations.text("projects.status.scanning") : ProjectService.error
        onEditRequested: root.editSource(root.selectedSource.path)
        onAddRequested: root.beginAdd()
        toolbarContent: [UI.ActionButton {
            objectName: "refreshProjects"
            visible: ProjectService.managing
            keyAction: "refresh"
            glyph: Theme.refreshIcon
            hint: Translations.text("projects.actions.refreshHint")
            enabled: !ProjectService.busy && !root.showForm && ProjectService.sources.length > 0
            onClicked: ProjectService.refresh()
        }]
        detailContent: [Rectangle {
                        id: sourceRow
                        readonly property var modelData: root.selectedSource ?? {path:"",kind:"folder",category:"personal"}
                        readonly property var projects: root.projectsForSource(modelData)
                        objectName: "projectSource_" + modelData.path
                        width: parent.width
                        visible: !root.showForm && !!root.selectedSource
                        implicitHeight: sourceContent.implicitHeight
                        color: "transparent"
                        radius: Theme.iconButtonRadius
                        Column {
                            id: sourceContent
                            x: 0
                            y: 0
                            width: parent.width
                            spacing: Theme.controlSpacing
                            UI.FolderForm {
                                width: parent.width
                                readOnly: true
                                showKind: true
                                showCategory: StatusService.enabled
                                text: sourceRow.modelData.path
                                kind: sourceRow.modelData.kind
                                category: sourceRow.modelData.category
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
                                model: sourceRow.modelData.kind === "root" || (manage.searchField.text.trim() && !root.matchesManagement(sourceRow.modelData.path)) ? sourceRow.projects : []
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
                                            visible: !!manage.searchField.text.trim() && !root.matchesManagement(projectRow.modelData.name)
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
                    }, UI.FolderForm {
            showCategory: StatusService.enabled
            id: sourceForm
            objectName: "projectAddForm"
            x: 0
            y: 0
            width: parent.width
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
        }, QC.ScrollView {
            id: draftScroll
            property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: draftScroll.contentItem as Flickable }
            objectName: "projectWorkspaceScroll"
            padding: 0
            leftPadding: Theme.scrollbarGutter
            rightPadding: Theme.scrollbarGutter
            QC.ScrollBar.horizontal: UI.ScrollBar { policy: QC.ScrollBar.AlwaysOff }
            QC.ScrollBar.vertical: UI.ScrollBar {}
            x: 0
            y: 0
            width: parent.width
            height: visible ? Math.min(draftContent.implicitHeight, Math.max(Theme.pickerRowHeight * 4, manage.detailScroll.height - (sourceForm.visible ? sourceForm.height : 0) - Theme.controlSpacing)) : 0
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
        }]
        actionContent: [UI.ManagementActions {
                visible: !root.showForm && !!root.selectedSource
                                    path: root.selectedSource?.path ?? ""
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
                                }, UI.EditorActions {
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
            }]
    }
    Item { id: footer; visible: false }
}
