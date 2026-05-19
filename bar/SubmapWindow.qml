pragma ComponentBehavior: Bound
import QtQuick
import "../theme"
import "../theme/ui" as UI
import "../services"

TopPanelTooltip {
    id: root

    visible: SubmapService.submapActive

    contentX: width - contentWidth - Theme.tooltipRadius + 1
    contentWidth: Theme.submapWindowWidth
    contentHeight: keybindsColumn.implicitHeight + Theme.tooltipPaddingHeight * 2

    Column {
        id: keybindsColumn
        anchors.centerIn: parent
        width: root.contentWidth - Theme.tooltipPaddingWidth * 2
        spacing: 4

        Repeater {
            model: SubmapService.keybinds
            delegate: Row {
                id: row
                required property var modelData
                spacing: 16
                width: keybindsColumn.width

                UI.Text {
                    id: keyText
                    text: row.modelData.key
                    color: Theme.accent
                }

                UI.Text {
                    width: row.width - keyText.width - row.spacing
                    text: row.modelData.action
                    elide: Text.ElideMiddle
                    UI.HoverTooltip {
                        text: parent.text
                    }
                }
            }
        }
    }
}
