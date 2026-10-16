import Quickshell.Wayland
import "../config"

// Same presentation and lifetime; privacy remains fixed on the native window.
TopPanelTooltip {
    WlrLayershell.namespace: Config.screenShareHiddenNamespace
}
