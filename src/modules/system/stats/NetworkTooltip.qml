import "../../../i18n"
import QtQuick
import "../../../ui" as UI
import "../../../theme"
import "../../../services"

Column {
    id: root
    property var networkService: NetworkService
    spacing: Theme.controlSpacing

    Canvas {
        id: graph
        width: parent.width
        height: Theme.networkGraphHeight

        Connections {
            target: root.networkService
            function onSpeedHistoryChanged() { graph.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const history = root.networkService.speedHistory
            if (history.length < 2) return

            let maxSpeed = 1
            for (let i = 0; i < history.length; i++) {
                if (history[i].down > maxSpeed) maxSpeed = history[i].down
                if (history[i].up > maxSpeed) maxSpeed = history[i].up
            }

            function drawLine(color, getValue) {
                ctx.beginPath()
                ctx.strokeStyle = color
                ctx.lineWidth = 1.5
                for (let i = 0; i < history.length; i++) {
                    const x = i / (history.length - 1) * width
                    const y = height - (getValue(history[i]) / maxSpeed) * (height - 2) - 1
                    if (i === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.stroke()
            }

            drawLine(Theme.networkDownColor, h => h.down)
            drawLine(Theme.networkUpColor, h => h.up)
        }
    }

    Item {
        width: parent.width
        height: Math.max(downloadRate.implicitHeight, uploadRate.implicitHeight)

        Row {
            id: downloadRate
            anchors.left: parent.left
            spacing: Theme.controlSpacing
            UI.IconText {
                text: Theme.networkDownIcon
                font.pixelSize: Theme.fontSize
                color: Theme.networkDownColor
            }
            UI.ColumnText {
                text: `${root.networkService.formatSpeed(root.networkService.downloadSpeed)}/s`
                color: Theme.networkDownColor
            }
        }
        Row {
            id: uploadRate
            anchors.right: parent.right
            spacing: Theme.controlSpacing
            UI.IconText {
                text: Theme.networkUpIcon
                font.pixelSize: Theme.fontSize
                color: Theme.networkUpColor
            }
            UI.ColumnText {
                text: `${root.networkService.formatSpeed(root.networkService.uploadSpeed)}/s`
                color: Theme.networkUpColor
            }
        }
    }

    Column {
        width: parent.width
        visible: root.networkService.connectedNetworks.length > 0

        UI.ColumnText {
            text: Translations.text("stats.network.networks")
            color: Theme.inactive
        }

        Repeater {
            model: root.networkService.connectedNetworks
            delegate: Item {
                id: netRow
                required property var modelData
                width: parent.width
                height: netName.implicitHeight

                UI.ColumnText {
                    id: netName
                    anchors.left: parent.left
                    anchors.right: netSpeed.left
                    anchors.rightMargin: 4
                    elide: Text.ElideRight
                    text: netRow.modelData.name
                    color: netRow.modelData.connected ? Theme.text : Theme.inactive
                }
                Row {
                    id: netSpeed
                    anchors.right: parent.right
                    spacing: Theme.controlSpacing
                    visible: netRow.modelData.connected
                    UI.IconText {
                        text: Theme.networkDownIcon
                        font.pixelSize: Theme.fontSize
                        color: Theme.inactive
                    }
                    UI.ColumnText {
                        text: root.networkService.formatSpeed(netRow.modelData.downloadSpeed)
                        color: Theme.inactive
                    }
                    UI.IconText {
                        text: Theme.networkUpIcon
                        font.pixelSize: Theme.fontSize
                        color: Theme.inactive
                    }
                    UI.ColumnText {
                        text: root.networkService.formatSpeed(netRow.modelData.uploadSpeed)
                        color: Theme.inactive
                    }
                }
            }
        }
    }

    Column {
        width: parent.width
        visible: root.networkService.vpnConnections.length > 0

        UI.ColumnText {
            text: Translations.text("stats.network.vpn")
            color: Theme.inactive
        }

        Repeater {
            model: root.networkService.vpnConnections
            delegate: Item {
                id: vpnRow
                required property var modelData
                width: parent.width
                height: vpnName.implicitHeight

                UI.ColumnText {
                    id: vpnName
                    anchors.left: parent.left
                    anchors.right: vpnStatus.left
                    anchors.rightMargin: 4
                    elide: Text.ElideRight
                    text: vpnRow.modelData.name
                }
                UI.ColumnText {
                    id: vpnStatus
                    anchors.right: parent.right
                    text: Translations.text(vpnRow.modelData.active ? "common.states.online" : "common.states.offline")
                    color: vpnRow.modelData.active ? Theme.ok : Theme.inactive
                }
            }
        }
    }

}
