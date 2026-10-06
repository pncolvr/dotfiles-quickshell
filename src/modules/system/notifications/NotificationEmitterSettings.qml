pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QC
import "../../../theme"
import "../../../theme/ui" as UI
import "../../../services"

Item {
    id: root
    property string filter: "All"
    property alias searchText: searchField.text
    readonly property string searchQuery: searchField.query
    readonly property var emitters: Object.values(NotificationEmitterRepository.emitters)
        .filter(emitter => filter === "Hidden" ? emitter.muted : filter === "DND allowed" ? emitter.allowDuringDnd
            : filter === "History off" ? emitter.excludeFromHistory : true)
        .filter(emitter => !searchQuery || [emitter.name, emitter.desktopEntry].some(value =>
            String(value ?? "").toLowerCase().includes(searchQuery)))
        .sort((a, b) => a.name.localeCompare(b.name))
    implicitHeight: controls.implicitHeight + 12 + rows.implicitHeight
    height: implicitHeight
    onSearchTextChanged: rowsView.contentY = 0
    onFilterChanged: rowsView.contentY = 0

    function clearSearch() { searchField.resetSearch() }

    Column {
        id: controls
        width: root.width - 10
        spacing: 12
        UI.Text {
            centerVertical: false
            width: parent.width
            text: "Defaults: show notifications, DND blocked, history on. Transient notifications are not saved. Buttons show the current state; click to change it."
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            color: Theme.inactive
        }
        UI.SearchField {
            id: searchField
            objectName: "notificationEmitterSearchField"
            width: parent.width
            placeholderText: "Search emitters…"
        }
        Flow {
            width: parent.width
            spacing: Theme.controlSpacing
            Repeater {
                model: ["All", "Hidden", "DND allowed", "History off"]
                NotificationButton {
                    required property string modelData
                    label: modelData
                    foreground: root.filter === modelData ? Theme.accent : Theme.text
                    onClicked: root.filter = modelData
                }
            }
        }
    }

    Flickable {
        id: rowsView
        objectName: "notificationEmitterList"
        y: controls.height + 12
        width: root.width
        height: Math.max(0, root.height - y)
        clip: true
        contentWidth: width
        contentHeight: rows.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        QC.ScrollBar.vertical: UI.ScrollBar {}
        Column {
            id: rows
            width: rowsView.width - 10
            spacing: 12
            UI.Text {
                objectName: "notificationEmitterSearchEmpty"
                centerVertical: false
                visible: !root.emitters.length
                text: root.searchQuery ? "No matching emitters." : "No emitters in this list."
            }
            Repeater {
                model: root.emitters
                Rectangle {
                    id: row
                    required property var modelData
                    width: rows.width
                    implicitHeight: content.height + 20
                    radius: 10
                    color: Theme.alternateBackground
                    Column {
                        id: content
                        x: 10; y: 10
                        width: parent.width - 20
                        spacing: 8
                        UI.Text { centerVertical: false; width: parent.width; text: row.modelData.name; wrapMode: Text.Wrap; textFormat: Text.PlainText }
                        Item {
                            width: parent.width
                            height: Math.max(sourceControls.height, deleteButton.height)
                            NotificationSourceControls {
                                id: sourceControls
                                width: parent.width - deleteButton.width - Theme.controlSpacing
                                emitterKey: row.modelData.key
                            }
                            NotificationButton {
                                id: deleteButton
                                objectName: "notificationDeleteEmitter_" + row.modelData.key
                                anchors.right: parent.right
                                implicitWidth: Theme.controlHeight
                                glyph: Theme.deleteIcon
                                fillColor: Theme.notificationCritical
                                hint: "Delete emitter, its history and settings, and dismiss its notifications. New notifications recreate it with defaults."
                                onClicked: NotificationService.deleteEmitter(row.modelData.key)
                            }
                        }
                    }
                }
            }
        }
    }
}
