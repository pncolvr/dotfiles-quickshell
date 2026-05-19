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
}
