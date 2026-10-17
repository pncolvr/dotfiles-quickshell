pragma ComponentBehavior: Bound
import "../../i18n"
import QtQuick
import QtQuick.Window
import Quickshell.Io
import "../../theme"
import "../../theme/ui" as UI
import "../../config"

Item {
    id: root
    property var entry: null
    property var entries: []
    property bool searching: false
    required property real decodeWidth
    required property real decodeHeight
    property bool motionEnabled: UI.MotionPolicy.enabled
    readonly property string selectedSource: entry?.image ?? ""
    readonly property real pixelWidth: Math.max(1, Math.min(decodeWidth, Math.max(1, width - Theme.controlSpacing * 2)) * Screen.devicePixelRatio)
    readonly property real pixelHeight: Math.max(1, Math.min(decodeHeight, Math.max(1, height - Theme.controlSpacing * 2)) * Screen.devicePixelRatio)
    property size naturalSize: Qt.size(0,0)
    readonly property real decodeScale: naturalSize.width > 0 ? Math.min(1,
        pixelWidth / naturalSize.width, pixelHeight / naturalSize.height,
        Math.sqrt(Config.clipboardPreviewMaxPixels / (naturalSize.width * naturalSize.height)))
        : Math.min(1, Math.sqrt(Config.clipboardPreviewMaxPixels / (pixelWidth * pixelHeight)))
    readonly property size requestedDecodeSize: Qt.size(Math.max(1, Math.floor((naturalSize.width > 0 ? naturalSize.width : pixelWidth) * decodeScale)),
        Math.max(1, Math.floor((naturalSize.height > 0 ? naturalSize.height : pixelHeight) * decodeScale)))
    property size decodeSize: Qt.size(0,0)
    property bool metadataError: false
    property int metadataRequest: 0
    property var headerReader: null
    property bool initialized: false
    property bool loading: false
    property double lastSelectionTime: 0
    property bool rapidBrowsing: false
    property int requestSlot: 0
    property int frontSlot: -1
    property int outgoingSlot: -1
    property real fadeProgress: 1
    readonly property bool transitioning: fade.running
    readonly property var currentImage: frame(requestSlot)
    function frame(slot) { return slot === 0 ? firstImage : secondImage }
    function finishTransition() {
        fade.stop()
        fadeProgress = 1
        if (outgoingSlot >= 0 && outgoingSlot !== frontSlot) frame(outgoingSlot).source = ""
        outgoingSlot = -1
    }
    function clearImages() {
        finishTransition()
        firstImage.source = ""; secondImage.source = ""
        frontSlot = -1
    }
    function prepareSlot() {
        finishTransition()
        requestSlot = frontSlot === 0 ? 1 : 0
        frame(requestSlot).source = ""
    }
    function selectSource() {
        if (!initialized) return
        metadataRequest++
        selectionDelay.stop(); resize.stop()
        if (headerReader) { headerReader.running = false; headerReader.destroy(); headerReader = null }
        prepareSlot()
        naturalSize = Qt.size(0,0); metadataError = false
        loading = selectedSource.length > 0
        if (!selectedSource) {
            lastSelectionTime = 0
            rapidBrowsing = false
            clearImages()
            return
        }
        const now = Date.now()
        rapidBrowsing = lastSelectionTime > 0 && now - lastSelectionTime < 100
        lastSelectionTime = now
        // Start sharp images immediately for ordinary selection. Only closely
        // spaced changes use small frames and defer the expensive sharp pass.
        if (rapidBrowsing) selectionDelay.restart()
        else loadMetadata()
    }
    function loadMetadata() {
        if (!selectedSource) return
        const knownSize = quickPreview.originalSizeFor(selectedSource)
        if (knownSize.width > 0) {
            naturalSize = knownSize
            updateDecodeSize()
            return
        }
        if (!selectedSource.startsWith("file://")) {
            naturalSize = Qt.size(-1,-1)
            updateDecodeSize()
            return
        }
        headerReader = metadataTask.createObject(root, {request:metadataRequest,
            imagePath:decodeURIComponent(selectedSource.slice(7))})
        headerReader.running = true
    }
    function updateDecodeSize() {
        resize.stop()
        if (!selectedSource || naturalSize.width === 0 || metadataError) return
        const target = requestedDecodeSize
        // A resize with the same effective target does not restart a decode.
        if (currentImage.source.toString() === selectedSource && target.width === decodeSize.width && target.height === decodeSize.height) return
        if (currentImage.source.toString()) prepareSlot()
        decodeSize = target
        const image = currentImage
        image.originalSize = naturalSize
        image.generation = metadataRequest
        // Assign the complete target before a source: never decode the new file
        // using the previous image's dimensions, or reload the retained frame.
        image.sourceSize = target
        loading = true
        image.source = selectedSource
    }
    function imageStatus(slot) {
        const image = frame(slot)
        if (slot !== requestSlot || image.generation !== metadataRequest || !image.source.toString()) return
        if (image.status === Image.Error) {
            metadataError = true; loading = false
            clearImages()
            return
        }
        if (image.status !== Image.Ready) return
        loading = false
        outgoingSlot = frontSlot
        frontSlot = slot
        if (motionEnabled && Theme.imagePreviewFadeDuration > 0) {
            fadeProgress = 0
            fade.restart()
        } else finishTransition()
    }
    onSelectedSourceChanged: selectSource()
    onRequestedDecodeSizeChanged: if (initialized && naturalSize.width !== 0) resize.restart()
    onMotionEnabledChanged: if (!motionEnabled) finishTransition()
    Component.onCompleted: { initialized = true; selectSource() }
    Component {
        id: metadataTask
        Process {
            id: task
            required property int request
            required property string imagePath
            command: ["bash", decodeURIComponent(Qt.resolvedUrl("../../services/clipboard/image-size.sh").toString().replace(/^file:\/\//,"")), imagePath]
            stdout: StdioCollector { id: dimensions; waitForEnd: true }
            stderr: StdioCollector { waitForEnd: true }
            // qmllint disable signal-handler-parameters
            onExited: (code,status) => {
                if (request === root.metadataRequest) {
                    const match = dimensions.text.trim().match(/^([1-9][0-9]*) ([1-9][0-9]*)$/)
                    root.metadataError = code !== 0 || status !== 0 || !match
                    root.headerReader = null
                    if (root.metadataError) { root.loading = false; root.clearImages() }
                    else {
                        root.naturalSize = Qt.size(Number(match[1]), Number(match[2]))
                        root.updateDecodeSize()
                    }
                }
                task.destroy()
            }
            // qmllint enable signal-handler-parameters
        }
    }
    Timer { id: selectionDelay; interval: 150; onTriggered: root.loadMetadata() }
    Timer { id: resize; interval: 100; onTriggered: root.updateDecodeSize() }
    UI.MotionAnimation {
        id: fade
        target: root; property: "fadeProgress"; from: 0; to: 1
        animationDuration: Theme.imagePreviewFadeDuration
        easing.type: Easing.OutCubic
        onFinished: root.finishTransition()
    }
    component PreviewImage: UI.ScaledImage {
        required property int slot
        property int generation: -1
        property size originalSize: Qt.size(0,0)
        objectName: slot === root.requestSlot ? "clipboardLargeImage" : "clipboardPreviousImage"
        anchors.centerIn: parent
        width: Math.max(0, Math.min(root.width - Theme.controlSpacing * 2,
            originalSize.width > 0 ? originalSize.width / Screen.devicePixelRatio : root.width))
        height: Math.max(0, Math.min(root.height - Theme.controlSpacing * 2,
            originalSize.height > 0 ? originalSize.height / Screen.devicePixelRatio : root.height))
        opacity: quickPreview.visible && (slot !== root.frontSlot || source.toString() !== root.selectedSource) ? 0 : slot === root.frontSlot ? root.fadeProgress : slot === root.outgoingSlot ? 1 - root.fadeProgress : 0
        asynchronous: true
        cache: false
        onStatusChanged: root.imageStatus(slot)
    }
    PreviewImage { id: firstImage; slot: 0 }
    PreviewImage { id: secondImage; slot: 1 }
    NavigationImagePreview {
        id: quickPreview
        objectName: "navigationImagePreview"
        anchors.fill: parent
        source: root.selectedSource
        entries: root.entries
        loadSelected: root.rapidBrowsing || !root.loading
        prefetchEnabled: !root.loading
        visible: root.rapidBrowsing && !root.metadataError && hasImage && (root.loading || root.transitioning
            || root.frontSlot < 0 || root.frame(root.frontSlot).source.toString() !== root.selectedSource)
        opacity: root.frontSlot >= 0 && root.frame(root.frontSlot).source.toString() === root.selectedSource
            && !root.loading ? 1 - root.fadeProgress : 1
    }
    UI.Text {
        objectName: "clipboardPreviewFeedback"
        centerVertical: false
        anchors.centerIn: parent
        visible: !root.selectedSource || root.metadataError || root.currentImage.status === Image.Error
        text: Translations.text(root.metadataError || root.currentImage.status === Image.Error ? "images.preview.unavailable" : "images.preview.empty")
        color: Theme.inactive
    }
    UI.Text {
        objectName: "clipboardPreviewPending"
        centerVertical: false
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.searching || root.loading
        text: Translations.text(root.searching ? "common.status.searching" : "images.preview.loading")
        color: Theme.inactive
    }
}
