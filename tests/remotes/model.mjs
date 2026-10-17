import assert from 'node:assert/strict'
import {empty,validate} from '../../src/services/remotes/RemoteEntries.mjs'
const vm={...empty(),name:'Test VM',type:'vm',endpoint:'127.0.0.1',vmName:'fixture',username:'user;literal',password:'pa$$ \\ "quotes" $(literal)',arguments:['/drive:Docs,/some path','/cert:ignore']}
assert.equal(validate(vm).password,vm.password)
assert.equal(validate({...vm,port:'3390'}).port,3390)
assert.equal(validate({...vm,endpoint:'2001:db8::1'}).endpoint,'2001:db8::1')
assert.deepEqual(empty(['/clipboard']).arguments,['/clipboard'])
for (const patch of [{name:''},{port:0},{port:65536},{endpoint:'-option'},{endpoint:'host;code'},{password:'line\nbreak'},{category:'other'},{enabled:'true'},{type:'other'},{vmName:''},{arguments:['/args-from:stdin']},{arguments:['/p:secret']},{arguments:['/v:override']},{arguments:['/x:a\nb']}]) assert.throws(()=>validate({...vm,...patch}))
const remote={...vm,type:'remote',hopHost:'jump.example.test',hopUsername:'test',sshKeyPath:'/some path/key'}
assert.equal(validate(remote).sshKeyPath,remote.sshKeyPath)
assert.equal(validate({...remote,sshKeyPath:''}).sshKeyPath,'')
assert.equal(validate({...remote,sshKeyPath:'~/.ssh/key'}).sshKeyPath,'~/.ssh/key')
for(const patch of [{hopHost:''},{hopHost:'-bad'},{hopUsername:'test@host'},{sshKeyPath:'relative-key'}])assert.throws(()=>validate({...remote,...patch}))
console.log('PASS: remote model preserves literal credentials/arguments and validates connection fields')
const ssh={...empty([], 'ssh'),name:'SSH terminal',endpoint:'server.example',username:'user',password:'literal $secret',
    sshKeyPath:'~/keys/target key',hopHost:'jump.example',hopPort:2222,hopUsername:'jump',hopPassword:'other secret',
    hopKeyPath:'/keys/jump key',sshArguments:['-o','ServerAliveInterval=30']}
assert.equal(validate(ssh).port,22)
assert.equal(validate(ssh).hopPort,2222)
assert.equal(validate(ssh).hopPassword,'other secret')
assert.equal(validate({...ssh,username:'',hopHost:'',hopUsername:'',sshKeyPath:''}).username,'')
assert.equal(validate({...ssh,hopHost:' ',hopPort:'',hopUsername:'unused user',hopKeyPath:'unused relative path'}).hopPort,22)
assert.equal(validate({...ssh,endpoint:'2001:db8::1',hopHost:'[2001:db8::2]'}).endpoint,'2001:db8::1')
for(const patch of [{username:'bad user'},{username:'-option'},{hopPort:0},{hopPort:65536},{hopHost:'bad;host'},
    {hopUsername:'user@host'},{sshKeyPath:'relative'},{hopKeyPath:'relative'},{hopPassword:'a\nb'},
    {sshArguments:['line\nbreak']},{sshArguments:[12]},{sshArguments:['-f']},{sshArguments:['-vf']},
    {sshArguments:['-O','exit']},{sshArguments:['-p2222']},{sshArguments:['-o','ControlPath=/tmp/other']},
    {sshArguments:['-oProxyJump=other']},{sshArguments:['-o']},{sshArguments:['remote-command']}])assert.throws(()=>validate({...ssh,...patch}))
console.log('PASS: SSH destination and jump settings, independent passwords, default ports, config authentication and validation')
