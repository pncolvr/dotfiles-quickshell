pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../../theme"
import "../../../theme/ui" as UI

Column {
    id: root
    property var options: []
    property string selectedName: ""
    property string placeholder: "Choose a device"
    property string labelPrefix: ""
    property string hint: ""
    property int hintDelay: 500
    property bool compact: false
    property bool expanded: false
    property string toggleObjectName: "selectorToggle"
    property string choicesObjectName: "selectorChoices"
    readonly property string selectedDescription: options.find(option => option.name === selectedName)?.description ?? placeholder
    signal selected(string name)
    spacing: Theme.audioSpacing
    onEnabledChanged: if (!enabled) expanded = false

    QC.Button {
        id: selector
        objectName: root.toggleObjectName
        width: parent.width
        implicitHeight: root.compact ? Theme.audioButtonHeight
            : Math.max(Theme.audioButtonHeight, currentLabel.implicitHeight + Theme.audioButtonPadding * 2)
        padding: Theme.audioButtonPadding
        hoverEnabled: true
        opacity: enabled ? 1 : 0.5
        Accessible.name: root.hint || root.labelPrefix + root.selectedDescription
        onClicked: root.expanded = !root.expanded
        background: Rectangle {
            color: selector.hovered ? Theme.empty : Theme.background
            radius: Theme.iconButtonRadius
            border.width: selector.activeFocus || root.expanded ? 1 : 0
            border.color: Theme.accent
        }
        contentItem: Item {
            UI.ColumnText {
                id: currentLabel
                width: parent.width - arrow.width - Theme.audioSpacing
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.labelPrefix + root.selectedDescription
                wrapMode: root.compact ? Text.NoWrap : Text.Wrap
                elide: root.compact ? Text.ElideRight : Text.ElideNone
            }
            UI.IconText {
                id: arrow
                anchors.right: parent.right
                text: Theme.chevronDownIcon
                rotation: root.expanded ? 180 : 0
                color: Theme.inactive
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        UI.HoverTooltip { hoverTarget: selector; text: root.hint; delay: root.hintDelay }
    }

    ListView {
        id: choices
        objectName: root.choicesObjectName
        visible: root.expanded
        width: parent.width
        height: Math.min(contentHeight, rowHeight * Theme.audioProfileMaxVisibleRows)
        readonly property int rowHeight: root.compact ? Theme.audioAppOptionRowHeight : Theme.audioProfileRowHeight
        model: root.options
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        delegate: QC.ItemDelegate {
            id: option
            required property var modelData
            width: choices.width - (scrollbar.visible ? Theme.audioScrollbarWidth + Theme.audioScrollbarMargin : 0)
            height: choices.rowHeight
            padding: Theme.audioButtonPadding
            hoverEnabled: true
            enabled: modelData.available
            opacity: enabled ? 1 : 0.4
            Accessible.name: modelData.description
            onClicked: {
                root.expanded = false
                if (modelData.name !== root.selectedName) root.selected(modelData.name)
            }
            background: Rectangle {
                radius: Theme.iconButtonRadius
                color: option.hovered || option.activeFocus ? Theme.empty : Theme.background
            }
            contentItem: Item {
                UI.ColumnText {
                    width: parent.width - mark.width - Theme.audioSpacing
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: option.modelData.description
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: option.modelData.name === root.selectedName ? Theme.accent : Theme.text
                }
                UI.IconText {
                    id: mark
                    anchors.right: parent.right
                    text: Theme.checkIcon
                    visible: option.modelData.name === root.selectedName
                    color: Theme.accent
                }
            }
            HoverHandler {
                enabled: option.enabled
                cursorShape: Qt.PointingHandCursor
            }
        }
        QC.ScrollBar.vertical: UI.ScrollBar {
            id: scrollbar
        }
    }
}
