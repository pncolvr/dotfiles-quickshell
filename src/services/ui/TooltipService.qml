pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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
    readonly property bool ownsTooltipWindow: source?.ownsTooltipWindow === true
    readonly property bool typingPaused: _internal.typingPaused
    readonly property bool dragging: _internal.dragging

    QtObject {
        id: _internal
        property bool visible: false
        property bool pinned: false
        property real x: 0
        property bool centered: false
        property Component content: null
        property var source: null
        property var screen: null
        property bool typingPaused: false
        property bool dragging: false
        property bool triggerHovered: false
        property bool panelHovered: false
        property var cursorBaseline: null
        property var lastLocalPointer: null
    }

    function show(xPos: real, tooltipContent: Component, tooltipSource, screenCentered, tooltipScreen) {
        if (_internal.dragging) return
        if (_internal.pinned) return
        if (_internal.typingPaused && _internal.source !== (tooltipSource ?? null)) return
        if (_internal.source !== (tooltipSource ?? null) || _internal.screen !== (tooltipScreen ?? null)) {
            _internal.typingPaused = false
            _internal.triggerHovered = false
            _internal.panelHovered = false
        }
        _internal.x = xPos
        _internal.centered = screenCentered ?? false
        _internal.content = tooltipContent
        _internal.source = tooltipSource ?? null
        _internal.screen = tooltipScreen ?? null
        _internal.visible = true
        hideTimer.stop()
    }

    function hide() {
        if (_internal.pinned || _internal.typingPaused || _internal.dragging) return
        hideTimer.start()
    }

    function togglePin(xPos: real, tooltipContent: Component, tooltipSource, screenCentered, tooltipScreen) {
        if (_internal.dragging) return
        if (_internal.pinned && _internal.source === tooltipSource) {
            _internal.pinned = false
            // Keep it open while the pointer is still over the clicked icon.
            hideTimer.stop()
            return
        }
        _internal.pinned = false
        _internal.typingPaused = false
        show(xPos, tooltipContent, tooltipSource, screenCentered, tooltipScreen)
        _internal.pinned = true
    }

    function cancelHide() {
        hideTimer.stop()
    }

    function beginDrag() {
        _internal.dragging = true
        hideTimer.stop()
    }

    function endDrag() {
        _internal.dragging = false
        if (!_internal.panelHovered && !_internal.triggerHovered) hide()
    }

    function pauseDismissal() {
        if (!_internal.visible) return
        if (!_internal.typingPaused) _internal.cursorBaseline = null
        _internal.typingPaused = true
        hideTimer.stop()
    }

    function resumeDismissal() {
        if (!_internal.typingPaused) return
        _internal.typingPaused = false
        if (!_internal.panelHovered && !_internal.triggerHovered) hide()
    }

    function setTriggerHovered(tooltipSource, hovered) {
        if (_internal.source !== (tooltipSource ?? null)) return
        _internal.triggerHovered = hovered
        if (hovered) cancelHide()
        else if (!_internal.panelHovered) hide()
    }

    function setPanelHovered(hovered) {
        _internal.panelHovered = hovered
        if (hovered) cancelHide()
        else if (!_internal.triggerHovered) hide()
    }

    function observePointer(xPos, yPos, localEvent = false) {
        if (!Number.isFinite(xPos) || !Number.isFinite(yPos)) return
        const previous = localEvent ? _internal.lastLocalPointer : _internal.cursorBaseline
        if (localEvent) _internal.lastLocalPointer = {x: xPos, y: yPos}
        else _internal.cursorBaseline = {x: xPos, y: yPos}
        if (previous && (previous.x !== xPos || previous.y !== yPos)) resumeDismissal()
    }

    // Hover events stop outside our windows. Query the compositor only while typing
    // protection is active, so movement elsewhere also restores normal dismissal.
    Timer {
        interval: 100
        running: root.typingPaused && root.visible && cursorSocket.path.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!cursorSocket.connected) cursorSocket.connected = true
    }

    Socket {
        id: cursorSocket
        path: Hyprland.requestSocketPath
        onConnectedChanged: if (connected) { write("j/cursorpos"); flush() }
        parser: SplitParser {
            splitMarker: "}"
            onRead: data => {
                try {
                    const position = JSON.parse(data + "}")
                    root.observePointer(position.x, position.y)
                } catch (_) { /* Ignore incomplete or unavailable compositor replies. */ }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: Config.tooltipHideDelay
        onTriggered: {
            _internal.visible = false
            _internal.typingPaused = false
            _internal.triggerHovered = false
            _internal.panelHovered = false
            _internal.cursorBaseline = null
            _internal.lastLocalPointer = null
            _internal.content = null
            _internal.source = null
            _internal.screen = null
        }
    }
}
