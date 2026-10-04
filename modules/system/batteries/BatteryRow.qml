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

        Column {
            anchors.centerIn: parent
            width: parent.width - Theme.batteryPadding * 2
            spacing: Theme.batteryTextSpacing

            UI.ColumnText {
                objectName: "batteryName"
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                textFormat: Text.PlainText
                text: root.battery.name
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            UI.ColumnText {
                objectName: "batteryPercentage"
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.battery.percentage === null ? "Level unavailable" : Math.round(root.battery.percentage) + "%"
                font.pixelSize: root.battery.percentage === null ? Theme.fontSize : Theme.batteryPercentageFontSize
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.batteryTextSpacing

                UI.IconText {
                    text: Theme.batteryStatusIcons[root.battery.state] ?? Theme.batteryStatusIcons.unknown
                }
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

            UI.ColumnText {
                objectName: "batteryTime"
                width: parent.width
                visible: text.length > 0
                horizontalAlignment: Text.AlignHCenter
                text: BatteryService.timeText(root.battery)
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
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
