pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/theme"
import "../../src/config" as Settings
import "../../src/ui" as UI
import "../../src/modules/clock"

Scope {
    id: root
    property bool failed: false
    // Only the isolated fixture makes this property writable.
    property var fixtureTheme: Theme
    Test.TestCase { id: events; when: false }
    function check(ok, message) { if (!ok) { failed = true; console.error("THEME FAIL:", message) } }
    function same(actual, expected, message) { check(Qt.colorEqual(actual, expected), message) }
    function luminance(color) {
        const linear = channel => channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    }
    function contrast(foreground, background) {
        const a = luminance(foreground), b = luminance(background)
        return (Math.max(a,b) + 0.05) / (Math.min(a,b) + 0.05)
    }
    FloatingWindow {
        visible: true
        implicitWidth: 720; implicitHeight: 430
        color: Theme.background
        Rectangle {
            id: preview
            anchors.fill: parent
            color: Theme.tooltipBackground
            border.color: Theme.selectionBorder
            radius: Theme.tooltipRadius
            Column {
                x: 20; y: 18; width: 385; spacing: Theme.controlSpacing
                UI.ColumnText { text: "Theme preview"; color: Theme.accent }
                UI.TabBar { width: parent.width; labels: ["Overview", "Manage"]; currentIndex: 0 }
                UI.InputField { id: input; width: parent.width; text: "Search or edit a value" }
                UI.PickerRow { id: selected; width: parent.width; current: true; multiple: true; selected: true; entry: ({title:"Selected entry", subtitle:"Selected details", pinned:true}) }
                UI.PickerRow { width: parent.width; entry: ({title:"Normal entry", subtitle:"Secondary details"}) }
                Row {
                    spacing: Theme.controlSpacing
                    UI.ActionButton { id: apply; glyph: Theme.checkIcon; label: "Apply"; fillColor: Theme.accent; width: 120 }
                    UI.ActionButton { id: remove; glyph: Theme.deleteIcon; label: "Delete"; fillColor: Theme.urgent; width: 120 }
                    UI.ActionButton { id: disabled; glyph: Theme.cancelIcon; enabled: false }
                }
                UI.TextArea { id: area; width: parent.width; height: 60; text: "Notes and multiline input" }
                Rectangle {
                    width: parent.width; height: 68; radius: Theme.notificationRadius
                    color: Theme.notificationBackground; border.color: Theme.notificationBorder
                    Column {
                        x: 12; y: 8; spacing: 4
                        UI.ColumnText { text: "Notification"; color: Theme.accent }
                        UI.ColumnText { text: "Normal text and muted details"; color: Theme.inactive }
                    }
                }
                UI.ColumnText { text: "Warning · critical · offline"; color: Theme.warning }
            }
            MonthTooltip { id: calendar; x: 450; y: 20; width: Theme.calendarWidth }
        }
    }
    function verify(light) {
        root.same(input.color,Theme.text,"input text follows Theme")
        root.same(input.selectedTextColor,Theme.selectionText,"input selection follows Theme")
        root.same(area.selectedTextColor,Theme.selectionText,"multiline selection follows Theme")
        root.same(selected.foreground,Theme.selectionText,"selected row foreground follows Theme")
        root.same(selected.color,Theme.accent,"selected row background follows Theme")
        root.same(apply.foreground,Theme.foregroundOn((apply.background as Rectangle).color),"action foreground follows Theme's contrast policy")
        root.check(disabled.opacity === 0.45 && !disabled.enabled,"disabled state preserved")
        root.check(Theme === Settings.Theme,"both imports use the same Theme instance")
        if (light) {
            for (const color of [Theme.text, Theme.inactive, Theme.accent, Theme.warning, Theme.urgent])
                root.check(contrast(color,Theme.background) >= 4.5,"light text/status color has readable contrast: " + color)
            for (const action of [apply,remove]) {
                root.check(contrast(action.foreground,(action.background as Rectangle).color) >= 4.5,"filled control contrast")
                action.down = true
                root.check(contrast(action.foreground,(action.background as Rectangle).color) >= 4.5,"pressed control contrast")
                action.down = false
                events.mouseMove(action,action.width / 2,action.height / 2)
                events.wait(20)
                root.check(contrast(action.foreground,(action.background as Rectangle).color) >= 4.5,"hovered control contrast")
                events.mouseMove(preview,690,420)
            }
            root.check(contrast(Theme.selectionText,Theme.accent) >= 4.5,"selection contrast")
            root.check(contrast(Theme.calendarTodayText,Theme.calendarTodayBackground) >= 4.5,"today contrast")
            root.check(contrast(Theme.calendarHolidayText,Theme.calendarHolidayBackground) >= 4.5,"holiday contrast")
            root.check(contrast(Theme.calendarClockChangeEveText,Theme.calendarClockChangeEveBackground) >= 4.5,"clock-change contrast")
        }
        input.forceActiveFocus(); input.selectAll()
        events.keyClick(Qt.Key_A, Qt.NoModifier, 0)
        root.check(input.activeFocus && input.text === "a","input focus and editing preserved")
        input.text = "Search or edit a value"
        const output = Quickshell.env("THEME_TEST_PREVIEWS")
        if (output) events.grabImage(preview).save(output + (light ? "/light.png" : "/dark.png"))
    }
    Timer {
        interval: 120; running: true
        onTriggered: {
            const dark = {background:"#000000",text:"#d8dadc",alternateBackground:"#be1b1a1a",accent:"#6B8FB3",
                urgent:"#B80F0A",ok:"#3E8E5A",active:"#5C9E7E",warning:"#fd6d37",inactive:"#b0b3b8",empty:"#8080804d",
                selectionBackground:"#1b1b1b",selectionHoverBackground:"#30343a",selectionSelectedBackground:"#273441",selectionBorder:"#454a50",
                updatesUnchangedColor:"#62666b",batteryEmptyColor:"#232323",twitchColor:"#A970FF",notificationBorder:"#2a2d38",notificationCritical:"#d32f2f"}
            root.check(Theme.darkMode,"dark is the default")
            for (const key of Object.keys(dark)) root.same(Theme[key],dark[key],"original dark color: " + key)
            root.same(Theme.notificationBackground,Qt.rgba(33/255,34/255,44/255,0.95),"original notification alpha")
            const geometry = [Theme.barHeight,Theme.fontSize,Theme.pickerWidth,Theme.controlHeight,apply.width,calendar.width]
            const motion = Settings.Config.animationsEnabled
            try {
                root.verify(false)
                root.fixtureTheme.darkMode = false
                events.wait(100)
                root.verify(true)
                root.check(JSON.stringify(geometry) === JSON.stringify([Theme.barHeight,Theme.fontSize,Theme.pickerWidth,Theme.controlHeight,apply.width,calendar.width]),"mode does not change dimensions")
                root.check(Settings.Config.animationsEnabled === motion,"mode does not change motion policy")
                root.fixtureTheme.darkMode = true
                events.wait(50)
                root.same(Theme.text,dark.text,"switching back restores dark colors")
                root.same(apply.foreground,Theme.text,"original dark filled-control text preserved")
            } catch (error) { root.check(false,String(error)) }
            if (!root.failed) console.log("PASS: dark palette compatibility, light contrast, shared controls, calendar, focus, singleton identity and mode changes")
            Qt.quit()
        }
    }
}
