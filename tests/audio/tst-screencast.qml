import QtQuick
import QtTest
import "../../src/services/audio"

TestCase {
    name: "Screencast"
    ScreencastModel { id: captures }
    function node(id, props, description = "") { return {id, properties: props, description} }
    function test_individualStreams() {
        const source = node(1, {"media.class": "Video/Source"}, "Monitor 1")
        const first = node(2, {"media.class": "Stream/Input/Video", "application.name": "Browser"})
        const second = node(3, {"media.class": "Stream/Input/Video", "application.name": "Browser"})
        const audio = node(4, {"media.class": "Stream/Input/Audio"})
        captures.nodes = [first, second, audio, source]
        captures.links = [{source, target: first}, {source, target: second}]
        const streams = captures.streams
        compare(streams.length, 2)
        compare(streams[0].id, 2)
        compare(streams[1].id, 3)
        compare(streams[0].description, "Monitor 1")
        captures.links = []
        compare(captures.streams[0].description, "Browser")
        captures.nodes = []
        compare(captures.streams.length, 0)
    }
    function test_cameraAndUnknown() {
        for (const props of [{"media.role": "Camera"}, {"device.api": "v4l2"}, {"device.api": "libcamera"}]) {
            const camera = node(1, props)
            const receiver = node(2, {"media.class": "Stream/Input/Video"})
            compare(captures.collectStreams([camera, receiver], [{source: camera, target: receiver}]).length, 0)
        }
        const unknown = node(3, {"media.class": "Stream/Input/Video", "application.process.binary": "tomato"})
        const streams = captures.collectStreams([unknown], [])
        compare(streams.length, 1)
        compare(streams[0].description, "tomato")
        compare(captures.collectStreams([node(4, {"media.class": "Stream/Input/Video", "media.name": "banana", "application.name": "potato"})], [])[0].description, "banana")
        compare(captures.collectStreams([node(5, {"media.class": "Stream/Input/Video"})], [])[0].description, "Video capture")
        compare(captures.collectStreams([], []).length, 0)
    }
}
