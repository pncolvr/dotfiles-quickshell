pragma ComponentBehavior: Bound
import "../../../i18n"
import QtQuick
import "../../../theme"
import "../../../ui" as UI
import "../../../services"
import ".."

Column {
    id: root
    property var diskService: DiskService
    property bool efiExpanded: false
    readonly property var mainDisks: diskService.disks.filter(disk => !disk.efi)
    readonly property var efiDisks: diskService.disks.filter(disk => disk.efi)
    readonly property var emptyDisk: ({key: "", name: "", mount: "", mounts: [], size: 0, used: 0, avail: 0, read: 0, write: 0})
    spacing: Theme.controlSpacing
    Row {
        width: parent.width
        spacing: Theme.controlSpacing
        Repeater {
            model: ["read", "write"]
            Column {
                required property string modelData
                width: (root.width - Theme.controlSpacing) / 2
                spacing: 4
                UI.ColumnText {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.inactive
                    text: Translations.text("stats.disks." + parent.modelData)
                }
                UI.ColumnText {
                    objectName: parent.modelData === "read" ? "statsDisksReadTotal" : "statsDisksWriteTotal"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    color: parent.modelData === "read" ? Theme.statsDiskReadColor : Theme.statsDiskWriteColor
                    text: root.diskService.formatRate(parent.modelData === "read" ? root.diskService.readSpeed : root.diskService.writeSpeed)
                }
            }
        }
    }
    StorageBar {
        width: parent.width
        visible: root.diskService.totalSize > 0
        diskService: root.diskService
    }
    UI.EmptyState {
        objectName: "statsDisksStatus"
        visible: root.diskService.disks.length === 0 || root.diskService.error.length > 0
        color: root.diskService.error ? Theme.warning : Theme.inactive
        text: root.diskService.error || Translations.text(root.diskService.loading ? "stats.disks.loading" : "stats.disks.empty")
    }
    Column {
        width: parent.width
        spacing: Theme.statsDiskSpacing
        Repeater {
            // Count-based model keeps delegates (and their hover hints) across samples.
            model: root.mainDisks.length
            DiskRow {
                required property int index
                objectName: "statsDisk-" + disk.key
                width: root.width
                disk: root.mainDisks[index] ?? root.emptyDisk
                diskService: root.diskService
            }
        }
    }
    Column {
        width: parent.width
        spacing: Theme.statsDiskSpacing
        visible: root.efiDisks.length > 0
        UI.CollapsibleSection {
            id: efiToggle
            objectName: "statsDisksEfiToggle"
            width: parent.width
            implicitHeight: efiLabel.implicitHeight
            padding: 0
            expanded: root.efiExpanded
            onExpansionRequested: expanded => root.efiExpanded = expanded
            Accessible.name: Translations.text("stats.disks.system") + ", "
                + Translations.text(showingContent ? "common.actions.collapse" : "common.actions.expand")
            contentItem: Item {
                UI.ColumnText {
                    id: efiLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.inactive
                    text: Translations.text("stats.disks.system")
                }
                Rectangle {
                    anchors.left: efiLabel.right
                    anchors.leftMargin: Theme.controlSpacing
                    anchors.right: efiCount.left
                    anchors.rightMargin: Theme.controlSpacing
                    anchors.verticalCenter: parent.verticalCenter
                    height: 1
                    color: Theme.empty
                }
                UI.ColumnText {
                    id: efiCount
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.inactive
                    text: String(root.efiDisks.length)
                }
            }
        }
        Repeater {
            model: efiToggle.showingContent ? root.efiDisks.length : 0
            DiskRow {
                required property int index
                objectName: "statsDisk-" + disk.key
                width: root.width
                disk: root.efiDisks[index] ?? root.emptyDisk
                diskService: root.diskService
            }
        }
    }
}
