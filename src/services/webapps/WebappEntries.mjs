export function empty() {
    return {id:'',name:'',url:'',browser:'qutebrowser',profile:'',windowMode:'normal',enabled:true,
        category:'',arguments:[],before:[],after:[]}
}
export function profileOptions(browser) {
    const profiles = Array.isArray(browser?.profiles) ? browser.profiles : []
    return [{name:'',description:'Browser default'},...profiles.map(profile => ({name:profile.id,description:profile.name || profile.id}))]
}
export function windowOptions(browser) {
    const normal = Array.isArray(browser?.reuseArguments) ? 'Reuse profile window' : 'Browser default'
    const options = [{name:'normal',description:normal},{name:'window',description:'New window'}]
    if (browser?.appArguments) options.push({name:'app',description:'App window'})
    return options
}
export function validate(value, browsers) {
    const entry = Object.assign(empty(),value)
    entry.name = String(entry.name ?? '').trim()
    entry.url = String(entry.url ?? '').trim()
    if (!entry.name) throw new Error('Enter a name.')
    if (!/^https?:\/\/[^\s/?#]+(?:[/?#][^\s]*)?$/i.test(entry.url)) throw new Error('Enter an http:// or https:// URL.')
    const browser = browsers.find(browser => browser.id === entry.browser)
    if (!browser || !Array.isArray(browser.command) || !browser.command.length)
        throw new Error('Choose a configured browser.')
    if (!['normal','window','app'].includes(entry.windowMode)) throw new Error('Choose a window mode.')
    if (entry.windowMode === 'app' && !browser.appArguments) throw new Error('This browser does not support app windows.')
    if (entry.profile && !browser.profileArguments) throw new Error('This browser does not support profiles.')
    for (const key of ['arguments','before','after']) {
        if (!Array.isArray(entry[key]) || entry[key].some(word => typeof word !== 'string' || word.includes('\0')))
            throw new Error('Commands and arguments must be lists of literal strings.')
        if (key !== 'arguments' && entry[key].length && (!entry[key][0] || entry[key][0].startsWith('-')))
            throw new Error('A launch hook needs an executable.')
    }
    if ([entry.name,entry.url,entry.profile,entry.category].some(value => typeof value !== 'string' || value.includes('\0')))
        throw new Error('Entry fields contain an invalid character.')
    if (entry.profile && !profileOptions(browser).some(profile => profile.name === entry.profile))
        throw new Error('Choose a profile configured for this browser in Config.qml.')
    if (entry.profile.includes('/') || entry.profile.includes('\\') || ['.','..'].includes(entry.profile))
        throw new Error('Use a profile name, without directory separators.')
    if (typeof entry.enabled !== 'boolean') throw new Error('Enabled must be true or false.')
    entry.enabled = entry.enabled !== false
    return entry
}
function expand(words, entry) {
    const values = {url:entry.url,profile:entry.profile}
    return words.map(word => String(word).replace(/\{(url|profile)\}/g, (_,key) => values[key]))
}
export function launch(entry, browsers) {
    entry = validate(entry,browsers)
    const browser = browsers.find(browser => browser.id === entry.browser)
    let windowArguments = []
    switch (entry.windowMode) {
        case 'normal': windowArguments = expand(browser.reuseArguments ?? [],entry); break
        case 'app': windowArguments = expand(browser.appArguments,entry); break
        case 'window': windowArguments = expand(browser.windowArguments ?? [],entry); break
    }
    const profile = entry.profile ? expand(browser.profileArguments,entry) : []
    const target = entry.windowMode === 'app' ? [] : [entry.url]
    return browser.command.concat(profile,windowArguments,entry.arguments,target)
}
