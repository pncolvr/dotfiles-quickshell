import QtQuick
import Quickshell
import Quickshell.Io
import "../../../services"

// Render outside the bar's viewport to snapshot provider images, including muted ones.
Image {
    id: root
    x: -8192
    y: -8192
    property var job: null
    property bool busy: false
    property bool capturing: false
    width: Math.max(1, Math.min(512, sourceSize.width))
    height: Math.max(1, Math.min(512, sourceSize.height))
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
    source: job?.source || ""
    readonly property string temporaryPath: job ? Quickshell.shellPath("data/notification-image-" + job.id + ".png") : ""
    readonly property string encoderPath: Quickshell.shellPath("services/notifications/encode-image.sh")

    function next() {
        if (!enabled || busy) return
        job = NotificationService.imageJobs[0] ?? null
        if (job) busy = true
    }
    function finish(data) {
        NotificationService.finishImage(job, data)
        job = null
        busy = false
        capturing = false
        Qt.callLater(next)
    }
    function capture() {
        if (!job || !busy || capturing) return
        if (status === Image.Error) { finish(""); return }
        if (status !== Image.Ready) return
        capturing = true
        const capturedJob = job
        const target = temporaryPath
        if (!grabToImage(result => {
            if (job !== capturedJob) return
            if (!result.saveToFile(target)) { finish(""); return }
            encoder.command = ["bash", root.encoderPath, target]
            encoder.running = true
        })) finish("")
    }
    onStatusChanged: if (busy) Qt.callLater(capture)
    onJobChanged: if (job) Qt.callLater(capture)
    onEnabledChanged: if (enabled) Qt.callLater(next)
    Connections { target: NotificationService; function onImageJobsChanged() { root.next() } }
    Process {
        id: encoder
        stdout: StdioCollector { onStreamFinished: root.finish(text.trim()) }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) console.warn("Notification image: " + text.trim()) }
    }
    Component.onCompleted: Qt.callLater(next)
}
