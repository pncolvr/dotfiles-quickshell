pragma ComponentBehavior: Bound
import QtQuick
import "../../../services"
import ".."

StatsBar {
    id: root
    property var statsService: StatsService
    objectName: "statsMemoryBar"
    label: "RAM"
    function size(mib) { return mib >= 1024 ? (mib / 1024).toFixed(1) + " GiB" : Math.round(mib) + " MiB" }
    value: root.size(root.statsService.memoryUsed) + " / " + root.size(root.statsService.memoryTotal)
    ratio: root.statsService.memoryTotal > 0 ? root.statsService.memoryUsed / root.statsService.memoryTotal : 0
    hint: "RAM used by apps and the kernel, excluding reclaimable memory.\nTotal is usable physical RAM."
}
