export function empty(argumentsList = [], type = 'remote') {
    return {id:'',name:'',type,enabled:true,category:'personal',endpoint:'',port:type === 'ssh' ? 22 : 3389,
        displayName:'',username:'',password:'',domain:'',hopHost:'',hopUsername:'',sshKeyPath:'',vmName:'',arguments:argumentsList.slice(),
        hopPort:22,hopPassword:'',hopKeyPath:'',sshArguments:[]}
}
export function validate(value) {
    const entry = Object.assign(empty([],value.type),value)
    for (const key of ['id','name','category','endpoint','displayName','username','password','domain','hopHost','hopUsername','sshKeyPath','vmName','hopPassword','hopKeyPath']) {
        if (typeof entry[key] !== 'string' || /[\0\r\n]/.test(entry[key]))
            throw new Error("validation.fields.invalidCharacters")
    }
    entry.name = entry.name.trim(); entry.endpoint = entry.endpoint.trim(); entry.hopHost = entry.hopHost.trim()
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
        case 'ssh':
            for (const user of entry.hopHost ? [entry.username,entry.hopUsername] : [entry.username])
                if (/[\s@]/.test(user) || user.startsWith('-')) throw new Error("remotes.errors.sshUsername")
            for (const path of entry.hopHost ? [entry.sshKeyPath,entry.hopKeyPath] : [entry.sshKeyPath])
                if (path && !path.startsWith('/') && !path.startsWith('~/')) throw new Error("remotes.errors.sshKeyPath")
            if (entry.hopHost && (!/^[a-zA-Z0-9_:[\].%\-]+$/.test(entry.hopHost) || entry.hopHost.startsWith('-')))
                throw new Error("remotes.errors.jumpHostRequired")
            entry.hopPort = Number(entry.hopPort)
            const validHopPort = Number.isInteger(entry.hopPort) && entry.hopPort >= 1 && entry.hopPort <= 65535
            if (entry.hopHost && !validHopPort) throw new Error("remotes.errors.port")
            if (!validHopPort) entry.hopPort = 22
            if (!Array.isArray(entry.sshArguments) || entry.sshArguments.some(arg => typeof arg !== 'string' || /[\0\r\n]/.test(arg)))
                throw new Error("remotes.errors.sshArguments")
            // Keep ownership and connection fields under the managed session.
            for (let i=0;i<entry.sshArguments.length;i++) {
                const argument=entry.sshArguments[i]
                if (!argument.startsWith('-') || argument === '--') throw new Error("remotes.errors.sshArgumentOverrides")
                for (let j=1;j<argument.length;j++) {
                    const flag=argument[j]
                    if ('fMOSJilpW'.includes(flag)) throw new Error("remotes.errors.sshArgumentOverrides")
                    if ('BbcDEeFILmoPpQRSwW'.includes(flag)) {
                        const value=argument.slice(j+1) || entry.sshArguments[++i]
                        if (!value) throw new Error("remotes.errors.sshArguments")
                        if (flag === 'o' && /^(?:User|Port|IdentityFile|ProxyJump|ProxyCommand|ControlMaster|ControlPath|ControlPersist|ForkAfterAuthentication)(?:\s|=)/i.test(value))
                            throw new Error("remotes.errors.sshArgumentOverrides")
                        break
                    }
                }
            }
            break
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
