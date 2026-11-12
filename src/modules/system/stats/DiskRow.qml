pragma ComponentBehavior: Bound
import "../../../i18n"
import QtQuick
import "../../../theme"
import "../../../ui" as UI
import "../../../services"

// A battery-style body without the terminal, filled by used / total space.
Item {
    id: root
    required property var disk
    property var diskService: DiskService
    readonly property real ratio: disk.size > 0 ? Math.max(0, Math.min(1, disk.used / disk.size)) : 0
    readonly property color fillColor: ratio >= Theme.statsDiskUrgentRatio ? Theme.urgent : ratio > Theme.statsDiskWarningRatio ? Theme.warning : Theme.accent
    implicitHeight: Theme.statsDiskRowHeight

    Rectangle {
        id: body
        anchors.fill: parent
        radius: Theme.statsDiskRadius
        color: Theme.batteryEmptyColor
        clip: true

        Rectangle {
            objectName: "statsDiskFill"
            x: 1
            y: 1
            width: (parent.width - 2) * root.ratio
            height: parent.height - 2
            radius: Math.max(0, Theme.statsDiskRadius - 1)
            color: root.fillColor
            opacity: Theme.batteryFillOpacity
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.statsDiskPadding + 2
            anchors.rightMargin: Theme.statsDiskPadding + 2
            anchors.topMargin: Theme.statsDiskPadding
            anchors.bottomMargin: Theme.statsDiskPadding

            Item {
                anchors.top: parent.top
                width: parent.width
                height: Math.max(name.implicitHeight, percentage.implicitHeight)

                Row {
                    anchors.left: parent.left
                    anchors.right: percentage.left
                    anchors.rightMargin: Theme.controlSpacing
                    spacing: Theme.batteryTextSpacing
                    clip: true
                    UI.Text {
                        id: name
                        objectName: "statsDiskName"
                        textFormat: Text.PlainText
                        text: root.disk.name
                        font.bold: true
                    }
                    UI.Text {
                        objectName: "statsDiskMount"
                        visible: root.disk.mount !== root.disk.name
                        textFormat: Text.PlainText
                        text: root.disk.mount
                        color: Theme.inactive
                        elide: Text.ElideMiddle
                        width: Math.min(implicitWidth, parent.width - name.width - parent.spacing)
                    }
                }
                UI.Text {
                    id: percentage
                    objectName: "statsDiskPercentage"
                    anchors.right: parent.right
                    text: Math.round(root.ratio * 100) + "%"
                }
            }

            Item {
                anchors.bottom: parent.bottom
                width: parent.width
                height: usage.implicitHeight

                UI.Text {
                    id: usage
                    objectName: "statsDiskUsage"
                    anchors.left: parent.left
                    anchors.right: rates.left
                    anchors.rightMargin: Theme.controlSpacing
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    text: Translations.text("stats.disks.usage", [root.diskService.formatBytes(root.disk.used),
                        root.diskService.formatBytes(root.disk.size), root.diskService.formatBytes(root.disk.avail)])
                }
                Row {
                    id: rates
                    anchors.right: parent.right
                    spacing: Theme.controlSpacing
                    UI.Text {
                        objectName: "statsDiskRead"
                        color: Theme.statsDiskReadColor
                        text: "R " + root.diskService.formatRate(root.disk.read)
                    }
                    UI.Text {
                        objectName: "statsDiskWrite"
                        color: Theme.statsDiskWriteColor
                        text: "W " + root.diskService.formatRate(root.disk.write)
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: body
        radius: Theme.statsDiskRadius
        color: "transparent"
        border.width: 1
        border.color: Theme.batteryBorderColor
    }

    UI.HoverTooltip {
        textFormat: Text.PlainText
        text: [root.disk.device, root.disk.fstype, root.disk.model].filter(part => part).join(" · ")
            + (root.disk.mounts.length > 1 ? "\n" + root.disk.mounts.join("\n") : "")
    }
}
