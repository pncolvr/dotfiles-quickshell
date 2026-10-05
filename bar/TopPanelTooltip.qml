pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import "../theme"
import "../theme/ui" as UI

// Quickshell selects a creatable PanelWindow backend at runtime.
// qmllint disable uncreatable-type
PanelWindow {
    // qmllint enable uncreatable-type
    id: root

    default property alias contentData: panel.data
    property alias contentX: panel.x
    property alias contentWidth: panel.width
    property alias contentHeight: panel.height
    readonly property int shadowBlurRadius: Math.max(2, Math.min(64, Theme.tooltipShadowBlurRadius))
    readonly property real shadowBottomPadding: Theme.tooltipShadowEnabled
        ? shadowBlurRadius + Math.max(0, Theme.tooltipShadowVerticalOffset) : 0

    anchors.top: true
    exclusiveZone: 0
    implicitWidth: screen.width
    implicitHeight: Math.ceil(panel.height + shadowBottomPadding)
    color: "transparent"

    // Only the panel receives input; transparent joins and shadow pass it through.
    mask: Region { x: root.contentX; width: root.contentWidth; height: root.contentHeight }

    UI.TooltipBackground {
        id: background
        x: panel.x - curveRadius
        y: panel.y
        panelWidth: panel.width
        height: panel.height
        layer.enabled: Theme.tooltipShadowEnabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Theme.tooltipShadowColor
            shadowOpacity: Theme.tooltipShadowOpacity
            blurMax: root.shadowBlurRadius
            shadowBlur: 1
            shadowHorizontalOffset: Theme.tooltipShadowHorizontalOffset
            shadowVerticalOffset: Theme.tooltipShadowVerticalOffset
            // MultiEffect pads for blur automatically; offsets need extra room.
            paddingRect: Qt.rect(Math.max(0, -Theme.tooltipShadowHorizontalOffset),
                Math.max(0, -Theme.tooltipShadowVerticalOffset),
                Math.max(0, Theme.tooltipShadowHorizontalOffset),
                Math.max(0, Theme.tooltipShadowVerticalOffset))
        }
    }

    // Keep content outside the effect so text and controls render directly.
    Item {
        id: panel
        y: 0
    }
}
