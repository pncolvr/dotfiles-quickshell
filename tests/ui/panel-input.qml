pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../src/config"
import "../../src/ui/panels"
import "../../src/ui" as UI
import "../../src/services"
import "../../src/modules/system/timers"
import "../../src/modules/system/stats"
import "../../src/modules/system/totp"
import "../../src/modules/media"
import "../launcher" as Fixtures

// Real native hosts and controls, synthetic text, isolated storage, stationary cursor.
Scope {
    id: root
    property int currentCase: 0
    readonly property var host: currentCase === 2 ? privateWindow : publicWindow
    readonly property var panel: host.loadedContent
    readonly property string fieldName: ["countdownName", "statsProcessSearch", "totpSearchField",
        "twitchSearchField", "prefocusedInput", "multilineInput"][currentCase] ?? ""
    readonly property var field: driver.find(panel, fieldName)
    QtObject {
        id: origin
        readonly property bool totpModule: root.currentCase === 2
        readonly property bool ownsTooltipWindow: totpModule
    }
    Component { id: countdownPanel; TimersTooltip {} }
    Component { id: statsPanel; StatsTooltip {} }
    Component { id: totpPanel; TotpTooltip {} }
    Component {
        id: twitchPanel
        TwitchTooltip {
            users: ["alpha", "beta", "gamma"].map(login => ({
                login, online: true, game: "Synthetic", title: "Test stream", viewers: "1", avatar: ""
            }))
        }
    }
    Component {
        id: sharedPanel
        Column {
            width: 400
            UI.InputField { objectName: "prefocusedInput"; width: parent.width }
            UI.TextArea { objectName: "multilineInput"; width: parent.width; height: 100 }
        }
    }
    TooltipWindow { id: publicWindow }
    TotpWindow { id: privateWindow }
    Fixtures.NativeFocusDriver {
        id: driver
        timeout: 1200
        onFailed: message => { console.error("PANEL INPUT FAIL:", "case " + root.currentCase + ": " + message); TooltipService.dismiss(); Qt.quit() }
        onCompleted: { TooltipService.dismiss(); Qt.quit() }
    }
    function check(condition, message) {
        driver.check(condition, "case " + currentCase + ": " + message)
    }
    function click(control, x = control.width / 2, y = control.height / 2) { driver.click(control, x, y) }
    function open(pinned) {
        const components = [countdownPanel, statsPanel, totpPanel, twitchPanel, sharedPanel, sharedPanel]
        driver.add("open panel", () => {
            console.log("PANEL INPUT STAGE", currentCase, pinned, "open")
            TooltipService.show(600, components[currentCase], origin, false, Quickshell.screens[0])
            TooltipService.setTriggerHovered(origin, true)
        })
        driver.waitFor("native panel must open", () => !!root.panel && root.host.visible, () => {
            if (currentCase === 1) panel.currentIndex = 1
        })
        driver.waitFor("input must be visible and enabled", () => !!root.field?.visible && root.field.enabled)
        driver.pause(40)
        driver.waitFor("panel geometry must settle before clicking", () => !root.host.transitioning)
        driver.pause(40)
        driver.add("passive opening", () => {
            if (pinned) TooltipService.togglePin(600, components[currentCase], origin, false)
            check(TooltipService.pinned === pinned, "only explicit pinning changes the pin")
            check(host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None && !host.nativeWindow.active,
                "hover/opening must keep native keyboard input disabled")
        })
    }
    function typeAndEdit(pinned, index) {
        let initialHeight = 0
        let clickedCursor = 0
        let clickedSelection = ""
        if (index === 4) {
            driver.add("programmatic focus", () => field.forceActiveFocus(Qt.OtherFocusReason))
            driver.pause(40)
            driver.add("programmatic focus stays passive", () => check(field.activeFocus && host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None,
                "programmatic field focus must remain passive"))
        }
        driver.add("click input", () => click(field))
        driver.waitFor("clicked panel must receive native keyboard focus", () => host.nativeWindow.active)
        driver.pause(50)
        driver.add("type into activated field", () => {
            check(field.activeFocus && host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.OnDemand,
                "a consumed field click must activate its native window and keep the clicked field")
            initialHeight = panel.implicitHeight
            driver.key(Qt.Key_A); driver.key(Qt.Key_B); driver.key(Qt.Key_C)
            check(field.text === "abc", "typed keys must reach the clicked field (keep the desktop keyboard idle during this test)")
        })
        if (index === 3) {
            driver.waitFor("Twitch search must shrink the panel", () => panel.implicitHeight < initialHeight)
            driver.add("stationary pointer leaves shrinking panel", () => {
                TooltipService.setTriggerHovered(origin, false)
                TooltipService.setPanelHovered(true)
                TooltipService.setPanelHovered(false)
            })
            driver.pause(Config.tooltipHideDelay + 80)
            driver.add("focused search survives shrink", () => check(TooltipService.visible && field.activeFocus && host.nativeWindow.active
                && TooltipService.interactionHeld && !TooltipService.interactionBlocksReplacement,
                "a focused search must survive shrinking away from the pointer"))
        }
        driver.add("select and replace", () => {
            driver.key(Qt.Key_A, Qt.ControlModifier)
            check(field.selectedText === "abc", "select-all must work")
            driver.key(Qt.Key_X)
            check(field.text === "x", "typing replaces selected text")
        })
        driver.add("repeat click", () => {
            click(field, field.leftPadding + 1, field.topPadding + 1)
            clickedCursor = field.cursorPosition
            clickedSelection = field.selectedText
        })
        driver.pause(60)
        driver.add("caret and deletion", () => {
            check(TooltipService.visible && field.activeFocus && host.nativeWindow.active
                && host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.OnDemand,
                "repeated field interaction must preserve the existing native grab")
            check(field.cursorPosition === clickedCursor && field.selectedText === clickedSelection,
                "native activation must preserve the clicked caret and selection")
            driver.key(Qt.Key_Home); driver.key(Qt.Key_Y)
            check(field.text === "yx", "typing follows the clicked caret")
            driver.key(Qt.Key_Backspace)
            check(field.text === "x", "normal deletion must work; active=" + field.activeFocus
                + ", native=" + host.nativeWindow.active + ", cursor=" + field.cursorPosition
                + ", length=" + field.text.length + ", unchanged=" + (field.text === "yx"))
        })
        if (index === 0) {
            driver.add("timer Tab navigation", () => {
                driver.key(Qt.Key_A, Qt.ControlModifier); driver.key(Qt.Key_N); driver.key(Qt.Key_Tab)
                check(!field.activeFocus && host.nativeWindow.active, "Tab must reach the next timer input")
            })
            driver.add("create countdown", () => {
                click(driver.find(panel, "countdownStart"))
                check(TimersService.countdowns.length === 1 && TimersService.countdowns[0].label === "n",
                    "creating a countdown must use the typed name")
                TimersService.remove(TimersService.countdowns[0])
            })
        }
        driver.add("dismiss panel", () => {
            check(TooltipService.pinned === pinned, "editing must never auto-pin or unpin")
            TooltipService.dismiss()
        })
        driver.waitFor("dismissed panel must close", () => !host.visible)
        driver.pause(100)
        open(pinned)
        driver.add("passive reopen", () => {
            check(host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None,
                "reopening must not inherit the old mouse focus")
            TooltipService.dismiss()
        })
        driver.waitFor("reopened panel closes", () => !host.visible)
        driver.pause(100)
    }
    Component.onCompleted: {
        TotpService.maintenance = true
        driver.waitFor("services ready", () => TimersService.ready && TwitchService.usersReady)
        for (const pinned of [false, true]) {
            for (let index = 0; index < 6; index++) {
                driver.add("select panel " + index, () => { root.currentCase = index })
                open(pinned)
                typeAndEdit(pinned, index)
            }
        }
        driver.add("finished", () => console.log("PASS: native click-to-type in Countdowns, Stats, private TOTP, Twitch, prefocused and multiline fields; editing, caret, repeat clicks, Tab, countdown creation, shrinking-search retention, passive reopen and manual pins"))
        driver.running = true
    }
}
