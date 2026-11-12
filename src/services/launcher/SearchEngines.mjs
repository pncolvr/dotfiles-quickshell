// Web search fallback for typed Bookmarks queries. Templates use {query} for the
// URL-encoded text.
export const engines = [
    {id: 'duckduckgo', name: 'DuckDuckGo', template: 'https://duckduckgo.com/?q={query}'},
    {id: 'google', name: 'Google', template: 'https://www.google.com/search?q={query}'},
    {id: 'bing', name: 'Bing', template: 'https://www.bing.com/search?q={query}'},
    {id: 'brave', name: 'Brave Search', template: 'https://search.brave.com/search?q={query}'},
    {id: 'startpage', name: 'Startpage', template: 'https://www.startpage.com/do/search?q={query}'},
    {id: 'ecosia', name: 'Ecosia', template: 'https://www.ecosia.org/search?q={query}'},
    {id: 'kagi', name: 'Kagi', template: 'https://kagi.com/search?q={query}'},
    {id: 'qwant', name: 'Qwant', template: 'https://www.qwant.com/?q={query}'},
]
export const defaultEngine = 'duckduckgo'

// Scheme URLs, host names with a dot, localhost and IPv4 addresses open as
// typed; anything else (spaces, single words) is a search.
export function looksLikeUrl(text) {
    const value = text.trim()
    if (/^[a-z][a-z0-9+.-]*:\/\//i.test(value) || /^(about|file|mailto|data):/i.test(value)) return true
    if (/\s/.test(value)) return false
    return /^(localhost|\d{1,3}(\.\d{1,3}){3}|([a-z0-9-]+\.)+[a-z][a-z0-9-]*)(:\d+)?([/?#].*)?$/i.test(value)
}

// Returns the search URL, or '' when searching is off or the template is invalid.
export function searchUrl(engine, customTemplate, text) {
    const template = engine === 'custom' ? String(customTemplate ?? '').trim()
        : engines.find(entry => entry.id === engine)?.template ?? ''
    if (!template.includes('{query}') || !/^https?:\/\//i.test(template)) return ''
    return template.replace(/\{query\}/g, () => encodeURIComponent(text.trim()))
}
