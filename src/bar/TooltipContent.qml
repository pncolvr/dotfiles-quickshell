pragma ComponentBehavior: Bound
import QtQuick
import "../ui" as UI
import "../theme"
import "../services"

UI.PanelFocusScope {
    id: root
    required property var host
    property bool hideForCapture: loadedContent?.hideForCapture ?? false
    property Component retainedContent: null
    readonly property var loadedContent: loader.item
    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight
    panel: loader.item
    onDismissRequested: TooltipService.dismiss()
    function syncContent() {
        if (host.requestedVisible) retainedContent = TooltipService.content
        else if (!host.visible) retainedContent = null
    }
    Binding { target: root.host; property: "contentKey"; value: root.retainedContent }
    Component.onCompleted: syncContent()
    Connections { target: TooltipService; function onContentChanged() { root.syncContent() } }
    Connections {
        target: root.host
        function onRequestedVisibleChanged() { root.syncContent() }
        function onVisibleChanged() { root.syncContent() }
    }
    Loader {
        id: loader
        active: root.host.visible
        // Content belongs at the top even while the old native height is
        // retained for a resize. Vertical centering flashes shorter tabs midway
        // down the outgoing panel before its new geometry has been committed.
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.tooltipPaddingHeight
        sourceComponent: root.retainedContent
        onLoaded: if (root.host.requestedVisible && TooltipService.keyboardActive) root.focusSearch()
    }
}
