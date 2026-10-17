// Local calendar arithmetic: setDate/setMonth preserve boundaries across DST.
export function key(date) {
    return date.getFullYear() + '-' + String(date.getMonth() + 1).padStart(2, '0') + '-' + String(date.getDate()).padStart(2, '0')
}
export function start(date, kind) {
    if (!['week', 'month'].includes(kind)) throw Error('Invalid calendar period')
    return new Date(date.getFullYear(), date.getMonth(), kind === 'month' ? 1 : date.getDate() - (date.getDay() + 6) % 7)
}
export function shift(date, kind, amount) {
    const result = start(date, kind)
    if (kind === 'month') result.setMonth(result.getMonth() + amount)
    else result.setDate(result.getDate() + amount * 7)
    return result
}
export function adjacent(values, current, delta) {
    return delta < 0 ? values.filter(value => value < current).slice(-1)[0] ?? ''
        : values.find(value => value > current) ?? ''
}
export function daysInMonth(month, year) { return new Date(year, month + 1, 0).getDate() }
export function firstDayOfMonth(month, year) { return (new Date(year, month, 1).getDay() + 6) % 7 }
export function weekNumber(date) {
    // UTC arithmetic avoids daylight-saving offsets when counting ISO weeks.
    const day = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
    day.setUTCDate(day.getUTCDate() + 3 - (day.getUTCDay() + 6) % 7)
    const first = new Date(Date.UTC(day.getUTCFullYear(), 0, 4))
    return 1 + Math.round(((day - first) / 86400000 - 3 + (first.getUTCDay() + 6) % 7) / 7)
}
