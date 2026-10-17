import QtQuick
import "../../theme"

// Rendering and font defaults without layout constraints or style-name overrides.
Text {
    renderType: Theme.textRenderType
    font.hintingPreference: Theme.fontHintingPreference
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: Theme.fontBold
}
