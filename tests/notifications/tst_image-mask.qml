import QtQuick
import QtTest
import "../../src/modules/system/notifications" as Notifications

TestCase {
    name: "NotificationImageMask"

    Notifications.NotificationAvatar { id: avatar; source: ""; visible: false }

    function mask(rows) {
        const width = rows[0].length
        const pixels = new Uint8Array(width * rows.length * 4)
        for (let y = 0; y < rows.length; y++) {
            for (let x = 0; x < width; x++) {
                const offset = (y * width + x) * 4
                const pixel = rows[y][x]
                pixels[offset] = pixel === "R" ? 200 : pixel === "D" ? 3 : 0
                pixels[offset + 1] = pixel === "D" ? 3 : 0
                pixels[offset + 2] = pixel === "D" ? 3 : 0
                pixels[offset + 3] = pixel === "T" ? 0 : 255
            }
        }
        return Array.from(avatar.alphaMask(pixels, width, rows.length))
    }
    function test_paddingPreservesEnclosedBlackDetails() {
        compare(mask(["BBBBB", "BRRRB", "BRBRB", "BRRRB", "BBBBB"]),
            [0, 0, 0, 0, 0, 0, 255, 255, 255, 0, 0, 255, 255, 255, 0, 0, 255, 255, 255, 0, 0, 0, 0, 0, 0])
    }
    function test_nearBlackPadding() {
        compare(mask(["DDD", "DRD", "DDD"]), [0, 0, 0, 0, 255, 0, 0, 0, 0])
    }
    function test_blackWithoutFourPaddedCorners() {
        compare(mask(["RBB", "BBB", "BBB"]), [255, 255, 255, 255, 255, 255, 255, 255, 255])
    }
    function test_alreadyTransparentArtwork() {
        compare(mask(["TTT", "TBT", "TTT"]), [255, 255, 255, 255, 255, 255, 255, 255, 255])
    }
    function test_nonSquareImage() {
        compare(mask(["BBBBBBB", "BRRRRRB", "BBBBBBB"]),
            [0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0])
    }
}
