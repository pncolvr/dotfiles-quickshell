import QtQuick
import "../../services"
import "../../theme"
import "../../theme/ui" as UI

UI.TooltipArea {
    id: root
    objectName: "exposeButton"
    readonly property bool hovered: containsMouse
    acceptedButtons: Qt.LeftButton
    tooltipSource: root
    tooltip: Component {
        UI.ColumnText { text: "Exposé (Meta+Shift+E)" }
    }
    Accessible.name: "Exposé"
    onClicked: PickerService.expose("current")

    UI.IconText {
        objectName: "exposeBarIcon"
        text: Theme.exposeIcon
        color: root.hovered ? Theme.text
            : PickerService.visible && PickerService.layout === "expose" ? Theme.accent : Theme.inactive
    }
}
