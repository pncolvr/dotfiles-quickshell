pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Templates as T
import Quickshell
import "../../theme"
import "ButtonColors.mjs" as Colors

// One state, focus, cursor and background policy for every button family.
Rectangle {
    id: root
    required property T.AbstractButton control
    property color fillColor: Theme.alternateBackground
    property color hoverColor: Theme.buttonHoverColor(fillColor)
    property color pressedColor: Theme.buttonPressedColor(hoverColor)
    property bool highlighted: false
    readonly property bool keyboardFocusVisible: pointerFocus.keyboardFocusVisible
    readonly property var adaptiveContrastColors: [Theme.text, Theme.inactive, Theme.accent, Theme.active, Theme.warning]
    readonly property color surfaceColor: resolveSurface()
    readonly property color referenceColor: !control.enabled ? fillColor
        : control.down ? pressedColor : control.hovered || highlighted ? hoverColor : fillColor
    color: colorFor(referenceColor)
    function colorFor(reference: color): color {
        const value = Colors.calibrate(surfaceColor, Theme.background, reference, Theme.foregroundOn(reference))
        return Qt.rgba(value.r, value.g, value.b, value.a)
    }
    radius: Theme.iconButtonRadius
    border.width: keyboardFocusVisible ? 1 : 0
    border.color: Theme.accent

    function surfaceMarker(item: var): var { return item.buttonSurfaceColor }
    function windowColor(window: var): color { return window?.buttonSurfaceColor ?? window?.color ?? Theme.background }
    function resolveSurface(): color {
        const layers = []
        let base = Theme.background
        for (let item = control.parent; item; item = item.parent) {
            const marker = surfaceMarker(item)
            if (marker !== undefined) { base = marker; break }
            if (item instanceof Rectangle) layers.push((item as Rectangle).color)
            else if (item instanceof T.Control && (item as T.Control).background instanceof Rectangle)
                layers.push(((item as T.Control).background as Rectangle).color)
            if (!item.parent) {
                const window = control.QsWindow.window
                base = windowColor(window)
            }
        }
        let value = Colors.composite(base, Theme.background)
        for (let index = layers.length - 1; index >= 0; index--) value = Colors.composite(layers[index], value)
        return Qt.rgba(value.r, value.g, value.b, 1)
    }
    PointerFocus { id: pointerFocus; parent: root.control }
    FocusReveal { owner: root.control }
    HoverHandler {
        parent: root.control
        target: null
        cursorShape: root.control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
