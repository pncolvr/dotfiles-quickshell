pragma Singleton

import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../" as Services

Singleton {
    id: root
    property var modules: []
    function register(item) { modules = [...modules, item] }
    function unregister(item) { modules = modules.filter(module => module !== item) }

    function open(name) {
        if (Services.TooltipService.dragging) return false
        const screen = Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name)
            ?? Quickshell.screens[0]
        const item = modules.find(module => module.moduleName === name && module.tooltipScreen === screen
            && module.visible && module.enabled)
        if (!item) return false
        if (item.tooltip) {
            const pos = item.mapToGlobal(item.width / 2, 0)
            Services.TooltipService.openForKeyboard(pos.x, item.tooltip, item, item.centerTooltip, screen)
        } else return false

        return Services.TooltipService.source === item
    }

    IpcHandler {
        target: "bar"
        function open(module: string): bool { return root.open(module) }
    }
}
