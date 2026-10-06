import QtQuick
import "../../../theme/ui" as UI
import "../../../theme"
import "../../../services"

Column {
    id: root
    spacing: 4
    width: Theme.networkTooltipWidth

    Canvas {
        id: graph
        width: parent.width
        height: Theme.networkGraphHeight

        Connections {
            target: NetworkService
            function onSpeedHistoryChanged() { graph.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            const history = NetworkService.speedHistory
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

    Row {
        spacing: 12

        UI.ColumnText {
            text: `↓ ${NetworkService.formatSpeed(NetworkService.downloadSpeed)}/s`
            color: Theme.networkDownColor
        }
        UI.ColumnText {
            text: `↑ ${NetworkService.formatSpeed(NetworkService.uploadSpeed)}/s`
            color: Theme.networkUpColor
        }
    }

    Column {
        width: parent.width
        visible: NetworkService.connectedNetworks.length > 0

        UI.ColumnText {
            text: "networks"
            color: Theme.inactive
        }

        Repeater {
            model: NetworkService.connectedNetworks
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
                UI.ColumnText {
                    id: netSpeed
                    anchors.right: parent.right
                    text: netRow.modelData.connected
                        ? `↓${NetworkService.formatSpeed(netRow.modelData.downloadSpeed)} ↑${NetworkService.formatSpeed(netRow.modelData.uploadSpeed)}`
                        : ""
                    color: Theme.inactive
                }
            }
        }
    }

    Column {
        width: parent.width
        visible: NetworkService.vpnConnections.length > 0

        UI.ColumnText {
            text: "vpn"
            color: Theme.inactive
        }

        Repeater {
            model: NetworkService.vpnConnections
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
                    text: vpnRow.modelData.active ? "online" : "offline"
                    color: vpnRow.modelData.active ? Theme.ok : Theme.inactive
                }
            }
        }
    }

    Column {
        width: parent.width
        visible: NetworkService.topProcesses.length > 0

        UI.ColumnText {
            text: "processes"
            color: Theme.inactive
        }

        Repeater {
            model: NetworkService.topProcesses
            delegate: Item {
                id: procRow
                required property var modelData
                width: parent.width
                height: procName.implicitHeight

                UI.ColumnText {
                    id: procName
                    anchors.left: parent.left
                    anchors.right: procSpeed.left
                    anchors.rightMargin: 4
                    elide: Text.ElideRight
                    text: procRow.modelData.program
                }
                UI.ColumnText {
                    id: procSpeed
                    anchors.right: parent.right
                    text: `↓${NetworkService.formatSpeed(procRow.modelData.received)}/s ↑${NetworkService.formatSpeed(procRow.modelData.sent)}/s`
                    color: Theme.inactive
                }
            }
        }
    }
}
