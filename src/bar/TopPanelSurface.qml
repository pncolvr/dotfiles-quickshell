pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import "../theme"
import "../theme/ui" as UI

Item {
    id: root

    default property alias contentData: panel.data
    property alias contentX: panel.x
    property alias contentWidth: panel.width
    property alias contentHeight: panel.height
    // Same-window popups must stay inside the panel's visible input region.
    readonly property Item popupContentBounds: panel
    property real backgroundOpacity: 1
    readonly property int shadowBlurRadius: Math.max(2, Math.min(64, Theme.tooltipShadowBlurRadius))
    readonly property real shadowBottomPadding: Theme.tooltipShadowEnabled
        ? shadowBlurRadius + Math.max(0, Theme.tooltipShadowVerticalOffset) : 0

    readonly property rect inputRect: Qt.rect(contentX, 0, contentWidth, contentHeight)
    implicitHeight: Math.ceil(panel.height + shadowBottomPadding)

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
        backgroundOpacity: root.backgroundOpacity
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
