pragma ComponentBehavior: Bound
import QtQml
import Quickshell
import "../../../services"

// Reusable presentation registration: follow the actual closing animation as well as requests.
Scope {
    id: root
    required property var host
    property bool requested: false
    property bool presentationPending: host.visible
    readonly property bool presented: requested || presentationPending
    onPresentedChanged: CaptureHandoffService.update(root, presented)
    Component.onCompleted: CaptureHandoffService.update(root, presented)
    Component.onDestruction: CaptureHandoffService.update(root, false)
}
