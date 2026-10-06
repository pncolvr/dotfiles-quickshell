pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

Item {
    id: root
    required property url source
    readonly property int status: avatar.status

    // Recognize black padding at all four corners, then flood only the edges.
    // Enclosed dark details retain a fully opaque mask.
    function alphaMask(pixels, imageWidth, imageHeight) {
        const count = imageWidth * imageHeight
        const alpha = new Uint8Array(count)
        alpha.fill(255)
        if (!count) return alpha
        const corners = [0, imageWidth - 1, (imageHeight - 1) * imageWidth, count - 1]
        if (corners.some(index => pixels[index * 4 + 3] < 250
            || Math.max(pixels[index * 4], pixels[index * 4 + 1], pixels[index * 4 + 2]) > 6)) return alpha
        const removed = new Uint8Array(count)
        const queue = new Int32Array(count)
        let tail = 0
        function visit(index) {
            if (removed[index]) return
            const offset = index * 4
            if (pixels[offset + 3] > 0 && Math.max(pixels[offset], pixels[offset + 1], pixels[offset + 2]) > 6) return
            removed[index] = 1
            queue[tail++] = index
        }
        for (let x = 0; x < imageWidth; x++) {
            visit(x)
            visit((imageHeight - 1) * imageWidth + x)
        }
        for (let y = 0; y < imageHeight; y++) {
            visit(y * imageWidth)
            visit(y * imageWidth + imageWidth - 1)
        }
        for (let head = 0; head < tail; head++) {
            const index = queue[head]
            if (index % imageWidth > 0) visit(index - 1)
            if (index % imageWidth < imageWidth - 1) visit(index + 1)
            if (index >= imageWidth) visit(index - imageWidth)
            if (index < count - imageWidth) visit(index + imageWidth)
        }
        for (let i = 0; i < count; i++) alpha[i] = removed[i] ? 0 : 255
        return alpha
    }

    Image {
        id: avatar
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        smooth: true
        mipmap: true
        visible: false
        onStatusChanged: if (status === Image.Ready) paddingMask.requestPaint()
    }
    Canvas {
        id: paddingMask
        // A bounded, oversampled mask is computed once when the image changes.
        width: 128
        height: 128
        property bool ready: false
        property url loadedSource: ""
        function loadSource() {
            ready = false
            if (!available) return
            if (loadedSource.toString()) unloadImage(loadedSource)
            loadedSource = root.source
            if (!loadedSource.toString()) return
            loadImage(loadedSource)
            if (isImageLoaded(loadedSource)) requestPaint()
        }
        onAvailableChanged: if (available) loadSource()
        Connections { target: root; function onSourceChanged() { paddingMask.loadSource() } }
        onImageLoaded: requestPaint()
        onPaint: {
            if (avatar.status !== Image.Ready || !isImageLoaded(root.source)) return
            const ctx = getContext("2d")
            ctx.reset()
            const imageWidth = avatar.sourceSize.width
            const imageHeight = avatar.sourceSize.height
            const cropSize = Math.min(imageWidth, imageHeight)
            if (cropSize <= 0) return
            ctx.drawImage(root.source, (imageWidth - cropSize) / 2, (imageHeight - cropSize) / 2,
                cropSize, cropSize, 0, 0, width, height)
            const image = ctx.getImageData(0, 0, width, height)
            const pixels = image.data
            const alpha = root.alphaMask(pixels, width, height)
            const radius = width / 2
            for (let i = 0; i < alpha.length; i++) {
                const dx = i % width + 0.5 - radius
                const dy = Math.floor(i / width) + 0.5 - radius
                const coverage = Math.max(0, Math.min(1, radius + 0.5 - Math.sqrt(dx * dx + dy * dy)))
                pixels[i * 4] = 255
                pixels[i * 4 + 1] = 255
                pixels[i * 4 + 2] = 255
                pixels[i * 4 + 3] = Math.round(alpha[i] * coverage)
            }
            ctx.clearRect(0, 0, width, height)
            ctx.putImageData(image, 0, 0, 0, 0, width, height)
            ready = true
        }
    }
    ShaderEffectSource {
        id: maskTexture
        sourceItem: paddingMask
        hideSource: true
        visible: false
        textureSize: Qt.size(paddingMask.width, paddingMask.height)
    }
    MultiEffect {
        anchors.fill: parent
        source: avatar
        visible: paddingMask.ready && avatar.status === Image.Ready
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: maskTexture
    }
}
