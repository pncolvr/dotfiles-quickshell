import { analyze } from "./ImageCrop.mjs";

WorkerScript.onMessage = function(message) {
    const pixels = new Uint8Array(message.pixels.length * 4)
    for (let index = 0; index < message.pixels.length; index++) {
        const value = message.pixels[index], offset = index * 4
        pixels[offset] = value & 255
        pixels[offset + 1] = (value >>> 8) & 255
        pixels[offset + 2] = (value >>> 16) & 255
        pixels[offset + 3] = value >>> 24
    }
    const started = Date.now()
    const result = analyze(pixels, 128, 128, message.aspect)
    result.sourceWidth = message.width
    result.sourceHeight = message.height
    if (result.padding) result.padding = Array.from(result.padding)
    result.analysisMilliseconds = Date.now() - started
    WorkerScript.sendMessage({serial: message.serial, result})
}
