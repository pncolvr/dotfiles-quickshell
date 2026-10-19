import assert from 'node:assert/strict'
import fs from 'node:fs'
import {fileURLToPath} from 'node:url'
import * as Catalog from '../../src/i18n/Catalog.mjs'
const folder=fileURLToPath(new URL('../../src/i18n/languages/',import.meta.url))
const catalogs=Object.fromEntries(fs.readdirSync(folder).filter(name=>name.endsWith('.json'))
    .map(name=>[name.slice(0,-5),JSON.parse(fs.readFileSync(folder+name,'utf8'))]))
const en=catalogs.en
const available=Object.keys(catalogs)
assert.ok(en,'English fallback is packaged')
function checkInitialCapital(value, key) {
    if (typeof value === 'string') assert.doesNotMatch(value, /^\p{Ll}/u, 'initial capital: '+key)
    else for (const [part, child] of Object.entries(value)) if(part!=='$locale') checkInitialCapital(child,key+'.'+part)
}
for (const [locale, catalog] of Object.entries(catalogs)) checkInitialCapital(catalog,locale)
const placeholders=value=>String(value).match(/%n|%[1-9]\d*/g)?.sort() ?? []
const messageKeys=catalog=>Object.keys(catalog).filter(key=>key!=='$locale').sort()
for(const [code,catalog] of Object.entries(catalogs)) {
  assert.deepEqual(messageKeys(en),messageKeys(catalog),'catalog coverage: '+code)
  if(catalog.$locale!==undefined) assert.match(catalog.$locale,/^[a-z]{2,3}(?:[_-][A-Za-z0-9]+)*$/)
  for(const key of messageKeys(en)) {
    assert.match(key,/^[a-z][a-zA-Z0-9]*(?:\.[a-z][a-zA-Z0-9]*)+$/,'stable semantic ID: '+key)
    assert.equal(typeof en[key],typeof catalog[key],key)
    if(Array.isArray(en[key])) assert.equal(en[key].length,catalog[key].length,key)
    else if(typeof en[key]==='object') {
        assert.deepEqual(Object.keys(en[key]).sort(),['one','other'],key)
        for(const form of ['one','other']) assert.deepEqual(placeholders(en[key][form]),placeholders(catalog[key][form]),key)
    } else {
        assert.notEqual(catalog[key],'','Translation value: '+code+':'+key)
        assert.deepEqual(placeholders(en[key]),placeholders(catalog[key]),key)
    }
}
}
assert.equal(Catalog.language('system','pt_PT',available),'pt')
assert.equal(Catalog.language('system','pt-BR',available),'pt')
assert.equal(Catalog.language('system','de_DE',available),'en')
assert.equal(Catalog.language('en','pt_PT',available),'en')
assert.equal(Catalog.language('pt','en_US',available),'pt')
assert.equal(Catalog.language('invalid','pt_PT',available),'en')
assert.equal(Catalog.language('system','de_DE',[...available,'de']),'de')
assert.equal(Catalog.language('pt-PT','en_US',[...available,'pt_PT']),'pt_PT')
assert.equal(Catalog.language('zz','en_US',[...available,'zz']),'zz')
assert.deepEqual(Catalog.parse('broken JSON'),{})
assert.equal(Catalog.text('fallback',{}, {fallback:'English'}),'English')
assert.equal(Catalog.text('missing',{},{}),'missing')
assert.equal(Catalog.text('value',{value:'%2: %1'}, {},['$HOME %2','ação']),'ação: $HOME %2')
assert.equal(Catalog.text('count',{count:{one:'%n ficheiro',other:'%n ficheiros'}},{},[],0),'0 ficheiros')
assert.equal(Catalog.text('count',{count:{one:'%n ficheiro',other:'%n ficheiros'}},{},[],1),'1 ficheiro')
assert.equal(Catalog.text('count',{count:{one:'%n ficheiro',other:'%n ficheiros'}},{},[],2),'2 ficheiros')
assert.equal(Catalog.text('count',{count:{}},{count:{one:'%n file',other:'%n files'}},[],1),'1 file')
console.log('PASS: semantic catalog parity, locale selection, fallback, placeholders and plurals')
// A wording change must not require touching call sites. IDs stay semantic and stable.
assert.equal(Catalog.text('common.actions.save', {'common.actions.save':'Store'}, en),'Store')
const sourceRoot=fileURLToPath(new URL('../../src/',import.meta.url))
const sources=[]
function visit(folder) {
    for(const file of fs.readdirSync(folder,{withFileTypes:true})) {
        const name=folder+'/'+file.name
        if(file.isDirectory()) { if(file.name!=='i18n'&&file.name!=='vendor')visit(name) }
        else if(/\.(qml|mjs|sh)$/.test(file.name))sources.push([name,fs.readFileSync(name,'utf8')])
    }
}
visit(sourceRoot)
for(const [name,source] of sources) {
    for(const call of source.matchAll(/Translations\.text\(([^\n,;]+)/g)) {
        const expression=call[1]
        for(const literal of expression.matchAll(/["']([a-z][a-zA-Z0-9]*(?:\.[a-z][a-zA-Z0-9]*)+)["']/g))
            assert.ok(literal[1] in en,`unknown translation ID ${literal[1]} in ${name}`)
        assert.ok(!/(?:Prefix|Suffix)["']/.test(expression),'split message in '+name)
    }
}
console.log('PASS: catalog IDs resolve and wording stays independent of call sites')
