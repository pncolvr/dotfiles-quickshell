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
            case "recovering": return "Recording finishing"
            default: return "Screen recording"
        }
    }
    details: RecordingService.filename ? [RecordingService.filename] : []
    tooltipWidth: Theme.recordingTooltipWidth
    icon: Theme.recordingIcon
    pulseColor: Theme.recordingPulseColor
    animationEnabled: MotionPolicy.recordingPulseEnabled
}
