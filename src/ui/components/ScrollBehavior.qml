pragma ComponentBehavior: Bound
import QtQuick

// Scroll viewports accept wheels and scrollbar drags, never content flicks.
Item {
    id: root
    required property Flickable viewport
    visible: false

    property Binding interaction: Binding {
        target: root.viewport
        property: "interactive"
        value: false
        when: root.viewport !== null
    }
    function enclosingBehavior(item: var): var {
        for (let parent = item; parent; parent = parent.parent) {
            const behavior = parent.scrollBehavior
            if (behavior?.viewport && behavior.viewport !== root.viewport
                && behavior.enabled && behavior.viewport.enabled) return behavior
        }
        return null
    }
    function handleWheel(event: WheelEvent): void {
        if (event.phase === Qt.ScrollMomentum) {
            event.accepted = true
            return
        }
        const view = root.viewport
        const minX = view.originX - view.leftMargin
        const minY = view.originY - view.topMargin
        const maxX = Math.max(minX, view.originX + view.contentWidth - view.width + view.rightMargin)
        const maxY = Math.max(minY, view.originY + view.contentHeight - view.height + view.bottomMargin)
        let dx = event.pixelDelta.x || event.angleDelta.x / 120 * 40
        let dy = event.pixelDelta.y || event.angleDelta.y / 120 * 40
        if (maxX > minX && ((event.modifiers & Qt.ShiftModifier) || maxY === minY)) {
            dx = dx || dy
            dy = 0
        }
        const x = dx && maxX > minX ? Math.max(minX, Math.min(maxX, view.contentX - dx)) : view.contentX
        const y = dy && maxY > minY ? Math.max(minY, Math.min(maxY, view.contentY - dy)) : view.contentY
        event.accepted = x !== view.contentX || y !== view.contentY
        if (!event.accepted) {
            // WheelHandler blocks native propagation. Hand a boundary event to
            // the nearest enclosing viewport using the same input policy.
            const enclosing = root.enclosingBehavior(view.parent)
            if (enclosing) enclosing.handleWheel(event)
            return
        }
        view.cancelFlick()
        if (x !== view.contentX) view.contentX = x
        if (y !== view.contentY) view.contentY = y
    }
    WheelHandler {
        parent: root.viewport ?? root
        target: null
        enabled: root.enabled && (root.viewport?.enabled ?? false)
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => root.handleWheel(event)
    }
}
