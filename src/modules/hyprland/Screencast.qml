import "../../i18n"
import "../../theme"
import "../../services"
import "../../ui"

ActivityIndicator {
    moduleName: "sharing"
    visible: AudioService.screencastActive
    heading: Translations.text("screenshare.indicator.label")
    details: AudioService.screencastStreams.map(stream => stream.description)
    tooltipWidth: Theme.screencastTooltipWidth
    icon: Theme.screencastIcon
    pulseColor: Theme.screencastPulseColor
    animationEnabled: MotionPolicy.screenSharePulseEnabled
}
