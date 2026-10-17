import "../../i18n"
import "../../theme"
import "../../services"
import "../../theme/ui"

ActivityIndicator {
    moduleName: "recording"
    visible: RecordingService.active || RecordingService.state === "finalizing"
    heading: {
        switch (RecordingService.state) {
            case "stopping":
            case "finalizing":
            case "recovering": return Translations.text("recording.status.finishing")
            default: return Translations.text("recording.indicator.label")
        }
    }
    details: RecordingService.filename ? [RecordingService.filename] : []
    tooltipWidth: Theme.recordingTooltipWidth
    icon: Theme.recordingIcon
    pulseColor: Theme.recordingPulseColor
    animationEnabled: MotionPolicy.recordingPulseEnabled
}
