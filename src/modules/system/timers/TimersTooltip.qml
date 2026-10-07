import QtQuick
import "../../../theme"
import "../../../theme/ui" as UI

Column {
    id: root
    width: Theme.timersTooltipWidth
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
        labels: ["Countdowns", "Timers"]
    }
    Item {
        width: parent.width
        height: Math.max(countdowns.implicitHeight, timers.implicitHeight)
        CountdownTab { id: countdowns; width: parent.width; visible: tabs.currentIndex === 0 }
        StopwatchTab { id: timers; width: parent.width; visible: tabs.currentIndex === 1 }
    }
}
