pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import Quickshell
import "../../theme"
import "../../theme/ui" as UI

Column {
    id: root
    required property var statusService
    property string expandedProcess: ""
    readonly property var matches: statusService.detectionMatches ?? []
    readonly property string homePath: Quickshell.env("HOME")
    spacing: Theme.controlSpacing
    objectName: "statusDetectionDetails"
    onMatchesChanged: if (!matches.some(match => match.name === expandedProcess)) expandedProcess = ""
    function displayPath(path) {
        const shortened = path === homePath ? "~" : path.startsWith(homePath + "/") ? "~" + path.slice(homePath.length) : path
        return shortened.replace(/\n/g,"\\n").replace(/\r/g,"\\r").replace(/\t/g,"\\t")
    }
    Rectangle { width: parent.width; height: 1; color: Theme.empty }
    RowLayout {
        width: parent.width
        UI.ColumnText { text: Translations.text("status.detection.title"); color: Theme.inactive; Layout.fillWidth: true }
        UI.ColumnText {
            text: root.statusService.detectionLoading && root.matches.length ? Translations.text("common.status.refreshing")
                : Translations.text("status.detection.processes",[],root.matches.length)
            color: Theme.inactive; font.bold: false; font.weight: Font.Normal; font.styleName: ""
        }
    }
    UI.ColumnText {
        objectName: "statusDetectionManual"
        width: parent.width
        visible: root.statusService.source === "manual"
        text: Translations.text("status.detection.manualHint")
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        color: Theme.inactive; font.bold: false; font.weight: Font.Normal; font.styleName: ""
    }
    UI.ColumnText {
        objectName: "statusDetectionFeedback"
        width: parent.width
        visible: text.length > 0
        text: root.statusService.detectionError || (!root.matches.length
            ? Translations.text(root.statusService.detectionLoading ? "status.detection.checking" : "status.detection.empty") : "")
        textFormat: Text.PlainText; wrapMode: Text.Wrap
        color: root.statusService.detectionError ? Theme.warning : Theme.inactive
        font.bold: false; font.weight: Font.Normal; font.styleName: ""
    }
    UI.ColumnText {
        objectName: "statusDetectionStale"
        width: parent.width
        visible: root.statusService.detectionStale ?? false
        text: Translations.text("status.detection.stale")
        color: Theme.inactive; font.bold: false; font.weight: Font.Normal; font.styleName: ""
    }
    Repeater {
        model: root.matches
        delegate: Column {
            id: match
            required property var modelData
            width: root.width
            readonly property bool expanded: root.expandedProcess === modelData.name
            readonly property string methods: modelData.methods.map(method => ({process:Translations.text("status.detection.configuredProcess"),directory:Translations.text("status.detection.workingDirectory"),file:Translations.text("status.detection.openFiles")})[method] || method).join(" · ")
            QC.ItemDelegate {
                id: toggle
                objectName: "statusDetectionToggle-" + match.modelData.name
                width: parent.width
                height: Theme.controlHeight
                padding: Theme.controlFieldPadding
                enabled: match.modelData.paths.length > 0
                Accessible.name: match.modelData.name + ", " + match.methods + ", " + Translations.text("status.detection.paths",[],match.modelData.paths.length)
                Accessible.expanded: match.expanded
                onClicked: root.expandedProcess = match.expanded ? "" : match.modelData.name
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
                HoverHandler {
                    id: toggleHover
                    cursorShape: toggle.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
                background: Rectangle {
                    color: toggle.hovered || match.expanded ? Theme.alternateBackground : "transparent"
                    radius: Theme.iconButtonRadius
                }
                contentItem: RowLayout {
                    spacing: Theme.controlSpacing
                    UI.IconText { centerVertical: false; text: match.expanded ? Theme.chevronDownIcon : Theme.chevronRightIcon; color: Theme.inactive }
                    UI.ColumnText {
                        objectName: "statusDetectionProcess"
                        Layout.fillWidth: true
                        text: match.modelData.name
                        textFormat: Text.PlainText; elide: Text.ElideRight
                        color: match.expanded ? Theme.accent : Theme.text
                        UI.HoverTooltip {
                            hoverTarget: toggleHover
                            text: match.modelData.name + " · " + match.methods
                            textFormat: Text.PlainText
                        }
                    }
                    UI.ColumnText {
                        Layout.maximumWidth: root.width * 0.4
                        text: "· " + match.methods
                        textFormat: Text.PlainText; elide: Text.ElideRight; color: Theme.inactive
                        font.bold: false; font.weight: Font.Normal; font.styleName: ""
                    }
                    UI.ColumnText {
                        text: Translations.text("status.detection.paths",[],match.modelData.paths.length)
                        color: Theme.inactive; font.bold: false; font.weight: Font.Normal; font.styleName: ""
                    }
                }
            }
            Column {
                width: parent.width
                visible: match.expanded
                Repeater {
                    model: match.expanded ? match.modelData.paths : []
                    UI.ColumnText {
                        id: pathRow
                        required property string modelData
                        objectName: "statusDetectionPaths-" + modelData
                        x: Theme.controlFieldPadding * 2
                        width: parent.width - x
                        text: root.displayPath(modelData)
                        textFormat: Text.PlainText; elide: Text.ElideMiddle; color: Theme.inactive
                        font.bold: false; font.weight: Font.Normal; font.styleName: ""
                        UI.HoverTooltip { text: pathRow.modelData; textFormat: Text.PlainText }
                    }
                }
            }
        }
    }
}
