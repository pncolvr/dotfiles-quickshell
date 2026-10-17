import "../../theme"

TextBase {
    property bool centerVertical: true
    anchors.verticalCenter: centerVertical ? parent.verticalCenter : undefined
    font.styleName: Theme.fontStyle
    font.weight: Theme.fontWeight
}
