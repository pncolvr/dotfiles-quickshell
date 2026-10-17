pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../../theme"

TooltipArea {
    id: root
    required property string heading
    required property string icon
    required property color pulseColor
    required property bool animationEnabled
    property var details: []
    property real tooltipWidth: Theme.tooltipWidth
    tooltip: activityTooltip

    Component {
        id: activityTooltip
        Column {
            width: root.tooltipWidth
            spacing: Theme.controlSpacing
            ColumnText { text: root.heading; color: Theme.accent }
            Repeater {
                model: root.details
                delegate: ColumnText {
                    required property string modelData
                    width: parent.width
                    text: modelData
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    color: Theme.inactive
                }
            }
        }
    }

    BarIcon {
        centerGlyphVertically: true
        font.pixelSize: Theme.fontSize
        color: root.moduleIconColor
        animationEnabled: root.animationEnabled
        pulsing: !root.pinned
        pulseColor: root.pulseColor
        text: root.icon
    }
}
