export function searchPattern(search, smartCase) {
    const sensitive = smartCase && search !== search.toLowerCase()
        && search !== search.toUpperCase()
    const normalized = (sensitive ? search : search.toLowerCase()).trim()
    return {sensitive, needles: normalized ? normalized.split(/\s+/) : []}
}
export function score(text, pattern, fuzzy, foldedText, matchedPositions) {
    if (!pattern.needles.length) return 0
    const haystack = pattern.sensitive ? text : (foldedText ?? text.toLowerCase())
    let sourcePositions = null
    if (fuzzy && haystack.length !== text.length) {
        sourcePositions = []
        let offset = 0
        for (const character of text) {
            for (let index = 0; index < character.toLowerCase().length; index++) sourcePositions.push(offset)
            offset += character.length
        }
    }
    let total = 0
    for (const needle of pattern.needles) {
        if (!fuzzy) {
            const exact = haystack.indexOf(needle)
            if (exact < 0) return Infinity
            total += exact + (exact === 0 ? -20 : 0)
            if (matchedPositions) for (let position = exact; position < exact + needle.length; position++) matchedPositions.push(position)
            continue
        }
        // Reject missing subsequences with native string searches before scoring.
        let found = -1
        for (let character = 0; character < needle.length; character++) {
            found = haystack.indexOf(needle[character], found + 1)
            if (found < 0) return Infinity
        }
        // Keep only matching positions, rather than allocating and walking a
        // full-text array for every query character. The same recurrence still
        // finds later compact matches and rewards boundaries and adjacent letters.
        let previousPositions = []
        let previousCosts = []
        let previousMatches = matchedPositions ? [] : null
        let best = Infinity
        let bestMatch = null
        for (let character = 0; character < needle.length; character++) {
            const nextPositions = []
            const nextCosts = []
            const nextMatches = matchedPositions ? [] : null
            let bestGap = Infinity
            let bestGapMatch = null
            let previousIndex = 0
            best = Infinity
            const start = character === 0 ? 0 : previousPositions[0] + 1
            for (let position = haystack.indexOf(needle[character], start); position >= 0;
                position = haystack.indexOf(needle[character], position + 1)) {
                while (previousIndex < previousPositions.length && previousPositions[previousIndex] < position - 1) {
                    const gap = previousCosts[previousIndex] - 2 * previousPositions[previousIndex]
                    if (gap < bestGap) {
                        bestGap = gap
                        if (matchedPositions) bestGapMatch = previousMatches[previousIndex]
                    }
                    previousIndex++
                }
                const sourcePosition = sourcePositions ? sourcePositions[position] : position
                const boundary = position === 0 || (sourcePosition > 0
                    && (!sourcePositions || sourcePosition !== sourcePositions[position - 1])
                    && (/[\s._:/\\-]/.test(text[sourcePosition - 1])
                        || (text[sourcePosition - 1] !== text[sourcePosition - 1].toUpperCase()
                            && text[sourcePosition] !== text[sourcePosition].toLowerCase())))
                const adjacent = previousPositions[previousIndex] === position - 1 ? previousCosts[previousIndex] - 16 : Infinity
                const gap = bestGap + 2 * (position - 1)
                const cost = character === 0 ? Math.min(20, position * 0.1) : Math.min(adjacent, gap)
                const value = cost - (boundary ? 12 : 0)
                const match = matchedPositions ? {position, previous: character === 0 ? null
                    : adjacent <= gap ? previousMatches[previousIndex] : bestGapMatch} : null
                if (value < best) bestMatch = match
                best = Math.min(best, value)
                if (character < needle.length - 1) {
                    nextPositions.push(position)
                    nextCosts.push(value)
                    if (matchedPositions) nextMatches.push(match)
                }
                // A single-letter query cannot improve on a boundary at position zero.
                if (needle.length === 1 && best === -12) break
            }
            previousPositions = nextPositions
            previousCosts = nextCosts
            previousMatches = nextMatches
        }
        if (best === Infinity) return Infinity
        total += best
        if (matchedPositions) for (let match = bestMatch; match; match = match.previous) matchedPositions.push(match.position)
    }
    return total
}

// StyledText markup, using the same best subsequence as filtering. Terms can
// match separate displayed fields (for example a repository name and its path).
export function highlight(text, pattern, fuzzy, color) {
    const escape = value => String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;")
        .replace(/>/g, "&gt;").replace(/"/g, "&quot;")
    const positions = []
    for (const needle of pattern.needles) score(text, {sensitive: pattern.sensitive, needles: [needle]}, fuzzy, undefined, positions)
    const selected = new Set(positions)
    let result = "", offset = 0, run = "", active = false
    const flush = () => { if (run) result += active ? '<font color="' + escape(color) + '">' + escape(run) + '</font>' : escape(run); run = "" }
    // Case folding may expand a character; keep styled runs on whole glyphs.
    for (const character of text) {
        const length = (pattern.sensitive ? character : character.toLowerCase()).length
        let matching = false
        for (let index = offset; index < offset + length; index++) matching = matching || selected.has(index)
        if (matching !== active) { flush(); active = matching }
        run += character
        offset += length
    }
    flush()
    return result
}

// Cache normalized strings once per history snapshot, inside the worker engine.
export function prepareRows(rows) {
    return rows.map((row, index) => {
        const title = String(row.title ?? "");
        const search = row.search ? String(row.search) : "";
        return {index, title, search, titleFolded: title.toLowerCase(),
            searchFolded: search === title ? "" : search.toLowerCase(), pinned: row.pinned === true, kind: row.kind};
    });
}

export function filterPrepared(rows, candidates, pattern, fuzzy, pinnedOnly, kind) {
    const matches = [];
    for (const index of candidates) {
        const row = rows[index];
        if ((pinnedOnly && !row.pinned) || (kind && row.kind !== kind)) continue;
        const value = Math.min(score(row.title, pattern, fuzzy, row.titleFolded),
            row.search && row.search !== row.title ? score(row.search, pattern, fuzzy, row.searchFolded) + 12 : Infinity);
        if (value !== Infinity) matches.push({index, score: value});
    }
    return matches.sort((a, b) => a.score - b.score || a.index - b.index).map(match => match.index);
}
