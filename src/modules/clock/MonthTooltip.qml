import "../../theme/ui" as UI
import "../../services"

UI.MonthCalendar {
    onDaySelected: day => CalendarService.openDate(day)
}
