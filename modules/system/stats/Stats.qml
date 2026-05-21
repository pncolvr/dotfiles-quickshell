pragma ComponentBehavior: Bound

import QtQuick
import "../../../theme/ui" as UI
import "../../../theme"
import "../../../services"
import "../../../config"
import "../"
UI.Row {
    id: root
    property bool expanded: hoverHandler.hovered || TooltipService.source === root
    onExpandedChanged: {
        StatsService.active = expanded
        NetworkService.active = expanded
        statsBackground.visible = expanded
    }
    
    HoverHandler {
        id: hoverHandler
        target: root
    }

    UI.IconText {
        text: expanded ? Theme.statsOpenIcon : Theme.statsClosedIcon
    }

    Rectangle {
        id: statsBackground
        visible: false
        color: Theme.expandedBackground
        radius: Theme.expandedBackgroundRadius
        implicitWidth: items.implicitWidth + Theme.expandedBackgroundPaddingWidth * 2
        implicitHeight: items.implicitHeight + Theme.expandedBackgroundPaddingHeight

        UI.Row {
            id: items
            spacing: Theme.moduleSpacing
            anchors.centerIn: parent

            UI.TooltipArea {
                tooltipSource: root
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
                tooltipSource: root
                tooltip: Component { MemoryTooltip {} }
                UI.Text {
                    text: `${(StatsService.memoryUsed / 1024).toFixed(1)}G`
                }
            }

            UI.TooltipArea {
                tooltipSource: root
                tooltip: Component { CpuTooltip {} }
                UI.Text {
                    text: `${String(StatsService.cpu).padStart(3)}%`
                }
            }

            UI.Text {
                text: `${String(Math.round(StatsService.temperature)).padStart(3)}°C`
            }

            UI.TooltipArea {
                tooltipSource: root
                tooltip: Component { NetworkTooltip {} }
                UI.IconText {
                    text: Theme.networkIcon
                }
            }
        }
    }


}