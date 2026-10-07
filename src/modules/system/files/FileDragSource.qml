pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../../services"

Item {
    id: root
    property var fileService: RecentFilesService
    property var files: []
    property string originTab: ""
    property bool dragging: false
    Drag.dragType: Drag.Automatic
    Drag.active: dragging
    Drag.source: root
    Drag.mimeData: ({"text/uri-list": files.map(file => file.uri + "\r\n").join("")})
    Drag.supportedActions: Qt.CopyAction
    Drag.proposedAction: Qt.CopyAction
    Drag.imageSource: files.length > 0 ? Quickshell.iconPath(files[0].icon || "text-x-generic", true) : ""
    Drag.imageSourceSize: Qt.size(32, 32)
    Drag.hotSpot: Qt.point(16, 16)
    Drag.onDragFinished: finish()
    function prepare(entries, tab) {
        if (dragging || entries.length === 0) return false
        files = entries.slice()
        originTab = tab
        return true
    }
    function start(entries, tab) {
        if (!prepare(entries, tab)) return
        fileService.beginDrag()
        TooltipService.beginDrag()
        dragging = true
    }
    function finish() {
        if (!dragging) return
        dragging = false
        fileService.endDrag()
        TooltipService.endDrag()
        files = []
        originTab = ""
    }
    Component.onDestruction: finish()
}
