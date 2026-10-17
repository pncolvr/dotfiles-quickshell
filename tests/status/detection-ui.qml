pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import QtTest as Test
import Quickshell
import "../../src/modules/status"
import "../../src/ui" as UI

Scope {
    id: root
    property bool failed: false
    function check(ok,message) { if (!ok) { failed = true; console.error("DETECTION FAIL:",message) } }
    function find(item,name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) { const found = find(child,name); if (found) return found }
        return null
    }
    QtObject {
        id: backend
        property var detectionMatches: []
        property string detectionError: ""
        property bool detectionLoading: false
        property bool detectionStale: false
        property string source: "automatic"
    }
    Test.TestCase { id: events; when: false }
    FloatingWindow {
        visible: true; implicitWidth: 300; implicitHeight: 420
        Flickable {
            id: scroll
            anchors.fill: parent; anchors.margins: 10
            contentHeight: section.height; clip: true
            StatusDetectionSection { id: section; width: scroll.width; statusService: backend }
        }
    }
    Timer {
        interval: 100; running: true
        onTriggered: {
            try {
                const home = Quickshell.env("HOME")
                const literal = home + "/Projects/<b>quotes\"&tabs\tnew\nline</b>"
                const paths = [literal,...Array.from({length:24},(_,i) => home + "/Projects/" + "long-directory-".repeat(5) + i)]
                const longName = "very-long-process-name-".repeat(8)
                backend.detectionMatches = [{name:longName,methods:["directory","file"],paths},{name:"empty",methods:["process"],paths:[]},{name:"other",methods:["process"],paths:["/opt/other"]}]
                events.wait(30)
                const row = root.find(section,"statusDetectionToggle-" + longName) as QC.ItemDelegate
                const empty = root.find(section,"statusDetectionToggle-empty") as QC.ItemDelegate
                root.check(!empty.enabled && section.expandedProcess === "","empty evidence cannot expand and rows begin collapsed")
                root.check(row.contentItem.width <= row.width && row.contentItem.height <= row.height,"narrow disclosure geometry stays bounded")
                row.forceActiveFocus(Qt.TabFocusReason)
                events.keyClick(Qt.Key_Space)
                events.wait(20)
                root.check(section.expandedProcess === longName,"Space expands a keyboard-focused process")
                const label = root.find(section,"statusDetectionPaths-" + literal) as UI.ColumnText
                root.check(label && label.text === "~/Projects/<b>quotes\"&tabs\\tnew\\nline</b>" && label.textFormat === Text.PlainText,"path markup/quotes/newlines remain literal with home abbreviation")
                root.check(section.displayPath(home + "-other/file") === home + "-other/file","home abbreviation respects a directory boundary")
                root.check(!label.font.bold && label.font.weight === Font.Normal && label.width + label.x <= section.width,"paths use regular text and bounded indentation")
                events.keyClick(Qt.Key_Return); events.wait(20)
                root.check(section.expandedProcess === "","Enter collapses")
                const title = root.find(row,"statusDetectionProcess")
                events.mouseClick(title,title.width / 2,title.height / 2)
                events.wait(20)
                root.check(section.expandedProcess === longName,"name tooltip does not intercept row activation")
                backend.detectionMatches = [...backend.detectionMatches]; events.wait(20)
                root.check(section.expandedProcess === longName,"refresh preserves expansion by name")
                root.check(scroll.contentHeight > scroll.height,"many paths use bounded outer scrolling")
                scroll.contentY = scroll.contentHeight - scroll.height
                events.wait(20)
                const last = root.find(section,"statusDetectionPaths-" + paths[paths.length - 1])
                const position = last.mapToItem(scroll,0,0)
                root.check(position.y >= 0 && position.y + last.height <= scroll.height + 1,"last path remains reachable")
                scroll.contentY = 0
                const other = root.find(section,"statusDetectionToggle-other") as QC.ItemDelegate
                other.forceActiveFocus(Qt.TabFocusReason); events.keyClick(Qt.Key_Enter); events.wait(20)
                root.check(section.expandedProcess === "other" && !root.find(section,"statusDetectionPaths-" + literal),"only one process expands")
                backend.detectionMatches = backend.detectionMatches.filter(match => match.name !== "other"); events.wait(20)
                root.check(section.expandedProcess === "","removed process clears expansion")
                backend.source = "manual"; backend.detectionError = "Synthetic partial scan failure"; backend.detectionStale = true
                root.check(root.find(section,"statusDetectionManual").visible && root.find(section,"statusDetectionFeedback").text === backend.detectionError && root.find(section,"statusDetectionStale").visible,"manual and failed/partial scan evidence stays explicit")
                backend.detectionError = ""; backend.detectionStale = false; backend.detectionMatches = []; backend.detectionLoading = true
                root.check(root.find(section,"statusDetectionFeedback").text === "Checking automatic detection…","first scan has checking feedback")
                backend.detectionLoading = false
                root.check(root.find(section,"statusDetectionFeedback").text === "No active work detections.","empty success has one message")
                if (!root.failed) console.log("PASS: detection keyboard/mouse, literal paths, refresh/removal, narrow scrolling and scan states")
            } catch (_) { root.check(false,"disclosure assertion") }
            Qt.quit()
        }
    }
}
