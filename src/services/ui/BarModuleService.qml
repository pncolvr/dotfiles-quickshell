pragma Singleton

import QtQml
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../" as Services
import "../../config"

Singleton {
    id: root
    property var modules: []
    property var hoverItem: null
    property var cursorItem: null
    property var pointerItem: null
    property bool pointerReady: false
    onPointerItemChanged: if (!pointerItem) pointerReady = false
    readonly property var pointerWindow: pointerItem?.tooltipWindow?.contentItem.Window.window ?? null

    Connections {
        target: root.pointerWindow
        function onFrameSwapped() {
            const item = root.pointerItem
            if (!item?.visible || !item.enabled) { root.pointerItem = null; return }
            if (item.tooltip) {
                const pos = item.mapToGlobal(item.width / 2, 0)
                Services.TooltipService.show(pos.x, item.tooltip, item, item.centerTooltip, item.tooltipScreen)
                root.pointerReady = true
            } else root.finishPointerMove()
        }
    }

    function finishPointerMove() {
        const item = pointerItem
        pointerItem = null
        if (item?.visible && item.enabled) movePointer(item)
    }

    function queuePointer(item) {
        pointerItem = item
        // Positioners settle after submap badges and expanded modules change size.
        if (pointerWindow) pointerWindow.update()
        else { pointerItem = null; movePointer(item) }
    }

    function register(item) { modules = [...modules, item] }
    function unregister(item) {
        if (pointerItem === item) pointerItem = null
        releasePointerHover(item)
        modules = modules.filter(module => module !== item)
    }

    function releasePointerHover(item) {
        if (hoverItem !== item) return
        hoverItem = null
        item.pointerHovered = false
    }

    Timer {
        interval: Config.tooltipPointerInterval
        running: !!root.hoverItem && cursorSocket.path.length > 0
        repeat: true
        onTriggered: if (!cursorSocket.connected) {
            root.cursorItem = root.hoverItem
            cursorSocket.connected = true
        }
    }
    Socket {
        id: cursorSocket
        path: Hyprland.requestSocketPath
        onConnectedChanged: if (connected) { write("j/cursorpos"); flush() }
        parser: SplitParser {
            splitMarker: "}"
            onRead: data => {
                cursorSocket.connected = false
                const item = root.cursorItem
                if (!item || item !== root.hoverItem) return
                try {
                    const cursor = JSON.parse(data + "}")
                    const pos = item.mapToGlobal(0, 0)
                    if (!item.visible || cursor.x < pos.x || cursor.x >= pos.x + item.width
                        || cursor.y < pos.y || cursor.y >= pos.y + item.height)
                        root.releasePointerHover(item)
                } catch (_) { /* Retry incomplete compositor replies. */ }
            }
        }
    }

    function movePointer(item) {
        if (!item || !Hyprland.requestSocketPath) return
        const target = item.modulePointerTarget ?? item
        const pos = target.mapToGlobal(target.width / 2, target.height / 2)
        if (hoverItem) releasePointerHover(hoverItem)
        // Cursor warps can leave Qt waiting for a physical pointer frame.
        if (!item.moduleFocusSearch) {
            hoverItem = item
            item.pointerHovered = true
        }
        Hyprland.dispatch(`hl.dsp.cursor.move({ x = ${Math.round(pos.x)}, y = ${Math.round(pos.y)} })`)
    }

    function open(name) {
        if (Services.TooltipService.dragging) return false
        const screen = Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name)
            ?? Quickshell.screens[0]
        const item = modules.find(module => module.moduleName === name && module.tooltipScreen === screen
            && module.visible && module.enabled)
        if (!item) return false
        pointerItem = null
        if (item.tooltip) {
            const pos = item.mapToGlobal(item.width / 2, 0)
            if (item.moduleFocusSearch) {
                Services.TooltipService.openForKeyboard(pos.x, item.tooltip, item, item.centerTooltip, screen)
                return true // Search focus moves the pointer after the panel renders.
            }
            Services.TooltipService.openForHover(pos.x, item.tooltip, item, item.centerTooltip, screen)
        } else Services.TooltipService.dismiss()
        queuePointer(item)
        return true
    }

    IpcHandler {
        target: "bar"
        function open(module: string): bool { return root.open(module) }
    }
}
