import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/modules/updates" as Updates
import "../../src/theme/ui" as UI
import "../../src/theme"
import "../../src/config"
import "../../src/services"

Scope {
    id: root
    property bool failed: false
    // Only the copied fixture makes these production settings mutable.
    property var settings: Config
    property var network: NetworkService
    function check(ok, message) {
        if (!ok) { failed = true; console.error("SERVICES FAIL: " + message) }
    }
    function waitUntil(predicate, message) {
        for (let attempt = 0; attempt < 80 && !predicate(); attempt++) events.wait(25)
        check(predicate(), message)
    }
    function runCount() {
        runs.reload()
        return runs.text().split("\n").filter(line => line.length > 0).length
    }
    FileView { id: runs; path: Quickshell.shellPath("runs"); preload: false; blockAllReads: true }
    Test.TestCase { id: events; when: false }
    Test.TestResult { id: objects }
    FloatingWindow {
        visible: true
        implicitWidth: 340
        implicitHeight: 180
        Updates.UpdatesTooltip { id: panel }
    }
    Timer {
        interval: 50
        running: true
        onTriggered: {
            root.waitUntil(() => !UpdatesService.checking && UpdatesService.lastChecked.getTime() > 0, "initial empty snapshot")
            const button = objects.findChild(panel, "updatesCheckNow") as UI.ActionButton
            const notes = objects.findChild(panel, "updatesNotes") as UI.ActionButton
            const install = objects.findChild(panel, "updatesInstall") as UI.ActionButton
            root.check(button.enabled && !notes.enabled && !install.enabled, "check now works with no updates")
            root.check(button.glyph === Theme.refreshIcon && notes.x < button.x && button.x + button.width <= install.x,
                "refresh icon sits between notes and install")
            root.settings.language = "en"
            events.wait(20)
            root.check(button.hint === "Check now" && notes.hint === "Open update notes", "English action hints")
            root.settings.language = "pt"
            events.wait(20)
            root.check(button.hint === "Verificar agora" && notes.hint === "Abrir notas de atualização", "Portuguese action hints")
            root.settings.language = "en"
            events.wait(20)

            UpdatesService.schedule()
            events.wait(100)
            events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton)
            events.wait(20)
            root.check(UpdatesService.checking && !button.enabled, "click starts a check immediately and disables its button")
            root.check(UpdatesService.count === 0, "current snapshot remains visible during a check")
            UpdatesService.checkNow()
            root.waitUntil(() => !UpdatesService.checking && UpdatesService.count === 1, "manual check publishes new snapshot")
            events.wait(750)
            root.check(root.runCount() === 2 && button.enabled, "pending timer cancelled and repeated request reused active check; runs=" + root.runCount())

            const snapshot = JSON.stringify(UpdatesService.updates)
            const lastChecked = UpdatesService.lastChecked.getTime()
            UpdatesService.schedule()
            root.waitUntil(() => UpdatesService.error.length > 0 && !UpdatesService.checking, "a new scheduled check can still run and fail")
            root.check(root.runCount() === 3 && JSON.stringify(UpdatesService.updates) === snapshot
                && UpdatesService.lastChecked.getTime() === lastChecked && button.enabled, "failed check preserves snapshot and restores button; runs=" + root.runCount())

            UpdatesService.schedule()
            events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton)
            root.waitUntil(() => !UpdatesService.checking && !UpdatesService.error && UpdatesService.count === 0, "manual check recovers to empty snapshot")
            events.wait(750)
            root.check(root.runCount() === 4 && button.enabled && !notes.enabled && !install.enabled,
                "empty success keeps check now enabled and cancels pending retry; runs=" + root.runCount())

            root.network.online = false
            events.mouseClick(button, button.width / 2, button.height / 2, Qt.LeftButton)
            root.waitUntil(() => !UpdatesService.checking && UpdatesService.count === 1, "manual check runs despite cached offline status")
            root.check(root.runCount() === 5, "one helper invocation per check")
            console.log(root.failed ? "SERVICES FAIL: manual update check" : "PASS: check-now button, translations, timer clearing, active-check reuse, retries, failures, empty snapshots and offline override")
            Qt.quit()
        }
    }
}
