pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Wayland
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/theme/ui" as UI

// Actual native launcher hosts, synthetic projects/input, isolated storage.
Scope {
    id: root
    property bool failed: false
    property var firstMapModes: []
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        id: origin
        visible: true
        implicitWidth: 420
        implicitHeight: 80
        UI.InputField { id: originInput; anchors.fill: parent; focus: true }
    }
    PickerWindow {
        id: publicWindow
        onVisibleChanged: if (visible && requestedVisible) root.firstMapModes.push(WlrLayershell.keyboardFocus)
    }
    PrivatePickerWindow {
        id: privateWindow
        onVisibleChanged: if (visible && requestedVisible) root.firstMapModes.push(WlrLayershell.keyboardFocus)
    }
    ExposeWindow { id: overview }
    function check(condition, message) { if (!condition) throw new Error(message) }
    function waitFor(predicate, message) {
        for (let attempt = 0; attempt < 100 && !predicate(); attempt++) events.wait(5)
        check(predicate(), message)
    }
    function run(kind, rapid = false) {
        const host = kind === "overview" ? overview : kind === "private" || kind === "secret" ? privateWindow : publicWindow
        const started = Date.now()
        if (kind === "projects") PickerService.projects()
        else {
            PickerService.begin(kind === "secret" ? PickerService.Mode.Secret : PickerService.Mode.Menu, "Synthetic opening")
            PickerService.privateRequest = kind === "private"
            PickerService.allowTyped = kind !== "secret"
            if (kind === "overview") {
                PickerService.mode = PickerService.Mode.Windows
                PickerService.layout = "expose"
                PickerService.exposeWorkspace = 0
            }
            PickerService.show()
        }
        check(host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.Exclusive,
            kind + ": explicit opening must request native activation immediately")
        if (kind !== "overview") {
            const field = events.findChild(host.panel, kind === "secret" ? "secretInput" : "pickerSearch")
            check(!!field && field.focus, kind + ": input must be prepared synchronously at the end of show")
        }
        waitFor(() => host.contentItem.Window.active, kind + ": native activation")
        const focusDelay = Date.now() - started
        if (UI.MotionPolicy.enabled && !rapid) {
            check(kind === "overview" ? overview.transitionProgress < 1 : host.transitioning,
                kind + ": keyboard focus must not wait for opening animation completion")
        }
        // Send the first keys as soon as this actual native window owns input.
        for (const key of [Qt.Key_H, Qt.Key_Y, Qt.Key_P, Qt.Key_R]) events.keyClick(key, Qt.NoModifier, 0)
        const field = events.findChild(kind === "overview" ? overview.previewItem : host.panel,
            kind === "secret" ? "secretInput" : kind === "overview" ? "exposeSearch" : "pickerSearch")
        check(!!field && field.text === "hypr", kind + ": first native input must contain every character")
        if (kind !== "secret") check(PickerService.query === "hypr", kind + ": query retains the complete first input")
        // Expose reserves Ctrl+A for its existing All-workspaces action.
        if (kind === "overview") events.keyClick(Qt.Key_Home, Qt.ShiftModifier, 0)
        else events.keyClick(Qt.Key_A, Qt.ControlModifier, 0)
        events.keyClick(Qt.Key_X, Qt.NoModifier, 0)
        check(field.text === "x", kind + ": ordinary selection and replacement remain available")
        events.wait(10)
        events.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
        check(!PickerService.visible && host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None,
            kind + ": Escape releases input immediately during closing")
        console.log("OPENING NATIVE", kind, rapid ? "rapid" : "initial/reopen", "focus-ms", focusDelay)
        if (!rapid) waitFor(() => !host.visible, kind + ": native close")
    }
    Timer {
        interval: 50
        running: true
        repeat: true
        onTriggered: {
            if (!DbService.ready || !origin.contentItem.Window.active) return
            stop()
            try {
                root.check(ProjectRepository.apply([{path: "/synthetic/projects", kind: "root", category: "personal", error: "",
                    projects: [{path: "/synthetic/projects/hypr", name: "hypr", workspaces: []}]}], true), "seed synthetic projects")
                for (const kind of ["menu", "projects", "private", "secret", "overview"]) {
                    root.run(kind)
                    root.run(kind)
                }
                root.run("menu", true)
                root.run("menu", true)
                root.waitFor(() => !publicWindow.visible, "final close")
                root.check(root.firstMapModes.length > 0 && root.firstMapModes.every(mode => mode === WlrKeyboardFocus.Exclusive),
                    "every initial public/private map requests exclusive focus before panel readiness")
                root.check(originInput.text === "", "no test keystroke reaches the previous application")
                console.log("PASS: native launcher first-map focus, immediate input, animated readiness, reopen, rapid open, Escape and editing")
            } catch (error) {
                root.failed = true
                console.error("OPENING NATIVE FAIL:", error)
            }
            PickerService.close()
            Qt.quit()
        }
    }
}
