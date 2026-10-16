export function empty(argumentsList = []) {
    return {id:'',name:'',type:'remote',enabled:true,category:'personal',endpoint:'',port:3389,
        displayName:'',username:'',password:'',domain:'',hopHost:'',hopUsername:'',sshKeyPath:'',vmName:'',arguments:argumentsList.slice()}
}
export function validate(value) {
    const entry = Object.assign(empty(),value)
    for (const key of ['id','name','category','endpoint','displayName','username','password','domain','hopHost','hopUsername','sshKeyPath','vmName']) {
        if (typeof entry[key] !== 'string' || /[\0\r\n]/.test(entry[key]))
            throw new Error('Fields must be text without line breaks or NUL characters.')
    }
    entry.name = entry.name.trim(); entry.endpoint = entry.endpoint.trim()
    if (!entry.name) throw new Error('Enter a name.')
    if (!entry.endpoint || !/^[a-zA-Z0-9_:[\].%\-]+$/.test(entry.endpoint) || entry.endpoint.startsWith('-'))
        throw new Error('Enter a host name or IP address.')
    entry.port = Number(entry.port)
    if (!Number.isInteger(entry.port) || entry.port < 1 || entry.port > 65535) throw new Error('Enter a port from 1 to 65535.')
    if (!['personal','work'].includes(entry.category)) throw new Error('Choose Personal or Work.')
    if (typeof entry.enabled !== 'boolean') throw new Error('Enabled must be true or false.')
    if (!Array.isArray(entry.arguments) || entry.arguments.some(arg => typeof arg !== 'string' || /[\0\r\n]/.test(arg)))
        throw new Error('RDP arguments must be literal strings without line breaks.')
    if (entry.arguments.some(arg => /^\/(?:v|u|p|d|t|args-from|from-stdin)(?::|$)/i.test(arg)))
        throw new Error('Use the connection fields for host, credentials and title.')
    switch (entry.type) {
        case 'remote':
            if (!/^[a-zA-Z0-9_.:\-]+$/.test(entry.hopHost) || entry.hopHost.startsWith('-')) throw new Error('Enter an SSH jump host.')
            if (!entry.hopUsername || /[\s@]/.test(entry.hopUsername) || entry.hopUsername.startsWith('-')) throw new Error('Enter an SSH username.')
            if (entry.sshKeyPath && !entry.sshKeyPath.startsWith('/') && !entry.sshKeyPath.startsWith('~/')) throw new Error('Use an absolute or ~/ SSH key path, or leave it empty for your SSH configuration.')
            break
        case 'vm':
            if (!entry.vmName || entry.vmName.startsWith('-')) throw new Error('Enter a virtual machine name.')
            break
        default: throw new Error('Choose SSH tunnel or Virtual machine.')
    }
    return entry
}
