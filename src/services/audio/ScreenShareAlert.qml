import QtQml
import "../../i18n"
import "../"

QtObject {
    id: root
    property bool active: false
    property bool ready: false
    property string audioStatus: "unknown"
    property int duration: 15000
    property string lastMessage: ""
    readonly property bool desktopAudioCaptured: audioStatus === "desktop" || audioStatus === "both"
    readonly property string message: Translations.text("screenshare.alert.audio.desktop")
    function publish() {
        if (!active || (ready && !desktopAudioCaptured)) {
            AlertService.dismiss("screenshare-status")
            lastMessage = ""
        }
        // Keep the current alert during registry changes; do not announce a
        // partially discovered video node before camera filtering is ready.
        else if (ready && desktopAudioCaptured && message !== lastMessage) {
            AlertService.post("screenshare-status", message, "warning", duration)
            lastMessage = message
        }
    }
    onActiveChanged: Qt.callLater(root.publish)
    onReadyChanged: Qt.callLater(root.publish)
    onDesktopAudioCapturedChanged: Qt.callLater(root.publish)
    onMessageChanged: Qt.callLater(root.publish)
    Component.onCompleted: Qt.callLater(root.publish)
    Component.onDestruction: AlertService.dismiss("screenshare-status")
}
