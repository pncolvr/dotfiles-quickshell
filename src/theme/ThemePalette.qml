import QtQuick

// Color data and contrast policy are private to Theme; components use Theme only.
QtObject {
    property bool darkMode: true
    readonly property var colors: darkMode ? dark : light
    readonly property var dark: ({
            background: "#000000",
            text: "#d8dadc",
            alternateBackground: "#be1b1a1a",
            accent: "#6B8FB3",
            urgent: "#B80F0A",
            // Button and field surfaces. Every button is labelled in `text`; fills
            // keep their hue with lightness moved until `text` reaches 4.5:1 on
            // normal, hover and pressed. Accent and urgent stay for foregrounds,
            // outlines and indicators, where the fills are too faint.
            controlFill: "#24272b",
            controlFillHover: "#33373c",
            controlFillPressed: "#1b1d20",
            controlBorder: "#454a51",
            accentFill: "#2a4c6d",
            accentFillHover: "#3d6082",
            accentFillPressed: "#1d3e5e",
            urgentFill: "#9d0000",
            urgentFillHover: "#b5281d",
            urgentFillPressed: "#850000",
            ok: "#3E8E5A",
            active: "#5C9E7E",
            warning: "#fd6d37",
            inactive: "#b0b3b8",
            empty: "#8080804d",
            tooltipShadowColor: "black",
            selectionBackground: "#1b1b1b",
            selectionHoverBackground: "#30343a",
            selectionSelectedBackground: "#273441",
            selectionBorder: "#454a50",
            updatesUnchangedColor: "#b0b3b8",
            batteryEmptyColor: "#232323",
            twitchColor: "#A970FF",
            notificationBackground: Qt.rgba(33 / 255, 34 / 255, 44 / 255, 0.95),
            notificationBorder: "#2a2d38",
            notificationCritical: "#d32f2f"
        })

    readonly property var light: ({
            background: "#fafbfc",              // near-white, barely cool; the "true black" equivalent
            text: "#101418",                    // near-black, ~17:1 contrast
            alternateBackground: "#ccedf0f3",   // visible but subtle row/panel tint
            accent: "#1f5fa6",                  // same hue family, more saturated
            urgent: "#c0121b",
            controlFill: "#e6e9ed",
            controlFillHover: "#d9dde2",
            controlFillPressed: "#c9cfd6",
            controlBorder: "#aab2bc",
            accentFill: "#609fec",
            accentFillHover: "#518fdb",
            accentFillPressed: "#4280ca",
            urgentFill: "#ff6e64",
            urgentFillHover: "#ed5e55",
            urgentFillPressed: "#db4d46",
            ok: "#1e7b44",
            active: "#12785a",
            warning: "#b4540a",
            inactive: "#5b626a",
            empty: "#c4cad2",
            tooltipShadowColor: "black",
            selectionBackground: "#ffffff",     // cards lift above the background
            selectionHoverBackground: "#eceff3",
            selectionSelectedBackground: "#d6e4f5", // clearer blue tint
            selectionBorder: "#c3cad2",         // thin and light instead of heavy
            updatesUnchangedColor: "#5b626a",
            batteryEmptyColor: "#e3e6ea",
            twitchColor: "#A970FF",
            notificationBackground: Qt.rgba(1, 1, 1, 0.97),
            notificationBorder: "#d3d8de",
            notificationCritical: "#c62020"
        })

    function luminance(color) {
        const linear = channel => channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
        return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b);
    }
    // Fills without explicit hover/pressed tokens move only in OKLCH lightness,
    // keeping hue and chroma: dark hovers lighter and presses darker; light does
    // both darker, so a hover never fades into the window. Qt.lighter/darker
    // scale channels, which barely changes near-black and clips near white.
    readonly property real hoverLightness: darkMode ? 0.07 : -0.05
    readonly property real pressedLightness: darkMode ? -0.05 : -0.10
    function shiftLightness(color, delta) {
        const linear = value => value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4);
        const encode = value => value <= 0.0031308 ? 12.92 * value : 1.055 * Math.pow(value, 1 / 2.4) - 0.055;
        const r = linear(color.r), g = linear(color.g), b = linear(color.b);
        const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
        const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
        const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
        const lightness = Math.min(1, Math.max(0, 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s + delta));
        const a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
        const bb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
        const hue = Math.atan2(bb, a);
        let chroma = Math.hypot(a, bb), rgb = null;
        // Lower chroma until the colour fits in sRGB, so clamping keeps the hue.
        for (let step = 0; step <= 100; step++) {
            const ca = chroma * Math.cos(hue), cb = chroma * Math.sin(hue);
            const l3 = Math.pow(lightness + 0.3963377774 * ca + 0.2158037573 * cb, 3);
            const m3 = Math.pow(lightness - 0.1055613458 * ca - 0.0638541728 * cb, 3);
            const s3 = Math.pow(lightness - 0.0894841775 * ca - 1.2914855480 * cb, 3);
            rgb = [4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
                -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
                -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3];
            if (rgb.every(value => value >= -0.0005 && value <= 1.0005)) break;
            chroma *= 0.97;
        }
        const channel = value => encode(Math.min(1, Math.max(0, value)));
        return Qt.rgba(channel(rgb[0]), channel(rgb[1]), channel(rgb[2]), color.a);
    }
    // The shift grows in its direction until it is visible (at least 1.1:1).
    // Returns null where that direction cannot show, as for white made lighter.
    function visibleShift(color, delta) {
        const contrast = (a, b) => (Math.max(luminance(a), luminance(b)) + 0.05) / (Math.min(luminance(a), luminance(b)) + 0.05);
        for (let step = 0; step < 40; step++) {
            const shifted = shiftLightness(color, Math.sign(delta) * (Math.abs(delta) + 0.01 * step));
            if (contrast(shifted, color) >= 1.1) return shifted;
        }
        return null;
    }
    function foregroundOn(surface, background, text) {
        // Preserve the existing dark palette, including its filled-control text.
        if (darkMode)
            return text;
        const fill = Qt.rgba(surface.r * surface.a + background.r * (1 - surface.a), surface.g * surface.a + background.g * (1 - surface.a), surface.b * surface.a + background.b * (1 - surface.a), 1);
        const contrast = color => (Math.max(luminance(fill), luminance(color)) + 0.05) / (Math.min(luminance(fill), luminance(color)) + 0.05);
        const white = Qt.rgba(1, 1, 1, 1);
        const normalContrast = contrast(text), whiteContrast = contrast(white);
        // Mid-tone hover fills can need black to keep a readable foreground.
        if (Math.max(normalContrast, whiteContrast) < 4.5)
            return Qt.rgba(0, 0, 0, 1);
        return normalContrast >= whiteContrast ? text : white;
    }
}
