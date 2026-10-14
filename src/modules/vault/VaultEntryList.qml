pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QC
import "../../theme"
import "../../theme/ui" as UI

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
    delegate: QC.ItemDelegate {
        id: entryRow
        required property var modelData
        required property int index
        width: list.width
        padding: Theme.pickerRowPadding
        leftPadding: Theme.controlFieldPadding
        rightPadding: Theme.controlFieldPadding + Theme.scrollbarWidth
        height: Math.max(Theme.controlHeight, contentItem.implicitHeight + topPadding + bottomPadding)
        objectName: "vaultEntry-" + modelData.id
        onClicked: { list.currentIndex = index; list.entrySelected(modelData.id) }
        background: Rectangle { color: entryRow.index === list.currentIndex ? Theme.alternateBackground : "transparent"; radius: Theme.iconButtonRadius }
        contentItem: Column {
            UI.Text { centerVertical: false; width: parent.width; textFormat: Text.PlainText; text: entryRow.modelData.name; color: entryRow.index === list.currentIndex ? Theme.accent : Theme.text; elide: Text.ElideRight }
            UI.Text { centerVertical: false; width: parent.width; visible: text.length > 0; textFormat: Text.PlainText; text: [entryRow.modelData.user, entryRow.modelData.folder].filter(Boolean).join(" · "); color: entryRow.index === list.currentIndex ? Theme.accent : Theme.inactive; elide: Text.ElideRight }
        }
        Keys.onReturnPressed: list.entrySelected(modelData.id)
        Keys.onEnterPressed: list.entrySelected(modelData.id)
    }
    UI.Text { centerVertical: false; anchors.centerIn: parent; text: "No entries"; visible: !list.entries.length && !list.busy }
}
