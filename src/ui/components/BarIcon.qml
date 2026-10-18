import ".."
import "../../theme"

FixedIconText {
    // TooltipArea already contributes padding on both sides of each module.
    slotWidth: Math.ceil(glyphWidth) + Math.max(0, Theme.moduleSpacing - Theme.tooltipHoverPaddingWidth * 2)
    centerGlyphHorizontally: true
    font.pixelSize: Theme.fontSizeWorkspaces
}
