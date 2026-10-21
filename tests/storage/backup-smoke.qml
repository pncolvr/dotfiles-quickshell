pragma ComponentBehavior: Bound

import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/ui" as UI

WorkerScope {
    id: root
    property int step: 0
    property int ticks: 0
    property bool restored: false
    property string generatedPassword: ""
    property bool generatedTwice: false
    property bool warningsCaptureRequested: false
    property bool warningsCaptured: false
    property var backupPhases: []
    readonly property string archive: Quickshell.env("BACKUP_UI_DIRECTORY") + "/ui-backup.7z"
    readonly property string locations: Quickshell.env("BACKUP_UI_DIRECTORY") + "/locations"
    Test.TestResult { id: objects }
    Test.TestEvent { id: events }
    Process { id: fixPaths; command: ["bash",Quickshell.env("BACKUP_UI_DIRECTORY") + "/fix-paths.sh"] }
    Process { id: removeToken; command: ["rm", Quickshell.env("BACKUP_UI_DIRECTORY") + "/keyring/11111111-1111-1111-1111-111111111111.json"] }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: panel.implicitWidth
        implicitHeight: Math.max(root.step >= 9 ? 600 : 240, panel.implicitHeight)
        PickerPanel { id: panel; anchors.fill: parent }
    }
    Connections { target: BackupService; function onRestored() { root.restored = true } }
    Connections {
        target: BackupService
        function onPhaseChanged() { if (BackupService.busy) root.backupPhases = root.backupPhases.concat([BackupService.phase]) }
    }
    function field() { return objects.findChild(panel.panel, "secretInput") as UI.SecretField }
    function button(name) { return objects.findChild(panel.panel, name) as UI.ActionButton }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) { const result = find(child,name); if (result) return result }
        return null
    }
    function warning(name) { return find(panel,name) }
    function check(ok, message) {
        if (ok) return true
        console.error("BACKUP FAIL:", message, "step", step)
        ticker.stop()
        Qt.quit()
        return false
    }
    Timer {
        id: ticker
        interval: 80
        repeat: true
        running: true
        onTriggered: {
            if (!root.check(++root.ticks < 500, "timed out")) return
            switch (root.step) {
            case 0:
                if (!DbService.ready) return
                if (!root.check(PreferencesRepository.setValue("backup.fixture", "before"), "seed preference")) return
                if (!root.check(DbService.write(tx => {
                    tx.executeSql("INSERT INTO project_sources(path,kind,category) VALUES (?,'root','personal')",[root.locations + "/source"])
                    for (const name of ["project-present","project-missing"]) {
                        tx.executeSql("INSERT INTO projects(source_path,path,name) VALUES (?,?,?)",[root.locations + "/source",root.locations + "/" + name,name])
                    }
                    tx.executeSql("INSERT INTO project_workspaces(project_path,path,name,included) VALUES (?,?,?,1)",
                        [root.locations + "/project-present",root.locations + "/project-present/test.code-workspace","Workspace"])
                    for (const name of ["directory-present","directory-missing"]) {
                        tx.executeSql("INSERT INTO directories(path,name,category) VALUES (?,?,'personal')",[root.locations + "/" + name,name])
                    }
                    tx.executeSql("INSERT INTO directories(path,name,category) VALUES ('smb://server/share','Remote','personal')")
                }), "seed saved path references")) return
                if (!root.check(BackupService.open("export", root.archive), "open create")) return
                root.step++
                break
            case 1:
                if (!root.field()) return
                if (!root.check(PickerService.privateWindow && root.field().echoMode === TextInput.Password,
                    "existing private secret picker and masked field")) return
                if (!root.check(!BackupService.completed, "opening a prompt is not reported as completed")) return
                if (!root.check(!objects.findChild(panel.panel,"submitBackup") && !objects.findChild(panel.panel,"cancelBackup"),
                    "prompt uses Enter/Escape without submit/cancel buttons")) return
                root.field().text = "discarded"
                root.button("copyBackupPassword").forceActiveFocus()
                events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
                root.step++
                break
            case 2:
                if (!root.check(!BackupService.busy && !BackupService.visible && !ClipboardService.maintenance,
                    "Escape on an action cancels without maintenance")) return
                if (!root.check(BackupService.open("export", root.archive), "reopen after cancel")) return
                root.step++
                break
            case 3:
                if (!root.field()) return
                if (!root.check(root.field().text.length === 0 && !root.field().revealed, "draft cleared")) return
                root.button("generateBackupPassword").clicked()
                root.step++
                break
            case 4:
                if (BackupService.generating || root.field().text.length === 0) return
                if (!root.generatedTwice) {
                    root.generatedPassword = root.field().text
                    root.generatedTwice = true
                    root.button("generateBackupPassword").clicked()
                    return
                }
                if (!root.check(root.field().text !== root.generatedPassword, "generator can be reused")) return
                root.generatedPassword = root.field().text
                if (!root.check(root.generatedPassword.length === 32, "secure generator length")) return
                root.button("copyBackupPassword").clicked()
                if (Quickshell.env("BACKUP_TEST_SCREENSHOT")) {
                    panel.grabToImage(result => result.saveToFile(Quickshell.env("BACKUP_TEST_SCREENSHOT")))
                }
                root.step++
                break
            case 5:
                root.field().forceActiveFocus()
                events.keyClick(Qt.Key_Return, Qt.NoModifier, 0)
                root.step++
                break
            case 6:
                if (BackupService.busy) return
                if (!root.check(!BackupService.error && BackupService.phase === "Backup created", "create completes")) return
                if (!root.check(!ClipboardService.maintenance && !DbService.maintenance && !TotpService.maintenance,
                    "maintenance released after export")) return
                if (!root.check(AlertService.messages.some(message => message.id === "backup" && message.severity === "success"),
                    "shared alert reports completion")) return
                if (!root.check(root.backupPhases.includes("Backup: encrypting archive"), "helper streams progress stages")) return
                if (!root.check(BackupService.outputPath === root.archive && AlertService.messages.some(message =>
                    message.id === "backup" && message.text === "Backup created: " + root.archive && message.expiresAt > Date.now() + 10000),
                    "completion includes the output path and stays visible")) return
                if (!root.check(ClipboardRepository.count() === 0, "copied password excluded from clipboard history")) return
                PreferencesRepository.setValue("backup.fixture", "after")
                removeToken.running = true
                if (!root.check(BackupService.open("import", root.archive), "open restore")) return
                root.step++
                break
            case 7:
                if (removeToken.running) return
                if (!root.field()) return
                if (!root.check(!root.button("generateBackupPassword").visible, "restore asks for existing password")) return
                root.field().text = root.generatedPassword
                root.field().forceActiveFocus()
                events.keyClick(Qt.Key_Enter, Qt.NoModifier, 0)
                root.step++
                break
            case 8:
                if (!root.restored) {
                    root.check(!BackupService.error, "restore backend error")
                    return
                }
                if (!root.check(DbService.maintenance && ClipboardService.maintenance, "writes stay suspended until reload")) return
                if (!root.check(DbService.read("SELECT value_json FROM preferences WHERE key='backup.fixture'")[0].value_json === '"before"',
                    "restore updated the live attached database")) return
                if (!root.check(BackupService.recovery.length > 0, "recovery path reported")) return
                if (!root.check(BackupService.lastRestore?.warningCount === 5, "restore warning summary")) return
                // Production reloads here. Release and reload repositories in
                // the fixture so it can inspect Manage rows in the same run.
                BackupService.release()
                PreferencesRepository.reload(); DirectoryRepository.reload(); ProjectRepository.reload()
                PickerService.directories(); DirectoryService.setManaging(true)
                root.step++
                break
            case 9:
                if (DirectoryService.checkingPaths || !DirectoryService.pathStates[root.locations + "/directory-missing"]) return
                panel.panel.managementView.select(root.locations + "/directory-missing")
                if (!root.check(root.warning("directoryPathWarning_" + root.locations + "/directory-missing")?.text === "Folder missing or unavailable",
                    "directory Manage warning: " + JSON.stringify(DirectoryService.pathStates[root.locations + "/directory-missing"])
                        + " / " + root.warning("directoryPathWarning_" + root.locations + "/directory-missing")?.text)) return
                panel.panel.managementView.select("smb://server/share")
                if (!root.check(root.warning("directoryPathWarning_smb://server/share")?.text === "Location not checked", "remote location unchecked")) return
                panel.panel.managementView.select(root.locations + "/directory-missing")
                if (Quickshell.env("BACKUP_WARNINGS_SCREENSHOT") && !root.warningsCaptured) {
                    if (!root.warningsCaptureRequested) {
                        root.warningsCaptureRequested = true
                        panel.grabToImage(result => { result.saveToFile(Quickshell.env("BACKUP_WARNINGS_SCREENSHOT")); root.warningsCaptured = true })
                    }
                    return
                }
                PickerService.projects(); ProjectService.setManaging(true)
                root.step++
                break
            case 10:
                if (ProjectService.checkingPaths || !ProjectService.pathStates[root.locations + "/project-missing"]) return
                panel.panel.managementView.select(root.locations + "/source")
                if (!root.check(root.warning("sourcePathWarning_" + root.locations + "/source")?.text === "Folder missing or unavailable", "source Manage warning: " + JSON.stringify({sources:ProjectService.sources,selected:panel.panel.managementView.selectedId,state:ProjectService.pathStates[root.locations + "/source"],warning:root.warning("sourcePathWarning_" + root.locations + "/source")?.text}))) return
                if (!root.check(root.warning("projectPathWarning_" + root.locations + "/project-missing")?.text === "Folder missing or unavailable", "project Manage warning")) return
                if (!root.check(root.warning("projectPathWarning_" + root.locations + "/project-present")?.text === "1 project file missing or unavailable", "workspace summary")) return
                ProjectService.editProject(root.locations + "/project-present")
                root.step++
                break
            case 11:
                if (!root.warning("workspacePathWarning_" + root.locations + "/project-present/test.code-workspace")) return
                if (!root.check(root.warning("workspacePathWarning_" + root.locations + "/project-present/test.code-workspace").text === "Workspace file missing or unavailable",
                    "workspace editor warning")) return
                ProjectService.cancelDraft()
                fixPaths.running = true
                root.step++
                break
            case 12:
                if (fixPaths.running) return
                ProjectService.checkPaths(); DirectoryService.checkPaths()
                root.step++
                break
            case 13:
                if (ProjectService.checkingPaths || DirectoryService.checkingPaths) return
                if (!root.check(ProjectService.pathWarning(root.locations + "/source") === ""
                    && ProjectService.pathWarning(root.locations + "/project-present",ProjectService.projects.find(project => project.path.endsWith("project-present")).workspaces) === ""
                    && DirectoryService.pathStates[root.locations + "/directory-missing"]?.status === "available", "warnings clear when paths return")) return
                if (!root.check(DirectoryService.directories.length === 3 && ProjectService.projects.length === 2, "unavailable records preserved")) return
                BackupService.open("export",Quickshell.env("BACKUP_UI_DIRECTORY") + "/does-not-exist/failed.7z")
                root.step++
                break
            case 14:
                if (!root.field()) return
                root.field().text = "Public failure fixture"
                root.field().forceActiveFocus()
                events.keyClick(Qt.Key_Return,Qt.NoModifier,0)
                root.step++
                break
            case 15:
                if (BackupService.busy) return
                if (!root.check(BackupService.error.startsWith("Backup folder does not exist:") &&
                    AlertService.messages.some(message => message.id === "backup" && message.severity === "error" &&
                        message.expiresAt > Date.now() + 55000 && message.expiresAt <= Date.now() + 60000),
                    "destination failure shows a useful error for one minute")) return
                console.log("PASS: backup private prompt, generation, copy, Enter/Escape, progress, maintenance and live database restore")
                console.log("PASS: Manage warnings for directories, sources, projects and workspaces; rechecks clear recovered paths")
                ticker.stop()
                Qt.quit()
                break
            }
        }
    }
}
