import * as Browser from '../webapps/WebappEntries.mjs'

export function empty() {
    return Object.assign(Browser.empty(),{category:'personal',apiKey:''})
}
export function baseUrl(value) {
    const url=String(value ?? '').trim().replace(/\/+$/,'')
    if (!/^https?:\/\/[^\s/?#@]+(?:\/[^\s?#]*)?$/i.test(url) || /[\x00-\x1f\x7f]/.test(url))
        throw new Error('Enter the instance http:// or https:// address, including any base path, without credentials or a query.')
    return url
}
export function validate(value,browsers) {
    const entry=Browser.validate(Object.assign(empty(),value),browsers)
    entry.url=baseUrl(entry.url)
    entry.apiKey=String(entry.apiKey ?? '').trim()
    if (/[\x00-\x1f\x7f]/.test(entry.apiKey)) throw new Error('The API key contains an invalid character.')
    if (!['personal','work'].includes(entry.category)) throw new Error('Choose Personal or Work.')
    // Instance records contain connection/browser settings, never workflow definitions or launch hooks.
    return {id:entry.id,name:entry.name,url:entry.url,apiKey:entry.apiKey,browser:entry.browser,
        profile:entry.profile,windowMode:entry.windowMode,enabled:entry.enabled,category:entry.category}
}
export function apiUrl(instance,cursor='') {
    return baseUrl(instance.url)+'/api/v1/workflows?limit=25'+(cursor ? '&cursor='+encodeURIComponent(cursor) : '')
}
export function workflowUrl(instance,id) { return baseUrl(instance.url)+'/workflow/'+encodeURIComponent(id) }
export function page(value) {
    if (!value || !Array.isArray(value.data) || (value.nextCursor!=null && typeof value.nextCursor!=='string'))
        throw new Error('The server returned an invalid workflow page; the saved list was kept.')
    const workflows=value.data.map(workflow=>{
        if (!workflow || typeof workflow.id!=='string' || !workflow.id || typeof workflow.name!=='string' || !workflow.name.trim())
            throw new Error('The server returned an incomplete workflow; the saved list was kept.')
        return {id:workflow.id,name:workflow.name}
    })
    if (!workflows.length && value.nextCursor) throw new Error('The server returned an incomplete workflow page; the saved list was kept.')
    return {workflows,cursor:value.nextCursor || ''}
}
export function launch(instance,url,browsers) {
    return Browser.launch(Object.assign(Browser.empty(),instance,{url}),browsers)
}
export function items(instances,rows) {
    const result=[]
    for (const instance of instances) {
        const cached=rows.filter(row=>row.instance_id===instance.id)
        const source=cached.find(row=>row.id==='')
        const workflows=source?.url===instance.url ? cached.filter(row=>row.id!=='') : []
        const links=[{id:'',name:'Open '+instance.name,url:instance.url},...workflows]
        for (const link of links) result.push({id:JSON.stringify([instance.id,link.id]),title:link.name,
            subtitle:instance.name+' · '+link.url,search:link.name+' '+instance.name+' '+link.url,
            result:{instanceId:instance.id,workflowId:link.id}})
    }
    return result
}
