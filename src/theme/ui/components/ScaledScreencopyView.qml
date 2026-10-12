import QtQuick
import QtQuick.Window
import Quickshell.Wayland

ScreencopyView {
    live: visible && (Window.window?.visible ?? false)
    smooth: TextureSettings.smooth
    // Generate mipmaps from source pixels, including when parent transforms scale the view.
    layer.enabled: hasContent && width > 0 && height > 0
        && sourceSize.width > 0 && sourceSize.height > 0
    layer.textureSize: sourceSize
    layer.mipmap: TextureSettings.mipmap
    layer.smooth: TextureSettings.smooth
}
