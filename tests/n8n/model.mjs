import assert from 'node:assert/strict'
import * as Entries from '../../src/services/n8n/N8nEntries.mjs'
const browsers=[{id:'qutebrowser',command:['browser'],profileArguments:['--profile','{profile}'],
    profiles:[{id:'test'}],reuseArguments:['--target','tab']}]
const first=Entries.validate({...Entries.empty(),id:'a',name:'Personal',url:'https://example.test/base/',apiKey:'fixture',profile:'test'},browsers)
const second={...first,id:'b',name:'Work',category:'work'}
assert.equal(first.url,'https://example.test/base')
assert.equal(Entries.apiUrl(first,'next +&?'), 'https://example.test/base/api/v1/workflows?limit=25&cursor=next%20%2B%26%3F')
assert.equal(Entries.workflowUrl(first,'id/ ?'),'https://example.test/base/workflow/id%2F%20%3F')
for (const url of ['file:///tmp/test','https://user:password@example.test','https://example.test/?token=key','https://example.test/#fragment','https://example.test/\rheader'])
    assert.throws(()=>Entries.baseUrl(url))
assert.throws(()=>Entries.validate({...first,apiKey:'key\r\nInjected: value'},browsers))
assert.throws(()=>Entries.validate({...first,category:'unknown'},browsers))
const page=Entries.page({data:[{id:'same',name:'Workflow',nodes:[{private:'discard'}]}],nextCursor:null})
assert.deepEqual(page,{workflows:[{id:'same',name:'Workflow'}],cursor:''})
for (const invalid of [{}, {data:{}},{data:[{id:'x'}]},{data:[{id:'',name:'Invalid'}]},{data:[],nextCursor:'more'},{data:[],nextCursor:3}])
    assert.throws(()=>Entries.page(invalid))
const rows=[first,second].flatMap(instance=>[
    {instance_id:instance.id,id:'',url:instance.url},
    {instance_id:instance.id,id:'same',name:'Same workflow',url:Entries.workflowUrl(instance,'same')}
])
const items=Entries.items([first,second],rows)
assert.equal(items.length,4)
assert.equal(new Set(items.map(row=>row.id)).size,4)
assert.ok(items[1].subtitle.startsWith('Personal · '))
assert.deepEqual(items[3].result,{instanceId:'b',workflowId:'same'})
assert.ok(!JSON.stringify(items).includes('fixture'))
assert.equal(Entries.items([{...first,url:'https://changed.test'}],rows).length,1)
assert.deepEqual(Entries.launch(first,Entries.workflowUrl(first,'same'),browsers),
    ['browser','--profile','test','--target','tab','https://example.test/base/workflow/same'])
console.log('PASS: n8n connection validation, minimal pages, base paths and independent instance/workflow identities')
