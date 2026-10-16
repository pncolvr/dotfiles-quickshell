import assert from 'node:assert/strict'
import * as Args from '../../src/services/launcher/CommandArguments.mjs'
import * as Entries from '../../src/services/webapps/WebappEntries.mjs'
const browsers=[
    {id:'qutebrowser',profiles:[{id:'qutebrowser-webapp',name:'Webapps'}],command:['qutebrowser'],profileArguments:['--desktop-file-name','{profile}','-B','/data/{profile}'],reuseArguments:['--target','tab'],windowArguments:['--target','window']},
    {id:'vivaldi',profiles:[{id:'Original profile',name:'Work'},{id:'$(literal)',name:'Literal test'}],command:['vivaldi'],profileArguments:['--profile-directory={profile}'],appArguments:['--app={url}'],windowArguments:['--new-window']},
    {id:'default',command:['xdg-open']}
]
const literal=['literal $(touch /tmp/no)','space separated',"single'quote",'', 'a\\b', 'https://example.test/?x={profile}']
assert.deepEqual(Args.split(Args.join(literal)),literal)
assert.deepEqual(Args.split('a "two words" \'three words\' escaped\\ space'),['a','two words','three words','escaped space'])
assert.throws(()=>Args.split('"unclosed'))
assert.throws(()=>Args.split('trailing\\'))
const window={...Entries.empty(),name:'Window',browser:'qutebrowser',profile:'qutebrowser-webapp',windowMode:'window',url:'https://example.test/a?x=1&y=2'}
const app={...Entries.empty(),name:'App',browser:'vivaldi',profile:'Original profile',windowMode:'app',url:'https://example.test/app'}
assert.deepEqual(Entries.launch(window,browsers),['qutebrowser','--desktop-file-name','qutebrowser-webapp','-B','/data/qutebrowser-webapp','--target','window','https://example.test/a?x=1&y=2'])
assert.deepEqual(Entries.launch({...window,windowMode:'normal'},browsers),['qutebrowser','--desktop-file-name','qutebrowser-webapp','-B','/data/qutebrowser-webapp','--target','tab','https://example.test/a?x=1&y=2'])
assert.equal(Entries.windowOptions(browsers[0])[0].description,'Reuse profile window')
assert.equal(Entries.windowOptions(browsers[1])[0].description,'Browser default')
assert.deepEqual(Entries.launch({...window,windowMode:'normal',profile:''},browsers),['qutebrowser','--target','tab','https://example.test/a?x=1&y=2'])
assert.deepEqual(Entries.launch(app,browsers),['vivaldi','--profile-directory=Original profile','--app=https://example.test/app'])
const strange={...app,url:'https://example.test/?literal={profile}&x=$(touch)',profile:'$(literal)',windowMode:'normal'}
assert.deepEqual(Entries.launch(strange,browsers),['vivaldi','--profile-directory=$(literal)','https://example.test/?literal={profile}&x=$(touch)'])
for (const change of [{url:'javascript:alert(1)'},{profile:'../escape'},{browser:'missing'},{profile:'not-configured'},{windowMode:'other'},{before:['']},{arguments:['nul\0']}])
    assert.throws(()=>Entries.validate({...window,...change},browsers))
assert.deepEqual(Args.command('docker start "literal $(not-executed)"'),['docker','start','literal $(not-executed)'])
assert.deepEqual(Entries.launch({...Entries.empty(),name:'Default',browser:'default',url:'https://example.test'},browsers),['xdg-open','https://example.test'])
assert.throws(()=>Entries.validate({...window,browser:'default'},browsers))
assert.deepEqual(Entries.profileOptions(browsers[0]),[{name:'',description:'Browser default'},{name:'qutebrowser-webapp',description:'Webapps'}])
assert.deepEqual(Entries.profileOptions(browsers[2]),[{name:'',description:'Browser default'}])
assert.throws(()=>Entries.launch(window,[{...browsers[0],profiles:[]}]))
console.log('PASS: webapp browser profiles/window modes, literal command arguments and input validation')
