pragma ComponentBehavior: Bound
import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Item {
    id: root
    required property var process
    required property string resource
    property bool childProcess: false
    property bool canExpand: false
    property bool isExpanded: false
    readonly property bool pidFocused: pid.activeFocus
    signal toggleExpanded()
    property var statsService: StatsService
    property var networkService: NetworkService
    height: childProcess ? Theme.statsChildRowHeight : Theme.statsProcessRowHeight
    HoverHandler { id: rowHover }
    Rectangle {
        anchors.fill: parent
        radius: Theme.iconButtonRadius
        color: rowHover.hovered || root.isExpanded ? Theme.alternateBackground
            : root.childProcess ? Qt.rgba(Theme.alternateBackground.r, Theme.alternateBackground.g,
                Theme.alternateBackground.b, Theme.alternateBackground.a * 0.35) : "transparent"
    }
    Rectangle {
        visible: root.childProcess
        x: Theme.fontSize / 2
        y: -Theme.statsProcessRowSpacing / 2
        width: 1
        height: parent.height + Theme.statsProcessRowSpacing
        color: Theme.empty
    }
    MouseArea {
        objectName: "statsExpandProcess"
        anchors.left: parent.left
        anchors.right: pid.left
        anchors.rightMargin: Theme.controlSpacing
        height: parent.height
        enabled: root.canExpand
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleExpanded()
    }
    UI.IconText {
        id: chevron
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: root.canExpand
        width: Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        text: root.isExpanded ? Theme.chevronDownIcon : Theme.chevronRightIcon
        color: Theme.inactive
    }
    UI.ColumnText {
        id: name
        objectName: "statsProcessName"
        x: root.childProcess ? Theme.fontSize + Theme.controlSpacing * 3 : Theme.fontSize + Theme.controlSpacing
        width: Math.max(0, Math.min(implicitWidth, pid.x - x - Theme.controlSpacing
            - (badge.visible ? badge.width + Theme.controlSpacing : 0)))
        anchors.verticalCenter: parent.verticalCenter
        text: root.process.label || root.process.name
        textFormat: Text.PlainText
        elide: Text.ElideMiddle
        color: root.childProcess ? Theme.inactive : Theme.text
        font.styleName: root.childProcess ? "" : Theme.fontStyle
        font.bold: !root.childProcess
        font.weight: root.childProcess ? Font.Normal : Theme.fontWeight
        UI.HoverTooltip {
            text: root.childProcess ? root.process.name + " · PID " + root.process.pid
                : root.process.name + " · " + (root.process.count || 1) + " contributing processes"
            cursorShape: root.canExpand ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (root.canExpand) root.toggleExpanded()
        }
    }
    Rectangle {
        id: badge
        objectName: "statsProcessCount"
        visible: !root.childProcess && root.process.count > 1
        x: name.x + name.width + Theme.controlSpacing
        anchors.verticalCenter: parent.verticalCenter
        width: countLabel.implicitWidth + Theme.controlFieldPadding
        height: countLabel.implicitHeight + 4
        radius: Theme.iconButtonRadius
        color: Theme.alternateBackground
        UI.ColumnText {
            id: countLabel
            anchors.centerIn: parent
            text: String(root.process.count || 1)
            color: Theme.inactive
            font.pixelSize: Theme.fontSize - 1
            font.styleName: ""
            font.bold: false
            font.weight: Font.Normal
        }
    }
    UI.ActionButton {
        id: pid
        objectName: "statsCopyPid"
        anchors.right: usage.left
        anchors.rightMargin: Theme.controlSpacing
        width: Theme.statsPidWidth
        height: parent.height
        label: root.process.pid > 0 ? String(root.process.pid) : "—"
        glyph: Theme.copyIcon
        foreground: Theme.inactive
        fillColor: "transparent"
        hint: root.process.pid > 0 ? "Copy " + (root.canExpand || root.process.count > 1 ? "parent " : "") + "PID " + root.process.pid : "PID unavailable"
        enabled: root.process.pid > 0
        onClicked: root.statsService.copyPid(root.process.pid)
    }
    Item {
        id: usage
        objectName: "statsProcessUsage"
        anchors.right: parent.right
        height: parent.height
        width: root.resource === "network" ? Theme.statsTrafficWidth * 2 + Theme.controlSpacing : Theme.statsValueWidth
        UI.ColumnText {
            visible: root.resource !== "network"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.resource === "cpu" ? root.process.value.toFixed(1) + "%"
                : root.process.value >= 1073741824 ? (root.process.value / 1073741824).toFixed(1) + " GiB"
                : (root.process.value / 1048576).toFixed(1) + " MiB"
            color: root.resource === "cpu" && root.process.value >= 90 ? Theme.warning : root.childProcess ? Theme.text : Theme.accent
            font.styleName: root.childProcess ? "" : Theme.fontStyle
            font.bold: !root.childProcess
            font.weight: root.childProcess ? Font.Normal : Theme.fontWeight
        }
        Row {
            visible: root.resource === "network"
            height: parent.height
            spacing: Theme.controlSpacing
            Repeater {
                model: ["down", "up"]
                UI.ColumnText {
                    required property string modelData
                    objectName: modelData === "down" ? "statsProcessDownload" : "statsProcessUpload"
                    width: Theme.statsTrafficWidth
                    height: usage.height
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    text: root.networkService.formatSpeed(root.process[modelData]) + "/s"
                    color: modelData === "down" ? Theme.networkDownColor : Theme.networkUpColor
                    font.styleName: root.childProcess ? "" : Theme.fontStyle
                    font.bold: !root.childProcess
                    font.weight: root.childProcess ? Font.Normal : Theme.fontWeight
                }
            }
        }
    }
}
