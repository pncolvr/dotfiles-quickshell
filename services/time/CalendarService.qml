pragma Singleton

import QtQuick
import Quickshell
import "../../config"

Singleton {
    
    function dateUrl(date) {
        const y = date.getFullYear()
        const m = date.getMonth() + 1
        const d = date.getDate()
        return `${Config.calendarUrl}/${y}/${m}/${d}`
    }

    function openDate(date) {
        Qt.openUrlExternally(dateUrl(date))
    }

    function formatDate(date) {
        if (!date) return ""
        const time = " 'at' hh:mm"
        let format = "yyyy-MM-dd"
        const d = new Date(date)
        const d2 = new Date()
        if (d.isSameDay(d2)) {
            format = "'today'"
        } else if (d.isSameDay(d2.addDays(1))) {
            format = "'tomorrow'"
        }
        return Qt.formatDateTime(d, format + time)
    }

    Component.onCompleted: {

        Date.prototype.addDays = function(days) {
            var date = new Date(this.valueOf())
            date.setDate(date.getDate() + days)
            return date
        }

        Date.prototype.isSameDay = function(date) {
            const now = new Date(this.valueOf())
            return now.getDate() === date.getDate()
                && now.getMonth() === date.getMonth()
                && now.getFullYear() === date.getFullYear()
        }

    }
}
