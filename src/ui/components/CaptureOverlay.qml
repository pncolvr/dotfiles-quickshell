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
    property bool captureParticipant: false
    // A closing Loader can release its content (and its opt-in property) before
    // the native surface unmaps. Retain that participation through the close.
    function synchronizeParticipation() {
        if (requested) captureParticipant = hideForCapture
        else if (!presentationPending) captureParticipant = false
    }
    onRequestedChanged: synchronizeParticipation()
    onPresentationPendingChanged: synchronizeParticipation()
    onHideForCaptureChanged: {
        if (hideForCapture) synchronizeParticipation()
        else Qt.callLater(synchronizeParticipation)
    }
    readonly property bool presented: captureParticipant && (requested || presentationPending)
    onPresentedChanged: CaptureHandoffService.update(root, presented)
    function hide() { host.captureHideRequested() }
    Component.onCompleted: { synchronizeParticipation(); CaptureHandoffService.registerPanel(root); CaptureHandoffService.update(root, presented) }
    Component.onDestruction: CaptureHandoffService.unregisterPanel(root)
}
