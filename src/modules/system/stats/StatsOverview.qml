pragma ComponentBehavior: Bound
import QtQuick
import "../../../theme"
import ".."
import "../../../theme/ui" as UI
import "../../../services"

Column {
    id: root
    property var statsService: StatsService
    property var networkService: NetworkService
    spacing: Theme.controlSpacing
    Row {
        width: parent.width
        spacing: Theme.controlSpacing
        Repeater {
            model: ["CPU", "Memory", "Temperature"]
            Column {
                required property string modelData
                width: (root.width - Theme.controlSpacing * 2) / 3
                spacing: 4
                UI.ColumnText { width: parent.width; text: parent.modelData; color: Theme.inactive; horizontalAlignment: Text.AlignHCenter }
                UI.ColumnText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Theme.fontSize * 1.4
                    text: parent.modelData === "CPU" ? root.statsService.cpu + "%"
                        : parent.modelData === "Memory" ? (root.statsService.memoryUsed / 1024).toFixed(1) + " GiB"
                        : Number.isFinite(root.statsService.temperature) ? Math.round(root.statsService.temperature) + "°C" : "—"
                }
            }
        }
    }
    StatsBar {
        width: parent.width
        label: "RAM"
        value: (root.statsService.memoryUsed / 1024).toFixed(1) + " / " + (root.statsService.memoryTotal / 1024).toFixed(1) + " GiB"
        ratio: root.statsService.memoryTotal > 0 ? root.statsService.memoryUsed / root.statsService.memoryTotal : 0
    }
    Row {
        width: parent.width
        spacing: Theme.controlSpacing
        Repeater {
            model: ["Download", "Upload"]
            Column {
                required property string modelData
                width: (root.width - Theme.controlSpacing) / 2
                spacing: 4
                UI.ColumnText { width: parent.width; text: parent.modelData; color: Theme.inactive; horizontalAlignment: Text.AlignHCenter }
                UI.ColumnText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: parent.modelData === "Download" ? Theme.networkDownColor : Theme.networkUpColor
                    text: root.networkService.formatSpeed(parent.modelData === "Download" ? root.networkService.downloadSpeed : root.networkService.uploadSpeed) + "/s"
                }
            }
        }
    }
    Repeater {
        model: [{label: "Connected", value: root.networkService.connectedNetworks.filter(network => network.connected).map(network => network.name).join(", ") || "None"},
            {label: "VPN", value: root.networkService.vpnConnections.filter(vpn => vpn.active).map(vpn => vpn.name).join(", ") || "Off"}]
        Item {
            required property var modelData
            width: root.width
            height: Theme.controlHeight
            UI.ColumnText { id: label; text: parent.modelData.label; color: Theme.inactive }
            UI.ColumnText {
                anchors.right: parent.right
                width: Math.min(implicitWidth, parent.width - label.width - Theme.controlSpacing)
                horizontalAlignment: Text.AlignRight
                text: parent.modelData.value
                elide: Text.ElideMiddle
                UI.HoverTooltip { text: parent.text }
            }
        }
    }
}
