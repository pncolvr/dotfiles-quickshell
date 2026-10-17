pragma ComponentBehavior: Bound
import QtQml
import Quickshell
import "../../services"

// Follow logical requests and actual panel closing motion/native visibility.
Scope {
    id: root
    required property var host
    property bool requested: false
    property bool hideForCapture: host.hideForCapture ?? false
    property bool presentationPending: host.visible
    readonly property bool presented: hideForCapture && (requested || presentationPending)
    onPresentedChanged: CaptureHandoffService.update(root, presented)
    function hide() { host.captureHideRequested() }
    Component.onCompleted: { CaptureHandoffService.registerPanel(root); CaptureHandoffService.update(root, presented) }
    Component.onDestruction: CaptureHandoffService.unregisterPanel(root)
}
