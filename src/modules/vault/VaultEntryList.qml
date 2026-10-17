pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import "../../ui" as UI

ListView {
    id: list
    required property var entries
    property bool busy: false
    signal entrySelected(string entryId)
    objectName: "vaultList"
    clip: true
    model: list.entries
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    topMargin: Theme.controlSpacing
    bottomMargin: Theme.controlSpacing
    QC.ScrollBar.vertical: UI.ScrollBar {}
    Rectangle {
        parent: list
        anchors.fill: parent
        anchors.margins: 1
        z: 1
        color: "transparent"
        radius: Theme.iconButtonRadius
        border.width: 1
        border.color: Theme.empty
    }
    delegate: UI.SelectableRow {
        id: entryRow
        required property var modelData
        required property int index
        width: list.width
        objectName: "vaultEntry-" + modelData.id
        current: index === list.currentIndex
        onActivated: { list.currentIndex = index; list.entrySelected(modelData.id) }
        contentItem: Column {
            UI.Text { centerVertical: false; width: parent.width; textFormat: Text.PlainText; text: entryRow.modelData.name; color: entryRow.foreground; elide: Text.ElideRight }
            UI.Text { centerVertical: false; width: parent.width; visible: text.length > 0; textFormat: Text.PlainText; text: [entryRow.modelData.user, entryRow.modelData.folder].filter(Boolean).join(" · "); color: entryRow.secondaryForeground; elide: Text.ElideRight }
        }
    }
    UI.Text { centerVertical: false; anchors.centerIn: parent; text: Translations.text("vault.empty.entries"); visible: !list.entries.length && !list.busy }
}
