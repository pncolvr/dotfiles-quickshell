pragma Singleton
import QtQml

// A temporary picker can borrow focus without closing the panels underneath it.
QtObject {
    id: root
    property var handlers: []
    property var owner: null
    property var target: null
    property var heldSessions: []
    property var returnHandler: null
    readonly property bool active: owner !== null

    function register(handler) { handlers = handlers.concat([handler]) }
    function unregister(handler) {
        handlers = handlers.filter(item => item !== handler)
        if (target?.handler === handler) target = null
        if (returnHandler === handler) { returnHandler = null; finishReturn() }
    }
    function held(handler) {
        return active && handler.handoffOwner !== owner
            && heldSessions.some(saved => saved.handler === handler && saved.session === handler.focusSession)
    }
    function textPosition(item) {
        if (typeof item?.text !== "string" || typeof item.cursorPosition !== "number"
            || typeof item.select !== "function") return null
        return {text:item.text, cursor:item.cursorPosition, start:item.selectionStart, end:item.selectionEnd}
    }
    function restoreTextPosition(item, saved) {
        // A form may update while Clipboard is open. Never reapply positions to
        // changed text, or restore a selection belonging to another field.
        if (!saved || item.text !== saved.text) return
        item.cursorPosition = saved.cursor
        if (saved.start !== saved.end) {
            const backwards = saved.cursor === saved.start
            item.select(backwards ? saved.end : saved.start, backwards ? saved.start : saved.end)
        }
    }
    function begin(session) {
        if (owner === session) return
        returnHandler = null
        const handler = handlers.find(item => item.hostRequestedVisible && item.windowActive
            && item.ready && !item.blocked && !item.nativeDialogOpen)
        const item = handler?.nativeWindow?.activeFocusItem
        target = handler ? {handler, session:handler.focusSession, item, position:textPosition(item)} : null
        heldSessions = handlers.filter(item => item.hostRequestedVisible)
            .map(item => ({handler:item, session:item.focusSession}))
        // Set the hold before the new window can clear the old native focus grab.
        owner = session
        TooltipService.setInteraction(root, true, true)
    }
    function hasTarget(session) {
        return owner === session && !!target && handlers.includes(target.handler)
            && target.handler.hostRequestedVisible && target.handler.focusSession === target.session
    }
    function finishReturn() {
        if (active) return
        if (returnHandler?.hostRequestedVisible && returnHandler.requestingKeyboardFocus
            && !returnHandler.windowActive) return
        returnHandler = null
        TooltipService.setInteraction(root, false)
    }
    property Connections returnChanges: Connections {
        target: root.returnHandler
        function onWindowActiveChanged() { root.finishReturn() }
        function onHostRequestedVisibleChanged() { root.finishReturn() }
        function onRequestingKeyboardFocusChanged() { root.finishReturn() }
    }
    function finish(session, paste = false, restore = true) {
        if (owner !== session) return
        const previous = hasTarget(session) ? target : null
        target = null
        owner = null
        heldSessions = []
        // Let the outgoing window release Qt/native activation before restoring
        // the field; otherwise that release can clear the just-restored focus.
        Qt.callLater(() => {
            if (root.active) return
            if (restore && previous && root.handlers.includes(previous.handler)
                && previous.handler.hostRequestedVisible && previous.handler.focusSession === previous.session) {
                root.returnHandler = previous.handler
                const restored = previous.handler.restoreFocus(previous.item)
                if (restored) root.restoreTextPosition(previous.item, previous.position)
                // Qt's text controls paste from the clipboard directly, including
                // normal selection replacement. No payload is read into this service.
                if (paste && restored && previous.item?.visible && previous.item.enabled
                    && typeof previous.item.paste === "function") previous.item.paste()
            }
            root.finishReturn()
        })
    }
}
