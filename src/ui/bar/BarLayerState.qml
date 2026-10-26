import QtQml
import Quickshell.Wayland
import "../../services"

QtObject {
    required property var screen
    readonly property bool overlay: AdaptiveBarService.overlays.some(attachment =>
        attachment.revealsBar && attachment.host.screen === screen
            && (attachment.requested || attachment.presentationPending))
    readonly property int layer: overlay ? WlrLayer.Overlay : WlrLayer.Top
}
