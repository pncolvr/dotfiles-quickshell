pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../src/services"
WorkerScope {
    id: root
    readonly property string directory: Quickshell.env("PROJECT_LAUNCH_TEST_DIR")
    readonly property string projectPath: directory + "/Game $literal; folder"
    readonly property bool restarting: Quickshell.env("PROJECT_LAUNCH_PHASE") === "restart"
    property int step: 0
    property int ticks: 0
    property bool failed: false
    function check(value,message) { if (!value) { failed=true; console.error("LAUNCHER FAIL:",message) } }
    function choices() {
        PickerService.projects()
        ProjectService.accept([PickerService.items.find(row=>row.result===root.projectPath)])
        return PickerService.items
    }
    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (root.failed || ++root.ticks > 120) { console.error("LAUNCHER FAIL:",root.step,ProjectService.error); Qt.quit(); return }
            if (!DbService.ready || ProjectService.busy) return
            if (root.step === 0) {
                if (root.restarting) {
                    const rows = root.choices()
                    root.check(rows.length===4 && PickerService.currentItem.result.endsWith(".sampleproj"),"included files and last action persist across restart")
                    ProjectService.editProject(root.projectPath)
                    ProjectService.setIncluded(root.projectPath,root.projectPath+"/project.godot",false)
                    root.check(ProjectService.saveDraft(),"save exclusion")
                    root.check(!root.choices().some(row=>row.title==="Open in Godot"),"excluded Godot file disappears while other actions remain")
                    if (!root.failed) console.log("PASS: project launcher restart, remembered action and Godot exclusion")
                    Qt.quit(); return
                }
                ProjectService.addSource(root.projectPath,"folder","personal")
                root.step=1
            } else if (root.step === 1) {
                root.check(ProjectService.draft?.projects[0].workspaces.length===3,"scan discovers configured Code, Godot and custom files")
                root.check(ProjectService.saveDraft(),"save project-file choices")
                const rows=root.choices()
                root.check(JSON.stringify(rows.map(row=>row.title))===JSON.stringify([
                    "Open in Code", "Open in Custom editor", "Open in Godot", "Mixed"
                ]),"app actions sort alphabetically above named workspace choices")
                PreferencesRepository.setValue("launcher.selection.projects.workspaces:"+root.projectPath,root.projectPath+"/project.godot")
                root.choices()
                root.check(PickerService.currentItem.result.endsWith("project.godot"),"legacy path-only choices still restore the selected action")
                ProjectService.accept([PickerService.currentItem])
                root.check(!PickerService.visible,"Godot launch closes picker")
                root.step=2
            } else if (root.step === 2) {
                ProjectService.accept([root.choices()[0]])
                root.step=3
            } else if (root.step === 3) {
                ProjectService.accept([root.choices().find(row=>row.title==="Mixed")])
                root.step=4
            } else if (root.step === 4) {
                ProjectService.accept([root.choices().find(row=>row.title==="Open in Custom editor")])
                root.step=5
            } else if (root.step === 5) {
                ProjectService.addSource(root.directory+"/Standalone","folder","personal")
                root.step=6
            } else if (root.step === 6) {
                root.check(ProjectService.saveDraft(),"save Godot-only project")
                PickerService.projects()
                ProjectService.accept([PickerService.items.find(row=>row.result===root.directory+"/Standalone")])
                root.check(!PickerService.visible && !ProjectService.projectPath,"Godot-only project opens directly without default Code or a chooser")
                ProjectService.addSource(root.directory+"/Plain","folder","personal")
                root.step=7
            } else if (root.step === 7) {
                PickerService.projects()
                ProjectService.accept([PickerService.items.find(row=>row.result===root.directory+"/Plain")])
                root.check(!PickerService.visible && !ProjectService.projectPath,"plain folder opens directly in default app")
                root.step=8
            } else {
                if (!root.failed) console.log("PASS: mixed project launches Godot, folder, Code workspace and a configured custom editor")
                Qt.quit()
            }
        }
    }
}
