pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import Quickshell.Wayland
import "../../src/config"
import "../../src/bar"
import "../../src/ui" as UI
import "../../src/services"
import "../../src/modules/system/timers"
import "../../src/modules/system/stats"
import "../../src/modules/system/totp"
import "../../src/modules/media"

// Real native hosts and controls, synthetic text, isolated storage, stationary cursor.
Scope {
    id: root
    property int currentCase: 0
    readonly property var host: currentCase === 2 ? privateWindow : publicWindow
    readonly property var panel: host.loadedContent
    readonly property string fieldName: ["countdownName", "statsProcessSearch", "totpSearchField",
        "twitchSearchField", "prefocusedInput", "multilineInput"][currentCase] ?? ""
    readonly property var field: events.findChild(panel, fieldName)
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
    Test.TestCase { id: events; when: false }
    function check(condition, message) {
        if (!condition) throw new Error("case " + currentCase + ": " + message)
    }
    function waitFor(predicate, message) {
        for (let attempt = 0; attempt < 60 && !predicate(); attempt++) events.wait(20)
        check(predicate(), message)
    }
    function click(control, x = control.width / 2, y = control.height / 2) {
        events.mouseClick(control, x, y, Qt.LeftButton, Qt.NoModifier, 0)
    }
    function key(value, modifiers = Qt.NoModifier) { events.keyClick(value, modifiers, 0) }
    function open(pinned) {
        console.log("PANEL INPUT STAGE", currentCase, pinned, "open")
        const components = [countdownPanel, statsPanel, totpPanel, twitchPanel, sharedPanel, sharedPanel]
        TooltipService.show(600, components[currentCase], origin, false, Quickshell.screens[0])
        TooltipService.setTriggerHovered(origin, true)
        waitFor(() => !!root.panel && root.host.visible, "native panel must open")
        if (currentCase === 1) panel.currentIndex = 1
        waitFor(() => !!root.field?.visible && root.field.enabled, "input must be visible and enabled")
        // Let queued tab/Loader geometry start, then wait for the real motion
        // state instead of clicking through a still-moving/clipped field.
        events.wait(40)
        waitFor(() => !root.host.transitioning, "panel geometry must settle before clicking")
        events.wait(40)
        if (pinned) TooltipService.togglePin(600, components[currentCase], origin, false)
        check(TooltipService.pinned === pinned, "only explicit pinning changes the pin")
        check(host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None && !host.nativeWindow.active,
            "hover/opening must keep native keyboard input disabled")
    }
    function typeAndEdit(pinned) {
        if (currentCase === 4) {
            field.forceActiveFocus(Qt.OtherFocusReason)
            events.wait(40)
            check(field.activeFocus && host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None,
                "programmatic field focus must remain passive")
        }
        click(field)
        waitFor(() => host.nativeWindow.active, "clicked panel must receive native keyboard focus")
        events.wait(50)
        check(field.activeFocus && host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.OnDemand,
            "a consumed field click must activate its native window and keep the clicked field")
        const initialHeight = panel.implicitHeight
        key(Qt.Key_A); key(Qt.Key_B); key(Qt.Key_C)
        check(field.text === "abc", "typed keys must reach the clicked field (keep the desktop keyboard idle during this test)")
        if (currentCase === 3) {
            // Filtering the real Twitch list shrinks its native panel. A stationary
            // pointer can then be outside even though the user is still typing.
            waitFor(() => panel.implicitHeight < initialHeight, "Twitch search must shrink the panel")
            TooltipService.setTriggerHovered(origin, false)
            TooltipService.setPanelHovered(true)
            TooltipService.setPanelHovered(false)
            events.wait(Config.tooltipHideDelay + 80)
            check(TooltipService.visible && field.activeFocus && host.nativeWindow.active
                && TooltipService.interactionHeld && !TooltipService.interactionBlocksReplacement,
                "a focused search must survive shrinking away from the pointer")
        }
        key(Qt.Key_A, Qt.ControlModifier)
        check(field.selectedText === "abc", "select-all must work")
        key(Qt.Key_X)
        check(field.text === "x", "typing replaces selected text")
        click(field, field.leftPadding + 1, field.topPadding + 1)
        const clickedCursor = field.cursorPosition
        const clickedSelection = field.selectedText
        events.wait(60)
        check(TooltipService.visible && field.activeFocus && host.nativeWindow.active
            && host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.OnDemand,
            "repeated field interaction must preserve the existing native grab")
        check(field.cursorPosition === clickedCursor && field.selectedText === clickedSelection,
            "native activation must preserve the clicked caret and selection")
        key(Qt.Key_Home)
        key(Qt.Key_Y)
        check(field.text === "yx", "typing follows the clicked caret")
        key(Qt.Key_Backspace)
        check(field.text === "x", "normal deletion must work; active=" + field.activeFocus
            + ", native=" + host.nativeWindow.active + ", cursor=" + field.cursorPosition
            + ", length=" + field.text.length + ", unchanged=" + (field.text === "yx"))
        if (currentCase === 0) {
            key(Qt.Key_A, Qt.ControlModifier); key(Qt.Key_N)
            key(Qt.Key_Tab)
            check(!field.activeFocus && host.nativeWindow.active, "Tab must reach the next timer input")
            click(events.findChild(panel, "countdownStart"))
            check(TimersService.countdowns.length === 1 && TimersService.countdowns[0].label === "n",
                "creating a countdown must use the typed name")
            TimersService.remove(TimersService.countdowns[0])
        }
        check(TooltipService.pinned === pinned, "editing must never auto-pin or unpin")
        TooltipService.dismiss()
        waitFor(() => !host.visible, "dismissed panel must close")
        events.wait(100)
        // Reopening must discard native activation, including with a manual pin.
        open(pinned)
        check(host.WlrLayershell.keyboardFocus === WlrKeyboardFocus.None,
            "reopening must not inherit the old mouse focus")
        TooltipService.dismiss()
        events.wait(100)
    }
    Component.onCompleted: TotpService.maintenance = true
    Timer {
        interval: 30
        repeat: true
        running: true
        onTriggered: {
            if (!TimersService.ready || !TwitchService.usersReady) return
            stop()
            try {
                for (const pinned of [false, true]) {
                    for (let index = 0; index < 6; index++) {
                        root.currentCase = index
                        root.open(pinned)
                        root.typeAndEdit(pinned)
                    }
                }
                console.log("PASS: native click-to-type in Countdowns, Stats, private TOTP, Twitch, prefocused and multiline fields; editing, caret, repeat clicks, Tab, countdown creation, shrinking-search retention, passive reopen and manual pins")
            } catch (error) {
                console.error("PANEL INPUT FAIL:", error)
            }
            TooltipService.dismiss()
            Qt.quit()
        }
    }
}
