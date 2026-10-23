pragma ComponentBehavior: Bound

import "../../../i18n"
import QtQuick
import QtQuick.Controls as QC
import QtQuick.Layouts
import "../../../theme"
import "../../../ui" as UI
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
        x: Theme.scrollbarGutter
        width: Math.max(0, root.width - Theme.scrollbarGutter * 2)
        spacing: 12
        UI.Text {
            centerVertical: false
            width: parent.width
            text: Translations.text("notifications.emitters.defaultsHint")
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            color: Theme.inactive
        }
        UI.SearchField {
            id: searchField
            objectName: "notificationEmitterSearchField"
            width: parent.width
            placeholderText: Translations.text("notifications.emitters.searchPlaceholder")
        }
        Flow {
            width: parent.width
            spacing: Theme.controlSpacing
            Repeater {
                model: ["All", "Hidden", "DND allowed", "History off"]
                NotificationButton {
                    required property string modelData
                    label: Translations.text(({All:"common.filters.all", Hidden:"notifications.filters.hidden", "DND allowed":"notifications.dnd.allowed", "History off":"notifications.history.disabled"})[modelData])
                    foreground: root.filter === modelData ? Theme.accent : Theme.text
                    onClicked: root.filter = modelData
                }
            }
        }
    }

    Flickable {
        id: rowsView
        property UI.ScrollBehavior scrollBehavior: UI.ScrollBehavior { viewport: rowsView }
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
            x: Theme.scrollbarGutter
            width: Math.max(0, rowsView.width - Theme.scrollbarGutter * 2)
            spacing: 12
            UI.EmptyState {
                objectName: "notificationEmitterSearchEmpty"
                visible: !root.emitters.length
                text: Translations.text(root.searchQuery ? "notifications.empty.filteredEmitters" : "notifications.empty.emitters")
            }
            Repeater {
                model: root.emitters
                Rectangle {
                    id: row
                    required property var modelData
                    width: rows.width
                    implicitHeight: content.implicitHeight + Theme.controlSpacing * 2
                    radius: 10
                    color: Theme.alternateBackground
                    RowLayout {
                        id: content
                        x: 10; y: Theme.controlSpacing
                        width: parent.width - 20
                        spacing: Theme.controlSpacing
                        UI.Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            centerVertical: false
                            text: row.modelData.name
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }
                        NotificationSourceControls {
                            Layout.minimumWidth: naturalWidth
                            Layout.preferredWidth: naturalWidth
                            emitterKey: row.modelData.key
                        }
                        NotificationButton {
                            objectName: "notificationDeleteEmitter_" + row.modelData.key
                            implicitWidth: Theme.controlHeight
                            glyph: Theme.deleteIcon
                            fillColor: Theme.notificationCritical
                            hint: Translations.text("notifications.actions.deleteEmitterHint")
                            onClicked: NotificationService.deleteEmitter(row.modelData.key)
                        }
                    }
                }
            }
        }
    }
}
