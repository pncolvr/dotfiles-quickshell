import QtQuick
import QtTest
import "../../src/services/audio/Screencast.js" as Screencast

TestCase {
    name: "Screencast"
    function node(id, props, description = "") { return {id, properties: props, description} }
    function test_individualStreams() {
        const source = node(1, {"media.class": "Video/Source"}, "Monitor 1")
        const first = node(2, {"media.class": "Stream/Input/Video", "application.name": "Browser"})
        const second = node(3, {"media.class": "Stream/Input/Video", "application.name": "Browser"})
        const audio = node(4, {"media.class": "Stream/Input/Audio"})
        const streams = Screencast.streams([first, second, audio, source],
            [{source, target: first}, {source, target: second}])
        compare(streams.length, 2)
        compare(streams[0].id, 2)
        compare(streams[1].id, 3)
        compare(streams[0].description, "Monitor 1")
    }
    function test_cameraAndUnknown() {
        for (const props of [{"media.role": "Camera"}, {"device.api": "v4l2"}, {"device.api": "libcamera"}]) {
            const camera = node(1, props)
            const receiver = node(2, {"media.class": "Stream/Input/Video"})
            compare(Screencast.streams([camera, receiver], [{source: camera, target: receiver}]).length, 0)
        }
        const unknown = node(3, {"media.class": "Stream/Input/Video", "application.process.binary": "tomato"})
        const streams = Screencast.streams([unknown], [])
        compare(streams.length, 1)
        compare(streams[0].description, "tomato")
        compare(Screencast.streams([node(4, {"media.class": "Stream/Input/Video", "media.name": "banana", "application.name": "potato"})], [])[0].description, "banana")
        compare(Screencast.streams([node(5, {"media.class": "Stream/Input/Video"})], [])[0].description, "Video capture")
        compare(Screencast.streams([], []).length, 0)
    }
}
