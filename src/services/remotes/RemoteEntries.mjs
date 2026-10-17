export function empty(argumentsList = []) {
    return {id:'',name:'',type:'remote',enabled:true,category:'personal',endpoint:'',port:3389,
        displayName:'',username:'',password:'',domain:'',hopHost:'',hopUsername:'',sshKeyPath:'',vmName:'',arguments:argumentsList.slice()}
}
export function validate(value) {
    const entry = Object.assign(empty(),value)
    for (const key of ['id','name','category','endpoint','displayName','username','password','domain','hopHost','hopUsername','sshKeyPath','vmName']) {
        if (typeof entry[key] !== 'string' || /[\0\r\n]/.test(entry[key]))
            throw new Error("validation.fields.invalidCharacters")
    }
    entry.name = entry.name.trim(); entry.endpoint = entry.endpoint.trim()
    if (!entry.name) throw new Error("validation.name.required")
    if (!entry.endpoint || !/^[a-zA-Z0-9_:[\].%\-]+$/.test(entry.endpoint) || entry.endpoint.startsWith('-'))
        throw new Error("remotes.errors.hostRequired")
    entry.port = Number(entry.port)
    if (!Number.isInteger(entry.port) || entry.port < 1 || entry.port > 65535) throw new Error("remotes.errors.port")
    if (!['personal','work'].includes(entry.category)) throw new Error("category.errors.invalid")
    if (typeof entry.enabled !== 'boolean') throw new Error("validation.enabled.type")
    if (!Array.isArray(entry.arguments) || entry.arguments.some(arg => typeof arg !== 'string' || /[\0\r\n]/.test(arg)))
        throw new Error("remotes.errors.arguments")
    if (entry.arguments.some(arg => /^\/(?:v|u|p|d|t|args-from|from-stdin)(?::|$)/i.test(arg)))
        throw new Error("remotes.errors.argumentOverrides")
    switch (entry.type) {
        case 'remote':
            if (!/^[a-zA-Z0-9_.:\-]+$/.test(entry.hopHost) || entry.hopHost.startsWith('-')) throw new Error("remotes.errors.jumpHostRequired")
            if (!entry.hopUsername || /[\s@]/.test(entry.hopUsername) || entry.hopUsername.startsWith('-')) throw new Error("remotes.errors.sshUsernameRequired")
            if (entry.sshKeyPath && !entry.sshKeyPath.startsWith('/') && !entry.sshKeyPath.startsWith('~/')) throw new Error("remotes.errors.sshKeyPath")
            break
        case 'vm':
            if (!entry.vmName || entry.vmName.startsWith('-')) throw new Error("remotes.errors.vmRequired")
            break
        default: throw new Error("remotes.errors.type")
    }
    return entry
}
