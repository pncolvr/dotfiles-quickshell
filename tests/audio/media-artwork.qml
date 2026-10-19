pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Quickshell
import Quickshell.Services.Mpris
import "../../src/config"
import "../../src/modules/system/audio"
import "../../src/services"

Scope {
    id: root
    property bool started: false
    function run() {
        if (started || cover.status !== Image.Ready) return
        started = true
        try {
            tests.test_config_default()
            for (const data of tests.test_styles_data()) {
                tests.test_styles(data)
                const preview = Quickshell.env("MEDIA_ARTWORK_PREVIEW")
                if (preview && data.size === 540 && data.style !== "unknown")
                    tests.grabImage(cover).save(preview + "-" + data.style + ".png")
            }
            tests.test_missing_artwork()
            tests.test_preferred_player()
            console.log("PASS: fullscreen artwork styles, responsive sizes, fallback and preferred-player entry")
        } catch (error) {
            console.error("ARTWORK FAIL:", error)
        }
        Qt.quit()
    }
    Component.onCompleted: Qt.callLater(root.run)
    Connections { target: cover; function onStatusChanged() { Qt.callLater(root.run) } }
    QtObject { id: audio }
    QtObject { id: media; property var players: [] }
    FloatingWindow {
        visible: true
        implicitWidth: 700
        implicitHeight: 700
        Item {
            anchors.fill: parent
            MediaFullscreenArtwork {
                id: cover
                width: 360
                height: implicitHeight
                source: Qt.resolvedUrl("art.svg")
                title: "<Live> & loud"
            }
            TestCase {
                id: tests
                name: "FullscreenArtwork"
                when: false
                function test_styles_data() {
                    const cases = []
                    for (const size of [180, 360, 540])
                        for (const style of ["plain", "cassette", "cd", "disc", "unknown"])
                            cases.push({tag: style + "-" + size, style, size})
                    return cases
                }
                function test_styles(data) {
                    cover.style = data.style
                    cover.width = data.size
                    const expected = data.style === "unknown" ? "plain" : data.style
                    compare(cover.resolvedStyle, expected)
                    compare(cover.height, data.size * (expected === "cassette" ? 0.64 : expected === "cd" ? 0.89 : 1))
                    tryCompare(cover, "status", Image.Ready)
                    const image = findChild(cover, "mediaArtwork")
                    verify(image)
                    compare(String(image.source), String(Qt.resolvedUrl("art.svg")))
                    verify(cover.printRect.x >= 0 && cover.printRect.y >= 0)
                    verify(cover.printRect.x + cover.printRect.width <= cover.width)
                    verify(cover.printRect.y + cover.printRect.height <= cover.height)
                    compare(image.width, cover.printRect.width)
                    compare(image.height, cover.printRect.height)
                    compare(findChild(cover, "mediaCassetteDecoration").visible, expected === "cassette")
                    compare(findChild(cover, "mediaCdDecoration").visible, expected === "cd")
                    compare(findChild(cover, "mediaDiscDecoration").visible, expected === "disc")
                    compare(image.circular, expected === "disc")
                    compare(cover.layer.enabled, expected === "disc")
                    if (expected === "disc" && Quickshell.env("MEDIA_ARTWORK_GPU") === "1") {
                        const rendered = grabImage(cover)
                        const middle = Math.floor(cover.width / 2)
                        compare(rendered.alpha(0, 0), 0)
                        compare(rendered.alpha(middle, middle), 0)
                        verify(rendered.alpha(middle, Math.floor(cover.height * 0.25)) > 0.98)
                    }
                    if (expected === "cassette") {
                        const title = findChild(cover, "mediaCassetteTitle")
                        compare(title.text, "<Live> & loud")
                        compare(title.textFormat, Text.PlainText)
                        const reels = findChild(cover, "mediaCassetteReels")
                        verify(reels.x >= cover.printRect.x && reels.y >= cover.printRect.y)
                        verify(reels.x + reels.width <= cover.printRect.x + cover.printRect.width)
                        verify(reels.y + reels.height <= cover.printRect.y + cover.printRect.height)
                    }
                }
                function test_config_default() {
                    const fresh = Qt.createComponent("../../src/modules/system/audio/MediaFullscreenArtwork.qml")
                    compare(fresh.status, Component.Ready)
                    const item = fresh.createObject(cover.parent, {width: 100}) as MediaFullscreenArtwork
                    verify(item)
                    compare(item.style, Config.mediaFullscreenArtworkStyle)
                    item.destroy()
                }
                function test_missing_artwork() {
                    cover.source = ""
                    for (const style of ["plain", "cassette", "cd", "disc"]) {
                        cover.style = style
                        tryCompare(cover, "status", Image.Null)
                        verify(findChild(cover, "mediaFullscreenArtworkFallback").visible)
                    }
                    cover.source = Qt.resolvedUrl("art.svg")
                }
                function test_preferred_player() {
                    const paused = {playbackState: MprisPlaybackState.Paused, isPlaying: false, canPlay: true}
                    const playing = {playbackState: MprisPlaybackState.Playing, isPlaying: true, canPlay: true}
                    const stopped = {playbackState: MprisPlaybackState.Stopped, isPlaying: false, canPlay: false}
                    media.players = [paused, playing]
                    verify(MediaFullscreenService.openPreferred(Quickshell.screens[0], audio, media))
                    compare(MediaFullscreenService.player, playing)
                    compare(MediaFullscreenService.targetScreen, Quickshell.screens[0])
                    compare(MediaFullscreenService.flipped, false)
                    verify(MediaFullscreenService.openPreferred(null, audio, media))
                    compare(MediaFullscreenService.targetScreen, Quickshell.screens[0])
                    MediaFullscreenService.forceClose()
                    media.players = [paused]
                    verify(MediaFullscreenService.openPreferred(null, audio, media))
                    compare(MediaFullscreenService.player, paused)
                    MediaFullscreenService.forceClose()
                    media.players = [stopped]
                    verify(!MediaFullscreenService.openPreferred(null, audio, media))
                    verify(!MediaFullscreenService.visible)
                    media.players = []
                    verify(!MediaFullscreenService.openPreferred(null, audio, media))
                }
            }
        }
    }
}
