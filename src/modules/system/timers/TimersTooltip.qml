import "../../../i18n"
import QtQuick
import "../../../services"
import "../../../theme"
import "../../../ui" as UI

Column {
    id: root
    width: Theme.timersTooltipWidth
    enabled: TimersService.ready
    spacing: Theme.controlSpacing
    property alias countdownTab: countdowns
    property alias timersTab: timers
    property alias currentIndex: tabs.currentIndex
    readonly property var activeTab: tabs.currentIndex === 0 ? countdowns : timers
    readonly property real maxListHeight: activeTab.maxListHeight

    UI.TabBar {
        id: tabs
        objectName: "timersTabs"
        width: parent.width
        labels: [Translations.text("timers.tabs.countdowns"), Translations.text("timers.tabs.stopwatches")]
    }
    Item {
        width: parent.width
        height: Math.max(countdowns.implicitHeight, timers.implicitHeight)
        CountdownTab { id: countdowns; width: parent.width; visible: tabs.currentIndex === 0 }
        StopwatchTab { id: timers; width: parent.width; visible: tabs.currentIndex === 1 }
    }
}
