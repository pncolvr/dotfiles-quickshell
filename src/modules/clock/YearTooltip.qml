pragma ComponentBehavior: Bound

import QtQuick
import "../../theme/ui" as UI
import "../../theme"
import "../../services"

Item {
    id: root

    property int displayYear: new Date(TimeService.time).getFullYear()

    readonly property int gridSpacing: 8
    readonly property int gridWidth: 3 * Theme.calendarWidth + 2 * gridSpacing

    width: gridWidth
    height: col.implicitHeight

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.angleDelta.y > 0) root.displayYear--
            else root.displayYear++
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: root.gridSpacing

        UI.ColumnText {
            width: parent.width
            text: root.displayYear
            horizontalAlignment: Text.AlignHCenter
        }

        Grid {
            columns: 3
            spacing: root.gridSpacing

            Repeater {
                model: 12
                delegate: MonthTooltip {
                    required property int index
                    wheelEnabled: false
                    showYearTitle: false
                    displayMonth: index
                    displayYear: root.displayYear
                }
            }
        }
    }
}
