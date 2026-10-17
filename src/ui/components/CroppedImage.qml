pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import QtQuick.Effects

Item {
    id: root
    property alias source: image.source
    property size sourceSize: Qt.size(-1, -1)
    property alias asynchronous: image.asynchronous
    property alias cache: image.cache
    smooth: TextureSettings.smooth
    property alias mipmap: image.mipmap
    property int fillMode: Image.PreserveAspectFit
    property bool circular: false
    property bool removeBlackPadding: false
    property bool detectionEnabled: true
    readonly property int status: image.status === Image.Loading && image.retainWhileLoading ? Image.Ready : image.status
    readonly property real progress: image.progress
    readonly property size originalSize: analysis?.sourceWidth > 0 ? Qt.size(analysis.sourceWidth, analysis.sourceHeight)
        : Qt.size(image.implicitWidth, image.implicitHeight)
    readonly property size decodedSize: image.sourceSize
    readonly property bool vectorSource: /(^data:image\/svg\+xml|\.svg(?:[?#]|$))/i.test(source.toString())
    readonly property real paintedWidth: paintRect.width
    readonly property real paintedHeight: paintRect.height
    property var analysis: null
    property string analysisKey: ""
    property string requestedKey: ""
    readonly property rect baseCrop: {
        if (analysis?.ring) {
            const ring = analysis.ring
            // Mipmaps can sample outside the inner edge at avatar sizes. Add
            // only the margin needed by this display size; fullscreen retains
            // the detector's larger crop and the original source texture.
            const pixels = Math.max(1, Math.min(width, height) * Screen.devicePixelRatio)
            // Trilinear filtering can reach almost two device pixels at a
            // fractional minification ratio between adjacent mip levels.
            const inset = Math.min(0.05, Math.max(0, 2 / pixels - 2 / (128 * Math.max(ring.width, ring.height))))
            return Qt.rect(ring.x + ring.width * inset, ring.y + ring.height * inset,
                ring.width * (1 - 2 * inset), ring.height * (1 - 2 * inset))
        }
        if (circular && originalSize.width > 0 && originalSize.height > 0) {
            const side = Math.min(originalSize.width, originalSize.height)
            return Qt.rect((1 - side / originalSize.width) / 2, (1 - side / originalSize.height) / 2,
                side / originalSize.width, side / originalSize.height)
        }
        return Qt.rect(0, 0, 1, 1)
    }
    readonly property real cropAspect: originalSize.height > 0 && baseCrop.height > 0
        ? originalSize.width * baseCrop.width / (originalSize.height * baseCrop.height) : 1
    readonly property rect paintRect: {
        if (fillMode !== Image.PreserveAspectFit || width <= 0 || height <= 0) return Qt.rect(0, 0, width, height)
        const w = Math.min(width, height * cropAspect), h = w / cropAspect
        return Qt.rect((width - w) / 2, (height - h) / 2, w, h)
    }
    readonly property rect displayCrop: {
        if (fillMode !== Image.PreserveAspectCrop || width <= 0 || height <= 0) return baseCrop
        const ratio = width / height
        const w = cropAspect > ratio ? baseCrop.width * ratio / cropAspect : baseCrop.width
        const h = cropAspect < ratio ? baseCrop.height * cropAspect / ratio : baseCrop.height
        return Qt.rect(baseCrop.x + (baseCrop.width - w) / 2, baseCrop.y + (baseCrop.height - h) / 2, w, h)
    }
    readonly property bool paddingNeeded: removeBlackPadding && !!analysis?.padding && !analysis?.ring
    readonly property bool circleNeeded: circular || !!analysis?.ring
    clip: true
    layer.enabled: circleNeeded || paddingNeeded
    layer.smooth: smooth
    layer.mipmap: mipmap
    layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio)),
        Math.max(1, Math.ceil(height * Screen.devicePixelRatio)))
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: maskTexture
        // MultiEffect's sharp default thresholds turn antialiased coverage
        // into a binary silhouette. Keep the mask's fractional edge alpha.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        autoPaddingEnabled: false
    }

    function requestAnalysis() {
        if (!detectionEnabled || status !== Image.Ready || !sampler.available) return
        const key = source.toString()
        if (!key || analysisKey === key) return
        const cached = ImageCropCache.lookup(key)
        if (cached) { analysisKey = key; analysis = cached; return }
        requestedKey = key
        ImageCropCache.request(key, root)
    }
    function cancelAnalysis() {
        if (requestedKey) ImageCropCache.cancel(requestedKey, root)
        requestedKey = ""
        sampler.clearSource()
    }
    function analyzeImage(key) {
        if (source.toString() !== key || status !== Image.Ready) { ImageCropCache.cancel(key, root); return }
        sampler.loadedSource = source
        sampler.submitted = false
        sampler.loadSource()
    }
    onSourceChanged: { cancelAnalysis(); analysis = null; analysisKey = ""; Qt.callLater(root.requestAnalysis) }
    // A cached crop can change SVG decode size immediately. Apply it after
    // Image's status notification has finished to avoid reentering its binding.
    onStatusChanged: Qt.callLater(root.requestAnalysis)
    onDetectionEnabledChanged: {
        if (detectionEnabled) Qt.callLater(root.requestAnalysis)
        else { cancelAnalysis(); analysis = null; analysisKey = "" }
    }
    Component.onDestruction: cancelAnalysis()
    Connections {
        target: ImageCropCache
        function onComputed(key: string, result: var) {
            if (key !== root.requestedKey) return
            root.analysisKey = key
            root.analysis = result
            root.requestedKey = ""
            sampler.clearSource()
        }
        function onRetry(key: string) { if (key === root.requestedKey) root.requestAnalysis() }
    }
    ScaledImage {
        id: image
        smooth: root.smooth
        // Raster artwork keeps every source pixel. Vector sources rasterize at
        // the current device size, so small SVGs also stay sharp in fullscreen.
        sourceSize: root.sourceSize.width > 0 || root.sourceSize.height > 0 ? root.sourceSize
            : root.vectorSource ? Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio)), -1) : undefined
        retainWhileLoading: root.analysisKey.length > 0 && root.analysisKey === source.toString()
        // Geometry changes only; the full-resolution source is never replaced
        // with the analysis thumbnail or a saved, resampled bitmap.
        x: root.paintRect.x - root.displayCrop.x * width
        y: root.paintRect.y - root.displayCrop.y * height
        width: root.displayCrop.width > 0 ? root.paintRect.width / root.displayCrop.width : 0
        height: root.displayCrop.height > 0 ? root.paintRect.height / root.displayCrop.height : 0
        fillMode: Image.Stretch
    }
    Canvas {
        id: sampler
        width: 128; height: 128
        visible: false
        property url loadedSource: ""
        property bool submitted: false
        function loadSource() {
            if (!loadedSource.toString() || intrinsicSource.status !== Image.Ready) return
            loadImage(loadedSource)
            if (isImageLoaded(loadedSource)) requestPaint()
        }
        function clearSource() {
            if (loadedSource.toString()) unloadImage(loadedSource)
            loadedSource = ""
        }
        onAvailableChanged: if (available) root.requestAnalysis()
        onImageLoaded: {
            if (isImageError(loadedSource)) ImageCropCache.finish(root.requestedKey, root, {ring: null, padding: null})
            else requestPaint()
        }
        onPaint: {
            if (submitted || !loadedSource.toString() || !isImageLoaded(loadedSource) || root.requestedKey !== loadedSource.toString()) return
            submitted = true
            const started = Date.now()
            const ctx = getContext("2d")
            ctx.reset()
            // Canvas pixel reads use device coordinates. Keep this thumbnail
            // exactly 128 physical pixels at every monitor scale factor.
            ctx.scale(1 / Screen.devicePixelRatio, 1 / Screen.devicePixelRatio)
            ctx.drawImage(loadedSource, 0, 0, width, height)
            const pixels = ctx.getImageData(0, 0, width, height).data
            const packed = new Array(width * height)
            for (let index = 0; index < packed.length; index++) {
                const offset = index * 4
                packed[index] = pixels[offset] | (pixels[offset + 1] << 8) | (pixels[offset + 2] << 16) | (pixels[offset + 3] << 24)
            }
            ImageCropCache.submit(root.requestedKey, root, packed, intrinsicSource.implicitWidth, intrinsicSource.implicitHeight, started)
        }
    }
    ScaledImage {
        id: intrinsicSource
        source: sampler.loadedSource
        asynchronous: true
        visible: false
        // A consumer's requested decode size may change a vector image's
        // aspect ratio. Analyze its intrinsic source, shared by Qt's image cache.
        onStatusChanged: {
            if (status === Image.Error) ImageCropCache.finish(root.requestedKey, root, {ring: null, padding: null})
            else if (status === Image.Ready) sampler.loadSource()
        }
    }
    Timer {
        interval: 5000
        running: sampler.loadedSource.toString().length > 0
        onTriggered: ImageCropCache.finish(root.requestedKey, root, {ring: null, padding: null})
    }
    Item {
        id: maskItem
        width: root.width; height: root.height
        // hideSource below keeps the mask offscreen without suppressing Canvas
        // initialization and paints through an invisible ancestor.
        Rectangle {
            visible: !root.paddingNeeded
            x: root.paintRect.x + (root.baseCrop.x - root.displayCrop.x) * image.width
            y: root.paintRect.y + (root.baseCrop.y - root.displayCrop.y) * image.height
            width: root.baseCrop.width * image.width
            height: root.baseCrop.height * image.height
            radius: root.circleNeeded ? Math.min(width, height) / 2 : 0
            antialiasing: true
            color: "white"
        }
        Canvas {
            id: paddingMask
            width: 128 / Screen.devicePixelRatio; height: width
            x: root.paintRect.x; y: root.paintRect.y
            transform: Scale { xScale: root.paintRect.width / paddingMask.width; yScale: root.paintRect.height / paddingMask.height }
            visible: root.paddingNeeded
            Connections {
                target: root
                function onAnalysisChanged() { paddingMask.requestPaint() }
                function onDisplayCropChanged() { paddingMask.requestPaint() }
            }
            onVisibleChanged: if (visible) requestPaint()
            onAvailableChanged: if (available) requestPaint()
            onPaint: {
                if (!root.paddingNeeded) return
                const ctx = getContext("2d")
                const side = 128
                const output = ctx.createImageData(side, side)
                const mask = root.analysis.padding
                for (let y = 0; y < side; y++) for (let x = 0; x < side; x++) {
                    const u = root.displayCrop.x + (x + 0.5) / side * root.displayCrop.width
                    const v = root.displayCrop.y + (y + 0.5) / side * root.displayCrop.height
                    const offset = (y * side + x) * 4
                    const index = Math.min(127, Math.floor(v * 128)) * 128 + Math.min(127, Math.floor(u * 128))
                    const coverage = root.circular ? Math.max(0, Math.min(1, 64.5 - Math.hypot(x - 63.5, y - 63.5))) : 1
                    output.data[offset] = 255; output.data[offset + 1] = 255; output.data[offset + 2] = 255
                    output.data[offset + 3] = Math.round(mask[index] * coverage)
                }
                ctx.reset()
                ctx.scale(1 / Screen.devicePixelRatio, 1 / Screen.devicePixelRatio)
                // Explicit dirty bounds also work with Qt versions that leave
                // the optional putImageData rectangle empty by default.
                ctx.putImageData(output, 0, 0, 0, 0, side, side)
            }
        }
    }
    ScaledTexture {
        id: maskTexture
        sourceItem: maskItem
        textureSize: Qt.size(Math.max(1, Math.ceil(root.width * Screen.devicePixelRatio)),
            Math.max(1, Math.ceil(root.height * Screen.devicePixelRatio)))
        hideSource: true
        visible: false
        // Generate circular edges at the display's actual resolution, including
        // fullscreen artwork. Only black-padding metadata uses a small bitmap.
    }
}
