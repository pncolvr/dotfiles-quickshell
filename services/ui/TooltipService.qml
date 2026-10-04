pragma Singleton

import QtQml
import Quickshell
import "../../config"

Singleton {
    id: root

    readonly property bool visible: _internal.visible
    readonly property bool pinned: _internal.pinned
    readonly property real x: _internal.x
    readonly property bool centered: _internal.centered
    readonly property Component content: _internal.content
    readonly property var source: _internal.source
    readonly property var screen: _internal.screen
    readonly property bool notificationPanel: _internal.notificationPanel

    QtObject {
        id: _internal
        property bool visible: false
        property bool pinned: false
        property real x: 0
        property bool centered: false
        property Component content: null
        property var source: null
        property var screen: null
        property bool notificationPanel: false
    }

    function show(xPos: real, tooltipContent: Component, tooltipSource, screenCentered, tooltipScreen) {
        if (_internal.pinned) return
        _internal.x = xPos
        _internal.centered = screenCentered ?? false
        _internal.content = tooltipContent
        _internal.source = tooltipSource ?? null
        _internal.notificationPanel = !!tooltipSource?.notificationsModule
        _internal.screen = tooltipScreen ?? null
        _internal.visible = true
        hideTimer.stop()
    }

    function hide() {
        if (_internal.pinned) return
        hideTimer.start()
    }

    function togglePin(xPos: real, tooltipContent: Component, tooltipSource, screenCentered, tooltipScreen) {
        if (_internal.pinned && _internal.source === tooltipSource) {
            _internal.pinned = false
            // Keep it open while the pointer is still over the clicked icon.
            hideTimer.stop()
            return
        }
        _internal.pinned = false
        show(xPos, tooltipContent, tooltipSource, screenCentered, tooltipScreen)
        _internal.pinned = true
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
            _internal.screen = null
            _internal.notificationPanel = false
        }
    }
}
