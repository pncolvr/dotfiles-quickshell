pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../src/services"
import "../../src/config"
import "../../src/theme"
import "../../src/modules/launcher"

Scope {
    id: root
    readonly property string folder: Config.wallpaperDirectory
    readonly property string image: folder + "/quote ' \" $(touch injected) #%.PNG"
    readonly property string second: folder + "/nested/second\nline.jpg"
    property var field: null
    property string retainedQuery: "quote"
    property int closures: 0
    Connections { target: PickerService; function onVisibleChanged() { if (!PickerService.visible) root.closures++ } }
    Test.TestCase { id: events; when: false }
    LauncherFocusHandler {
        id: dismissal
        host: listWindow
        autoFocus: false
        dismissOnOutside: false
    }
    FloatingWindow {
        id: listWindow
        visible: true
        implicitWidth: 1100
        implicitHeight: 700
        PickerPanel { id: panel; anchors.fill: parent; availableContentWidth: 1100; availableContentHeight: 700 }
    }
    QtObject {
        id: previewHost
        property var requestedScreen: Quickshell.screens[0]
        property bool requestedVisible: PickerService.visible
        property real contentHeight: 250
        property real layoutContentHeight: contentHeight
        property real shadowBottomPadding: 0
    }
    FloatingWindow {
        visible: previewSurface.presented
        // Match the native non-activating companion inside the offscreen fixture.
        onVisibleChanged: if (visible) Qt.callLater(() => listWindow.contentItem.Window.window.requestActivate())
        implicitWidth: previewHost.requestedScreen.width
        implicitHeight: previewHost.requestedScreen.height - Theme.barHeight
        PickerPreviewSurface { id: previewSurface; anchors.fill: parent; host: previewHost; picker: PickerService; previewPanel: panel }
    }
    FileView {
        id: control
        path: Quickshell.env("WALL_TEST_DIR") + "/control"
        preload: false; blockWrites: true; printErrors: false
    }
    FileView {
        id: calls
        path: Quickshell.env("WALL_TEST_DIR") + "/commands"
        preload: false; blockLoading: true; printErrors: false
    }
    function check(ok, message) { if (!ok) throw new Error(message) }
    function waitFor(predicate, message) {
        const deadline = Date.now() + 3000
        while (!predicate() && Date.now() < deadline) events.wait(10)
        check(predicate(), message)
    }
    function commandList() {
        calls.reload()
        return calls.text().trim().split("\n").filter(line => line).map(line => JSON.parse(line))
    }
    function state(options = {}) { control.setText(JSON.stringify(options)) }
    function step(key) {
        waitFor(() => PickerService.visible && PickerService.selectionKey === "wallpaper." + key
            && PickerService.items.length > 0, "expected native " + key + " step")
        check(PickerService.requestDirectory === "" && !!PickerService.menuCallback, "native choices have no bridge request")
        field = events.findChild(panel, "pickerSearch")
        waitFor(() => !!field && field.activeFocus, "shared search receives focus")
    }
    function images() {
        step("image")
        check(PickerService.previewImages && panel.panel.showThumbnails === false, "existing image picker has filename-only rows")
    }
    function restored() {
        images()
        check(PickerService.query === retainedQuery && field.text === retainedQuery && PickerService.currentItem.result === image,
            "browsing restores search, focused text and selected image independently of global history")
        const list = events.findChild(panel, "pickerList")
        events.wait(50)
        check(list.currentIndex === PickerService.currentIndex, "rendered list highlights the retained selected row")
        const row = list.currentItem
        check(row && row.y >= list.contentY - 1 && row.y + row.height <= list.contentY + list.height + 1,
            "retained selected row stays visible after rebuilding the picker")
    }
    function wallpaperAlert() { return AlertService.messages.find(message => message.id === "wallpaper") }
    function enter() { events.keyClick(Qt.Key_Return, Qt.NoModifier, 0) }
    function pressEscape() { events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0) }
    function cancelTarget() {
        const previousClosures = closures
        pressEscape()
        check(PickerService.visible && closures === previousClosures,
            "child cancellation retains the native picker instead of closing and reopening it")
        restored()
    }
    function chooseTarget() {
        const previousClosures = closures
        enter()
        if (Config.workModeEnabled) {
            step("mode")
            check(JSON.stringify(PickerService.items.map(row => row.result)) === '["personal","work"]', "separate mode choice")
            PickerService.select(1, false)
            enter()
        }
        step("monitor")
        check(JSON.stringify(PickerService.items.map(row => row.result)) === '["HDMI-A-1","DP-1","eDP-1"]', "focused monitor sorts first")
        PickerService.select(1, false)
        check(closures === previousClosures, "native steps retain one continuously open picker")
    }
    function replacement() { PickerService.promptMenu("Replacement", [{title: "Keep working"}], () => {}) }
    function checkReplacement() {
        check(PickerService.visible && PickerService.prompt === "Replacement" && WallpaperService.session === null,
            "late worker/cancel callback cannot overwrite another menu")
        PickerService.close()
    }
    function run() {
        state()
        if (Config.pickerRememberSelection) PreferencesRepository.setValue("launcher.selection.wallpaper.image", second)
        WallpaperService.open()
        images()
        check(PickerService.items.length === 33 && PickerService.items.some(row => row.result === second),
            "recursive image-only discovery preserves newline paths")
        check(PickerService.items.find(row => row.result === image).image.includes("%23%25.PNG"), "preview URL encodes reserved path characters")
        if (Config.pickerRememberSelection) check(PickerService.currentItem.result === second, "native menu restores saved image preference")
        retainedQuery = "."
        field.text = retainedQuery
        const selectedIndex = PickerService.filteredItems.findIndex(row => row.result === image)
        check(selectedIndex > 0, "regression selects a row beyond the first match")
        PickerService.select(selectedIndex, false)
        waitFor(() => {
            const preview = events.findChild(previewSurface, "clipboardLargeImage")
            return preview?.status === Image.Ready
        }, "shared preview loads literal/reserved-character image path")
        chooseTarget()
        enter()
        restored()
        waitFor(() => commandList().length === 1, "first wallpaper applied")
        check(commandList()[0][1] === image && commandList()[0][3] === "DP-1", "literal image and monitor passed exactly once")

        // Child Escape returns to the same image; image Escape ends the session.
        enter()
        step(Config.workModeEnabled ? "mode" : "monitor")
        cancelTarget()
        if (Config.workModeEnabled) {
            enter(); step("mode"); enter(); step("monitor"); cancelTarget()
        }
        check(commandList().length === 1, "child cancellation never applies")

        // Failure preserves browsing and the previously saved choice.
        state({applyFail: true})
        chooseTarget(); enter(); restored()
        waitFor(() => commandList().length === 2, "application failure is reported after one attempt")
        waitFor(() => wallpaperAlert()?.severity === "error" && wallpaperAlert().text.includes("Could not set wallpaper"),
            "native alert reports application failure")
        state({monitorFail: true})
        enter()
        if (Config.workModeEnabled) { step("mode"); enter() }
        restored()
        check(commandList().length === 2, "monitor failure does not apply")
        check(wallpaperAlert()?.severity === "error" && wallpaperAlert().text.includes("connected monitors"),
            "native alert reports monitor failure")
        state({monitorInvalid: true})
        enter()
        if (Config.workModeEnabled) { step("mode"); enter() }
        restored()
        state()
        pressEscape()
        check(!PickerService.visible && WallpaperService.session === null, "image Escape ends the browsing session")

        // Repeated opening and replacement during discovery cannot publish old rows.
        state({scanSlow: true})
        WallpaperService.open()
        const cancelled = WallpaperService.session
        replacement()
        waitFor(() => !cancelled.job?.running, "discovery process terminated on replacement")
        checkReplacement()
        WallpaperService.open()
        pressEscape()
        check(!PickerService.visible && WallpaperService.session === null, "Escape cancels a loading browser")
        state()
        retainedQuery = "quote"
        WallpaperService.open(folder + "/../linked-images")
        images()
        check(PickerService.items.some(row => row.result === image), "symlinked custom root resolves literal paths")
        field.text = "quote"
        enter()
        if (Config.workModeEnabled) step("mode")
        else step("monitor")
        replacement()
        events.wait(50)
        checkReplacement()

        // Outside dismissal and Vault replacement must not act like child Escape.
        for (const action of ["outside", "vault"]) {
            WallpaperService.open(); images(); field.text = "quote"; enter()
            step(Config.workModeEnabled ? "mode" : "monitor")
            if (action === "outside") dismissal.dismissRequested()
            else {
                // Suppress the external Vault worker; exercise the real opening path.
                RbwService.busy = true
                RbwService.open()
                check(RbwService.visible, "Vault opens when replacing Wallpaper")
            }
            events.wait(50)
            check(!PickerService.visible && WallpaperService.session === null,
                action + " fully dismisses Wallpaper without returning to images")
            if (action === "vault") { RbwService.close(); RbwService.busy = false }
        }

        // A cancelled async monitor read must not reopen any menu or report failure.
        AlertService.dismiss("wallpaper")
        state({monitorSlow: true})
        WallpaperService.open(); images(); field.text = "quote"; enter()
        if (Config.workModeEnabled) { step("mode"); enter() }
        waitFor(() => PickerService.selectionKey === "wallpaper.monitor", "pending monitor read")
        cancelTarget()
        events.wait(300)
        restored()
        check(!wallpaperAlert(), "cancelling discovery does not report a spurious failure")
        pressEscape()
        state()

        // An already accepted application can finish, but cannot resurrect browsing.
        WallpaperService.open(); images(); field.text = "quote"; chooseTarget()
        state({applySlow: true})
        enter()
        replacement()
        waitFor(() => commandList().length === 3, "accepted application completes after replacement")
        events.wait(100)
        checkReplacement()
        state()

        WallpaperService.open(folder + "/empty")
        waitFor(() => !PickerService.visible, "empty folder reports error and closes")
        check(WallpaperService.session === null, "empty discovery releases session")
        WallpaperService.open(folder + "/missing")
        waitFor(() => !PickerService.visible, "missing folder reports error and closes")
        check(WallpaperService.session === null, "missing discovery releases session")

        // Native restore receives Config directly; no shell -> picker Config request.
        WallpaperService.restore(Config.workModeEnabled ? "work" : "personal")
        waitFor(() => commandList().some(args => args[0] === "query"), "native restore waits for daemon")
        waitFor(() => commandList().filter(args => args[0] === "img").length === 4, "native restore applies saved slot")
        console.log("PASS: native Wallpaper discovery, shared previews/focus, mode/monitor choices, retained search/selection, cancellation/replacement, failures, custom roots and restore; work mode=" + Config.workModeEnabled + ", history=" + Config.pickerRememberSelection)
    }
    Timer {
        interval: 25; running: true; repeat: true
        onTriggered: {
            if (!DbService.ready) return
            stop()
            try { root.run() } catch (error) { console.error("WALLPAPER FAIL:", error) }
            PickerService.close()
            Qt.quit()
        }
    }
}
