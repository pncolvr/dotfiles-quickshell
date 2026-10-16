import QtQuick
import QtQuick.Dialogs as Dialogs

Dialogs.FolderDialog {
    id: root
    property bool settling: false
    readonly property bool nativeDialogOpen: visible || settling
    readonly property string selectedPath: pathFor(selectedFolder)
    signal folderSelected(string path)
    function pathFor(folder) { return decodeURIComponent(folder.toString().replace(/^file:\/\/(?:localhost)?/, "")) }
    function finishSession() { if (!visible) settling = false }
    // A native dialog can become invisible before it emits accepted. Deliver the
    // result while its owner is still retained, then restore focus next turn.
    onVisibleChanged: {
        if (visible) settling = true
        else Qt.callLater(root.finishSession)
    }
    onAccepted: { folderSelected(pathFor(selectedFolder)); root.finishSession() }
    onRejected: root.finishSession()
    options: Dialogs.FolderDialog.ReadOnly
}
