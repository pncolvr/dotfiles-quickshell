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
