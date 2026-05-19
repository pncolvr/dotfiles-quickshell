pragma ComponentBehavior: Bound

import QtQuick
import "../../services"
import "../../theme/ui"

TooltipArea {
  id: root
  acceptedButtons: Qt.LeftButton | Qt.RightButton

  enum View { Month, Year }
  property int viewMode: Clock.View.Month

  Component { id: monthComp; MonthTooltip {} }
  Component { id: yearComp; YearTooltip {} }

  tooltip: Component {
    Loader {
      sourceComponent: {
        switch (root.viewMode) {
          case Clock.View.Month: return monthComp
          case Clock.View.Year: return yearComp
        }
      }
    }
  }

  Text {
    text: Qt.formatDateTime(TimeService.time, TimeService.showSeconds ? "yyyy-MM-dd hh:mm:ss" : "yyyy-MM-dd hh:mm")
  }

  onClicked: (mouse) => {
    switch (mouse.button) {
      case Qt.LeftButton:
        TimeService.showSeconds = !TimeService.showSeconds
        break
      case Qt.RightButton:
        root.viewMode = (root.viewMode + 1) % 2
        break
    }
  }
}
