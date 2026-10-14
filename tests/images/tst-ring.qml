import QtQuick
import QtTest
import "../../src/theme/ui/components/ImageCrop.mjs" as Crop

TestCase {
    name: "ImageRingDetection"
    function pixels(options) {
        const result = new Uint8Array(128 * 128 * 4)
        const cx = 63.5 + (options.dx || 0), cy = 63.5 + (options.dy || 0)
        for (let y = 0; y < 128; y++) for (let x = 0; x < 128; x++) {
            const radius = Math.hypot((x - cx) * (options.aspect || 1), y - cy)
            let color = [175 + x % 25, 30 + y % 20, 115 + x % 20]
            if (options.solid) color = options.color
            else if (options.square && (x < 5 || y < 5 || x > 122 || y > 122)) color = options.color
            else if (options.ring && radius >= (options.thick ? 43 : 57) && radius <= 61
                && (!options.broken || x < cx)) color = options.color
            else if (options.patch && x < 24 && y < 40) color = options.color
            const offset = (y * 128 + x) * 4
            for (let channel = 0; channel < 3; channel++) result[offset + channel] = color[channel]
            result[offset + 3] = options.transparent ? 0 : 255
        }
        return result
    }
    function test_colors_data() {
        return [{tag:"green",color:[0,255,0]}, {tag:"red",color:[255,20,30]},
            {tag:"blue",color:[20,90,250]}, {tag:"orange",color:[250,135,5]}]
    }
    function test_colors(data) {
        const ring = Crop.detectRing(pixels({ring:true,color:data.color}),128,128,1)
        verify(!!ring)
        verify(ring.x > 0 && ring.width > 0.8 && ring.width < 0.9)
        verify((ring.x + ring.width / 2) * 128 + ring.width * 64 < 63.5 + 57)
    }
    function test_offset() {
        const ring = Crop.detectRing(pixels({ring:true,color:[0,255,0],dx:2,dy:-2}),128,128,1)
        verify(!!ring)
        verify(Math.abs(ring.x + ring.width / 2 - 65.5 / 128) < 0.02)
    }
    function test_nonsquareSource() {
        const ring = Crop.detectRing(pixels({ring:true,color:[0,255,0],aspect:2}),128,128,2)
        verify(!!ring)
        verify(Math.abs(ring.width * 2 - ring.height) < 0.001)
    }
    function test_rejections_data() {
        return [{tag:"ordinary-photo"}, {tag:"green-area",patch:true}, {tag:"square-border",square:true},
            {tag:"solid-background",solid:true}, {tag:"thick-circle",ring:true,thick:true},
            {tag:"broken-circle",ring:true,broken:true}, {tag:"transparent",ring:true,transparent:true}]
    }
    function test_rejections(data) {
        data.color = [0,255,0]
        compare(Crop.detectRing(pixels(data),128,128,1),null)
    }
}
