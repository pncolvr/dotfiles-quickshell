
// Work on a bounded thumbnail; all returned crop coordinates refer to the source.
export function paddingMask(pixels, width, height) {
    const count = width * height
    const alpha = new Uint8Array(count)
    alpha.fill(255)
    if (!count) return alpha
    const corners = [0, width - 1, (height - 1) * width, count - 1]
    if (corners.some(index => pixels[index * 4 + 3] < 250
        || Math.max(pixels[index * 4], pixels[index * 4 + 1], pixels[index * 4 + 2]) > 6)) return alpha
    const removed = new Uint8Array(count)
    const queue = new Int32Array(count)
    let head = 0, tail = 0
    function visit(index) {
        if (removed[index]) return
        const offset = index * 4
        if (pixels[offset + 3] > 0 && Math.max(pixels[offset], pixels[offset + 1], pixels[offset + 2]) > 6) return
        removed[index] = 1
        queue[tail++] = index
    }
    for (let x = 0; x < width; x++) { visit(x); visit((height - 1) * width + x) }
    for (let y = 0; y < height; y++) { visit(y * width); visit(y * width + width - 1) }
    while (head < tail) {
        const index = queue[head++]
        if (index % width > 0) visit(index - 1)
        if (index % width < width - 1) visit(index + 1)
        if (index >= width) visit(index - width)
        if (index < count - width) visit(index + width)
    }
    for (let index = 0; index < count; index++) if (removed[index]) alpha[index] = 0
    return alpha
}

export function detectRing(pixels, width, height, aspect) {
    const scaleX = aspect > 1 ? 1 / aspect : 1
    const scaleY = aspect < 1 ? aspect : 1
    const unit = Math.min(width, height)
    const directions = Array.from({length: 48}, (_, index) => {
        const angle = (index + 0.37) * Math.PI * 2 / 48
        return [Math.cos(angle) * scaleX, Math.sin(angle) * scaleY]
    })
    const probes = directions.filter((_, index) => index % 2 === 0)
    function pixel(cx, cy, radius, direction) {
        const x = Math.round(cx + radius * direction[0])
        const y = Math.round(cy + radius * direction[1])
        return x < 0 || y < 0 || x >= width || y >= height ? -1 : (y * width + x) * 4
    }
    function matches(offset, color) {
        return offset >= 0 && pixels[offset + 3] >= 235
            && Math.abs(pixels[offset] - color[0]) <= 38
            && Math.abs(pixels[offset + 1] - color[1]) <= 38
            && Math.abs(pixels[offset + 2] - color[2]) <= 38
    }
    function verify(cx, cy, radius, color) {
        // Reject filled backgrounds/gradients before tracing entire radial bands.
        let narrow = 0
        for (let index = 0; index < directions.length; index += 8) {
            const direction = directions[index], reach = unit * 0.065
            if (matches(pixel(cx, cy, radius, direction), color)
                && !matches(pixel(cx, cy, radius - reach, direction), color)
                && !matches(pixel(cx, cy, radius + reach, direction), color)) narrow++
        }
        if (narrow < 4) return null
        const inside = []
        let contrast = 0
        for (const direction of directions) {
            if (!matches(pixel(cx, cy, radius, direction), color)) continue
            let inner = radius, outer = radius
            while (inner > radius - unit * 0.09 && matches(pixel(cx, cy, inner - 0.5, direction), color)) inner -= 0.5
            while (outer < radius + unit * 0.09 && matches(pixel(cx, cy, outer + 0.5, direction), color)) outer += 0.5
            if (outer - inner < 0.5 || outer - inner > unit * 0.065) continue
            if (matches(pixel(cx, cy, inner - 1.5, direction), color)
                || matches(pixel(cx, cy, outer + 1.5, direction), color)) continue
            inside.push(inner)
            contrast++
        }
        if (contrast < directions.length * 0.9) return null
        inside.sort((a, b) => a - b)
        const spread = inside[Math.floor(inside.length * 0.95)] - inside[Math.floor(inside.length * 0.05)]
        if (spread > unit * 0.025) return null
        // Move inside the antialiased/compressed inner edge, retaining source detail.
        const inner = inside[0] - 2
        const rx = inner * scaleX / width, ry = inner * scaleY / height
        const x = cx / width - rx, y = cy / height - ry
        if (x < 0 || y < 0 || x + 2 * rx > 1 || y + 2 * ry > 1) return null
        return {x, y, width: 2 * rx, height: 2 * ry, score: contrast - spread * 2}
    }
    let best = null
    for (const dx of [0, -2, 2, -4, 4]) {
        for (const dy of [0, -2, 2, -4, 4]) {
            const cx = (width - 1) / 2 + dx, cy = (height - 1) / 2 + dy
            for (let radius = Math.ceil(unit * 0.40); radius <= unit * 0.495; radius++) {
                const bins = Object.create(null)
                let dominant = null
                for (const direction of probes) {
                    const offset = pixel(cx, cy, radius, direction)
                    if (offset < 0 || pixels[offset + 3] < 235) continue
                    const r = pixels[offset], g = pixels[offset + 1], b = pixels[offset + 2]
                    if (Math.max(r, g, b) < 100 || Math.max(r, g, b) - Math.min(r, g, b) < 70) continue
                    const key = ((r >> 5) << 6) | ((g >> 5) << 3) | (b >> 5)
                    const bin = bins[key] || (bins[key] = {count: 0, r: 0, g: 0, b: 0})
                    bin.count++; bin.r += r; bin.g += g; bin.b += b
                    if (!dominant || bin.count > dominant.count) dominant = bin
                }
                if (!dominant || dominant.count < probes.length * 0.65) continue
                const candidate = verify(cx, cy, radius, [dominant.r / dominant.count, dominant.g / dominant.count, dominant.b / dominant.count])
                if (candidate && candidate.score >= directions.length - 2) return candidate
                if (candidate && (!best || candidate.score > best.score
                    || (candidate.score === best.score && candidate.width > best.width))) best = candidate
            }
        }
    }
    return best
}

export function analyze(pixels, width, height, aspect) {
    const ring = detectRing(pixels, width, height, aspect)
    const alpha = ring ? null : paddingMask(pixels, width, height)
    return {ring, padding: alpha?.[0] === 0 ? alpha : null, width, height}
}
