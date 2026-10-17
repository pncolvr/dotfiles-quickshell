import QtQuick
import "../../"

Text {
    renderType: Theme.textRenderType
    font.hintingPreference: Theme.fontHintingPreference
    property bool centerVertical: true
    anchors.verticalCenter: centerVertical ? parent.verticalCenter : undefined
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize
    font.bold: Theme.fontBold
    font.styleName: Theme.fontStyle
    font.weight: Theme.fontWeight
}
