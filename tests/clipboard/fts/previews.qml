pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../../src/modules/launcher"
import "../../../src/theme/ui" as UI
import "../../../src/config"

Scope {
    id: root
    property bool failed: false
    property int decodeChanges: 0
    readonly property string directory: Quickshell.env("PREVIEW_TEST_DIRECTORY")
    function check(ok, message) { if (!ok) { failed = true; console.error("PREVIEW FAIL:", message) } }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) { const found = find(child,name); if (found) return found }
        return null
    }
    function select(name) { preview.entry = {image:"file://" + directory + "/" + name} }
    function loaded() {
        events.tryCompare(root.image,"status",Image.Ready,4000)
        check(root.image.sourceSize.width * root.image.sourceSize.height <= Config.clipboardPreviewMaxPixels,"decode pixel budget")
        check(root.image.smooth && root.image.mipmap && root.image.fillMode === Image.PreserveAspectFit && !root.image.cache,"shared rendering policy")
    }
    function sampleRss() {
        rss.running = true
        events.tryCompare(rss,"running",false,2000)
        return Number(rssOutput.text.trim())
    }
    readonly property var image: find(preview,"clipboardLargeImage")
    Test.TestCase { id: events; when: false }
    Process {
        id: rss
        command: ["awk", "$1==\"VmRSS:\" {print $2}", "/proc/" + Quickshell.processId + "/status"]
        stdout: StdioCollector { id: rssOutput; waitForEnd: true }
    }
    Connections { target: root.image; function onSourceSizeChanged() { root.decodeChanges++ } }
    FloatingWindow {
        visible: true
        implicitWidth: 1000; implicitHeight: 760
        ClipboardImagePreview { id: preview; anchors.fill: parent; decodeWidth: 900; decodeHeight: 700 }
    }
    Timer {
        interval: 100; running: true
        onTriggered: {
            try {
                root.check(Math.abs(preview.pixelWidth / preview.decodeWidth - Number(Quickshell.env("QT_SCALE_FACTOR"))) < 0.01,"effective display scale")
                for (const name of ["landscape.png","portrait.jpg","tiny.png","transparent.webp","sample.gif","sample.bmp","sample.tiff","large.png"]) {
                    root.select(name); root.loaded()
                    root.check(root.image.paintedWidth <= root.image.width + 1 && root.image.paintedHeight <= root.image.height + 1,"aspect-fit remains inside preview")
                    root.check(root.image.paintedWidth <= preview.naturalSize.width / Number(Quickshell.env("QT_SCALE_FACTOR")) + 1
                        && root.image.paintedHeight <= preview.naturalSize.height / Number(Quickshell.env("QT_SCALE_FACTOR")) + 1,"preview never enlarges images beyond native pixels")
                    if (name === "tiny.png") root.check(root.image.sourceSize.width <= 8 && root.image.sourceSize.height <= 4
                        && Math.abs(root.image.paintedWidth - 8 / Number(Quickshell.env("QT_SCALE_FACTOR"))) < 1,"tiny image decodes and displays without enlargement")
                }
                root.select("landscape.png"); root.loaded()
                const initialWidth = root.image.sourceSize.width
                root.decodeChanges = 0
                for (let i = 0; i < 12; i++) { preview.decodeWidth = 700 + i * 20; events.wait(5) }
                events.wait(150)
                root.loaded()
                console.log("RESIZE METRICS",JSON.stringify({changes:root.decodeChanges,initial:initialWidth,current:root.image.sourceSize.width,target:preview.decodeSize.width}))
                root.check(root.decodeChanges <= 2 && root.image.sourceSize.width !== initialWidth,"resize requests coalesce and settle")
                preview.decodeWidth = 10000; preview.decodeHeight = 10000
                events.wait(150); root.loaded()
                root.check(root.image.sourceSize.width * root.image.sourceSize.height <= Config.clipboardPreviewMaxPixels,"large display size stays bounded")
                preview.decodeWidth = 450; preview.decodeHeight = 650
                events.wait(150); root.loaded()
                const resizedWidth = root.image.sourceSize.width
                root.check(resizedWidth <= Math.ceil(450 * Number(Quickshell.env("QT_SCALE_FACTOR"))),"monitor viewport change restores sharp bounded decode")
                preview.entry = {image:Quickshell.env("PREVIEW_TEST_SLOW_URL")}
                events.wait(40)
                root.check(root.image.status === Image.Loading && root.find(preview,"clipboardPreviewPending").visible,"slow load has explicit feedback")
                root.select("tiny.png"); root.loaded()
                events.wait(600)
                root.check(root.image.source.toString().endsWith("tiny.png") && root.image.status === Image.Ready,"late image completion cannot replace current selection")
                root.select("missing.png"); events.tryCompare(preview,"metadataError",true,2000)
                root.check(root.find(preview,"clipboardPreviewFeedback").visible,"missing image feedback")
                root.select("corrupt.png"); events.tryCompare(preview,"metadataError",true,2000)
                root.check(root.find(preview,"clipboardPreviewFeedback").text === "Image unavailable","corrupt image feedback")
                for (let i = 0; i < 12; i++) { root.select(i % 2 ? "large.png" : "portrait.jpg"); root.loaded(); events.wait(20) }
                events.wait(250)
                const firstRss = root.sampleRss()
                for (let i = 0; i < 12; i++) { root.select(i % 2 ? "large.png" : "portrait.jpg"); root.loaded(); events.wait(20) }
                events.wait(250)
                const secondRss = root.sampleRss()
                root.check(firstRss > 0 && secondRss - firstRss < 128000,"repeated navigation reaches a stable memory plateau")
                preview.entry = null; events.wait(500)
                root.check(root.image.source.toString() === "" && root.find(preview,"clipboardPreviewFeedback").visible,"close/empty releases active source")
                console.log("PREVIEW METRICS",JSON.stringify({scale:Number(Quickshell.env("QT_SCALE_FACTOR")),decodeChanges:root.decodeChanges,firstRssKiB:firstRss,secondRssKiB:secondRss,releasedRssKiB:root.sampleRss()}))
                if (!root.failed) console.log("PASS: image formats, scaling, resize coalescing, slow/stale loads, errors and release")
            } catch (_) { root.check(false,"rendering assertion") }
            Qt.quit()
        }
    }
}
