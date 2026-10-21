pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../src/config"
import "../../src/services"
import "../../src/ui/bar"
import "../launcher"

WorkerScope {
    id: root
    readonly property var settings: Config
    readonly property var network: NetworkService
    readonly property string directory: Quickshell.env("QS_COLLECTION_FIXTURE")
    readonly property bool restart: Quickshell.env("QS_COLLECTION_PHASE") === "restart"
    readonly property var file: ({path:directory + "/document.txt", uri:"file://" + directory + "/document.txt",
        name:"document.txt", icon:"text-x-generic", isDirectory:false})
    property string savedPreferences: ""
    property string savedUpdates: ""
    property int disabledRuns: 0
    property real emptyWidth: 0
    function preferences() {
        return JSON.stringify(["files.pinned", "files.folders", "files.folderAliases", "files.defaultTab", "files.defaultFolder"]
            .map(key => PreferencesRepository.value(key, null)))
    }
    function module(name) { return modules.children.find(item => item.moduleName === name) }
    function count(kind = "") {
        runs.reload()
        return runs.text().split("\n").filter(line => line && (!kind || line === kind)).length
    }
    function disabledRequests() {
        UpdatesService.refresh(); UpdatesService.checkNow(); UpdatesService.schedule(); UpdatesService.writeMarkdown()
        UpdatesService.install(); UpdatesService.openMarkdown()
        UpdatesService.openPackage({repository:"core", architecture:"x86_64", name:"fixture"})
        root.network.online = true
        RecentFilesService.beginPanel(); RecentFilesService.refresh(); RecentFilesService.beginDrag()
        RecentFilesService.openFile(root.file)
        driver.check(!RecentFilesService.addFolder(directory + "/new") && !RecentFilesService.pinUrls([root.file.uri])
            && !RecentFilesService.togglePin(root.file) && !RecentFilesService.removeFolder(directory + "/folder")
            && !RecentFilesService.setDefaultTab("recent") && !RecentFilesService.setFolderAlias(directory + "/folder", "Changed"),
            "disabled file entry points cannot start work or alter preferences")
        PinnedFilesService.active = true
        PinnedFilesService.refresh()
        driver.check(!PinnedFilesService.pinUrls([root.file.uri]) && !PinnedFilesService.save([]), "disabled pin backend is guarded")
        driver.check(!BarModuleService.open("updates") && !BarModuleService.open("files"), "disabled bar shortcuts cannot open panels")
    }
    FileView { id: runs; path: root.directory + "/runs"; preload:false; blockAllReads:true }
    FileView { id: hold; path: root.directory + "/hold"; blockAllReads:true }
    FloatingWindow {
        id: host
        visible:true
        implicitWidth:1000; implicitHeight:40
        CenterModules { id:modules; window:host }
    }
    NativeFocusDriver {
        id: driver
        timeout:4000
        onFailed: message => { console.error("COLLECTION FAIL:", message); Qt.quit() }
        onCompleted: {
            console.log("PASS: optional Updates and Recent Files " + (root.restart ? "enabled restart preserves pins and preferences" : "disabled startup, guarded actions, hidden layout, cancellation, late results and re-enable"))
            Qt.quit()
        }
    }
    Component.onCompleted: {
        driver.waitFor("private storage", () => DbService.ready && PreferencesRepository.ready)
        if (!restart) {
            driver.add("seed retained preferences while disabled", () => {
                driver.check(PreferencesRepository.setValues({"files.pinned":[root.file], "files.folders":[directory + "/folder"],
                    "files.folderAliases":{[directory + "/folder"]:"Saved folder"}, "files.defaultTab":"recent", "files.defaultFolder":""}), "save fixtures")
                root.savedPreferences = preferences()
                driver.check(!UpdatesService.enabled && !RecentFilesService.enabled && !PinnedFilesService.enabled,
                    "both services start disabled")
                driver.check(!module("updates").visible && !module("files").visible, "both bar icons hidden")
                root.emptyWidth = modules.width
                disabledRequests()
            })
            driver.pause(120)
            driver.add("disabled startup is idle", () => {
                driver.check(count() === 0 && preferences() === root.savedPreferences, "disabled startup does not run helpers or change data")
                root.network.online = false
                root.settings.updatesEnabled = true
                root.settings.recentFilesEnabled = true
                RecentFilesService.beginPanel()
            })
        } else {
            driver.add("restart configuration enabled", () => {
                driver.check(UpdatesService.enabled && RecentFilesService.enabled, "enabled startup")
                driver.check(RecentFilesService.folders[0] === directory + "/folder"
                    && RecentFilesService.folderAliases[directory + "/folder"] === "Saved folder"
                    && PinnedFilesService.files.length === 1 && RecentFilesService.defaultTab === "recent", "preferences survive restart")
                RecentFilesService.beginPanel()
            })
        }
        driver.waitFor("enabled helpers publish data", () => UpdatesService.count === 1 && RecentFilesService.files.length === 1
            && !RecentFilesService.loading && !PinnedFilesService.checking && !PinnedFilesService.importing, () => {
            driver.check(UpdatesService.updates[0].name === "fixture" && RecentFilesService.files[0].uri === root.file.uri, "normal snapshots")
            driver.check(module("updates").visible && module("files").visible, "icons restored")
            if (!restart) driver.check(modules.width > root.emptyWidth, "disabled modules leave no reserved bar space")
        })
        if (!restart) {
            driver.add("start in-flight work", () => {
                root.savedPreferences = preferences()
                root.savedUpdates = JSON.stringify(UpdatesService.updates)
                hold.setText("hold")
                UpdatesService.checkNow(); UpdatesService.refresh()
                driver.check(RecentFilesService.addFolder(directory + "/new"), "start folder validation")
                driver.check(PinnedFilesService.pinUrls([root.file.uri]), "start pin import")
                PinnedFilesService.refresh()
            })
            driver.waitFor("helpers reached held requests", () => count("refresh") > 0 && RecentFilesService.addingFolder
                && PinnedFilesService.checking && PinnedFilesService.importing && UpdatesService.checking
                && ["refresh", "snapshot", "folder", "pins", "import"].every(kind => count("ready:" + kind) > 0), () => {
                UpdatesService.schedule()
                TooltipService.openForKeyboard(100,module("updates").tooltip,module("updates"),false,host.screen)
                root.settings.updatesEnabled = false
                driver.check(!TooltipService.visible, "disabling Updates closes its panel")
                TooltipService.openForKeyboard(100,module("files").tooltip,module("files"),false,host.screen)
                root.settings.recentFilesEnabled = false
                driver.check(!TooltipService.visible, "disabling Recent Files closes its panel")
                RecentFilesService.endPanel()
            })
            driver.waitFor("cancellation completes", () => !UpdatesService.checking && !RecentFilesService.loading
                && !PinnedFilesService.checking && !PinnedFilesService.importing && count("stopped:snapshot") > 0
                && count("stopped:folder") > 0 && count("stopped:pins") > 0 && count("stopped:import") > 0, () => {
                hold.setText("")
                driver.check(preferences() === root.savedPreferences && JSON.stringify(UpdatesService.updates) === root.savedUpdates,
                    "cancelled successful reports cannot remove pins, add folders or replace updates")
                driver.check(!UpdatesService.error && !RecentFilesService.error && !PinnedFilesService.error, "cancellation leaves no errors")
                root.disabledRuns = count()
                disabledRequests()
            })
            driver.pause(120)
            driver.add("disabled module stays idle", () => {
                driver.check(count() === root.disabledRuns && preferences() === root.savedPreferences, "disabled requests and timers stay idle")
                root.network.online = false
                root.settings.updatesEnabled = true
                root.settings.recentFilesEnabled = true
                RecentFilesService.beginPanel()
            })
            driver.waitFor("re-enable reloads saved data", () => UpdatesService.count === 1 && RecentFilesService.files.length === 1
                && !PinnedFilesService.checking && !RecentFilesService.loading, () => {
                driver.check(preferences() === root.savedPreferences && PinnedFilesService.files.length === 1, "re-enable retains preferences")
                RecentFilesService.endPanel()
            })
        }
        driver.add("close modules before fixture teardown", () => {
            TooltipService.dismiss()
            root.settings.updatesEnabled = false
            root.settings.recentFilesEnabled = false
        })
        driver.waitFor("final helpers stopped", () => !UpdatesService.checking && !RecentFilesService.loading
            && !PinnedFilesService.checking && !PinnedFilesService.importing)
        driver.running = true
    }
}
