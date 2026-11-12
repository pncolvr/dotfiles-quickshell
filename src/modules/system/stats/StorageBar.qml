pragma ComponentBehavior: Bound
import "../../../i18n"
import QtQuick
import "../../../theme"
import "../../../services"
import ".."

// Used / total space across every filesystem except EFI system partitions.
StatsBar {
    id: root
    property var diskService: DiskService
    objectName: "statsStorageBar"
    label: Translations.text("stats.overview.storage")
    value: diskService.formatBytes(diskService.totalUsed) + " / " + diskService.formatBytes(diskService.totalSize)
    ratio: diskService.totalSize > 0 ? diskService.totalUsed / diskService.totalSize : 0
    fillColor: ratio >= Theme.statsDiskUrgentRatio ? Theme.urgent : ratio > Theme.statsDiskWarningRatio ? Theme.warning : Theme.accent
    hint: Translations.text("stats.disks.usage", [diskService.formatBytes(diskService.totalUsed),
        diskService.formatBytes(diskService.totalSize), diskService.formatBytes(diskService.totalAvail)])
}
