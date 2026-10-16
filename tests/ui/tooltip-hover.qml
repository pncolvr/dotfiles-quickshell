pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/bar"
import "../../src/services"
import "../../src/config"

Scope {
    id: root
    property int step: 0
    property bool failed: false
    function check(ok, message) { if (!ok) { failed = true; console.error("HOVER FAIL:", message) } }
    function open(source) { TooltipService.show(200, content, source, false, host.screen) }
    QtObject { id: firstSource }
    QtObject { id: secondSource }
    Component { id: content; Item {} }
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        id: host
        visible: true
        implicitWidth: 600
        implicitHeight: 300
        Item { id: panel; x: 40; y: 40; width: 240; height: 160 }
        QC.Popup {
            id: popup
            parent: host.contentItem.QC.Overlay.overlay
            popupType: QC.Popup.Item
            x: 320; y: 40; width: 180; height: 120
            contentItem: Item {}
        }
    }
    QtObject {
        id: tooltipHost
        readonly property Item contentItem: host.contentItem
        readonly property var screen: host.screen
        readonly property bool visible: TooltipService.visible
        readonly property QtObject surfaceComponent: QtObject {
            readonly property Item popupContentBounds: panel
        }
    }
    TooltipPointerHandler { id: observer; tooltipWindow: tooltipHost }
    Timer {
        interval: Config.tooltipHideDelay + 100
        running: true
        repeat: true
        onTriggered: {
            if (root.step === 0) {
                events.mouseMove(host.contentItem, 10, 10)
                root.open(firstSource)
                TooltipService.setTriggerHovered(firstSource, true)
                TooltipService.hide()
            } else if (root.step === 1) {
                root.check(TooltipService.visible, "a late hide request must not close a hovered trigger")
                TooltipService.setTriggerHovered(firstSource, false)
            } else if (root.step === 2) {
                root.check(!TooltipService.visible, "leaving the trigger still dismisses")
                root.open(firstSource)
                events.mouseMove(panel, 100, 80)
            } else if (root.step === 3) {
                root.check(observer.hovered && TooltipService.visible, "the panel reports native Qt hover")
                TooltipService.hide()
            } else if (root.step === 4) {
                root.check(TooltipService.visible, "a late hide request must not close a hovered panel")
                root.open(firstSource)
                events.mouseMove(panel, 101, 80)
                root.open(secondSource)
                root.check(observer.hovered, "switching source leaves the stationary pointer in the same panel")
                TooltipService.setTriggerHovered(secondSource, false)
            } else if (root.step === 5) {
                root.check(TooltipService.visible, "switching tooltip source must resync stationary panel hover")
                events.mouseMove(host.contentItem, 10, 10)
            } else if (root.step === 6) {
                root.check(!TooltipService.visible, "leaving the panel dismisses after its grace period")
                root.open(firstSource)
                TooltipService.setTriggerHovered(firstSource, true)
                popup.open()
            } else if (root.step === 7) {
                events.mouseMove(popup.contentItem, 50, 40)
            } else if (root.step === 8) {
                root.check(observer.popupHovered && TooltipService.visible, "popup options report hover outside the panel bounds")
                TooltipService.setTriggerHovered(firstSource, false)
                TooltipService.hide()
            } else if (root.step === 9) {
                root.check(TooltipService.visible, "a late hide request must not close hovered popup options")
                popup.close()
                events.mouseMove(host.contentItem, 10, 10)
            } else if (root.step === 10) {
                root.check(!TooltipService.visible, "leaving popup options restores normal dismissal")
                console.log(root.failed ? "HOVER FAIL: tooltip lifecycle" : "PASS: trigger/panel/popup hover survives late hide requests and stationary source changes; leaving still dismisses")
                Qt.quit()
                return
            }
            root.step++
        }
    }
}
