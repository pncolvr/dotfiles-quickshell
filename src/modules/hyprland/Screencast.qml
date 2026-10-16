import "../../theme"
import "../../services"
import "../../theme/ui"

ActivityIndicator {
    moduleName: "sharing"
    visible: AudioService.screencastActive
    heading: "Screen sharing"
    details: AudioService.screencastStreams.map(stream => stream.description)
    tooltipWidth: Theme.screencastTooltipWidth
    icon: Theme.screencastIcon
    pulseColor: Theme.screencastPulseColor
    animationEnabled: MotionPolicy.screenSharePulseEnabled
}
