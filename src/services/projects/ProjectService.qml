pragma Singleton
import "../../i18n"
import QtQml
import "ProjectLaunchers.mjs" as Launchers
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
    property var pathStates: ({})
    property bool pathCheckPending: false
    property bool scanPending: false
    readonly property bool checkingPaths: pathCheck.running === true
    signal sourceAdded()
    signal saved(string path)
    signal sourcePathResolved(string path)
    enum Operation { None, Add, Refresh, Edit, Discard }
    property int operation: ProjectService.Operation.None
    readonly property bool busy: scanPending || scan.running === true
    readonly property var sources: ProjectRepository.sources
    readonly property var projects: ProjectRepository.projects
    readonly property var availableProjects: projects.filter(project => StatusService.includesCategory(project.category,showAll,Config.projectWorkStatus))
    function pathRecords() {
        const rows = sources.map(source => ({path:source.path,kind:"directory"}))
        for (const project of projects) {
            rows.push({path:project.path,kind:"directory"})
            for (const workspace of project.workspaces) rows.push({path:workspace.path,kind:"file"})
        }
        return Array.from(new Map(rows.map(row => [row.path,row])).values())
    }
    function pathWarning(path, workspaces = []) {
        const state = pathStates[path]
        if (state?.message) return Translations.text(state.message)
        const missing = workspaces.filter(workspace => pathStates[workspace.path]?.status === "unavailable").length
        return missing ? Translations.text("projects.files.missing",[],missing) : ""
    }
    function checkPaths() {
        if (pathCheck.running) { pathCheckPending = true; return }
        pathCheckPending = false
        pathCheck.input = JSON.stringify(pathRecords()) + "\n"
        pathCheck.stdinEnabled = true
        pathCheck.running = true
    }
    onManagingChanged: if (managing) checkPaths()
    onSourcesChanged: if (managing) checkPaths()
    onProjectsChanged: if (managing) checkPaths()

    function open(browser = false) {
        if (busy && [ProjectService.Operation.Add,ProjectService.Operation.Edit].includes(operation)) operation = ProjectService.Operation.Discard
        managing = false; urls = browser; showAll = false; projectPath = ""; draft = null; error = ""
        syncPicker()
    }
    Process {
        id: pathCheck
        property string input: ""
        command: ["timeout", "10", ...Config.directoryResolveCommand, "--check"]
        stdinEnabled: true
        onStarted: { write(input); input = ""; stdinEnabled = false }
        stdout: StdioCollector { id: pathOutput; waitForEnd: true }
        stderr: SplitParser { onRead: _data => {} }
        // qmllint disable signal-handler-parameters
        onExited: (code, status) => {
            try {
                if (code !== 0 || status !== 0) throw new Error(Translations.text("files.errors.check"))
                const rows = JSON.parse(pathOutput.text)
                const states = {}
                for (const row of rows) states[row.path] = row
                root.pathStates = states
            } catch (_) {
                const states = {}
                for (const row of root.pathRecords()) states[row.path] = {status:"unchecked",message:Translations.text("files.status.unchecked")}
                root.pathStates = states
            }
            if (root.pathCheckPending && root.managing) Qt.callLater(root.checkPaths)
        }
        // qmllint enable signal-handler-parameters
    }
    function toggleShowAll() {
        showAll = !showAll
        syncPicker()
    }
    function setManaging(value) {
        managing = value
        if (!value) { cancelDraft(); syncPicker(); PickerService.opened() }
    }
    function fileLabel(file) {
        const launcher = Launchers.forFile(file.path, Config.projectApps)
        return launcher && !launcher.useFileNames ? (launcher.name || launcher.id) + " · " + file.name : file.name
    }
    function syncPicker() {
        if (PickerService.mode !== PickerService.Mode.Projects) return
        const previous = PickerService.currentItem?.id
        const rows = []
        if (urls) {
            for (const project of availableProjects) {
                if (!project.url || rows.some(row => row.id === project.url)) continue
                rows.push({id:project.url,title:project.url.replace(/^https?:\/\//,""),result:project.url,search:project.name + " " + project.url})
            }
            rows.sort((a,b) => a.title.localeCompare(b.title))
            PickerService.multiple = true
            PickerService.acceptLabel = Translations.text("common.actions.open")
        } else if (projectPath) {
            const project = availableProjects.find(project => project.path === projectPath)
            if (!project) { projectPath = ""; syncPicker(); return }
            rows.push(...Launchers.choices(project,Config.projectApps,Config.projectDefaultApp,Translations.text))
            PickerService.acceptLabel = Translations.text("common.actions.open")
        } else {
            for (const project of availableProjects) rows.push({id:project.path,title:project.name,subtitle:project.path,
                search:project.name + " " + project.path,result:project.path,category:project.category})
            PickerService.acceptLabel = Translations.text("common.actions.select")
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
            for (const selected of items) Quickshell.execDetached(Config.browserOpenCommand.concat([selected.result]))
            return
        }
        if (!projectPath) {
            const project = availableProjects.find(project => project.path === item.result)
            if (!project) return
            let actions
            try { actions = Launchers.choices(project,Config.projectApps,Config.projectDefaultApp,Translations.text) }
            catch (exception) { error = Translations.message(exception); PickerService.error = error; return }
            if (actions.length > 1) {
                projectPath = project.path
                PickerService.query = ""; syncPicker()
                const remembered = Config.pickerRememberSelection ? PreferencesRepository.value("launcher.selection.projects.workspaces:" + project.path, project.path) : project.path
                PickerService.currentIndex = Math.max(0, PickerService.items.findIndex(row => row.id === remembered || row.result === remembered))
                PickerService.opened()
                return
            }
            launch(actions[0].result,project,actions[0].launcherId)
        } else {
            const project = availableProjects.find(project => project.path === projectPath)
            if (!project) return
            if (Config.pickerRememberSelection) PreferencesRepository.setValue("launcher.selection.projects.workspaces:" + project.path, item.id)
            launch(item.result,project,item.launcherId)
        }
    }
    function launch(path, project, launcherId) {
        const launcher = Config.projectApps.find(item => item.id === launcherId)
        let action
        try { action = Launchers.prepare(launcher,path,project,project.category,StatusService.enabled) }
        catch (exception) { error = Translations.message(exception); PickerService.error = error; return }
        const client = (StatusService.enabled || !launcher.profileArguments?.length) && action.windowClass && action.windowTitlePrefix ? WindowService.allWindows.find(client =>
            client.class === action.windowClass && client.title.startsWith(action.windowTitlePrefix)) : null
        PickerService.close()
        Qt.callLater(() => {
            if (client) WindowService.focusWindow(client.address)
            else Quickshell.execDetached(action.command)
        })
    }
    function startScan(scanSources, action) {
        if (busy) return false
        let fileExtensions
        try { fileExtensions = Launchers.extensions(Config.projectApps) }
        catch (exception) { error = Translations.message(exception); PickerService.error = error; return false }
        error = ""; operation = action
        scanPending = true
        scan.input = JSON.stringify({sources:scanSources,sshConfig:Config.projectSshConfig,
            fileExtensions,fileExclusions:Config.projectFileExclusions,dotfilesGitDirectory:Config.projectDotfilesGitDirectory,
            dotfilesWorkTree:Config.projectDotfilesWorkTree}) + "\n"
        scan.running = true
        return true
    }
    function addSource(path, kind, category) {
        if (draft) { error = Translations.text("projects.errors.unsavedDraft"); return false }
        const home = Quickshell.env("HOME")
        path = path.trim().replace(/^~(?=\/|$)/,home).replace(/\/+$/,"") || "/"
        if (!path.startsWith("/") || !["root","folder"].includes(kind) || !["work","personal"].includes(category)) {
            error = Translations.text("projects.errors.pathAndCategoryRequired"); return false
        }
        return startScan([{path,kind,category}],ProjectService.Operation.Add)
    }
    function refresh(path = "") {
        if (draft) { error = Translations.text("projects.errors.unsavedRefresh"); return false }
        const selected = path ? sources.filter(source => source.path === path) : sources
        if (path && !selected.length) { error = Translations.text("projects.errors.sourceMissing"); return false }
        return startScan(selected,ProjectService.Operation.Refresh)
    }
    function editSource(path) {
        if (busy || draft) return
        const source = sources.find(source => source.path === path)
        if (!source) return
        draft = Object.assign({},source,{previousPath:path,originalKind:source.kind,projects:projects.filter(project => project.sourcePaths.includes(path))
            .map(project => Object.assign({},project,{workspaces:project.workspaces.map(workspace => Object.assign({},workspace))}))})
        managing = true; error = ""
    }
    function editProject(path) {
        if (busy || draft) return
        const project = projects.find(project => project.path === path)
        if (!project) return
        draft = {workspaceEdit:true,projects:[Object.assign({},project,{workspaces:project.workspaces.map(workspace => Object.assign({},workspace))})]}
        managing = true; error = ""
    }
    function setDraftPath(path) {
        if (draft?.previousPath) draft = Object.assign({},draft,{path})
    }
    function setDraftKind(kind) {
        if (draft?.previousPath && ["folder","root"].includes(kind)) draft = Object.assign({},draft,{kind})
    }
    function setDraftCategory(category) {
        if (draft?.previousPath && ["work","personal"].includes(category)) draft = Object.assign({},draft,{category})
    }
    function setIncluded(projectPath, path, included) {
        if (!draft) return
        draft = Object.assign({},draft,{projects:draft.projects.map(project => project.path !== projectPath ? project
            : Object.assign({},project,{workspaces:project.workspaces.map(workspace => workspace.path !== path ? workspace : Object.assign({},workspace,{included}))}))})
    }
    function cancelDraft() {
        if (busy && [ProjectService.Operation.Add,ProjectService.Operation.Edit].includes(operation)) operation = ProjectService.Operation.Discard
        draft = null; error = ""
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
        if (draft.previousPath) {
            const path = draft.path.trim().replace(/^~(?=\/|$)/,Quickshell.env("HOME")).replace(/\/+$/,"") || "/"
            if (!path.startsWith("/")) { error = Translations.text("projects.errors.absolutePathRequired"); return false }
            if (sources.some(source => source.path === path && source.path !== draft.previousPath)) { error = Translations.text("projects.errors.duplicateSource"); return false }
            if (path !== (draft.scannedPath || draft.previousPath) || draft.kind !== (draft.scannedKind || draft.originalKind)) {
                startScan([{path,kind:draft.kind,category:draft.category}],ProjectService.Operation.Edit)
                return false
            }
            draft = Object.assign({},draft,{path})
        }
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
        const adding = !draft.review && !draft.previousPath && !draft.workspaceEdit
        const savedPath = draft.path ?? ""
        const saved = draft.workspaceEdit ? ProjectRepository.saveWorkspaces(draft.projects)
            : draft.previousPath ? ProjectRepository.apply([draft],draft.path !== draft.previousPath,draft.path !== draft.previousPath ? draft.previousPath : "")
            : draft.review ? ProjectRepository.apply(results) : ProjectRepository.apply([draft],true)
        if (!saved) { error = ProjectRepository.error; return false }
        const refreshErrors = results?.filter(source => source.error).map(source => source.path + ": " + Translations.message(source.error)).join("\n") || ""
        cancelDraft(); error = refreshErrors; syncPicker()
        root.saved(savedPath)
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
            if (exitCode !== 0 || exitStatus !== 0) {
                root.error = errors.text.trim() || Translations.text("projects.errors.scan")
                root.syncPicker()
                root.scanPending = false
                return
            }
            try {
                const results = JSON.parse(output.text).sources
                switch (root.operation) {
                  case ProjectService.Operation.Add: {
                    const source = results[0]
                    if (source.error) throw new Error(source.error)
                    if (root.sources.some(existing => existing.path === source.path)) throw new Error(Translations.text("projects.errors.duplicateSource"))
                    if (!source.projects.some(project => project.workspaces.length > 0)) {
                        if (!ProjectRepository.apply([source],true)) throw new Error(ProjectRepository.error)
                        root.saved(source.path)
                        root.sourceAdded()
                    } else {
                        root.draft = Object.assign({},source,{projects:source.projects.map(project => Object.assign({},project,{workspaces:project.workspaces.map(workspace => Object.assign({},workspace,{included:true}))}))})
                    }
                    break
                  }
                  case ProjectService.Operation.Edit: {
                    if (!root.draft?.previousPath) break
                    const source = results[0]
                    if (source.error) throw new Error(source.error)
                    if (root.sources.some(existing => existing.path === source.path && existing.path !== root.draft.previousPath))
                        throw new Error(Translations.text("projects.errors.duplicateSource"))
                    const previousPath = root.draft.scannedPath || root.draft.previousPath
                    const previousProjects = root.draft.projects
                    const relative = (path,base) => path.slice(base === "/" ? 1 : base.length + 1)
                    let discovered = false
                    const updated = source.projects.map(project => {
                        const old = previousProjects.find(item => relative(item.path,previousPath) === relative(project.path,source.path))
                        return Object.assign({},project,{workspaces:project.workspaces.map(workspace => {
                            const choice = old?.workspaces.find(item => relative(item.path,previousPath) === relative(workspace.path,source.path))
                            if (!choice) discovered = true
                            return Object.assign({},workspace,{included:choice ? choice.included : true})
                        })})
                    })
                    root.draft = Object.assign({},root.draft,source,{scannedPath:source.path,scannedKind:source.kind,projects:updated})
                    root.sourcePathResolved(source.path)
                    if (!discovered) {
                        const scannedDraft = root.draft
                        Qt.callLater(() => { if (root.draft === scannedDraft) root.saveDraft() })
                    }
                    break
                  }
                  case ProjectService.Operation.Refresh: {
                    if (!root.reviewRefresh(results) && !ProjectRepository.apply(results)) throw new Error(ProjectRepository.error)
                    root.error = results.filter(source => source.error).map(source => source.path + ": " + Translations.message(source.error)).join("\n")
                    break
                  }
                  case ProjectService.Operation.None:
                  case ProjectService.Operation.Discard:
                    break
                }
            } catch (error) { root.error = Translations.message(error) || String(error) }
            root.syncPicker()
            root.scanPending = false
        }
        // qmllint enable signal-handler-parameters
    }
}
