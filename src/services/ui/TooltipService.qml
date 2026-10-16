pragma Singleton

import QtQml
import Quickshell
import "../../config"

Singleton {
    id: root

    readonly property bool visible: _internal.visible
    readonly property bool pinned: _internal.pinned
    readonly property bool keyboardActive: _internal.keyboardActive
    signal focusRequested()
    readonly property real x: _internal.x
    readonly property bool centered: _internal.centered
    readonly property Component content: _internal.content
    readonly property var source: _internal.source
    readonly property var screen: _internal.screen
    readonly property bool ownsTooltipWindow: source?.ownsTooltipWindow === true
    readonly property bool interactionHeld: _internal.holds.length > 0
    readonly property bool interactionBlocksReplacement: _internal.holds.some(hold => hold.blocksReplacement)
    readonly property bool dragging: _internal.dragging

    QtObject {
        id: _internal
        property bool visible: false
        property bool pinned: false
        property bool keyboardActive: false
        property real x: 0
        property bool centered: false
        property Component content: null
        property var source: null
        property var screen: null
        property var holds: []
        property bool dragging: false
        property bool triggerHovered: false
        property bool panelHovered: false
    }

    function show(xPos: real, tooltipContent: Component, tooltipSource, screenCentered, tooltipScreen) {
        if (_internal.dragging) return
        if (_internal.pinned) return
        if (root.interactionBlocksReplacement && _internal.source !== (tooltipSource ?? null)) return
        if (_internal.source !== (tooltipSource ?? null) || _internal.screen !== (tooltipScreen ?? null)) {
            _internal.keyboardActive = false
            _internal.holds = []
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
        if (_internal.pinned || root.interactionHeld || _internal.dragging) return
        if (_internal.triggerHovered || _internal.panelHovered) return
        hideTimer.start()
    }

    function togglePin(xPos: real, tooltipContent: Component, tooltipSource, screenCentered, tooltipScreen) {
        if (_internal.dragging || (interactionBlocksReplacement && source !== tooltipSource)) return
        _internal.keyboardActive = false
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

    function openForHover(xPos: real, tooltipContent: Component, tooltipSource, screenCentered, tooltipScreen) {
        if (_internal.dragging || (interactionBlocksReplacement && source !== tooltipSource)) return
        const wasManuallyPinned = _internal.pinned && _internal.source === tooltipSource
            && _internal.screen === (tooltipScreen ?? null)
        _internal.pinned = false
        _internal.keyboardActive = false
        show(xPos, tooltipContent, tooltipSource, screenCentered, tooltipScreen)
        _internal.pinned = wasManuallyPinned
    }

    function openForKeyboard(xPos: real, tooltipContent: Component, tooltipSource, screenCentered, tooltipScreen) {
        if (_internal.dragging || (interactionBlocksReplacement && source !== tooltipSource)) return
        openForHover(xPos, tooltipContent, tooltipSource, screenCentered, tooltipScreen)
        _internal.keyboardActive = true
        hideTimer.stop()
        focusRequested()
    }

    function dismiss() {
        hideTimer.stop()
        _internal.visible = false
        _internal.pinned = false
        _internal.keyboardActive = false
        _internal.holds = []
        _internal.triggerHovered = false
        _internal.panelHovered = false
        _internal.content = null
        _internal.source = null
        _internal.screen = null
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

    // Each owner releases only its own hold. Replacing/closing the panel drops
    // every hold, so delayed child callbacks cannot retain the next panel.
    function setInteraction(owner, active, blocksReplacement = true) {
        if (!active && !_internal.holds.some(hold => hold.owner === owner)) return
        const remaining = _internal.holds.filter(hold => hold.owner !== owner)
        _internal.holds = active && visible ? [...remaining, {owner, blocksReplacement}] : remaining
        if (root.interactionHeld) hideTimer.stop()
        else hide()
    }

    function setTriggerHovered(tooltipSource, hovered) {
        if (_internal.source !== (tooltipSource ?? null)) return
        _internal.triggerHovered = hovered
        if (hovered) cancelHide()
        else if (!_internal.panelHovered) hide()
    }

    function setPanelHovered(hovered) {
        if (_internal.panelHovered && !hovered) _internal.keyboardActive = false
        _internal.panelHovered = hovered
        if (hovered) cancelHide()
        else if (!_internal.triggerHovered) hide()
    }

    Timer {
        id: hideTimer
        interval: Config.tooltipHideDelay
        // A queued expiry can outlive a hover, pin, interaction or drag transition.
        onTriggered: if (!_internal.pinned && !root.interactionHeld && !_internal.dragging
            && !_internal.triggerHovered && !_internal.panelHovered) root.dismiss()
    }
}
