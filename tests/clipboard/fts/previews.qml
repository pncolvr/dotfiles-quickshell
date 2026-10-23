pragma ComponentBehavior: Bound
import QtQuick
import "../../../src/services"
import QtQuick.Window
import QtTest as Test
import Quickshell
import Quickshell.Io
import "../../../src/modules/launcher"
import "../../../src/config"
import "../../../src/theme"

WorkerScope {
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
        events.tryCompare(preview,"transitioning",false,1000)
        check(root.image.sourceSize.width * root.image.sourceSize.height <= Config.clipboardPreviewMaxPixels,"decode pixel budget")
        check(root.image.sourceSize.width <= preview.pixelWidth + 1 && root.image.sourceSize.height <= preview.pixelHeight + 1,"decode is bounded by the real preview pane")
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
    Connections { target: preview; function onDecodeSizeChanged() { root.decodeChanges++ } }
    FloatingWindow {
        visible: true
        implicitWidth: 1000; implicitHeight: 760
        ClipboardImagePreview { id: preview; anchors.fill: parent; decodeWidth: 900; decodeHeight: 700 }
    }
    Timer {
        interval: 100; running: true
        onTriggered: {
            try {
                root.check(Math.abs(preview.pixelWidth / Math.min(preview.decodeWidth, Math.max(1, preview.width - Theme.controlSpacing * 2)) - Number(Quickshell.env("QT_SCALE_FACTOR"))) < 0.01,"effective display scale")
                for (const name of ["landscape.png","portrait.jpg","tiny.png","transparent.webp","sample.gif","sample.bmp","sample.tiff","large.png"]) {
                    events.wait(120)
                    root.select(name)
                    root.check(!preview.rapidBrowsing && !root.find(preview,"navigationImagePreview").visible,"ordinary selection never shows a pixelated preview")
                    root.loaded()
                    root.check(root.image.paintedWidth <= root.image.width + 1 && root.image.paintedHeight <= root.image.height + 1,"aspect-fit remains inside preview")
                    root.check(root.image.paintedWidth <= preview.naturalSize.width / Number(Quickshell.env("QT_SCALE_FACTOR")) + 1
                        && root.image.paintedHeight <= preview.naturalSize.height / Number(Quickshell.env("QT_SCALE_FACTOR")) + 1,"preview never enlarges images beyond native pixels")
                    const small = root.find(preview,"navigationImagePreview")
                    events.tryCompare(small,"displayedSource",preview.selectedSource,2000)
                    const thumbnail = small.frame(small.frontSlot)
                    root.check(thumbnail.sourceSize.width <= 192 && thumbnail.sourceSize.height <= 192,"both dimensions of the navigation decode are bounded")
                    root.check(thumbnail.width <= thumbnail.originalSize.width / Number(Quickshell.env("QT_SCALE_FACTOR")) + 1
                        && thumbnail.height <= thumbnail.originalSize.height / Number(Quickshell.env("QT_SCALE_FACTOR")) + 1,"small previews do not enlarge tiny images")
                    if (name === "tiny.png") root.check(root.image.sourceSize.width <= 8 && root.image.sourceSize.height <= 4
                        && Math.abs(root.image.paintedWidth - 8 / Number(Quickshell.env("QT_SCALE_FACTOR"))) < 1,"tiny image decodes and displays without enlargement")
                }
                // Test a cached neighbor with no metadata process or network delay:
                // a single step must already have queued its sharp decode here.
                const quick = root.find(preview,"navigationImagePreview")
                preview.entries = ["landscape.png", "portrait.jpg", "transparent.webp"].map(name => ({image:"file://" + root.directory + "/" + name}))
                events.wait(120)
                root.select("portrait.jpg"); root.loaded()
                events.tryVerify(() => quick.originalSizeFor("file://" + root.directory + "/landscape.png").width > 0,4000)
                events.wait(120)
                root.select("landscape.png")
                root.check(root.image.source.toString().endsWith("landscape.png") && root.image.sourceSize.width > 192,
                    "a single cached-neighbor step queues the sharp image immediately without the 150ms delay")
                root.check(!preview.rapidBrowsing && !quick.visible,"cached small previews remain hidden during a single step")
                root.loaded()
                preview.entries = []
                const unchangedRequest = preview.metadataRequest
                preview.entry = {image:preview.entry.image, title:"Refreshed row object"}
                events.wait(80)
                root.check(preview.metadataRequest === unchangedRequest && root.image.status === Image.Ready,"same source survives row refresh without decoding again")
                const scale = preview.Screen.devicePixelRatio
                // Reproduce the short-pane case even when the compositor leaves
                // this fixture a large window: decoding must be height-limited.
                preview.decodeHeight = root.image.sourceSize.height / scale * 0.5
                events.tryVerify(() => preview.decodeSize.width === preview.requestedDecodeSize.width
                    && preview.decodeSize.height === preview.requestedDecodeSize.height,1000)
                root.loaded()
                const initialWidth = root.image.sourceSize.width
                root.check(initialWidth < preview.pixelWidth,"resize fixture starts height-limited")
                root.decodeChanges = 0
                // Start below the actual fitted width: on short native panes,
                // height can limit decoding before the configured width does.
                const smallerWidth = initialWidth / scale * 0.6
                for (let i = 0; i < 12; i++) preview.decodeWidth = smallerWidth * (1 + i * 0.02)
                const target = preview.requestedDecodeSize
                root.check(target.width < initialWidth,"resize fixture changes the effective decode target")
                events.tryVerify(() => preview.decodeSize.width === target.width && preview.decodeSize.height === target.height,1000)
                root.loaded()
                console.log("RESIZE METRICS",JSON.stringify({changes:root.decodeChanges,initial:initialWidth,current:root.image.sourceSize.width,target:target.width}))
                root.check(root.decodeChanges > 0 && root.decodeChanges <= 2 && root.image.sourceSize.width === target.width,
                    "resize requests coalesce and settle on the final effective target")
                const unchangedImage = root.image
                root.decodeChanges = 0
                preview.decodeHeight = preview.pixelHeight / scale * 0.9
                root.check(preview.requestedDecodeSize.width === target.width && preview.requestedDecodeSize.height === target.height,
                    "non-limiting height change keeps the effective decode target")
                events.wait(150)
                root.check(root.decodeChanges === 0 && root.image === unchangedImage && root.image.status === Image.Ready,
                    "unchanged effective decode size does not restart the image")
                preview.decodeWidth = 10000; preview.decodeHeight = 10000
                events.wait(150); root.loaded()
                root.check(root.image.sourceSize.width * root.image.sourceSize.height <= Config.clipboardPreviewMaxPixels,"large display size stays bounded")
                preview.decodeWidth = 450; preview.decodeHeight = 650
                events.wait(150); root.loaded()
                const resizedWidth = root.image.sourceSize.width
                root.check(resizedWidth <= Math.ceil(450 * Number(Quickshell.env("QT_SCALE_FACTOR"))),"monitor viewport change restores sharp bounded decode")
                preview.entry = {image:Quickshell.env("PREVIEW_TEST_SLOW_URL")}
                events.tryCompare(root.image,"status",Image.Loading,500)
                root.check(root.find(preview,"clipboardPreviewPending").visible,"slow load has explicit feedback")
                const retained = preview.frame(preview.frontSlot)
                root.check(retained.source.toString().endsWith("landscape.png") && retained.opacity === 1,"previous image stays visible while replacement loads")
                events.tryCompare(root.image,"status",Image.Ready,4000)
                root.check(preview.transitioning && root.image.opacity < 1 && preview.outgoingSlot >= 0,"ready replacement starts a shared crossfade")
                events.wait(45)
                root.check(root.image.opacity > 0 && root.image.opacity < 1 && retained.source.toString().length > 0,"crossfade keeps both frames while changing opacity")
                events.tryCompare(preview,"transitioning",false,1000)
                root.check(retained.source.toString() === "","completed fade releases previous source")
                preview.motionEnabled = false
                root.select("portrait.jpg"); root.loaded()
                root.check(!preview.transitioning && root.image.opacity === 1 && preview.outgoingSlot === -1,"disabled motion settles immediately")
                preview.motionEnabled = true
                // An interrupted network load can never replace the newly selected local image.
                preview.entry = {image:Quickshell.env("PREVIEW_TEST_SLOW_URL")}
                events.tryCompare(root.image,"status",Image.Loading,500)
                root.select("tiny.png"); root.loaded()
                events.wait(600)
                root.check(root.image.source.toString().endsWith("tiny.png") && root.image.status === Image.Ready,"late image completion cannot replace current selection")
                // Rapid navigation settles on its final selection and keeps the old frame readable.
                for (const name of ["large.png","portrait.jpg","landscape.png","tiny.png"]) { root.select(name); events.wait(5) }
                root.loaded()
                root.check(root.image.source.toString().endsWith("tiny.png"),"rapid navigation publishes only the final selection")
                const coldStart = quick.publishedFrames
                for (let i = 0; i < 32; i++) { root.select("held-" + (i % 8) + ".png"); events.wait(25) }
                const coldFrames = quick.publishedFrames - coldStart
                root.check(coldFrames > 1,"uncached large images publish during held navigation rather than starving until idle")
                root.loaded()
                root.check(root.image.source.toString().endsWith("held-7.png"),"uncached navigation settles on its final selection")
                // Warm only a bounded neighborhood, then hold arrows faster than
                // the sharp-pass delay. Each cached row must still paint now.
                preview.entries = ["landscape.png", "portrait.jpg", "transparent.webp", "sample.bmp", "sample.tiff"].map(name => ({image:"file://" + root.directory + "/" + name}))
                root.select("transparent.webp"); root.loaded()
                events.tryCompare(quick,"busySlot",-1,4000)
                events.wait(100)
                const started = Date.now()
                const before = quick.publishedFrames
                for (let i = 0; i < 24; i++) {
                    const name = ["portrait.jpg", "transparent.webp", "sample.bmp"][i % 3]
                    root.select(name); events.wait(25)
                    if (i > 0) root.check(preview.rapidBrowsing && quick.visible,"rapid browsing enables the low-resolution path")
                    root.check(quick.displayedSource.endsWith(name),"held arrows display the selected low-resolution frame without waiting for idle")
                }
                const warmElapsed = Date.now() - started
                root.check(quick.publishedFrames - before >= 24 && warmElapsed < 2500,"small neighboring previews keep up with repeated navigation")
                root.check(quick.frame(quick.frontSlot).sourceSize.width <= 192 && quick.frame(quick.frontSlot).sourceSize.height <= 192,"navigation preview stays small")
                root.loaded()
                root.check(root.image.source.toString().endsWith("sample.bmp") && root.image.sourceSize.width > 192 && !quick.visible,"final selection sharpens to the viewport and hides the small preview")
                events.wait(120)
                root.select("portrait.jpg")
                root.check(!preview.rapidBrowsing && !quick.visible,"a single step after fast browsing returns directly to sharp loading")
                root.loaded()
                console.log("NAVIGATION METRICS",JSON.stringify({coldFrames:coldFrames,warmSteps:24,warmElapsedMs:warmElapsed}))
                preview.entries = []
                root.select("missing.png"); events.tryCompare(preview,"metadataError",true,2000)
                root.check(root.find(preview,"clipboardPreviewFeedback").visible && preview.frontSlot === -1,"missing image feedback releases the previous image")
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
                root.check(root.image.source.toString() === "" && preview.frame(0).source.toString() === "" && preview.frame(1).source.toString() === ""
                    && !quick.hasImage && quick.busySlot === -1
                    && root.find(preview,"clipboardPreviewFeedback").visible,"close/empty releases both image sources")
                console.log("PREVIEW METRICS",JSON.stringify({scale:Number(Quickshell.env("QT_SCALE_FACTOR")),paneWidth:preview.width,paneHeight:preview.height,decodeChanges:root.decodeChanges,firstRssKiB:firstRss,secondRssKiB:secondRss,releasedRssKiB:root.sampleRss()}))
                if (!root.failed) console.log("PASS: image formats, scaling, resize coalescing, slow/stale loads, errors and release")
            } catch (_) { root.check(false,"rendering assertion") }
            Qt.quit()
        }
    }
}
