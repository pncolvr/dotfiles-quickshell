// Display strings only. IDs, commands, paths and user content never pass through this module.
export function language(requested, systemLocale, available) {
    const normalize = value => String(value).toLowerCase().replace(/-/g, '_')
    const value = normalize(requested === 'system' ? systemLocale : requested)
    return available.find(code => normalize(code) === value)
        ?? available.find(code => normalize(code) === value.split('_')[0])
        ?? 'en'
}
export function parse(contents) {
    try {
        const value = JSON.parse(contents)
        return value && typeof value === 'object' && !Array.isArray(value) ? value : {}
    } catch (_) { return {} }
}
export function entry(key, selected, english, count = -1) {
    let value = selected[key] ?? english[key] ?? key
    if (value && typeof value === 'object' && !Array.isArray(value))
        value = value[count === 1 ? 'one' : 'other'] ?? english[key]?.[count === 1 ? 'one' : 'other'] ?? key
    return value
}
export function text(key, selected, english, args = [], count = -1) {
    const value = entry(key, selected, english, count)
    if (typeof value !== 'string') return key
    // One pass keeps placeholder-looking user input literal and does not interpret markup.
    return value.replace(/%n|%([1-9]\d*)/g, (match, position) => {
        if (match === '%n') return count >= 0 ? String(count) : match
        return Number(position) <= args.length ? String(args[Number(position) - 1]) : match
    })
}
