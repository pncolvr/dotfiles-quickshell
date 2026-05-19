pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme/ui" as UI
import "../../../theme"
import "../../../services"
import "../../../config"
import "../"
UI.Row {
    id: root
    property bool expanded: hoverHandler.hovered
    onExpandedChanged: StatsService.active = expanded
    
    HoverHandler {
        id: hoverHandler
        target: root
        onHoveredChanged: root.expanded = hovered
    }

    UI.IconText {
        text: Theme.statsToggleIcon
    }

    UI.Row {
        id: items
        spacing: Theme.moduleSpacing
        visible: root.expanded
        
        UI.TooltipArea {
            tooltip: Component {
                UI.Text {
                    text: PowerProfileService.profile
                } 
            }
            UI.IconButton {
                onClicked: PowerProfileService.cycleProfile()
                text: Theme.powerProfileIcons[Config.powerProfiles.indexOf(PowerProfileService.profile)]
            }
        }
        
        UI.TooltipArea {
            tooltip: Component { MemoryTooltip {} }
            UI.Text {
                text: `${(StatsService.memoryUsed / 1024).toFixed(1)}G`
            }
        }

        UI.TooltipArea {
            tooltip: Component { CpuTooltip {} }
            UI.Text {
                text: `${StatsService.cpu}%`    
            }
        }

        UI.Text {
            text: `${Math.round(StatsService.temperature)}°C`
        }
    }


}