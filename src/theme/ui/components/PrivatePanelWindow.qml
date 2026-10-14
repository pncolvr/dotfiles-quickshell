import Quickshell
import Quickshell.Wayland
import "../../../config"

// Namespace belongs to the window and stays fixed for its lifetime.
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    WlrLayershell.namespace: Config.screenShareHiddenNamespace
}
