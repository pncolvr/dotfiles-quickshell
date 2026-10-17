pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../src/services"
import "../../src/modules/launcher"
import "../../src/ui" as UI

// Actual native launcher hosts, synthetic projects/input, isolated storage.
Scope {
    id: root
    property var firstMapModes: []
    property var testedHost: null
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
    function focusState() {
        const host = testedHost
        const handler = host ? driver.find(host.contentItem,"windowFocusHandler") : null
        return JSON.stringify({visible:PickerService.visible, hostVisible:host?.visible,
            active:host?.contentItem.Window.active, keyboardMode:host?.WlrLayershell.keyboardFocus,
            field:host?.contentItem.Window.window?.activeFocusItem?.objectName,
            ready:handler?.ready, requesting:handler?.requestingKeyboardFocus,
            settled:handler?.activationSettled, retaining:handler?.retainingNativeFocus})
    }
    function scenario(kind, rapid = false) {
        const host = kind === "overview" ? overview : kind === "private" || kind === "secret" ? privateWindow : publicWindow
        const fieldName = kind === "secret" ? "secretInput" : kind === "overview" ? "exposeSearch" : "pickerSearch"
        const field = () => driver.find(kind === "overview" ? overview.previewItem : host.panel, fieldName)
        const context = {started:0, delay:0}
        const name = kind + (rapid ? " rapid" : " initial/reopen")
        return [
            {name:name + " opening", run:() => {
                root.testedHost = host
                context.started = Date.now()
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
                driver.check(host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.Exclusive,
                    "explicit opening must request native activation immediately")
                if (kind !== "overview") driver.check(field()?.focus,
                    "input must be prepared synchronously at the end of show")
            }},
            {name:name + " native input", ready:() => host.contentItem.Window.active,
                run:() => {
                    context.delay = Date.now() - context.started
                    if (UI.MotionPolicy.enabled && !rapid) driver.check(
                        kind === "overview" ? overview.transitionProgress < 1 : host.transitioning,
                        "keyboard focus must not wait for opening animation completion")
                    for (const value of [Qt.Key_H, Qt.Key_Y, Qt.Key_P, Qt.Key_R]) driver.key(value)
                    driver.check(field()?.text === "hypr", "first native input must contain every character")
                    if (kind !== "secret") driver.check(PickerService.query === "hypr", "query retains complete first input")
                    driver.key(Qt.Key_A, Qt.ControlModifier)
                    driver.key(Qt.Key_X)
                    driver.check(field().text === "x", "ordinary selection and replacement remain available")
                }},
            {name:name + " closing", run:() => {
                driver.key(Qt.Key_Escape)
                driver.check(!PickerService.visible && host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None,
                    "Escape releases input immediately during closing")
                console.log("OPENING NATIVE",kind,rapid ? "rapid" : "initial/reopen","focus-ms",context.delay)
            }},
            ...(rapid ? [] : [{name:name + " native close", ready:() => !host.visible}])
        ]
    }
    NativeFocusDriver {
        id: driver
        onFailed: message => { console.error("OPENING NATIVE FAIL:",message,root.focusState()); PickerService.close(); Qt.quit() }
        onCompleted: { console.log("PASS: native launcher first-map focus, immediate input, animated readiness, reopen, rapid open, Escape and editing"); Qt.quit() }
    }
    Component.onCompleted: {
        let steps = [{name:"seed", ready:() => DbService.ready && origin.contentItem.Window.active, run:() => {
            driver.check(ProjectRepository.apply([{path:"/synthetic/projects",kind:"root",category:"personal",error:"",
                projects:[{path:"/synthetic/projects/hypr",name:"hypr",workspaces:[]}]}],true),"seed synthetic projects")
        }}]
        for (const kind of ["menu","projects","private","secret","overview"])
            steps = steps.concat(scenario(kind),scenario(kind))
        steps = steps.concat(scenario("menu",true),scenario("menu",true),[
            {name:"final close",ready:() => !publicWindow.visible, run:() => {
                driver.check(root.firstMapModes.length > 0 && root.firstMapModes.every(mode => mode === WlrKeyboardFocus.Exclusive),
                    "every initial public/private map requests exclusive focus before panel readiness")
                driver.check(originInput.text === "","no test keystroke reaches the previous application")
            }}
        ])
        driver.steps = steps
        driver.running = true
    }
}
