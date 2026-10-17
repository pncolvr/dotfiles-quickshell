pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "../../theme"
import "../../ui" as UI

// Shared floating geometry, content lifetime and motion; the native host stays thin.
Item {
    id: root
    required property var host
    required property var picker
    required property var previewPanel
    property var requestedScreen: host.requestedScreen
    readonly property bool hideForCapture: previewPanel?.hideForCapture ?? false
    readonly property real shadowRadius: Theme.tooltipShadowEnabled
        ? Math.max(2, Math.min(64, Theme.tooltipShadowBlurRadius)) : 0
    readonly property real shadowTop: Theme.tooltipShadowEnabled ? shadowRadius + Math.max(0, -Theme.tooltipShadowVerticalOffset) : 0
    readonly property real shadowBottom: Theme.tooltipShadowEnabled ? shadowRadius + Math.max(0, Theme.tooltipShadowVerticalOffset) : 0
    readonly property real horizontalInset: Math.max(Theme.tooltipPaddingWidth,
        Theme.tooltipShadowEnabled ? shadowRadius + Math.abs(Theme.tooltipShadowHorizontalOffset) : 0)
    // Use one visible margin above and below the preview; shadow bounds are
    // minimum insets, rather than extra gaps stacked between the two panels.
    readonly property real verticalMargin: Math.max(Theme.pickerPreviewGap,
        Theme.tooltipPaddingWidth, host.shadowBottomPadding, shadowTop,
        shadowBottom + Theme.controlSpacing)
    readonly property real listBottom: Math.max(host.contentHeight, host.layoutContentHeight,
        host.surfaceComponent?.motion?.displayedHeight ?? 0)
    readonly property real maximumPreviewHeight: Math.max(0, (requestedScreen?.height ?? 1080)
        - Theme.barHeight - listBottom - verticalMargin * 2)
    readonly property real previewWidth: Math.max(0, Math.min(Theme.pickerPreviewWidth,
        (requestedScreen?.width ?? 800) - horizontalInset * 2))
    readonly property real horizontalPadding: Theme.tooltipPaddingWidth
    readonly property real verticalPadding: Theme.tooltipPaddingHeight
    readonly property size imageNaturalSize: previewItem?.imageNaturalSize ?? Qt.size(0, 0)
    readonly property real fittedImageHeight: imageNaturalSize.width > 0 && imageNaturalSize.height > 0
        ? Math.min(imageNaturalSize.height / Screen.devicePixelRatio,
            Math.max(0, previewWidth - (horizontalPadding + Theme.controlSpacing) * 2)
                * imageNaturalSize.height / imageNaturalSize.width)
            + (verticalPadding + Theme.controlSpacing) * 2
        : maximumPreviewHeight
    readonly property real previewHeight: Math.min(maximumPreviewHeight, fittedImageHeight)
    readonly property real previewTop: listBottom + verticalMargin + (maximumPreviewHeight - previewHeight) / 2
    readonly property real previewCenterY: listBottom + verticalMargin + maximumPreviewHeight / 2
    property real displayedCenterY: previewCenterY
    readonly property real displayedTop: displayedCenterY - presentation.displayedHeight / 2
    function syncTop() {
        const panel = previewPanel?.panel ?? previewPanel
        if (picker.visible && host.requestedVisible && panel?.previewEnabled === true) displayedCenterY = previewCenterY
    }
    onPreviewCenterYChanged: syncTop()
    onRequestedVisibleChanged: if (requestedVisible) syncTop()
    readonly property bool requestedVisible: host.requestedVisible && !!previewPanel?.floatingPreviewRequested
        && previewHeight > Theme.tooltipPaddingHeight * 2
    readonly property var previewItem: preview.item
    readonly property bool transitioning: presentation.transitioning
    readonly property bool presented: presentation.presented && presentation.displayedWidth > 0 && presentation.displayedHeight > 0
    readonly property var displayedScreen: presentation.displayedScreen
    readonly property rect inputRect: requestedVisible ? Qt.rect(card.x,card.y,card.width,card.height) : Qt.rect(0,0,0,0)
    UI.PanelMotion {
        id: presentation
        requested: root.requestedVisible
        continuousGeometry: root.host.transitioning ?? false
        targetScreen: root.requestedScreen
        targetX: (root.width - root.previewWidth) / 2
        targetWidth: root.previewWidth
        targetHeight: root.previewHeight
    }
    Item {
        id: shadowSource
        visible: false
        width: card.width
        height: card.height
        Rectangle { anchors.fill: parent; radius: Theme.tooltipRadius; color: Theme.background }
    }
    MultiEffect {
        objectName: "floatingPickerShadow"
        source: shadowSource
        x: card.x + Theme.tooltipShadowHorizontalOffset
        y: card.y + Theme.tooltipShadowVerticalOffset
        width: shadowSource.width
        height: shadowSource.height
        visible: Theme.tooltipShadowEnabled
        blurEnabled: true
        blurMax: Math.max(2, Math.min(64, Theme.tooltipShadowBlurRadius))
        blur: 1
        colorization: 1
        colorizationColor: Theme.tooltipShadowColor
        opacity: presentation.fraction * Theme.tooltipShadowOpacity * Theme.tooltipShadowColor.a
    }
    Rectangle {
        id: card
        objectName: "floatingPickerPreview"
        x: presentation.displayedX
        y: root.displayedTop + Theme.controlSpacing * (1 - presentation.fraction)
        width: presentation.displayedWidth
        height: presentation.displayedHeight
        opacity: presentation.fraction
        radius: Theme.tooltipRadius
        color: Qt.rgba(Theme.tooltipBackground.r, Theme.tooltipBackground.g,
            Theme.tooltipBackground.b, Theme.tooltipBackground.a * Theme.pickerBackgroundOpacity)
        enabled: root.requestedVisible
        Loader {
            id: preview
            anchors.fill: parent
            anchors.leftMargin: root.horizontalPadding
            anchors.rightMargin: root.horizontalPadding
            anchors.topMargin: root.verticalPadding
            anchors.bottomMargin: root.verticalPadding
            clip: true
            active: presentation.presented
            sourceComponent: root.previewPanel?.floatingPreviewComponent ?? null
        }
    }
}
