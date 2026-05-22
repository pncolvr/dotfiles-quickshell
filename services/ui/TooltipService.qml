pragma Singleton

import QtQuick
import Quickshell
import "../../config"

Singleton {
    id: root

    readonly property bool visible: _internal.visible
    readonly property real x: _internal.x
    readonly property bool centered: _internal.centered
    readonly property Component content: _internal.content
    readonly property var source: _internal.source

    QtObject {
        id: _internal
        property bool visible: false
        property real x: 0
        property bool centered: false
        property Component content: null
        property var source: null
    }

    function show(xPos: real, tooltipContent: Component, tooltipSource, screenCentered) {
        _internal.x = xPos
        _internal.centered = screenCentered ?? false
        _internal.content = tooltipContent
        _internal.source = tooltipSource ?? null
        _internal.visible = true
        hideTimer.stop()
    }

    function hide() {
        hideTimer.start()
    }

    function cancelHide() {
        hideTimer.stop()
    }

    Timer {
        id: hideTimer
        interval: Config.tooltipHideDelay
        onTriggered: {
            _internal.visible = false
            _internal.content = null
            _internal.source = null
        }
    }
}