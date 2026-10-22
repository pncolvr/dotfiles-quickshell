pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/ui" as UI
import "../../src/ui/panels"
import "../../src/modules/system/audio" as Audio
import "../../src/theme"
import "../../src/services"

WorkerScope {
    id: root
    property bool failed: false
    property bool audioCase: false
    property bool searchable: false
    property bool compact: true
    property bool tall: false
    property int choices: 2
    property int commits: 0
    function check(ok, message) { if (!ok) { failed = true; console.error("HEIGHT FAIL:", message) } }
    function combo() { return control.item as UI.ComboSelector }
    function settle() { events.wait(Theme.selectionAnimationDuration + 40) }
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        id: host
        visible: true
        implicitWidth: 480
        implicitHeight: 640
        TopPanelSurface {
            id: surface
            anchors.fill: parent
            contentX: 20
            contentWidth: 360
            contentHeight: body.implicitHeight + Theme.tooltipPaddingHeight * 2
            requestedVisible: true
            Column {
                id: body
                x: Theme.tooltipPaddingWidth
                y: Theme.tooltipPaddingHeight
                width: parent.width - Theme.tooltipPaddingWidth * 2
                spacing: Theme.controlSpacing
                UI.ColumnText { text: "Short hover panel" }
                Loader {
                    id: control
                    width: parent.width
                    sourceComponent: root.audioCase ? audioSelector : genericSelector
                }
                Item { width: 1; height: root.tall ? 300 : 0; visible: root.tall }
            }
        }
    }
    Component {
        id: genericSelector
        UI.ComboSelector {
            compact: root.compact
            searchable: root.searchable
            selectedName: "0"
            options: Array.from({length: root.choices}, (_, i) => ({name: String(i), description: "Option " + i}))
            onSelected: root.commits++
        }
    }
    Component {
        id: audioSelector
        Audio.AudioSelector {
            compact: true
            selectedName: "0"
            options: [{name: "0", description: "Headset microphone"}, {name: "1", description: "Webcam microphone"}]
            onSelected: root.commits++
        }
    }
    property PopupInputRegion popupRegion: PopupInputRegion {
        overlay: host.contentItem.QC.Overlay.overlay
        enabled: surface.requestedVisible
    }
    Component.onCompleted: surface.motion.motionEnabled = false
    Timer {
        interval: 50
        running: true
        onTriggered: {
            try {
                for (const scenario of ["compact", "regular", "searchable", "audio"]) {
                    root.audioCase = scenario === "audio"
                    root.compact = scenario !== "regular"
                    root.searchable = scenario === "searchable"
                    root.choices = root.searchable ? 8 : 2
                    root.settle()
                    const combo = root.combo()
                    const height = surface.motion.displayedHeight
                    root.check(height === surface.contentHeight && height < 200,
                        scenario + " panel uses its natural height without blank space")
                    events.mouseClick(events.findChild(combo, combo.toggleObjectName), 20, 15)
                    root.settle()
                    root.check(combo.popup.opened && root.popupRegion.regions.length === 1,
                        scenario + " popup adds exactly one input region")
                    const popupItem = combo.popup.contentItem.parent
                    const bounds = popupItem.mapToItem(host.contentItem, 0, 0)
                    root.check(bounds.y + popupItem.height > surface.motion.displayedHeight
                        && bounds.y >= 0 && bounds.y + popupItem.height <= host.height,
                        scenario + " menu extends beyond the panel within window bounds")
                    root.check(surface.motion.displayedHeight === height && surface.inputRect.height === height,
                        scenario + " menu does not stretch the panel or its base input rectangle")
                    const row = combo.choicesView.itemAtIndex(1)
                    root.check(row && row.mapToItem(host.contentItem, 0, 0).y >= height,
                        scenario + " second option lies outside the panel")
                    const before = root.commits
                    events.mouseClick(row, row.width / 2, row.height / 2)
                    root.settle()
                    root.check(root.commits === before + 1 && !combo.expanded
                        && root.popupRegion.regions.length === 0,
                        scenario + " overflowing option accepts a pointer click and releases its input region")
                }
                root.audioCase = false
                root.settle()
                root.combo().expanded = true
                root.settle()
                root.popupRegion.closePopups()
                root.settle()
                root.check(!root.combo().expanded && root.popupRegion.regions.length === 0,
                    "closing the owner dismisses menus and removes their regions")
                root.tall = true
                root.settle()
                root.check(surface.motion.displayedHeight === surface.contentHeight && surface.motion.displayedHeight > 300,
                    "tall content retains its natural height")
                root.tall = false
                root.settle()
                root.check(surface.motion.displayedHeight === surface.contentHeight && surface.motion.displayedHeight < 200,
                    "collapsing contents contracts the panel without a minimum")
                surface.requestedVisible = false
                root.check(!surface.presented && surface.inputRect.height === 0 && root.popupRegion.regions.length === 0,
                    "dismissal releases the compact panel's complete input area")
                console.log(root.failed ? "HEIGHT FAIL: compact tooltip dropdowns" : "PASS: compact tooltips and shared dropdown overflow, pointer selection, input region cleanup and natural resizing")
            } catch (error) { console.error("HEIGHT FAIL:", error) }
            Qt.quit()
        }
    }
}
