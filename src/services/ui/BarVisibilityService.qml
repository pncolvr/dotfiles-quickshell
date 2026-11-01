pragma Singleton
import QtQml
import Quickshell.Hyprland
import "../../config"

QtObject {
    id: root
    readonly property bool enabled: Config.barAutoHideEnabled
    property var bars: []

    function register(bar) { bars = bars.concat([bar]) }
    function unregister(bar) { bars = bars.filter(candidate => candidate !== bar) }

    function toggleVisibility() {
        if (!enabled) return false
        const monitorName = Hyprland.focusedMonitor?.name ?? ""
        const bar = bars.find(candidate => candidate.screenName === monitorName) ?? bars[0]
        if (!bar) return false
        bar.manualVisibility = bar.shown ? -1 : 1
        return true
    }
}
