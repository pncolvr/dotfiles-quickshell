pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
import "../theme/ui" as UI
import "../services"

TopPanelTooltip {
    visible: AlertService.messages.length > 0

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
                color: Theme.urgent
            }
        }
    }
}
