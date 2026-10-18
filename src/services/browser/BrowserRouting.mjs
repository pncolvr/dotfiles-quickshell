import * as Browser from '../webapps/WebappEntries.mjs'

export function target(value) {
    const text=String(value ?? '').trim()
    if (!text || /[\x00-\x1f\x7f]/.test(text)) throw new Error('webapps.errors.invalidUrl')
    return text.startsWith('/') ? Browser.target(text) : text
}
export function action(entry) { return entry.action || 'browser' }
export function containsPatterns(entry) {
    return [...new Set((Array.isArray(entry.patterns) ? entry.patterns : [entry.pattern])
        .filter(value=>typeof value==='string').map(value=>value.trim()).filter(Boolean))]
}
export function empty(browser) {
    return {id:'',name:'',pattern:'',match:'contains',action:'browser',parameter:'url',command:[],onlyWhenRunning:'',
        desktopId:'',applicationName:'',targetTemplate:'{url}',extraArguments:[],browser,profile:'',windowMode:'normal',enabled:true,priority:0,workspace:0}
}
export function concreteCommand(words) {
    if (!Array.isArray(words) || !words.length || words.some(word=>typeof word!=='string' || word.includes('\0')) || !words[0] || words[0].startsWith('-'))
        throw new Error('webapps.errors.browser')
    if (words.some(word=>['xdg-open','quickshell-browser','default-browser.sh'].includes(word.split('/').pop()) || word.endsWith('/services/browser/browser.sh')))
        throw new Error('browser.routing.recursiveBrowser')
    return words
}
export function validate(value,browsers) {
    const entry=Object.assign(empty(''),value)
    entry.name=String(entry.name ?? '').trim()
    entry.pattern=String(entry.pattern ?? '').trim()
    if (!entry.name) throw new Error('validation.name.required')
    if (entry.match==='contains') {
        if (entry.patterns!==undefined && (!Array.isArray(entry.patterns) || entry.patterns.some(value=>typeof value!=='string')))
            throw new Error('browser.routing.invalidPattern')
        entry.patterns=containsPatterns(entry)
        if (!entry.patterns.length || entry.patterns.some(value=>value.length>4096 || /[\x00-\x1f\x7f]/.test(value)))
            throw new Error('browser.routing.invalidPattern')
        entry.pattern=entry.patterns[0]
    } else {
        delete entry.patterns
        if (!entry.pattern || entry.pattern.length>4096 || /[\x00-\x1f\x7f]/.test(entry.pattern)) throw new Error('browser.routing.invalidPattern')
    }
    if (!['contains','glob','host','regex'].includes(entry.match)) throw new Error('browser.routing.invalidPattern')
    if (entry.match==='regex') {
        try { new RegExp(entry.pattern) } catch(_) { throw new Error('browser.routing.invalidPattern') }
    }
    if (!Number.isSafeInteger(entry.priority) || !Number.isSafeInteger(entry.workspace) || entry.workspace<0 || entry.workspace>1000)
        throw new Error('browser.routing.invalidNumber')
    if (!['browser','redirect','query','command'].includes(entry.action)) throw new Error('browser.routing.invalidAction')
    if (typeof entry.enabled!=='boolean') throw new Error('validation.enabled.type')
    if (entry.action==='query' && (typeof entry.parameter!=='string' || !entry.parameter || /[\x00-\x20\x7f&=#]/.test(entry.parameter)))
        throw new Error('browser.routing.invalidParameter')
    if (entry.action==='command') {
        concreteCommand(entry.command)
        if (entry.desktopId && (typeof entry.targetTemplate!=='string' || !entry.targetTemplate.trim() || /[\x00-\x1f\x7f]/.test(entry.targetTemplate)))
            throw new Error('browser.routing.invalidTemplate')
        if (typeof entry.desktopId!=='string' || typeof entry.applicationName!=='string'
            || !Array.isArray(entry.extraArguments) || entry.extraArguments.some(word=>typeof word!=='string' || word.includes('\0')))
            throw new Error('browser.routing.invalidTemplate')
        if (typeof entry.onlyWhenRunning!=='string' || (entry.onlyWhenRunning && !/^[A-Za-z0-9_.+-]+$/.test(entry.onlyWhenRunning)))
            throw new Error('browser.routing.invalidProcess')
        for (const word of entry.command.concat(entry.desktopId ? [entry.targetTemplate] : [])) for (const token of word.match(/\{[^{}]+\}/g) ?? [])
            if (token!=='{url}' && !/^\{[1-9][0-9]*\}$/.test(token)) throw new Error('browser.routing.invalidTemplate')
    }
    if (entry.action==='browser') {
        const checked=Browser.validate(Object.assign(Browser.empty(),entry,{url:'https://routing.invalid'}),browsers)
        concreteCommand(browsers.find(row=>row.id===checked.browser).command)
        Object.assign(entry,{browser:checked.browser,profile:checked.profile,windowMode:checked.windowMode})
    }
    return entry
}
export function matches(rule,url) {
    switch(rule.match) {
        case 'contains': return containsPatterns(rule).some(pattern=>url.includes(pattern))
        case 'host': {
            const host=/^https?:\/\/([^/?#]+)/i.exec(url)?.[1].replace(/^.*@/,'').replace(/:\d+$/,'').toLowerCase()
            const expected=rule.pattern.toLowerCase()
            return !!host && (host===expected || host.endsWith('.'+expected))
        }
        case 'glob': {
            const pattern=rule.pattern.split('*').map(part=>part.split('?').map(word=>word.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')).join('.')).join('.*')
            return new RegExp('^'+pattern+'$').test(url)
        }
        case 'regex':
            try { return new RegExp(rule.pattern).test(url) } catch(_) { return false }
    }
    return false
}
export function choose(url,rules,defaultBrowser,used=[]) {
    return ordered(rules).filter(rule=>rule.enabled && !used.includes(rule.id+'\0'+url))
        .find(rule=>matches(rule,url)) ?? empty(defaultBrowser)
}
export function ordered(rules) {
    return rules.slice().sort((a,b)=>(a.priority ?? 0)-(b.priority ?? 0) || a.id.localeCompare(b.id))
}
export function browserRule(url,rules,defaultBrowser) {
    return choose(url,rules.filter(rule=>action(rule)==='browser'),defaultBrowser)
}
export function command(url,entry,browsers) {
    const valid=target(url)
    if (action(entry)==='command') {
        const captures=entry.match==='regex' ? new RegExp(entry.pattern).exec(valid) : null
        const words=concreteCommand(entry.command).map(word=>entry.desktopId
            ? word.replace(/\{url\}/g,()=>entry.targetTemplate ?? '{url}') : word)
        const argv=words.map(word=>word.replace(/\{(url|[1-9][0-9]*)\}/g,(_,key)=>{
            if (key==='url') return valid
            if (!captures || captures[Number(key)]===undefined) throw new Error('browser.routing.invalidTemplate')
            return captures[Number(key)]
        }))
        // Extra arguments precede the URL, so browser profile flags remain options.
        const index=entry.command.findIndex(word=>/\{(url|[1-9][0-9]*)\}/.test(word))
        const insertion=index>0 ? index : argv.length
        return argv.slice(0,insertion).concat(entry.extraArguments ?? [],argv.slice(insertion))
    }
    return Browser.launch(Object.assign(Browser.empty(),entry,{name:entry.name || 'Browser',url:valid}),browsers,target)
}
export function historyQuery(query) {
    return (String(query).match(/[A-Za-z0-9_\u0080-\uFFFF]+/g) ?? []).map(word=>'"'+word.replace(/"/g,'""')+'"*').join(' AND ')
}
