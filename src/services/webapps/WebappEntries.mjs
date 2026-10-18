export function target(value) {
    const url=String(value ?? '').trim()
    if (!url || /[\x00-\x1f\x7f]/.test(url)) throw new Error('webapps.errors.invalidUrl')
    if (url.startsWith('/')) return 'file://' + url.split('/').map(encodeURIComponent).join('/')
    if (/^https?:\/\/[^\s/?#]+(?:[/?#][^\s]*)?$/i.test(url) || /^file:\/\/\/[^\s]*$/i.test(url)) return url
    throw new Error('webapps.errors.invalidUrl')
}
export function empty(defaultBrowser = "") {
    return {id:'',name:'',url:'',browser:defaultBrowser,profile:'',windowMode:'normal',enabled:true,
        category:'',arguments:[],before:[],after:[]}
}
export function profileOptions(browser) {
    const profiles = Array.isArray(browser?.profiles) ? browser.profiles : []
    return [{name:'',description:'browser.profile.default'},...profiles.map(profile => ({name:profile.id,description:profile.name || profile.id}))]
}
export function windowOptions(browser) {
    const normal = Array.isArray(browser?.reuseArguments) ? 'browser.window.reuse' : 'browser.profile.default'
    const options = [{name:'normal',description:normal},{name:'window',description:'browser.window.new'}]
    if (browser?.appArguments) options.push({name:'app',description:'browser.window.app'})
    return options
}
export function validate(value, browsers, normalizeTarget = target) {
    const entry = Object.assign(empty(),value)
    entry.name = String(entry.name ?? '').trim()
    entry.url = normalizeTarget(entry.url)
    if (!entry.name) throw new Error("validation.name.required")
    const browser = browsers.find(browser => browser.id === entry.browser)
    if (!browser || !Array.isArray(browser.command) || !browser.command.length)
        throw new Error("webapps.errors.browser")
    if (!['normal','window','app'].includes(entry.windowMode)) throw new Error("webapps.errors.windowMode")
    if (entry.windowMode === 'app' && !browser.appArguments) throw new Error("webapps.errors.appUnsupported")
    if (entry.profile && !browser.profileArguments) throw new Error("webapps.errors.profileUnsupported")
    for (const key of ['arguments','before','after']) {
        if (!Array.isArray(entry[key]) || entry[key].some(word => typeof word !== 'string' || word.includes('\0')))
            throw new Error("webapps.errors.arguments")
        if (key !== 'arguments' && entry[key].length && (!entry[key][0] || entry[key][0].startsWith('-')))
            throw new Error("webapps.errors.hookExecutable")
    }
    if ([entry.name,entry.url,entry.profile,entry.category].some(value => typeof value !== 'string' || value.includes('\0')))
        throw new Error("webapps.errors.invalidCharacters")
    if (entry.profile && !profileOptions(browser).some(profile => profile.name === entry.profile))
        throw new Error("webapps.errors.profile")
    if (entry.profile.includes('/') || entry.profile.includes('\\') || ['.','..'].includes(entry.profile))
        throw new Error("webapps.errors.profileName")
    if (typeof entry.enabled !== 'boolean') throw new Error("validation.enabled.type")
    entry.enabled = entry.enabled !== false
    return entry
}
function expand(words, entry) {
    const values = {url:entry.url,profile:entry.profile}
    return words.map(word => String(word).replace(/\{(url|profile)\}/g, (_,key) => values[key]))
}
export function launch(entry, browsers, normalizeTarget = target) {
    entry = validate(entry,browsers,normalizeTarget)
    const browser = browsers.find(browser => browser.id === entry.browser)
    let windowArguments = []
    switch (entry.windowMode) {
        case 'normal': windowArguments = expand(browser.reuseArguments ?? [],entry); break
        case 'app': windowArguments = expand(browser.appArguments,entry); break
        case 'window': windowArguments = expand(browser.windowArguments ?? [],entry); break
    }
    const profile = entry.profile ? expand(browser.profileArguments,entry) : []
    const targets = entry.windowMode === 'app' ? [] : (entry.url.startsWith('-') ? ['--',entry.url] : [entry.url])
    return browser.command.concat(profile,windowArguments,entry.arguments,targets)
}
