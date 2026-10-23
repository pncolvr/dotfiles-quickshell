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
    Item {
      readonly property bool footerInGutter: legend.visible
      width: calendarBody.width
      height: calendarBody.height + (legend.visible ? Theme.tooltipPaddingWidth : 0)
      // The last date row already has space below its digits. Include that in
      // the legend's gutter so the visible gap is balanced above and below.
      FontMetrics {
        id: dateMetrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.bold: Theme.fontBold
        font.styleName: Theme.fontStyle
        font.weight: Theme.fontWeight
      }
      Column {
        id: calendarBody
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
      }
      ColumnText {
        id: legend
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
        anchors.bottom: parent.bottom
        height: Math.max(Theme.tooltipPaddingWidth, implicitHeight)
          + Math.max(0, (Theme.calendarCellHeight - dateMetrics.height) / 2 + dateMetrics.descent)
        verticalAlignment: Text.AlignVCenter
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
