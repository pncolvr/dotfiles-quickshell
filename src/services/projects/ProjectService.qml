pragma Singleton
import QtQml
import Quickshell
import Quickshell.Io
import "../"
import "../../config"

Singleton {
    id: root
    property bool managing: false
    property bool urls: false
    property bool showAll: false
    property string projectPath: ""
    property string error: ""
    property var draft: null
    property string editingProject: ""
    property string editingSource: ""
    signal sourceAdded()
    property string operation: ""
    readonly property bool busy: scan.running
    readonly property var sources: ProjectRepository.sources
    readonly property var projects: ProjectRepository.projects
    readonly property var availableProjects: projects.filter(project => showAll || StatusService.status === Config.projectWorkStatus || project.category !== "work")

    function open(browser = false) {
        if (busy && operation === "add") operation = "discard"
        managing = false; urls = browser; showAll = false; projectPath = ""; draft = null; editingProject = ""; editingSource = ""; error = ""
        syncPicker()
    }
    function toggleShowAll() {
        showAll = !showAll
        syncPicker()
        PickerService.opened()
    }
    function setManaging(value) {
        managing = value
        if (!value) { cancelDraft(); syncPicker(); PickerService.opened() }
    }
    function syncPicker() {
        if (PickerService.mode !== "projects") return
        const previous = PickerService.currentItem?.id
        const rows = []
        if (urls) {
            for (const project of availableProjects) {
                if (!project.url || rows.some(row => row.id === project.url)) continue
                rows.push({id:project.url,title:project.url.replace(/^https?:\/\//,""),result:project.url,search:project.name + " " + project.url})
            }
            rows.sort((a,b) => a.title.localeCompare(b.title))
            PickerService.multiple = true
            PickerService.acceptLabel = "Open"
        } else if (projectPath) {
            const project = availableProjects.find(project => project.path === projectPath)
            if (!project) { projectPath = ""; syncPicker(); return }
            rows.push({id:project.path,title:"Open folder",result:project.path,category:project.category})
            for (const workspace of project.workspaces.filter(workspace => workspace.included))
                rows.push({id:workspace.path,title:workspace.name,subtitle:workspace.path,result:workspace.path,category:project.category})
            PickerService.acceptLabel = "Open"
        } else {
            for (const project of availableProjects) rows.push({id:project.path,title:project.name,subtitle:project.path,
                search:project.name + " " + project.path,result:project.path,category:project.category})
            PickerService.acceptLabel = "Select"
        }
        PickerService.items = rows
        PickerService.currentIndex = Math.max(0, PickerService.filteredItems.findIndex(row => row.id === previous))
        PickerService.error = error
    }
    function back() {
        projectPath = ""; PickerService.query = ""; PickerService.selectedIds = []; syncPicker(); PickerService.currentIndex = 0; PickerService.opened()
    }
    function accept(items) {
        if (managing) return
        const item = items[0]
        if (urls) {
            PickerService.close()
            for (const selected of items) Quickshell.execDetached(Config.projectBrowserCommand.concat([selected.result]))
            return
        }
        if (!projectPath) {
            const project = availableProjects.find(project => project.path === item.result)
            if (!project) return
            if (project.workspaces.some(workspace => workspace.included)) {
                projectPath = project.path
                PickerService.query = ""; syncPicker()
                const remembered = Config.pickerRememberSelection ? PreferencesRepository.value("launcher.selection.projects.workspaces:" + project.path, project.path) : project.path
                PickerService.currentIndex = Math.max(0, PickerService.items.findIndex(row => row.result === remembered))
                PickerService.opened()
                return
            }
            launch(project.path, project)
        } else {
            const project = availableProjects.find(project => project.path === projectPath)
            if (!project) return
            if (Config.pickerRememberSelection) PreferencesRepository.setValue("launcher.selection.projects.workspaces:" + project.path, item.result)
            launch(item.result, project)
        }
    }
    function launch(path, project) {
        const folderName = path.endsWith(".code-workspace") ? path.slice(0,path.lastIndexOf("/")).split("/").pop() : path.split("/").pop()
        const client = WindowService.allWindows.find(client => client.class === "code" && client.title.startsWith(folderName))
        PickerService.close()
        Qt.callLater(() => {
            if (client) WindowService.focusWindow(client.address)
            else Quickshell.execDetached(Config.projectEditorCommand.concat([path,"--profile",Config.projectEditorProfiles[project.category] || project.category]))
        })
    }
    function startScan(scanSources, action) {
        if (busy) return false
        error = ""; operation = action
        scan.input = JSON.stringify({sources:scanSources,sshConfig:Config.projectSshConfig,
            workspaceExclusions:Config.projectWorkspaceExclusions,dotfilesGitDirectory:Config.projectDotfilesGitDirectory,
            dotfilesWorkTree:Config.projectDotfilesWorkTree}) + "\n"
        scan.running = true
        return true
    }
    function addSource(path, kind, category) {
        if (draft) { error = "Save or cancel the current draft first"; return false }
        const home = Quickshell.env("HOME")
        path = path.trim().replace(/^~(?=\/|$)/,home).replace(/\/+$/,"") || "/"
        if (!path.startsWith("/") || !["root","folder"].includes(kind) || !["work","personal"].includes(category)) {
            error = "Choose an absolute folder path and a category"; return false
        }
        return startScan([{path,kind,category}],"add")
    }
    function refresh(path = "") {
        if (draft) { error = "Save or cancel the current draft before refreshing"; return false }
        const selected = path ? sources.filter(source => source.path === path) : sources
        if (path && !selected.length) { error = "That folder is not configured"; return false }
        return startScan(selected,"refresh")
    }
    function editProject(path) {
        if (busy) return
        const project = projects.find(project => project.path === path)
        if (!project) return
        editingProject = path
        editingSource = ""
        draft = {projects:[Object.assign({},project,{workspaces:project.workspaces.map(workspace => Object.assign({},workspace))})]}
        managing = true
        error = ""
    }
    function editSource(path) {
        if (busy) return
        const source = sources.find(source => source.path === path)
        if (!source) return
        editingSource = path
        editingProject = ""
        draft = Object.assign({},source,{projects:projects.filter(project => project.sourcePaths.includes(path))
            .map(project => Object.assign({},project,{workspaces:project.workspaces.map(workspace => Object.assign({},workspace))}))})
        managing = true
        error = ""
    }
    function setDraftCategory(category) {
        if (!editingSource || !draft || !["work","personal"].includes(category)) return
        draft = Object.assign({},draft,{category})
    }
    function setIncluded(projectPath, path, included) {
        if (!draft) return
        draft = Object.assign({},draft,{projects:draft.projects.map(project => project.path !== projectPath ? project
            : Object.assign({},project,{workspaces:project.workspaces.map(workspace => workspace.path !== path ? workspace : Object.assign({},workspace,{included}))}))})
    }
    function cancelDraft() {
        if (busy && operation === "add") operation = "discard"
        draft = null; editingProject = ""; editingSource = ""; error = ""
    }
    function reviewRefresh(results) {
        const discoveries = []
        for (const source of results) {
            if (source.error) continue
            for (const project of source.projects) {
                const existing = projects.find(item => item.path === project.path)
                const added = project.workspaces.filter(workspace => !existing?.workspaces.some(item => item.path === workspace.path))
                if (!added.length) continue
                let discovery = discoveries.find(item => item.path === project.path)
                if (!discovery) {
                    discovery = {path:project.path,workspaces:[]}
                    discoveries.push(discovery)
                }
                for (const workspace of added) {
                    if (!discovery.workspaces.some(item => item.path === workspace.path))
                        discovery.workspaces.push(Object.assign({},workspace,{included:true}))
                }
            }
        }
        if (!discoveries.length) return false
        draft = {review:true,results,projects:discoveries}
        managing = true
        return true
    }
    function saveDraft() {
        if (!draft || busy) return false
        let results
        if (draft.review) {
            results = draft.results.map(source => Object.assign({},source,{projects:source.projects.map(project => {
                const reviewed = draft.projects.find(item => item.path === project.path)
                return Object.assign({},project,{workspaces:project.workspaces.map(workspace => {
                    const choice = reviewed?.workspaces.find(item => item.path === workspace.path)
                    return choice ? Object.assign({},workspace,{included:choice.included}) : workspace
                })})
            })}))
        }
        const adding = !editingProject && !editingSource && !draft.review
        const saved = editingProject || editingSource ? ProjectRepository.saveEdit(draft.projects,editingSource,draft.category)
            : draft.review ? ProjectRepository.apply(results) : ProjectRepository.apply([draft],true)
        if (!saved) { error = ProjectRepository.error; return false }
        const refreshErrors = results?.filter(source => source.error).map(source => source.path + ": " + source.error).join("\n") || ""
        cancelDraft(); error = refreshErrors; syncPicker()
        if (adding) sourceAdded()
        return true
    }
    function removeSource(path) {
        if (busy || draft) return false
        if (!ProjectRepository.removeSource(path)) { error = ProjectRepository.error; return false }
        return true
    }
    Connections {
        target: ProjectRepository
        function onProjectsChanged() { root.syncPicker() }
    }
    Connections {
        target: StatusService
        function onStatusChanged() { root.syncPicker() }
    }
    Process {
        id: scan
        objectName: "projectScan"
        property string input: ""
        command: Config.projectScanCommand
        stdinEnabled: true
        onStarted: { write(input); stdinEnabled = false }
        stdout: StdioCollector { id: output; waitForEnd: true }
        stderr: StdioCollector { id: errors; waitForEnd: true }
        // qmllint disable signal-handler-parameters
        onExited: (exitCode, exitStatus) => {
            stdinEnabled = true
            if (exitCode !== 0 || exitStatus !== 0) { root.error = errors.text.trim() || "Project scan failed"; root.syncPicker(); return }
            try {
                const results = JSON.parse(output.text).sources
                if (root.operation === "add") {
                    const source = results[0]
                    if (source.error) throw new Error(source.error)
                    if (root.sources.some(existing => existing.path === source.path)) throw new Error("That source is already configured")
                    if (!source.projects.some(project => project.workspaces.length > 0)) {
                        if (!ProjectRepository.apply([source],true)) throw new Error(ProjectRepository.error)
                        root.sourceAdded()
                    } else {
                        root.draft = Object.assign({},source,{projects:source.projects.map(project => Object.assign({},project,{workspaces:project.workspaces.map(workspace => Object.assign({},workspace,{included:true}))}))})
                    }
                } else if (root.operation === "refresh") {
                    if (!root.reviewRefresh(results) && !ProjectRepository.apply(results)) throw new Error(ProjectRepository.error)
                    root.error = results.filter(source => source.error).map(source => source.path + ": " + source.error).join("\n")
                }
            } catch (error) { root.error = error.message || String(error) }
            root.syncPicker()
        }
        // qmllint enable signal-handler-parameters
    }
}
