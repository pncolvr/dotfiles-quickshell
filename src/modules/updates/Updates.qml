import QtQuick
import "../../ui" as UI
import "../../theme"
import "../../services"
import "../../config"

UI.TooltipArea {
    id: root
    moduleName: "updates"
    visible: Config.updatesEnabled
    enabled: visible
    onVisibleChanged: if (!visible && TooltipService.source === root) TooltipService.dismiss()
    normalIconColor: UpdatesService.hasPriority ? Theme.warning : UpdatesService.hasUpdates ? Theme.text : Theme.empty
    cursorShape: Qt.PointingHandCursor
    tooltip: Component { UpdatesTooltip {} }
    property bool wasChecking: UpdatesService.checking

    Connections {
        target: UpdatesService
        function onCheckingChanged() {
            if (UpdatesService.checking) {
                completionTimer.stop()
                root.wasChecking = true
            } else if (root.wasChecking) {
                root.wasChecking = false
                completionTimer.restart()
            }
        }
    }

    Timer {
        id: completionTimer
        interval: Config.updatesPulseAfterDuration
        repeat: false
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    Row {
        spacing: 4

        UI.BarIcon {
            objectName: "updatesIcon"
            text: Theme.updatesIcon
            color: root.moduleIconColor
            animationEnabled: UI.MotionPolicy.updatesPulseEnabled
            pulsing: UpdatesService.scheduled || UpdatesService.checking || completionTimer.running
            baseColor: root.moduleIconColor
            pulseColor: Qt.rgba(root.moduleIconColor.r, root.moduleIconColor.g, root.moduleIconColor.b,
                root.moduleIconColor.a * 0.45)
        }
    }
}
