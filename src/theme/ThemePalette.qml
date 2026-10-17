import QtQuick

// Color data and contrast policy are private to Theme; components use Theme only.
QtObject {
    property bool darkMode: true
    readonly property var colors: darkMode ? dark : light
    readonly property var dark: ({
        background: "#000000", text: "#d8dadc", alternateBackground: "#be1b1a1a",
        accent: "#6B8FB3", urgent: "#B80F0A", ok: "#3E8E5A", active: "#5C9E7E",
        warning: "#fd6d37", inactive: "#b0b3b8", empty: "#8080804d",
        tooltipShadowColor: "black", selectionBackground: "#1b1b1b",
        selectionHoverBackground: "#30343a", selectionSelectedBackground: "#273441",
        selectionBorder: "#454a50", updatesUnchangedColor: "#62666b",
        batteryEmptyColor: "#232323", twitchColor: "#A970FF",
        notificationBackground: Qt.rgba(33 / 255, 34 / 255, 44 / 255, 0.95),
        notificationBorder: "#2a2d38", notificationCritical: "#d32f2f"
    })
    readonly property var light: ({
        background: "#f4f5f6", text: "#242a30", alternateBackground: "#bee6e8eb",
        accent: "#3f678e", urgent: "#a81915", ok: "#286542", active: "#2f6e52",
        warning: "#985021", inactive: "#626970", empty: "#b8c0c9",
        tooltipShadowColor: "black", selectionBackground: "#ffffff",
        selectionHoverBackground: "#e8edf2", selectionSelectedBackground: "#d9e5ef",
        selectionBorder: "#7d8995", updatesUnchangedColor: "#626b75",
        batteryEmptyColor: "#dde2e7", twitchColor: "#A970FF",
        notificationBackground: Qt.rgba(244 / 255, 245 / 255, 247 / 255, 0.95),
        notificationBorder: "#cad1d9", notificationCritical: "#b62424"
    })

    function luminance(color) {
        const linear = channel => channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
    }
    function foregroundOn(surface, background, text) {
        // Preserve the existing dark palette, including its filled-control text.
        if (darkMode) return text
        const fill = Qt.rgba(surface.r * surface.a + background.r * (1 - surface.a),
            surface.g * surface.a + background.g * (1 - surface.a),
            surface.b * surface.a + background.b * (1 - surface.a), 1)
        const contrast = color => (Math.max(luminance(fill), luminance(color)) + 0.05)
            / (Math.min(luminance(fill), luminance(color)) + 0.05)
        const white = Qt.rgba(1, 1, 1, 1)
        const normalContrast = contrast(text), whiteContrast = contrast(white)
        // Mid-tone hover fills can need black to keep a readable foreground.
        if (Math.max(normalContrast, whiteContrast) < 4.5) return Qt.rgba(0, 0, 0, 1)
        return normalContrast >= whiteContrast ? text : white
    }
}
