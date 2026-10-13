export function searchPattern(search, smartCase) {
    const sensitive = smartCase && search !== search.toLowerCase()
        && search !== search.toUpperCase()
    const normalized = (sensitive ? search : search.toLowerCase()).trim()
    return {sensitive, needles: normalized ? normalized.split(/\s+/) : []}
}
export function score(text, pattern, fuzzy, foldedText) {
    if (!pattern.needles.length) return 0
    const haystack = pattern.sensitive ? text : (foldedText ?? text.toLowerCase())
    let total = 0
    for (const needle of pattern.needles) {
        if (!fuzzy) {
            const exact = haystack.indexOf(needle)
            if (exact < 0) return Infinity
            total += exact + (exact === 0 ? -20 : 0)
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
        let best = Infinity
        for (let character = 0; character < needle.length; character++) {
            const nextPositions = []
            const nextCosts = []
            let bestGap = Infinity
            let previousIndex = 0
            best = Infinity
            const start = character === 0 ? 0 : previousPositions[0] + 1
            for (let position = haystack.indexOf(needle[character], start); position >= 0;
                position = haystack.indexOf(needle[character], position + 1)) {
                while (previousIndex < previousPositions.length && previousPositions[previousIndex] < position - 1) {
                    bestGap = Math.min(bestGap, previousCosts[previousIndex] - 2 * previousPositions[previousIndex])
                    previousIndex++
                }
                const boundary = position === 0 || /[\s._:/\\-]/.test(text[position - 1])
                    || (text[position - 1] !== text[position - 1].toUpperCase()
                        && text[position] !== text[position].toLowerCase())
                const cost = character === 0 ? Math.min(20, position * 0.1)
                    : Math.min(previousPositions[previousIndex] === position - 1 ? previousCosts[previousIndex] - 16 : Infinity,
                        bestGap + 2 * (position - 1))
                const value = cost - (boundary ? 12 : 0)
                best = Math.min(best, value)
                if (character < needle.length - 1) {
                    nextPositions.push(position)
                    nextCosts.push(value)
                }
                // A single-letter query cannot improve on a boundary at position zero.
                if (needle.length === 1 && best === -12) break
            }
            previousPositions = nextPositions
            previousCosts = nextCosts
        }
        if (best === Infinity) return Infinity
        total += best
    }
    return total
}

// Cache normalized strings once per history snapshot, inside the worker engine.
export function prepareRows(rows) {
    return rows.map((row, index) => {
        const title = String(row.title ?? "");
        const search = row.search ? String(row.search) : "";
        return {index, title, search, titleFolded: title.toLowerCase(),
            searchFolded: search === title ? "" : search.toLowerCase(), pinned: row.pinned === true};
    });
}

export function filterPrepared(rows, candidates, pattern, fuzzy, pinnedOnly) {
    const matches = [];
    for (const index of candidates) {
        const row = rows[index];
        if (pinnedOnly && !row.pinned) continue;
        const value = Math.min(score(row.title, pattern, fuzzy, row.titleFolded),
            row.search && row.search !== row.title ? score(row.search, pattern, fuzzy, row.searchFolded) + 12 : Infinity);
        if (value !== Infinity) matches.push({index, score: value});
    }
    return matches.sort((a, b) => a.score - b.score || a.index - b.index).map(match => match.index);
}
