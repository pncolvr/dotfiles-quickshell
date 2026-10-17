// Shell-style quoting for argument entry. Never expand variables, globs or commands.
export function split(value) {
    const words = []
    let word = '', quote = '', escaped = false, started = false
    for (const character of String(value ?? '')) {
        if (escaped) { word += character; escaped = false; started = true; continue }
        if (quote === "'") {
            if (character === quote) quote = ''
            else word += character
            continue
        }
        if (character === '\\') { escaped = true; started = true; continue }
        if (quote) {
            if (character === quote) quote = ''
            else word += character
            continue
        }
        switch (character) {
            case "'": case '"': quote = character; started = true; break
            case ' ': case '\t': case '\n':
                if (started) { words.push(word); word = ''; started = false }
                break
            default: word += character; started = true
        }
    }
    if (escaped || quote) throw new Error("arguments.errors.unclosedQuote")
    if (started) words.push(word)
    if (words.some(word => word.includes('\0'))) throw new Error("arguments.errors.nul")
    return words
}
export function join(words) {
    return words.map(word => "'" + String(word).replace(/'/g, "'\\''") + "'").join(' ')
}
export function command(value) {
    const words = split(value)
    if (words.length && (!words[0] || words[0].startsWith('-'))) throw new Error("arguments.errors.executableRequired")
    return words
}
