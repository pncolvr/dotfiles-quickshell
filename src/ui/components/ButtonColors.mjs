// Compare rendered colors, including translucent fills, in the active palette.
export function composite(front, back) {
    const a = front.a ?? 1;
    return {r: front.r * a + back.r * (1 - a), g: front.g * a + back.g * (1 - a),
        b: front.b * a + back.b * (1 - a), a: 1};
}
export function luminance(color) {
    const linear = value => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
    return linear(color.r) * 0.2126 + linear(color.g) * 0.7152 + linear(color.b) * 0.0722;
}
export function contrast(first, second) {
    const a = luminance(first), b = luminance(second);
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}
function mix(first, second, amount) {
    return {r: first.r + (second.r - first.r) * amount,
        g: first.g + (second.g - first.g) * amount,
        b: first.b + (second.b - first.b) * amount, a: 1};
}
function tone(surface, candidate, target, lighter) {
    const edge = lighter ? {r: 1, g: 1, b: 1, a: 1} : {r: 0, g: 0, b: 0, a: 1};
    if (contrast(edge, surface) + 1e-6 < target) return null;
    const sameSide = (luminance(candidate) >= luminance(surface)) === lighter;
    let lowColor = surface, highColor = sameSide ? candidate : edge;
    if (contrast(highColor, surface) < target) { lowColor = highColor; highColor = edge; }
    let low = 0, high = 1;
    for (let step = 0; step < 20; step++) {
        const amount = (low + high) / 2;
        if (contrast(mix(lowColor, highColor, amount), surface) < target) low = amount;
        else high = amount;
    }
    return mix(lowColor, highColor, (low + high) / 2);
}
export function calibrate(surface, paletteBackground, reference, foreground = null) {
    if (reference.a === 0) return reference;
    if (['r', 'g', 'b'].every(key => Math.abs(surface[key] - paletteBackground[key]) < 1 / 65535))
        return reference;
    const original = composite(reference, paletteBackground);
    const target = contrast(original, paletteBackground);
    const candidate = composite(reference, surface);
    const lighter = luminance(original) >= luminance(paletteBackground);
    let result = tone(surface, candidate, target, lighter);
    const alternate = tone(surface, candidate, target, !lighter);
    if (!result) result = alternate;
    if (!result) {
        // An extreme palette contrast can exceed both available directions.
        const black = {r: 0, g: 0, b: 0, a: 1}, white = {r: 1, g: 1, b: 1, a: 1};
        return contrast(black, surface) >= contrast(white, surface) ? black : white;
    }
    if (foreground) {
        const minimum = Math.min(4.5, contrast(original, foreground));
        if (contrast(result, foreground) + 1e-5 < minimum) {
            if (alternate && contrast(alternate, foreground) + 1e-5 >= minimum) result = alternate;
            // Some surfaces cannot retain both the palette's fill contrast and
            // its text contrast. Keep the readable palette fill in that case.
            else return original;
        }
    }
    return result;
}
