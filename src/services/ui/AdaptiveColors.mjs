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

export function sampleRegion(screen, barHeight, requestedHeight, clients, monitorId, workspaceId, specialId, borderSize) {
    const x = Math.round(screen.x), width = Math.floor(screen.width);
    const bottom = Math.floor(screen.y + screen.height);
    let y = Math.round(screen.y + barHeight + 1);
    let height = Math.min(Math.floor(requestedHeight), bottom - y);
    if (width < 1 || height < 1) return null;
    const border = Math.max(0, Math.ceil(borderSize));
    const edges = [];
    if (border > 0) for (const client of clients) {
        if (client.monitor !== monitorId || client.mapped === false || client.hidden
            || !(client.pinned || client.workspace?.id === workspaceId
                || (specialId !== 0 && client.workspace?.id === specialId))
            || !Array.isArray(client.at) || !Array.isArray(client.size)
            || !client.at.every(Number.isFinite) || !client.size.every(value => Number.isFinite(value) && value > 0)) continue;
        if (client.at[0] + client.size[0] + border <= x || client.at[0] - border >= x + width) continue;
        // Hyprland client positions/sizes describe the content rectangle.
        // Borders sit just outside it; include floating/pinned windows too.
        edges.push([client.at[1] - border, client.at[1]],
            [client.at[1] + client.size[1], client.at[1] + client.size[1] + border]);
    }
    // Moving below one border can expose another in staggered layouts.
    // Every move passes an edge, so this terminates without a retry timer.
    for (let remaining = edges.length; remaining > 0; remaining--) {
        const overlaps = edges.filter(edge => edge[0] < y + height && edge[1] > y);
        if (!overlaps.length) break;
        y = Math.ceil(Math.max(...overlaps.map(edge => edge[1])));
        height = Math.min(Math.floor(requestedHeight), bottom - y);
        if (height < 1) return null;
    }
    return {x, y, width, height};
}
