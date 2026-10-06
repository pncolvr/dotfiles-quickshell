import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Item {
    id: root
    required property var battery
    readonly property color fillColor: Theme.batteryLevelColors[BatteryService.levelStatus(battery.percentage)]
    implicitHeight: Theme.batteryRowHeight

    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.batteryTerminalWidth
        height: Theme.batteryTerminalHeight
        radius: 2
        color: Theme.batteryBorderColor
    }

    Rectangle {
        id: body
        objectName: "batteryBody"
        width: parent.width - Theme.batteryTerminalWidth
        height: parent.height
        radius: Theme.batteryRadius
        color: Theme.batteryEmptyColor
        clip: true

        Rectangle {
            objectName: "batteryFill"
            x: 1
            y: 1
            width: (parent.width - 2) * (root.battery.percentage ?? 0) / 100
            height: parent.height - 2
            radius: Math.max(0, Theme.batteryRadius - 1)
            color: root.fillColor
            opacity: Theme.batteryFillOpacity
        }

        Item {
            anchors.fill: parent
            anchors.margins: Theme.batteryPadding

            Item {
                id: topLine
                anchors.top: parent.top
                width: parent.width
                height: Math.max(name.implicitHeight, percentage.implicitHeight)

                UI.Text {
                    id: name
                    objectName: "batteryName"
                    anchors.left: parent.left
                    anchors.right: percentage.left
                    anchors.rightMargin: Theme.batteryTextSpacing
                    textFormat: Text.PlainText
                    text: BatteryService.displayName(root.battery)
                    elide: Text.ElideRight
                }

                UI.Text {
                    id: percentage
                    objectName: "batteryPercentage"
                    anchors.right: parent.right
                    text: root.battery.percentage === null ? "Level unavailable" : Math.round(root.battery.percentage) + "%"
                    font.pixelSize: root.battery.percentage === null ? Theme.fontSize : Theme.batteryPercentageFontSize
                }
            }

            Item {
                anchors.bottom: parent.bottom
                width: parent.width
                height: status.implicitHeight

                UI.Text {
                    objectName: "batteryTime"
                    anchors.left: parent.left
                    anchors.right: status.left
                    anchors.rightMargin: Theme.batteryTextSpacing
                    visible: text.length > 0
                    text: BatteryService.timeText(root.battery)
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                }

                Row {
                    id: status
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.batteryTextSpacing

                    UI.Text {
                        objectName: "batteryStatus"
                        text: BatteryService.statusText(root.battery.state)
                    }
                    UI.IconText {
                        objectName: "batteryPowerIcon"
                        visible: root.battery.pluggedIn
                        text: Theme.batteryPlugIcon
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: body
        radius: Theme.batteryRadius
        color: "transparent"
        border.width: 1
        border.color: Theme.batteryBorderColor
    }
}
