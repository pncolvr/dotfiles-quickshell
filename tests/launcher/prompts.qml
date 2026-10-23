pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../../src/services"
import "../../src/config"
import "../../src/i18n"
import "../../src/modules/launcher"

WorkerScope {
    id: root
    property var testConfig: Config
    property var defaults: null
    FloatingWindow {
        visible: true
        implicitWidth: 900; implicitHeight: 650
        PickerPanel { id: panel; anchors.fill: parent }
    }
    NativeFocusDriver {
        id: driver
        timeout: 2500
        onFailed: message => { console.error("PROMPTS FAIL:", message); Qt.quit() }
        onCompleted: { console.log("PASS: configurable picker placeholders preserve defaults, menu stages and live overrides without duplicate titles"); Qt.quit() }
    }
    function search(name = "pickerSearch") { return driver.find(panel, name) }
    function configure(values) { testConfig.pickerPrompts = Object.assign({}, defaults, values) }
    function menu(title, options = {}) { PickerService.promptMenu(title, [{title: "First"}], () => {}, "list", options) }
    Component.onCompleted: {
        defaults = Object.assign({}, Config.pickerPrompts)
        driver.waitFor("catalog and database", () => Translations.availableLanguages.includes("en") && DbService.ready)
        driver.add("generic menu", () => menu("Destination <literal>"))
        driver.waitFor("menu placeholder", () => search()?.placeholderText === "Destination <literal>", () => {
            const header = search().parent
            driver.check(!header.children.some(child => child.text === PickerService.prompt), "no duplicate prompt text row")
        })
        driver.add("next stage", () => menu("Framerate"))
        driver.waitFor("stage placeholder", () => search()?.placeholderText === "Framerate")
        driver.add("generic override", () => configure({menu: "Custom menu"}))
        driver.waitFor("live menu override", () => search()?.placeholderText === "Custom menu")
        driver.add("empty override", () => configure({menu: ""}))
        driver.waitFor("intentional empty placeholder", () => search()?.placeholderText === "")
        driver.add("empty title fallback", () => { configure({}); menu("") })
        driver.waitFor("Search fallback", () => search()?.placeholderText === "Search")
        driver.add("stage-specific setting", () => { configure({recordingCapture: "Pick capture"}); menu("Capture", {promptKey: "recordingCapture"}) })
        driver.waitFor("stage-specific placeholder", () => search()?.placeholderText === "Pick capture")
        driver.add("prompt key reset", () => menu("New caller"))
        driver.waitFor("no stale stage key", () => search()?.placeholderText === "New caller")
        driver.add("typed input", () => PickerService.promptMenu("Text to encode", [], () => {}, "list", {allowTyped:true, promptKey:"qr"}))
        driver.waitFor("typed placeholder", () => search()?.placeholderText === "Text to encode")
        driver.add("apps", () => PickerService.begin(PickerService.Mode.Apps, "Applications"))
        driver.waitFor("apps keep default", () => search()?.placeholderText === "Search applications")
        driver.add("apps override", () => configure({applications: "Find applications"}))
        driver.waitFor("apps configurable", () => search()?.placeholderText === "Find applications")
        driver.add("windows", () => PickerService.begin(PickerService.Mode.Windows, "Windows"))
        driver.waitFor("windows default", () => search()?.placeholderText === "Search windows")
        driver.add("bookmarks", () => menu("", {promptKey:"bookmarks"}))
        driver.waitFor("bookmarks default without routing panel", () => search()?.placeholderText === "Search bookmarks")
        driver.add("history", () => menu("", {promptKey:"history"}))
        driver.waitFor("history default", () => search()?.placeholderText === "Search browsing history")
        driver.add("screenshot", () => menu("", {promptKey:"screenshot"}))
        driver.waitFor("screenshot default", () => search()?.placeholderText === "Choose a screenshot method")
        driver.add("clipboard", () => PickerService.begin(PickerService.Mode.Clipboard, "Clipboard"))
        driver.waitFor("clipboard default", () => search()?.placeholderText === "Search clipboard")
        driver.add("clipboard override", () => configure({clipboard: "Find copied text"}))
        driver.waitFor("clipboard configurable", () => search()?.placeholderText === "Find copied text")
        driver.add("remotes", () => PickerService.begin(PickerService.Mode.Remotes, "Remotes"))
        driver.waitFor("collection default", () => search()?.placeholderText === "Search remotes")
        driver.add("collection override", () => configure({remotes: "Look in %1", remotesManage: "Manage %1"}))
        driver.waitFor("collection formatting", () => search()?.placeholderText === "Look in remotes")
        driver.add("manage", () => RemoteService.setManaging(true))
        driver.waitFor("manage configurable", () => search("collectionManageSearch")?.placeholderText === "Manage remotes")
        driver.add("translation key", () => configure({remotesManage: "common.actions.search"}))
        driver.waitFor("translation resolved", () => search("collectionManageSearch")?.placeholderText === "Search")
        driver.add("missing key fallback", () => { testConfig.pickerPrompts = ({}); RemoteService.setManaging(false) })
        driver.waitFor("partial dictionary default", () => search()?.placeholderText === "Search remotes")
        driver.add("independent menu", () => { CaptureMenuService.promptMenu("Audio output", [{title:"Output"}], () => {}); panel.picker = CaptureMenuService })
        driver.waitFor("capture menu title", () => search()?.placeholderText === "Audio output")
        driver.add("cleanup", () => { CaptureMenuService.close(); PickerService.close(); testConfig.pickerPrompts = defaults })
        driver.running = true
    }
}
