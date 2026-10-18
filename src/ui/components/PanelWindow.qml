import QtQuick
import Quickshell
import "../../services"

// Quickshell selects a creatable PanelWindow backend at runtime.
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    color: AdaptiveBarService.backgroundFor(screen)
}
