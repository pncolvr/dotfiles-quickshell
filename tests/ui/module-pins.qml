pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/modules/system" as System
import "../../src/modules/clock" as ClockModule
import "../../src/modules/updates" as UpdatesModule
import "../../src/modules/status" as StatusModule
import "../../src/modules/media" as MediaModule
import "../../src/modules/hyprland" as HyprlandModule
import "../../src/theme/ui" as UI
import "../../src/theme"
import "../../src/services"

Scope {
    id: root
    property int step: 0
    property bool failed: false
    readonly property var recordingService: RecordingService
    function check(ok, message) { if (!ok) { failed = true; console.error("PIN FAIL:", message) } }
    Test.TestCase { id: events; when: false }
    Test.TestResult { id: objects }
    FloatingWindow {
        id: host
        visible: true
        implicitWidth: 1200
        implicitHeight: 400
        Row {
            Repeater {
                id: triggers
                model: [clock, updates, files, timers, mic, volume, stats, twitch, status, totp, batteries, notifications, sharing, recording]
                Loader {
                    required property var modelData
                    width: modelData === clock ? 240 : 60
                    height: 35
                    sourceComponent: modelData
                }
            }
        }
        UpdatesModule.UpdatesTooltip { id: updatesPanel; x: 20; y: 70 }
        System.Tray { window: host; x: 400; y: 70 }
    }
    Component { id: clock; ClockModule.Clock {} }
    Component { id: updates; UpdatesModule.Updates {} }
    Component { id: files; System.RecentFiles { window: host } }
    Component { id: timers; System.Timers { window: host } }
    Component { id: mic; System.Mic {} }
    Component { id: volume; System.Volume {} }
    Component { id: stats; System.Stats {} }
    Component { id: twitch; MediaModule.Twitch { visible: true } }
    Component { id: status; StatusModule.Status {} }
    Component { id: totp; System.Totp { window: host } }
    Component { id: batteries; System.Batteries { window: host } }
    Component { id: notifications; System.Notifications { window: host } }
    Component { id: sharing; HyprlandModule.Screencast { visible: true } }
    Component { id: recording; HyprlandModule.Recording {} }
    Timer {
        interval: 120
        running: true
        repeat: true
        onTriggered: {
            if (root.step < triggers.count) {
                const trigger = (triggers.itemAt(root.step) as Loader).item as UI.TooltipArea
                const oldMuted = AudioService.muted
                const oldMicMuted = AudioService.micMuted
                TooltipService.dismiss()
                events.mouseClick(trigger, trigger.width / 2, trigger.height / 2, Qt.LeftButton)
                root.check(TooltipService.pinned && TooltipService.source === trigger && trigger.pinned,
                    trigger.moduleName + " left-click pins")
                root.check(trigger.moduleIconColor.toString() === Theme.accent.toString(), trigger.moduleName + " uses the shared pin color")
                root.check(oldMuted === AudioService.muted && oldMicMuted === AudioService.micMuted, "pinning does not mute audio")
                events.mouseClick(trigger, trigger.width / 2, trigger.height / 2, Qt.LeftButton)
                root.check(!TooltipService.pinned && !trigger.pinned, trigger.moduleName + " left-click unpins")
                if (root.step === 0) {
                    const calendar = trigger as ClockModule.Clock
                    const oldView = calendar.viewMode
                    const oldSeconds = TimeService.showSeconds
                    events.mouseClick(trigger, trigger.width / 2, trigger.height / 2, Qt.RightButton)
                    root.check(calendar.viewMode !== oldView && TimeService.showSeconds === oldSeconds, "right-click changes calendar view")
                    events.mouseClick(trigger, trigger.width / 2, trigger.height / 2, Qt.MiddleButton)
                    root.check(TimeService.showSeconds !== oldSeconds, "middle-click changes seconds")
                }
                root.step++
                return
            }
            if (root.step++ === triggers.count) {
                const indicator = (triggers.itemAt(triggers.count - 1) as Loader).item as HyprlandModule.Recording
                const sharingActive = AudioService.screencastActive
                root.check(indicator.icon === Theme.recordingIcon && indicator.details[0] === root.recordingService.filename,
                    "recording indicator shows its own icon and filename")
                root.check(indicator.animationEnabled === UI.MotionPolicy.recordingPulseEnabled,
                    "recording pulse uses the central motion policy")
                for (const state of ["idle", "configuring", "starting", "recording", "stopping", "recovering", "finalizing"]) {
                    root.recordingService.state = state
                    root.check(indicator.visible === ["recording", "stopping", "recovering", "finalizing"].includes(state),
                        "recording visibility follows " + state)
                    const finishing = ["stopping", "recovering", "finalizing"].includes(state)
                    root.check(indicator.heading === (finishing ? "Recording finishing" : "Screen recording"),
                        "recording tooltip follows " + state)
                }
                root.recordingService.state = "idle"
                root.check(AudioService.screencastActive === sharingActive, "recording remains independent from sharing")
                root.check(UpdatesService.hasUpdates, "mock updates are loaded")
                const notes = objects.findChild(updatesPanel, "updatesNotes") as UI.ActionButton
                const install = objects.findChild(updatesPanel, "updatesInstall") as UI.ActionButton
                root.check(notes.enabled && install.enabled && notes.glyph === Theme.notesIcon && install.glyph === Theme.downloadIcon,
                    "updates actions have accessible notes and download buttons")
                root.check(notes.y === install.y && notes.parent.x > 0, "updates actions share the compact header row")
                notes.clicked(); install.clicked()
                return
            }
            console.log(root.failed ? "PIN FAIL: modules" : "PASS: all 14 bar modules share left-click pinning and color; recording states, calendar mappings and updates header actions")
            Qt.quit()
        }
    }
}
