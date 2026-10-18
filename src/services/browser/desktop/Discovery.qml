import QtQuick
import Quickshell
import Quickshell.Io
import "DesktopApplications.mjs" as Applications

// Headless desktop-entry discovery for the interactive installer.
Item {
    id: root
    property bool reported: false
    function report() {
        if (reported) return
        reported = true
        output.setText(JSON.stringify(Applications.applications(DesktopEntries.applications.values, true)))
    }
    FileView {
        id: output
        path: Quickshell.env('QS_BROWSER_CHOICES_FILE')
        printErrors: false
        onSaved: Qt.quit()
        onSaveFailed: Qt.quit()
    }
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged() { Qt.callLater(root.report) }
    }
    // Desktop discovery is asynchronous. This deadline handles an empty desktop
    // database; normal completion follows its model update.
    Timer { interval: 3000; running: true; onTriggered: root.report() }
    Component.onCompleted: if (DesktopEntries.applications.values.length) Qt.callLater(report)
}
