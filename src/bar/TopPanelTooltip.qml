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
    mask: Region { x: root.contentX; y: panel.y; width: root.contentWidth; height: root.contentHeight }

    // Include the bar above the surface in the silhouette. Blurring only the
    // popup would give its shadow a detached, flat upper edge at the join.
    Item {
        id: shadowSource
        readonly property real barExtent: Math.max(Theme.barHeight,
            root.shadowBlurRadius + Math.max(0, -Theme.tooltipShadowVerticalOffset))
        y: -barExtent
        width: root.width
        height: barExtent + panel.height
        visible: false

        Rectangle {
            width: parent.width
            height: shadowSource.barExtent
            color: Theme.background
        }
        UI.TooltipBackground {
            x: background.x
            y: shadowSource.barExtent
            panelWidth: panel.width
            height: panel.height
        }
    }

    MultiEffect {
        source: shadowSource
        x: Theme.tooltipShadowHorizontalOffset
        y: shadowSource.y + Theme.tooltipShadowVerticalOffset
        width: shadowSource.width
        height: shadowSource.height
        visible: Theme.tooltipShadowEnabled
        blurEnabled: true
        blurMax: root.shadowBlurRadius
        blur: 1
        colorization: 1
        colorizationColor: Theme.tooltipShadowColor
        opacity: Theme.tooltipShadowOpacity * Theme.tooltipShadowColor.a
    }

    UI.TooltipBackground {
        id: background
        x: panel.x - curveRadius
        y: panel.y
        panelWidth: panel.width
        height: panel.height
    }

    // Keep content outside the effect so text and controls render directly.
    Item {
        id: panel
        y: 0
    }
}
