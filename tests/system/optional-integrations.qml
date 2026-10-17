pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/config"
import "../../src/services"
import "../../src/modules/system/batteries"
import "../../src/modules/media"
import "../../src/modules/launcher" as Launcher

Scope {
    id: root
    property bool failed: false
    readonly property var settings: Config
    Test.TestCase { id: events; when: false }
    Test.TestResult { id: objects }
    FileView { id: runs; path: Quickshell.shellPath("runs"); preload: false; blockAllReads: true }
    function count(kind) { runs.reload(); return runs.text().split("\n").filter(line => line === kind).length }
    function check(ok, message) { if (!ok) { failed = true; console.error("OPTIONAL FAIL:",message) } }
    function waitUntil(predicate, message) {
        for (let i = 0; i < 120 && !predicate(); i++) events.wait(25)
        check(predicate(),message)
    }
    FloatingWindow {
        id: host
        visible: true
        implicitWidth: 550
        implicitHeight: 450
        Batteries { id: batteries; window: host }
        Launcher.BrowserLaunchFields { id: browserFields; visible: false; width: 500 }
        TwitchTooltip { id: twitch; y: 40; width: 500; adding: true }
    }
    Timer {
        interval: 100
        running: true
        onTriggered: {
            root.waitUntil(() => DbService.ready,"isolated database ready")
            const receiverTimer = objects.findChild(BatteryService,"batteryReceiverTimer") as Timer
            const browserTimer = objects.findChild(twitch,"twitchBrowserSuggestionsTimer") as Timer
            root.check(!BatteryService.enabled && !batteries.visible && !receiverTimer.running
                && !BatteryService.scanningReceivers && !BatteryService.batteries.length,"disabled battery module is idle")
            root.check(!BarModuleService.open("batteries"),"disabled battery opening action is unavailable")
            TwitchService.refreshBrowserSuggestions()
            events.wait(150)
            root.check(TwitchService.enabled && !TwitchService.browserIntegrationEnabled
                && !browserTimer.running && !TwitchService.browserSuggestions.length && root.count("browser") === 0,
                "default opt-out prevents session reader and refresh timer")
            root.settings.twitchQutebrowserEnabled = true
            root.waitUntil(() => root.count("browser") > 0,"opt-in starts session reader")
            root.check(browserTimer.running,"opt-in enables editor refresh timer")
            root.settings.twitchQutebrowserEnabled = false
            const disabledCount = root.count("browser")
            events.wait(500)
            root.check(!browserTimer.running && !TwitchService.browserSuggestions.length
                && root.count("browser") === disabledCount,"opt-out cancels reader and rejects late results")
            root.settings.twitchQutebrowserEnabled = true
            root.waitUntil(() => TwitchService.browserSuggestions.includes("fixturechannel"),"re-enabling loads suggestions")
            const suggestions = objects.findChild(twitch,"twitchBrowserSuggestions") as TwitchActionGrid
            const addAll = objects.findChild(twitch,"addAllBrowserTwitchUsers") as Item
            root.check(suggestions.visible && suggestions.parent === addAll.parent
                && Math.abs(suggestions.y - addAll.y) < 1
                && suggestions.x + suggestions.width < addAll.x,
                "suggestions occupy the former heading row beside Add all")
            root.check(TwitchService.addUser("fixturechannel"),"normal Twitch channel management remains available")
            root.check(!TwitchService.browserSuggestions.includes("fixturechannel"),"followed channels stay filtered")
            root.settings.twitchEnabled = false
            root.check(!TwitchService.browserIntegrationEnabled && !browserTimer.running
                && !TwitchService.browserSuggestions.length,"whole-module disable also stops browser integration")
            root.check(root.count("battery") === 0,"disabled batteries never started a receiver helper")
            root.settings.batteriesEnabled = true
            root.waitUntil(() => BatteryService.receiverBatteries.length && !BatteryService.scanningReceivers,"enabled battery scan publishes readings")
            root.check(batteries.visible && receiverTimer.running && BatteryRepository.receiverSnapshot().length === 1,
                "enabled module displays and saves receiver readings")
            TooltipService.openForKeyboard(100,batteries.tooltip,batteries,false,host.screen)
            root.check(TooltipService.visible && TooltipService.source === batteries,"battery tooltip opened in fixture")
            root.waitUntil(() => BatteryService.scanningReceivers,"next receiver scan starts")
            root.settings.batteriesEnabled = false
            root.waitUntil(() => !BatteryService.scanningReceivers,"disable stops in-flight receiver scan")
            const batteryCount = root.count("battery")
            events.wait(300)
            root.check(!batteries.visible && !TooltipService.visible && !receiverTimer.running
                && !BatteryService.batteries.length && !BatteryService.receiverError && root.count("battery") === batteryCount,
                "disable hides UI, closes tooltip and leaves scanning idle without errors")
            root.check(BatteryRepository.receiverSnapshot().length === 1 && BatteryService.receiverBatteries.length === 1,
                "disable retains durable and in-memory receiver cache")
            root.settings.batteriesEnabled = true
            root.check(batteries.visible && BatteryService.receiverBatteries.length === 1,"re-enable reuses cached readings")
            root.settings.batteriesEnabled = false
            root.settings.webappBrowsers = [{id:"custom",name:"Custom",command:["true"]},
                {id:"other",name:"Other",command:["true"]}]
            root.settings.webappDefaultBrowser = "custom"
            WebappService.newEntry()
            N8nService.newEntry()
            root.check(WebappService.draft.browser === "custom" && N8nService.draft.browser === "custom"
                && browserFields.browser === "custom","one browser default configures both new-entry services and fields without qutebrowser")
            root.settings.webappDefaultBrowser = "other"
            root.check(WebappService.draft.browser === "custom" && N8nService.draft.browser === "custom",
                "changing defaults preserves existing draft browser choices")
            WebappService.newEntry()
            N8nService.newEntry()
            root.check(WebappService.draft.browser === "other" && N8nService.draft.browser === "other",
                "new entries use the changed default")
            if (!root.failed) console.log("PASS: optional Twitch session suggestions and batteries preserve features/cache, stop timers/readers/scans and close disabled UI; browser defaults work without qutebrowser")
            Qt.quit()
        }
    }
}
