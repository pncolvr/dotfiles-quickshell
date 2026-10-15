pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell.Io
import "../../theme"
import "../../theme/ui" as UI

// A small, bounded working set shared by wallpaper and clipboard navigation.
// Decode one image at a time. Key repeat replaces the queued selection rather
// than cancelling every decode before it can produce a frame.
Item {
    id: root
    property string source: ""
    property var entries: []
    property bool loadSelected: true
    property bool prefetchEnabled: false
    property int frontSlot: -1
    property int busySlot: -1
    property var headerReader: null
    property int requestId: 0
    property bool busyWasSelection: false
    readonly property bool hasImage: frontSlot >= 0
    readonly property string displayedSource: frontSlot >= 0 ? frame(frontSlot).requestedSource : ""
    readonly property bool navigating: settle.running
    property int publishedFrames: 0
    property bool initialized: false

    component SmallImage: UI.ScaledImage {
        property string requestedSource: ""
        property size originalSize: Qt.size(0, 0)
    }
    function frame(slot): SmallImage { return frames.itemAt(slot) as SmallImage }
    function originalSizeFor(imageSource) {
        for (let i = 0; i < frames.count; i++) {
            const image = frame(i)
            if (image.requestedSource === imageSource && image.originalSize.width > 0) return image.originalSize
        }
        return Qt.size(0, 0)
    }
    function desiredSources() {
        if (!source.startsWith("file://")) return []
        const wanted = [source]
        const index = entries.findIndex(entry => entry.image === source)
        if (index >= 0) {
            for (const offset of [1, -1, 2, -2]) {
                const next = entries[index + offset]?.image ?? ""
                if (next.startsWith("file://") && !wanted.includes(next)) wanted.push(next)
            }
        }
        return wanted
    }
    function publish(slot) {
        if (frontSlot === slot) return
        frontSlot = slot
        publishedFrames++
    }
    function clear() {
        requestId++
        busySlot = -1
        frontSlot = -1
        if (headerReader) { headerReader.running = false; headerReader.destroy(); headerReader = null }
        for (let i = 0; i < frames.count; i++) { frame(i).source = ""; frame(i).requestedSource = "" }
    }
    function schedule() {
        if (!initialized) return
        const wanted = desiredSources()
        if (!wanted.length) { clear(); return }
        for (let i = 0; i < frames.count; i++) {
            const image = frame(i)
            if (image.requestedSource === source && image.status === Image.Ready) publish(i)
        }
        if (busySlot >= 0 || !loadSelected) return
        // Keep a ready previous image until a replacement has decoded.
        for (let i = 0; i < frames.count; i++) {
            if (i !== frontSlot && !wanted.includes(frame(i).requestedSource)) { frame(i).source = ""; frame(i).requestedSource = "" }
        }
        for (const next of wanted) {
            if (next !== source && !prefetchEnabled) return
            let exists = false
            for (let i = 0; i < frames.count; i++) {
                if (frame(i).requestedSource === next) { exists = true; break }
            }
            if (exists) continue
            for (let i = 0; i < frames.count; i++) {
                const image = frame(i)
                if (i === frontSlot || image.requestedSource) continue
                busySlot = i
                busyWasSelection = next === source
                image.requestedSource = next
                image.originalSize = Qt.size(0, 0)
                headerReader = metadataTask.createObject(root, {slot: i, imageSource: next, requestId: root.requestId})
                headerReader.running = true
                return
            }
        }
    }
    function completed(slot) {
        if (slot !== busySlot) return
        const image = frame(slot)
        if (!image || (image.status !== Image.Ready && image.status !== Image.Error)) return
        // Completed intermediate frames are useful while the key is held. Once
        // navigation stops, only the final selection may replace the preview.
        if (image.status === Image.Ready && (image.requestedSource === source || (busyWasSelection && navigating))) publish(slot)
        busySlot = -1
        work.restart()
    }
    onSourceChanged: { settle.restart(); work.restart() }
    onEntriesChanged: work.restart()
    onPrefetchEnabledChanged: work.restart()
    onLoadSelectedChanged: work.restart()
    Component.onCompleted: { initialized = true; work.restart() }
    Component {
        id: metadataTask
        Process {
            id: task
            required property int requestId
            required property int slot
            required property string imageSource
            command: ["bash", decodeURIComponent(Qt.resolvedUrl("../../services/clipboard/image-size.sh").toString().replace(/^file:\/\//,"")), decodeURIComponent(imageSource.slice(7))]
            stdout: StdioCollector { id: dimensions; waitForEnd: true }
            stderr: StdioCollector { waitForEnd: true }
            // qmllint disable signal-handler-parameters
            onExited: (code, status) => {
                if (requestId !== root.requestId) { task.destroy(); return }
                root.headerReader = null
                const image = root.frame(slot)
                const match = dimensions.text.trim().match(/^([1-9][0-9]*) ([1-9][0-9]*)$/)
                if (code !== 0 || status !== 0 || !match) {
                    root.busySlot = -1
                    work.restart()
                } else {
                    const w = Number(match[1]), h = Number(match[2])
                    image.originalSize = Qt.size(w, h)
                    const scale = Math.min(1, 192 / w, 192 / h)
                    image.sourceSize = Qt.size(Math.max(1, Math.floor(w * scale)), Math.max(1, Math.floor(h * scale)))
                    image.source = imageSource
                }
                task.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }
    Timer { id: work; interval: 0; onTriggered: root.schedule() }
    Timer { id: settle; interval: 150; onTriggered: work.restart() }
    Repeater {
        id: frames
        model: 7
        delegate: SmallImage {
            required property int index
            anchors.centerIn: parent
            width: Math.max(0, Math.min(root.width - Theme.controlSpacing * 2, originalSize.width / Screen.devicePixelRatio))
            height: Math.max(0, Math.min(root.height - Theme.controlSpacing * 2, originalSize.height / Screen.devicePixelRatio))
            opacity: index === root.frontSlot ? 1 : 0
            asynchronous: true
            cache: false
            onStatusChanged: root.completed(index)
        }
    }
}
