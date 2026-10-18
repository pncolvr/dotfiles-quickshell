function rgb(value) {
    if (value && typeof value.r === 'number') return [value.r, value.g, value.b];
    if (typeof value !== 'string' || !/^#[0-9a-f]{6}$/i.test(value)) return null;
    return [1, 3, 5].map(offset => parseInt(value.slice(offset, offset + 2), 16) / 255);
}

export function luminance(value) {
    const channels = rgb(value);
    if (!channels) return NaN;
    const linear = channels.map(channel => channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4);
    return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722;
}

export function contrast(first, second) {
    const a = luminance(first), b = luminance(second);
    return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
}

export function readable(surface, palette, text, indicators, margin = 0) {
    if (!Number.isFinite(luminance(surface))) return false;
    if (contrast(surface, text) < Math.min(4.5 + margin, contrast(palette, text))) return false;
    // Preserve the palette's semantic colors without requiring existing low-
    // contrast decorative colors to meet a new, impossible threshold on black.
    return indicators.every(color => contrast(surface, color)
        >= Math.min(3 + margin, contrast(palette, color) * 0.85));
}

export function hasTiledWindow(clients, monitorId, workspaceId, specialId = 0) {
    if (!Number.isInteger(monitorId) || !Number.isInteger(workspaceId)) return true;
    return clients.some(client => client.monitor === monitorId && client.mapped !== false
        && !client.hidden && !client.floating
        && (client.pinned || client.workspace?.id === workspaceId || (specialId !== 0 && client.workspace?.id === specialId)));
}
