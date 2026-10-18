pragma ComponentBehavior: Bound

import "../../i18n"
import QtQuick
import "../../services"
import "../../ui"
import "../../theme"

TooltipArea {
  moduleName: "clock"
  id: root
  leftMargin: Math.max(Theme.tooltipHoverPaddingWidth, Theme.moduleSpacing / 2)
  rightMargin: leftMargin
  acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

  enum View { Month, Year }
  property int viewMode: Clock.View.Month

  Component { id: monthComp; MonthTooltip {} }
  Component { id: yearComp; YearTooltip {} }

  tooltip: Component {
    Column {
      spacing: Theme.calendarSpacing
      ColumnText {
        width: calendar.width
        visible: text.length > 0
        text: CalendarService.clockChangeNotice
        wrapMode: Text.WordWrap
      }
      Loader {
        id: calendar
        sourceComponent: {
          switch (root.viewMode) {
            case Clock.View.Month: return monthComp
            case Clock.View.Year: return yearComp
          }
        }
      }
      ColumnText {
        objectName: "calendarColorLegend"
        readonly property var view: calendar.item
        readonly property date today: new Date(TimeService.time)
        readonly property bool showToday: view !== null && view.displayYear === today.getFullYear()
          && (root.viewMode === Clock.View.Year || view.displayMonth === today.getMonth())
        readonly property bool showHolidays: view !== null && CalendarService.hasHolidays(view.displayYear,
          root.viewMode === Clock.View.Year ? -1 : view.displayMonth)
        readonly property bool showClockChangeEve: view !== null && CalendarService.transitionsFor(view.displayYear)
          .some(event => root.viewMode === Clock.View.Year || Number(event.eve.slice(5, 7)) === view.displayMonth + 1)
        width: calendar.width
        visible: text.length > 0
        font.pixelSize: Theme.fontSize - 1
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.RichText
        text: [showToday ? '<font color="' + Theme.calendarTodayBackground + '">' + Translations.text("calendar.relative.today") + '</font>' : '',
             showHolidays ? '<font color="' + Theme.calendarHolidayBackground + '">' + Translations.text("calendar.legend.holiday") + '</font>' : '',
             showClockChangeEve ? '<font color="' + Theme.calendarClockChangeEveBackground + '">' + Translations.text("calendar.legend.changeEve") + '</font>' : '']
            .filter(hint => hint.length > 0).join(' · ')
      }
    }
  }

  Text {
    color: root.moduleIconColor
    text: Qt.formatDateTime(TimeService.time, TimeService.showSeconds ? "yyyy-MM-dd hh:mm:ss" : "yyyy-MM-dd hh:mm")
  }

  onAlternateClicked: (mouse) => {
    switch (mouse.button) {
      case Qt.MiddleButton:
        TimeService.showSeconds = !TimeService.showSeconds
        break
      case Qt.RightButton:
        root.viewMode = (root.viewMode + 1) % 2
        break
    }
  }
}
