pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Quickshell.Io
import "../../theme"
import "../../theme/ui" as UI
import "../../config"

Item {
    id: root
    property var entry: null
    property bool searching: false
    required property real decodeWidth
    required property real decodeHeight
    property size naturalSize: Qt.size(0,0)
    property bool metadataError: false
    property int metadataRequest: 0
    property var headerReader: null
    readonly property real pixelWidth: Math.max(1,decodeWidth * Screen.devicePixelRatio)
    readonly property real pixelHeight: Math.max(1,decodeHeight * Screen.devicePixelRatio)
    readonly property real decodeScale: naturalSize.width > 0 ? Math.min(1,
        pixelWidth / naturalSize.width, pixelHeight / naturalSize.height,
        Math.sqrt(Config.clipboardPreviewMaxPixels / (naturalSize.width * naturalSize.height)))
        : Math.min(1,Math.sqrt(Config.clipboardPreviewMaxPixels / (pixelWidth * pixelHeight)))
    readonly property size requestedDecodeSize: Qt.size(Math.max(1,Math.floor((naturalSize.width > 0 ? naturalSize.width : pixelWidth) * decodeScale)),
        Math.max(1,Math.floor((naturalSize.height > 0 ? naturalSize.height : pixelHeight) * decodeScale)))
    property size decodeSize: Qt.size(0,0)
    function updateDecodeSize() { resize.stop(); decodeSize = requestedDecodeSize }
    onRequestedDecodeSizeChanged: resize.restart()
    function loadMetadata() {
        metadataRequest++
        if (headerReader) { headerReader.running = false; headerReader.destroy(); headerReader = null }
        naturalSize = Qt.size(0,0); metadataError = false
        const source = entry?.image ?? ""
        if (!source) return
        // Clipboard payloads are local files. Other sources retain the bounded
        // loader behavior (used by synthetic delayed-network loading fixtures).
        if (!source.startsWith("file://")) { naturalSize = Qt.size(-1,-1); updateDecodeSize(); return }
        headerReader = metadataTask.createObject(root,{request:metadataRequest,
            imagePath:decodeURIComponent(source.slice(7))})
        headerReader.running = true
    }
    onEntryChanged: loadMetadata()
    Component.onCompleted: { if (!headerReader && naturalSize.width === 0) loadMetadata(); updateDecodeSize() }
    Component {
        id: metadataTask
        Process {
            id: task
            required property int request
            required property string imagePath
            command: ["bash",decodeURIComponent(Qt.resolvedUrl("../../services/clipboard/image-size.sh").toString().replace(/^file:\/\//,"")),imagePath]
            stdout: StdioCollector { id: dimensions; waitForEnd: true }
            stderr: StdioCollector { waitForEnd: true }
            // qmllint disable signal-handler-parameters
            onExited: (code,status) => {
                if (request === root.metadataRequest) {
                    const match = dimensions.text.trim().match(/^([1-9][0-9]*) ([1-9][0-9]*)$/)
                    root.metadataError = code !== 0 || status !== 0 || !match
                    if (!root.metadataError) { root.naturalSize = Qt.size(Number(match[1]),Number(match[2])); root.updateDecodeSize() }
                    root.headerReader = null
                }
                task.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }
    // Coalesce viewport/display-scale changes; mode animation already supplies
    // final viewport dimensions, so it does not request a decode on every frame.
    Timer { id: resize; interval: 100; onTriggered: root.updateDecodeSize() }
    UI.ScaledImage {
        id: image
        objectName: "clipboardLargeImage"
        anchors.centerIn: parent
        width: Math.max(0,Math.min(parent.width - Theme.controlSpacing * 2,
            root.naturalSize.width > 0 ? root.naturalSize.width / Screen.devicePixelRatio : parent.width))
        height: Math.max(0,Math.min(parent.height - Theme.controlSpacing * 2,
            root.naturalSize.height > 0 ? root.naturalSize.height / Screen.devicePixelRatio : parent.height))
        source: root.naturalSize.width !== 0 && !root.metadataError ? root.entry?.image ?? "" : ""
        sourceSize: root.decodeSize
        asynchronous: true
        retainWhileLoading: true
        cache: false
    }
    UI.Text {
        objectName: "clipboardPreviewFeedback"
        centerVertical: false
        anchors.centerIn: parent
        visible: !root.entry || root.metadataError || image.status === Image.Error
        text: root.metadataError || image.status === Image.Error ? "Image unavailable" : "No image selected"
        color: Theme.inactive
    }
    UI.Text {
        objectName: "clipboardPreviewPending"
        centerVertical: false
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.searching || root.headerReader !== null || image.status === Image.Loading
        text: root.searching ? "Searching…" : "Loading image…"
        color: Theme.inactive
    }
}
