pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../src/bar"
import "../../src/modules/system"

Scope {
    id: root
    property bool loaded: false
    Component { id: centerModules; CenterModules { window: testWindow } }
    Component { id: rightModules; RightModules { window: testWindow } }
    FloatingWindow {
        id: testWindow
        visible: true
        implicitWidth: 500
        implicitHeight: 650
        RecentFiles { id: trigger; window: testWindow }
        Component.onCompleted: {
            // Resolve the same public module import as RightModules.qml, then
            // instantiate its tooltip without importing the files directory here.
            const panel = trigger.tooltip.createObject(testWindow.contentItem)
            root.loaded = panel !== null && centerModules.status === Component.Ready && rightModules.status === Component.Ready
        }
    }
    Timer {
        running: true
        interval: 500
        onTriggered: {
            console.log(root.loaded ? "PASS: recent-file module import and tooltip" : "RECENT FILES FAIL: module tooltip")
            Qt.quit()
        }
    }
}
