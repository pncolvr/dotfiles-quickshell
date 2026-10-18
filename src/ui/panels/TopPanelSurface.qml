pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../../theme"
import ".." as UI

Item {
    id: root
    default property alias contentData: panel.data
    property real contentX: 0
    property real contentWidth: 0
    property real contentHeight: 0
    property bool requestedVisible: false
    property bool continuousGeometry: false
    property alias centeredResize: presentation.centeredResize
    property alias contentKey: presentation.contentKey
    property real reservedContentHeight: 0
    property var requestedScreen: null
    property alias motion: presentation
    readonly property bool presented: presentation.presented
    readonly property Item popupContentBounds: contentClip
    property real backgroundOpacity: 1
    property color backgroundColor: Theme.tooltipBackground
    property bool islandMode: false
    property real shadowVisibility: requestedVisible ? 1 : 0
    UI.MotionBehavior on shadowVisibility {
        motionEnabled: presentation.motionAllowed
        UI.MotionAnimation {
            animationDuration: root.requestedVisible ? Theme.panelOpenDuration : Theme.panelCloseDuration
            easing.type: root.requestedVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    readonly property int shadowBlurRadius: Math.max(2, Math.min(64, Theme.tooltipShadowBlurRadius))
    readonly property real shadowBottomPadding: Theme.tooltipShadowEnabled
        ? shadowBlurRadius + Math.max(0, Theme.tooltipShadowVerticalOffset) : 0
    readonly property rect inputRect: requestedVisible ? Qt.rect(presentation.displayedX, 0, presentation.displayedWidth,
        Math.max(0, presentation.displayedHeight + presentation.offsetY)) : Qt.rect(0,0,0,0)
    implicitHeight: Math.ceil(presentation.reservedHeight + shadowBottomPadding)
    clip: true

    UI.PanelMotion {
        id: presentation
        requested: root.requestedVisible
        targetX: root.contentX
        targetWidth: root.contentWidth
        targetHeight: root.contentHeight
        reserveHeight: root.reservedContentHeight
        targetScreen: root.requestedScreen
        continuousGeometry: root.continuousGeometry
    }
    // Keep the bar edge fixed. Only the panel silhouette moves inside a capture
    // sized for the complete transition, avoiding per-frame shadow reallocations.
    Item {
        id: shadowSource
        objectName: "topPanelShadowSource"
        readonly property real barExtent: Math.max(Theme.barHeight,
            root.shadowBlurRadius + Math.max(0, -Theme.tooltipShadowVerticalOffset))
        y: -barExtent
        width: root.width
        height: barExtent + presentation.reservedHeight
        visible: false
        Rectangle {
            x: root.islandMode ? presentation.displayedX : 0
            width: root.islandMode ? presentation.displayedWidth : parent.width
            height: shadowSource.barExtent
            color: root.backgroundColor
        }
        UI.TooltipBackground {
            x: background.x
            y: shadowSource.barExtent + presentation.offsetY
            panelWidth: presentation.displayedWidth
            backgroundColor: root.backgroundColor
            barJoin: !root.islandMode
            height: presentation.displayedHeight
        }
    }
    MultiEffect {
        objectName: "topPanelShadow"
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
        opacity: root.shadowVisibility * Theme.tooltipShadowOpacity * Theme.tooltipShadowColor.a
    }
    Item {
        id: body
        width: root.width
        height: root.height
        y: presentation.offsetY
        UI.TooltipBackground {
            id: background
            backgroundOpacity: root.backgroundOpacity
            backgroundColor: root.backgroundColor
            barJoin: !root.islandMode
            x: presentation.displayedX - joinRadius
            panelWidth: presentation.displayedWidth
            height: presentation.displayedHeight
        }
        Item {
            id: contentClip
            x: presentation.displayedX
            width: presentation.displayedWidth
            height: presentation.displayedHeight
            clip: true
            enabled: root.requestedVisible
            Item {
                id: panel
                opacity: Math.min(presentation.fraction, presentation.contentOpacity)
                width: presentation.layoutWidth
                height: presentation.layoutHeight
            }
        }
    }
}
