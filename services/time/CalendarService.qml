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
    function isSameDay(d1, d2) {
        return d1.getDate() === d2.getDate()
            && d1.getMonth() === d2.getMonth()
            && d1.getFullYear() === d2.getFullYear()
    }

    function formatDate(date) {
        if (!date) return ""
        let format = "yyyy-MM-dd 'at' hh:mm"
        const d = new Date(date)
        const d2 = new Date()
        if (isSameDay(d, d2)) {
            format = "'today at' hh:mm"
        } else if (isSameDay(d, d2.addDays(1))) {
            format = "'tomorrow at' hh:mm"
        }
        
        return Qt.formatDateTime(d, format)
    }

    Component.onCompleted: {

        Date.prototype.addDays = function(days) {
            var date = new Date(this.valueOf());
            date.setDate(date.getDate() + days);
            return date;
        }

    }
}
