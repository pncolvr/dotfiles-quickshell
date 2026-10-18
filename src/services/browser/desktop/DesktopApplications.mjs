// DesktopEntries supplies parsed argv; retain literal arguments, replace URL
// field codes and expand metadata codes without evaluating shell syntax.
export function command(entry) {
    const words = []
    let hasTarget = false
    for (const word of entry.command) {
        if (word === '%i') {
            if (entry.icon) words.push('--icon', entry.icon)
            continue
        }
        if (/^%[fFuU]$/.test(word)) { words.push('{url}'); hasTarget = true; continue }
        if (/^%[dDnNvm]$/.test(word)) continue
        words.push(word.replace(/%%/g, '%').replace(/%c/g, entry.name))
    }
    if (!hasTarget) words.push('{url}')
    return words
}
export function applications(entries, browsersOnly = false) {
    return entries.filter(entry => !entry.noDisplay && !entry.runInTerminal && entry.command.length
        && entry.id !== 'quickshell-browser'
        && (!browsersOnly || entry.categories.includes('WebBrowser')))
        .map(entry => ({id: entry.id, name: entry.name, command: command(entry)}))
        .filter(entry => !entry.command.some(word => ['xdg-open', 'quickshell-browser', 'default-browser.sh'].includes(word.split('/').pop())))
        .sort((a, b) => a.name.localeCompare(b.name) || a.id.localeCompare(b.id))
}
