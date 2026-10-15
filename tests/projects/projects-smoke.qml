pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs as Dialogs
import QtTest as Test
import Quickshell
import "../../src/services"
import "../../src/modules/launcher"

Scope {
    id: root
    readonly property string directory: Quickshell.env("PROJECT_TEST_DIR")
    readonly property string phase: Quickshell.env("PROJECT_TEST_PHASE")
    property int step: 0
    property int ticks: 0
    property bool failed: false
    Test.TestEvent { id: events }
    FloatingWindow {
        id: testWindow
        visible: true
        implicitWidth: 700
        implicitHeight: panel.implicitHeight
        ProjectPickerPanel { id: panel; width: parent.width; height: parent.height }
    }
    function find(name,item=panel) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) { const found=find(name,child); if (found) return found }
        return null
    }
    function check(value,message) {
        if (!value) { failed=true; console.error("PROJECT FAIL: " + message) }
    }
    function banana() { return ProjectRepository.projects.find(project => project.name === "banana") }
    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (++root.ticks > 400 || root.failed) { console.error("PROJECT FAIL: timeout step=" + root.step + " error=" + ProjectService.error); stop(); Qt.quit(); return }
            if (ProjectService.busy || !DbService.ready) return
            if (root.phase === "restart") {
                if (root.step === 0) {
                    root.check(ProjectRepository.projects.length === 3 && root.banana().workspaces.length === 2
                        && !root.banana().workspaces.find(workspace => workspace.name === "Tomato").included, "sources and choices persist without automatic discovery")
                    root.check(ProjectService.sources.length === 2, "source records persist")
                    PickerService.projects()
                    root.check(!ProjectService.managing && PickerService.currentIndex === 0, "opening always starts at picker first row")
                    ProjectService.setManaging(true)
                    root.find("refreshSource_" + root.directory + "/single folder").clicked()
                    root.step=10
                    return
                }
                if (root.step === 10) {
                    root.check(!ProjectService.draft && ProjectRepository.projects.length === 3 && root.banana().workspaces.length === 2,
                        "refreshing one source does not scan the root's newly added projects and workspaces")
                    root.check(root.find("refreshProjects").visible,"refresh all is visible in Manage")
                    root.find("refreshProjects").clicked()
                    root.step=1
                    return
                }
                if (root.step === 1 || root.step === 2) {
                    root.check(ProjectService.managing && ProjectService.draft?.review, "refresh asks about new workspaces in Manage")
                    root.check(ProjectRepository.projects.length === 3 && root.banana().workspaces.length === 2, "refresh snapshot awaits confirmation")
                    const review = ProjectService.draft.projects[0]
                    root.check(review.workspaces.length === 2 && review.workspaces.every(workspace=>workspace.included), "checklist shows only new choices, checked by default")
                    if (root.step === 1) {
                        root.find("cancelProjectDraft").clicked()
                        root.check(!ProjectService.draft && root.banana().workspaces.length === 2, "cancel refresh preserves previous list")
                        root.find("refreshSource_" + root.directory + "/repos").clicked()
                        root.step=2
                    } else {
                        const optional = review.workspaces.find(workspace=>workspace.name === "Optional")
                        root.find("projectWorkspace_" + optional.path).clicked()
                        root.find("saveProjectDraft").clicked()
                        root.check(ProjectRepository.projects.length === 4 && root.banana().workspaces.length === 4, "approved refresh saves discovered projects and workspaces")
                        root.check(root.banana().workspaces.find(workspace=>workspace.name === "New").included
                            && !root.banana().workspaces.find(workspace=>workspace.name === "Optional").included
                            && !root.banana().workspaces.find(workspace=>workspace.name === "Tomato").included, "approved choices and previous inclusions persist")
                        ProjectService.refresh()
                        root.step=3
                    }
                    return
                }
                root.check(!ProjectService.draft && !root.banana().workspaces.find(workspace=>workspace.name === "Optional").included, "refresh does not ask again about explicitly excluded workspace")
                if (!root.failed) console.log("PASS: projects restart")
                stop(); Qt.quit(); return
            }
            if (root.phase === "missing") {
                if (root.step === 0) { ProjectService.refresh(); root.step=1; return }
                root.check(ProjectRepository.projects.length === 4 && root.banana().workspaces.length === 4, "real missing-source scan preserves previous snapshot")
                root.check(ProjectService.sources.some(source=>source.error) && !!ProjectService.error, "failed source scan exposes an error")
                root.check(ProjectService.removeSource(root.directory + "/single folder"), "source can be removed independently")
                root.check(ProjectRepository.projects.length === 3 && ProjectService.sources.length === 1, "removal deletes listing and preserves other sources")
                if (!root.failed) console.log("PASS: projects missing")
                stop(); Qt.quit(); return
            }
            if (root.step === 0) {
                root.check(ProjectService.sources.length === 0 && ProjectRepository.projects.length === 0, "no legacy JSON migration")
                PickerService.projects()
                root.check(!ProjectService.managing && PickerService.items.length === 0, "empty native picker")
                panel.focusSearch()
                root.step=10
            } else if (root.step === 10) {
                root.check(events.keyClick(Qt.Key_M,Qt.ControlModifier,0), "management shortcut receives key")
                root.check(ProjectService.managing, "Ctrl+M opens management")
                root.check(root.find("projectTabs").currentIndex === 1, "Manage tab follows shortcut")
                root.check(events.keyClick(Qt.Key_M,Qt.ControlModifier,0), "management toggle receives key again")
                root.check(!ProjectService.managing, "Ctrl+M returns to picker")
                root.check(root.find("projectTabs").currentIndex === 0, "Projects tab follows shortcut")
                root.find("projectTabs").itemAt(1).clicked()
                root.check(ProjectService.managing, "Manage control opens management")
                root.check(root.find("projectAddForm").visible, "empty management shows the add form")
                root.find("projectSourceKind").clicked()
                root.check(root.find("projectSourceKind").label === "Repositories root", "folder button labels its current state")
                panel.folderPicker.options = Dialogs.FolderDialog.ReadOnly | Dialogs.FolderDialog.DontUseNativeDialog
                panel.folderPicker.currentFolder = "file://" + root.directory + "/single%20folder"
                root.find("browseProjectSource").clicked()
                root.check(panel.nativeDialogOpen, "browse button opens folder picker")
                panel.folderPicker.selectedFolder = "file://" + root.directory + "/single%20folder"
                panel.folderPicker.accept()
                root.check(!panel.nativeDialogOpen, "accepting folder closes picker")
                root.check(root.find("projectSourcePath").text === root.directory + "/single folder", "folder picker fills decoded path without adding a source: " + root.find("projectSourcePath").text)
                root.check(!ProjectService.busy && ProjectService.sources.length === 0, "folder selection waits for scan action")
                root.find("projectSourcePath").text=root.directory + "/repos"
                root.find("projectSourceCategory").clicked()
                root.check(root.find("projectSourceCategory").label === "Work", "category button switches to Work")
                root.find("projectSourceCategory").clicked()
                root.check(root.find("projectSourceCategory").label === "Personal", "category button switches back to Personal")
                root.find("addProjectSource").clicked()
                root.step=1
            } else if (root.step === 1) {
                if (!ProjectService.draft) return
                root.check(ProjectService.draft.projects.length === 2, "root includes each immediate child, including non-Git folders")
                const project=ProjectService.draft.projects.find(project=>project.name === "banana")
                root.check(project.workspaces.length === 2 && project.workspaces.every(workspace=>workspace.included), "recursive workspace scan excludes VS Code config; add checklist defaults checked")
                root.check(project.url === "https://github.com/example/banana", "SSH alias and git suffix normalized")
                ProjectService.setIncluded(project.path,project.workspaces.find(workspace=>workspace.name === "Tomato").path,false)
                root.find("saveProjectDraft").clicked()
                root.check(root.banana().workspaces.find(workspace=>workspace.name === "Tomato").included === false, "excluded workspace retained")
                testWindow.contentItem.Window.window.requestActivate()
                panel.focusSearch()
                root.step=11
                return
            } else if (root.step === 11) {
                root.check(!root.find("projectAddForm").visible && root.find("beginAddProjectSource").visible, "saved sources hide add form behind plus button")
                panel.focusSearch()
                root.find("projectManageSearch").text="banana"
                root.check(root.find("projectManageSearch").activeFocus, "management search has keyboard focus")
                root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0), "add shortcut receives key in management search")
                root.check(root.find("projectAddForm").visible && root.find("projectManageSearch").visible, "Ctrl+A opens the bottom add form while keeping search visible")
                root.find("projectSourcePath").text = root.directory + "/cancelled"
                root.find("projectSourcePath").forceActiveFocus()
                root.step=12
                return
            } else if (root.step === 12) {
                const project = root.banana()
                root.check(root.find("projectSourcePath").activeFocus, "open path input has keyboard focus")
                root.check(events.keyClick(Qt.Key_A,Qt.ControlModifier,0), "Ctrl+A reaches the open path input")
                root.check(root.find("projectSourcePath").selectedText === root.directory + "/cancelled", "Ctrl+A selects the path after the form opens")
                root.find("cancelAddProjectSource").clicked()
                root.check(!root.find("projectAddForm").visible && root.find("projectSourcePath").text === ""
                    && ProjectService.sources.length === 1, "cancel closes and clears add form without saving")
                root.find("projectManageSearch").clear()
                const sourceGroup = root.find("projectSource_" + root.directory + "/repos")
                root.check(!!root.find("managedProject_" + project.path,sourceGroup)
                    && !!root.find("managedProject_" + root.directory + "/repos/potato",sourceGroup), "root groups its subfolders under the added path")
                root.check(root.find("managedProjectName_" + project.path).text === "banana", "subfolder header displays only its name")
                root.find("projectManageSearch").text="banana"
                root.check(!!root.find("managedProject_" + project.path)
                    && !root.find("managedProject_" + root.directory + "/repos/potato"), "management search filters subfolders")
                root.find("projectManageSearch").clear()
                root.check(!!root.find("editProject_" + project.path) && !!root.find("editSource_" + root.directory + "/repos"), "project management provides source and workspace editing")
                root.find("projectTabs").itemAt(0).clicked()
                PickerService.currentIndex=0
                PickerService.accept(false,false)
                root.check(ProjectService.projectPath === project.path && PickerService.items[0].title === "Open in Code" && PickerService.items[1].title === "Banana", "folder is first; only included workspace offered")
                PickerService.currentIndex=1
                PickerService.accept(false,false)
                PickerService.projects()
                root.check(!ProjectService.managing && !ProjectService.projectPath && PickerService.currentIndex === 0, "reopening resets management and first level")
                PickerService.accept(false,false)
                root.check(PickerService.currentItem.title === "Banana", "workspace selection remembered without moving Open folder")
                ProjectService.back()
                ProjectService.setManaging(true)
                ProjectService.addSource(root.directory + "/single folder","folder","work")
                root.step=2
            } else if (root.step === 2) {
                if (!ProjectService.draft) return
                root.check(ProjectService.draft.category === "work", "single folder uses explicitly chosen category")
                ProjectService.saveDraft()
                root.check(ProjectService.sources.length === 2 && ProjectRepository.projects.length === 3, "single non-Git folder saved")
                const singleGroup = root.find("projectSource_" + root.directory + "/single folder")
                root.check(!!singleGroup && !!root.find("editSource_" + root.directory + "/single folder",singleGroup)
                    && !root.find("managedProject_" + root.directory + "/single folder"), "single folder has edit without a duplicate project row")
                root.find("projectManageSearch").text="single folder"
                root.check(!root.find("projectSource_" + root.directory + "/repos")
                    && !!root.find("projectSource_" + root.directory + "/single folder"), "management search filters added paths")
                root.find("projectManageSearch").clear()
                ProjectService.refresh()
                root.step=3
            } else if (root.step === 3) {
                root.check(!root.banana().workspaces.find(workspace=>workspace.name === "Tomato").included, "refresh preserves deselection")
                root.find("editSource_" + root.directory + "/single folder").clicked()
                root.check(root.find("projectManageSearch").visible && !!root.find("projectSource_" + root.directory + "/repos"), "bottom editor keeps source list and search visible")
                root.find("editProjectSourcePath").text = root.directory + "/repos"
                root.find("saveProjectDraft").clicked()
                root.check(!!ProjectService.error && ProjectService.sources.length === 2, "duplicate edit is rejected without changing sources")
                root.find("editProjectSourcePath").text = root.directory + "/missing folder"
                root.find("saveProjectDraft").clicked()
                root.step=30
                return
            } else if (root.step === 30) {
                root.check(!!ProjectService.error && ProjectService.sources.some(source => source.path === root.directory + "/single folder"), "failed replacement scan keeps original source")
                root.find("editProjectSourcePath").text = root.directory + "/renamed folder"
                root.find("saveProjectDraft").clicked()
                root.step=31
                return
            } else if (root.step === 31) {
                root.check(!ProjectService.draft && ProjectService.sources.some(source => source.path === root.directory + "/renamed folder")
                    && !ProjectService.sources.some(source => source.path === root.directory + "/single folder"), "path edit replaces source after successful scan")
                root.check(ProjectRepository.projects.find(project => project.path === root.directory + "/renamed folder").workspaces[0].included, "moved workspace retains inclusion by relative path")
                root.find("editSource_" + root.directory + "/renamed folder").clicked()
                root.find("editProjectSourcePath").text = root.directory + "/single folder"
                root.find("saveProjectDraft").clicked()
                root.step=32
                return
            } else if (root.step === 32) {
                root.check(!ProjectService.draft && ProjectService.sources.length === 2, "restoring path leaves one source record")
                root.find("editSource_" + root.directory + "/single folder").clicked()
                root.check(root.find("projectSourceKind").label === "Single folder", "edit reuses add form and exposes source kind")
                root.find("projectSourceKind").clicked()
                root.find("saveProjectDraft").clicked()
                root.step=34
                return
            } else if (root.step === 34) {
                root.check(!ProjectService.draft && ProjectService.sources.find(source => source.path === root.directory + "/single folder").kind === "root"
                    && ProjectRepository.projects.length === 2, "switching folder type rescans and saves source kind")
                root.find("editSource_" + root.directory + "/single folder").clicked()
                root.find("projectSourceKind").clicked()
                root.find("saveProjectDraft").clicked()
                root.step=35
                return
            } else if (root.step === 35) {
                root.check(!!ProjectService.draft && ProjectService.draft.projects[0].workspaces.length === 1, "switching back asks about rediscovered workspaces")
                root.find("saveProjectDraft").clicked()
                root.check(ProjectService.sources.find(source => source.path === root.directory + "/single folder").kind === "folder"
                    && ProjectRepository.projects.length === 3, "same form saves folder type and workspace choices")
                root.find("editSource_" + root.directory + "/repos").clicked()
                root.find("editSourceCategory").clicked()
                root.find("cancelProjectDraft").clicked()
                root.check(ProjectService.sources.find(source => source.kind === "root").category === "personal", "cancel discards edit category")
                root.find("editSource_" + root.directory + "/repos").clicked()
                root.find("editSourceCategory").clicked()
                root.find("saveProjectDraft").clicked()
                root.check(root.banana().category === "work", "source edit updates category")
                root.find("editSource_" + root.directory + "/repos").clicked()
                root.find("editSourceCategory").clicked()
                root.find("saveProjectDraft").clicked()
                root.find("editProject_" + root.banana().path).clicked()
                const workspace = ProjectService.draft.projects[0].workspaces.find(item => item.name === "Tomato")
                root.find("projectWorkspace_" + workspace.path).clicked()
                root.find("saveProjectDraft").clicked()
                root.check(root.banana().workspaces.find(item => item.name === "Tomato").included, "workspace edit restores excluded option")
                ProjectService.editProject(root.banana().path)
                ProjectService.setIncluded(root.banana().path,workspace.path,false)
                ProjectService.saveDraft()
                root.find("editSource_" + root.directory + "/single folder").clicked()
                root.find("editProjectSourcePath").text = root.directory + "/other folder"
                root.find("saveProjectDraft").clicked()
                root.step=33
                return
            } else if (root.step === 33) {
                root.check(!!ProjectService.draft && ProjectService.draft.projects[0].workspaces[0].included, "changed path asks about newly discovered workspace before replacing source")
                root.check(ProjectService.sources.some(source => source.path === root.directory + "/single folder"), "workspace review retains original source")
                root.find("cancelProjectDraft").clicked()
                root.check(!ProjectService.draft && !ProjectService.sources.some(source => source.path === root.directory + "/other folder"), "cancel path edit leaves original source unchanged")
                // Failed source scan should keep the current project/workspace snapshot.
                ProjectRepository.apply([{path:root.directory + "/repos",kind:"root",category:"personal",error:"Unavailable",projects:[]}])
                root.check(ProjectRepository.projects.length === 3 && root.banana().workspaces.length === 2, "failed scan keeps previous data")
                ProjectService.refresh()
                root.step=4
            } else if (root.step === 4) {
                root.check(ProjectService.sources.every(source=>!source.error), "successful manual refresh clears errors")
                PickerService.projects(true)
                root.check(PickerService.items.length === 1 && PickerService.items[0].result === "https://github.com/example/banana" && PickerService.multiple, "GitHub uses shared unique URLs")
                ProjectService.setManaging(true)
                PickerService.projects()
                root.check(!ProjectService.managing, "default always picker even after management")
                ProjectService.setManaging(true)
                root.find("beginAddProjectSource").clicked()
                if (root.find("projectSourceKind").label !== "Single folder") root.find("projectSourceKind").clicked()
                root.find("projectSourcePath").text = root.directory + "/no workspaces"
                root.find("addProjectSource").clicked()
                root.step=5
            } else if (root.step === 5) {
                root.check(!ProjectService.draft && ProjectService.sources.length === 3 && ProjectRepository.projects.length === 4, "folder without workspaces saves without a checklist")
                root.check(!root.find("projectAddForm").visible && root.find("projectSourcePath").text === "", "automatic save closes and clears the add form")
                ProjectService.removeSource(root.directory + "/no workspaces")
                ProjectService.addSource(root.directory + "/plain root","root","personal")
                root.step=6
            } else if (root.step === 6) {
                root.check(!ProjectService.draft && ProjectService.sources.length === 3 && ProjectRepository.projects.length === 4, "root with no workspaces saves its projects without a checklist")
                ProjectService.removeSource(root.directory + "/plain root")
                ProjectService.addSource(root.directory + "/empty root","root","work")
                root.step=7
            } else if (root.step === 7) {
                root.check(!ProjectService.draft && ProjectService.sources.length === 3 && ProjectRepository.projects.length === 3, "empty root also saves without a checklist")
                ProjectService.removeSource(root.directory + "/empty root")
                if (!root.failed) console.log("PASS: projects setup")
                stop(); Qt.quit()
            }
        }
    }
}
