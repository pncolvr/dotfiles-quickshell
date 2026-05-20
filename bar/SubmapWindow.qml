pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../theme"
import "../theme/ui" as UI
import "../services"

TopPanelTooltip {
    id: root

    visible: SubmapService.submapActive

    contentX: width - contentWidth - Theme.tooltipRadius + 1
    contentWidth: Math.min(Theme.submapWindowMaxWidth, keybindsColumn.implicitWidth + Theme.tooltipPaddingWidth * 2)
    contentHeight: keybindsColumn.implicitHeight + Theme.tooltipPaddingHeight * 2

    ColumnLayout {
        id: keybindsColumn
        anchors.centerIn: parent
        width: root.contentWidth - Theme.tooltipPaddingWidth * 2
        spacing: 4

        Repeater {
            model: SubmapService.keybinds
            delegate: RowLayout {
                id: row
                required property var modelData
                spacing: 16
                Layout.fillWidth: true

                UI.Text {
                    text: row.modelData.key
                    color: Theme.accent
                }

                UI.Text {
                    text: row.modelData.action
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                    UI.HoverTooltip {
                        text: parent.text
                    }
                }
            }
        }
    }
}
