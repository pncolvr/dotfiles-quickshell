pragma Singleton
import QtQml
import "../../config"
import "../../services"

QtObject {
    function allowsMotion(allowDuringSharing, sharing) { return allowDuringSharing || !sharing }
    readonly property bool sharingAllowed: allowsMotion(Config.animateDuringScreenShare, AudioService.screencastActive)
    readonly property bool enabled: Config.animationsEnabled && sharingAllowed
    // Status feedback stays available when decorative motion is disabled.
    readonly property bool screenSharePulseEnabled: Config.screenSharePulseEnabled
    readonly property bool recordingPulseEnabled: Config.recordingPulseEnabled
    readonly property bool notificationBorderEnabled: Config.notificationBorderAnimationEnabled
    readonly property bool micPulseEnabled: Config.micPulseEnabled
    readonly property bool volumePulseEnabled: Config.volumePulseEnabled
}
