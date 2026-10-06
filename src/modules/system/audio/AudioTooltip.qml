pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import Quickshell
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Column {
    id: root
    property bool input: false
    property var audioService: AudioService
    readonly property var devices: input ? audioService.inputDevices : audioService.outputDevices
    readonly property var apps: input ? audioService.micApps : audioService.playbackApps
    readonly property var monitor: TooltipService.screen ?? (root.QsWindow.window as QsWindow)?.screen
    readonly property real maxPanelHeight: (monitor?.height ?? 1080) * Theme.audioTooltipMaxHeightRatio
    width: Math.min(Theme.audioTooltipWidth, (monitor?.width ?? Theme.audioTooltipWidth + Theme.tooltipPaddingWidth * 2) - Theme.tooltipPaddingWidth * 2)
    spacing: Theme.audioSpacing
    Component.onCompleted: audioService.beginPanel()
    Component.onDestruction: audioService.endPanel()

    Flickable {
        id: list
        objectName: "audioDeviceList"
        width: parent.width
        height: Math.min(contentHeight, root.maxPanelHeight)
        contentWidth: width
        contentHeight: contents.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        Column {
            id: contents
            width: list.width - (scrollbar.visible ? Theme.audioScrollbarWidth + Theme.audioScrollbarMargin : 0)
            spacing: Theme.audioSpacing

            Item {
                width: parent.width
                height: Math.max(appsTitle.implicitHeight, micActivity.implicitHeight)
                UI.Text {
                    id: appsTitle
                    objectName: "audioAppsTitle"
                    anchors.left: parent.left
                    anchors.right: root.input ? micActivity.left : parent.right
                    anchors.rightMargin: root.input ? Theme.audioSpacing : 0
                    text: root.apps.length > 0
                        ? (root.input ? "Apps using the microphone" : "Apps playing audio")
                        : (root.input ? "No apps recording" : "No apps playing audio")
                    color: Theme.inactive
                    elide: Text.ElideRight
                }
                UI.IconText {
                    id: micActivity
                    objectName: "micActivity"
                    anchors.right: parent.right
                    visible: root.input
                    text: Theme.audioRecordingIcon
                    font.pixelSize: Theme.fontSize
                    color: root.audioService.micActivityEnabled ? Theme.ok : Theme.inactive
                    UI.HoverTooltip {
                        objectName: "micActivityHint"
                        text: root.audioService.micActivityEnabled ? "Mic activity enabled" : "Mic activity disabled"
                    }
                }
            }
            Repeater {
                objectName: "audioProcesses"
                model: root.apps
                AudioAppRow {
                    required property var modelData
                    width: contents.width
                    app: modelData
                    input: root.input
                    audioService: root.audioService
                }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.empty }

            UI.ColumnText {
                width: parent.width
                visible: root.audioService.devicesError.length > 0
                text: root.audioService.devicesError
                color: Theme.warning
                wrapMode: Text.Wrap
            }

            UI.ColumnText {
                width: parent.width
                visible: root.audioService.routingBusy || root.audioService.routingError.length > 0 || root.audioService.routingMessage.length > 0
                text: root.audioService.routingBusy ? "Switching audio…" : root.audioService.routingError || root.audioService.routingMessage
                color: root.audioService.routingError ? Theme.warning : Theme.inactive
                wrapMode: Text.Wrap
            }
            Repeater {
                objectName: "audioDevices"
                model: root.devices
                AudioDeviceRow {
                    required property var modelData
                    node: modelData
                    input: root.input
                    audioService: root.audioService
                    width: contents.width
                }
            }
            UI.ColumnText {
                visible: root.devices.length === 0
                text: root.input ? "No microphones available" : "No audio outputs available"
                color: Theme.inactive
            }
        }
        QC.ScrollBar.vertical: UI.ScrollBar {
            id: scrollbar
        }
    }
}
