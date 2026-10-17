import "../../../ui" as UI
import "../../../ui/components/ImageCrop.mjs" as ImageCrop

UI.CroppedImage {
    circular: true
    removeBlackPadding: true

    // Keep the existing padding-mask contract for notification image fixtures.
    function alphaMask(pixels, width, height) { return ImageCrop.paddingMask(pixels, width, height) }
}
