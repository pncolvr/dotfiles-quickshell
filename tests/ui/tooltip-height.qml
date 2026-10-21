pragma ComponentBehavior: Bound
import QtQuick
import QtTest as Test
import Quickshell
import "../../src/ui" as UI
import "../../src/ui/panels"
import "../../src/theme"
import "../../src/services"

WorkerScope {
    id: root
    property bool failed: false
    property real availableHeight: 640
    function check(ok, message) { if (!ok) { failed = true; console.error("HEIGHT FAIL: " + message) } }
    function checkPopup() {
        const bounds = surface.popupContentBounds
        const position = combo.popup.contentItem.mapToItem(bounds, 0, 0)
        check(combo.popup.opened && combo.popup.height > 0, "combobox opens in the reserved panel space")
        check(position.y >= 0 && position.y + combo.popup.contentItem.height <= bounds.height + 0.1,
            "popup remains within the visible panel")
    }
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        id: host
        visible: true
        implicitWidth: 480
        implicitHeight: 640
        TopPanelSurface { id: ordinaryPanel; visible: false; width: 480; height: 640; contentHeight: 80 }
        TopPanelSurface {
            id: surface
            width: parent.width
            height: root.availableHeight
            contentX: 20
            contentWidth: 360
            contentHeight: body.implicitHeight + Theme.tooltipPaddingHeight * 2
            minimumContentHeight: Theme.tooltipMinHeight
            requestedVisible: true
            Column {
                id: body
                x: Theme.tooltipPaddingWidth
                y: Theme.tooltipPaddingHeight
                width: parent.width - Theme.tooltipPaddingWidth * 2
                spacing: Theme.controlSpacing
                UI.ColumnText { text: "Short hover panel" }
                UI.ComboSelector {
                    id: combo
                    width: parent.width
                    searchable: true
                    selectedName: "0"
                    options: Array.from({length: 8}, (_, index) => ({name:String(index), description:"Option " + index}))
                }
            }
        }
    }
    Component.onCompleted: surface.motion.motionEnabled = false
    Timer {
        interval: 50
        running: true
        onTriggered: {
            try {
                events.tryCompare(surface.motion, "transitioning", false, 500)
                root.check(ordinaryPanel.minimumContentHeight === 0, "other top-panel surfaces retain natural sizing")
                root.check(surface.contentHeight < Theme.tooltipMinHeight
                    && surface.motion.displayedHeight === Theme.tooltipMinHeight,
                    "short contents reserve the minimum visible height")
                root.check(body.y === Theme.tooltipPaddingHeight
                    && surface.inputRect.height === surface.motion.displayedHeight,
                    "content stays top-aligned and the full reserved area receives input")
                combo.expanded = true
                events.wait(160)
                root.checkPopup()
                root.check(combo.choicesView.height >= combo.optionRowHeight,
                    "a short panel has room for a full option and search")
                root.availableHeight = Theme.tooltipMinHeight - 20
                events.tryCompare(surface, "height", root.availableHeight, 500)
                events.tryCompare(surface.motion, "displayedHeight", root.availableHeight - surface.shadowBottomPadding, 500)
                root.check(surface.motion.displayedHeight === root.availableHeight - surface.shadowBottomPadding,
                    "the minimum fits a short monitor while reserving its shadow")
                root.checkPopup()
                combo.expanded = false
                root.availableHeight = 640
                events.tryCompare(surface, "height", 640, 500)
                surface.contentHeight = 560
                events.wait(10)
                root.check(surface.motion.displayedHeight === 560, "tall content grows beyond the minimum")
                surface.contentHeight = 80
                events.wait(10)
                root.check(surface.motion.displayedHeight === Theme.tooltipMinHeight,
                    "a shorter tab returns to the shared minimum")
                surface.requestedVisible = false
                root.check(!surface.presented && surface.inputRect.height === 0,
                    "closing releases the entire minimum-sized input area")
                console.log(root.failed ? "HEIGHT FAIL: tooltip minimum height" : "PASS: shared tooltip minimum height, usable combobox space, monitor bounds, natural growth and dismissal")
            } catch (error) { console.error("HEIGHT FAIL: " + error + " " + JSON.stringify({host:host.height,implicit:host.implicitHeight,surface:surface.height,displayed:surface.motion.displayedHeight,content:surface.contentHeight})) }
            Qt.quit()
        }
    }
}
