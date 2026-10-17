pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import "../theme"
import "../theme/ui" as UI
import "../services"

TopPanelTooltip {
    id: root
    requestedVisible: AlertService.messages.length > 0
    // Status must remain visible over fullscreen apps without taking focus.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    readonly property real maximumTextWidth: Math.max(1,
        (geometryScreen?.width ?? 800) - Theme.tooltipRadius * 2 - Theme.tooltipPaddingWidth * 2)

    contentX: width - contentWidth - Theme.tooltipRadius + 1
    contentWidth: alertColumn.implicitWidth + Theme.tooltipPaddingWidth * 2
    contentHeight: alertColumn.implicitHeight + Theme.tooltipPaddingHeight * 2

    Column {
        id: alertColumn
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: AlertService.messages
            delegate: UI.Text {
                required property var modelData
                centerVertical: false
                text: modelData.text
                textFormat: Text.PlainText
                width: Math.min(implicitWidth, root.maximumTextWidth)
                wrapMode: Text.Wrap
                color: {
                    switch (modelData.severity) {
                        case "info": return Theme.text
                        case "success": return Theme.ok
                        case "warning": return Theme.warning
                        default: return Theme.urgent
                    }
                }
            }
        }
    }
}
