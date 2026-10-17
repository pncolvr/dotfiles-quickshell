import assert from 'node:assert/strict'
import fs from 'node:fs'
import {fileURLToPath} from 'node:url'
import * as Catalog from '../../src/i18n/Catalog.mjs'
const folder=fileURLToPath(new URL('../../src/i18n/',import.meta.url))
const en=JSON.parse(fs.readFileSync(folder+'en.json','utf8'))
const pt=JSON.parse(fs.readFileSync(folder+'pt.json','utf8'))
assert.deepEqual(Object.keys(en).sort(),Object.keys(pt).sort(),'catalog coverage matches')
function checkInitialCapital(value, key) {
    if (typeof value === 'string') assert.doesNotMatch(value, /^\p{Ll}/u, 'initial capital: '+key)
    else for (const [part, child] of Object.entries(value)) checkInitialCapital(child,key+'.'+part)
}
for (const [locale, catalog] of Object.entries({en,pt})) checkInitialCapital(catalog,locale)
const placeholders=value=>String(value).match(/%n|%[1-9]\d*/g)?.sort() ?? []
for(const key of Object.keys(en)) {
    assert.match(key,/^[a-z][a-zA-Z0-9]*(?:\.[a-z][a-zA-Z0-9]*)+$/,'stable semantic ID: '+key)
    assert.equal(typeof en[key],typeof pt[key],key)
    if(Array.isArray(en[key])) assert.equal(en[key].length,pt[key].length,key)
    else if(typeof en[key]==='object') {
        assert.deepEqual(Object.keys(en[key]).sort(),['one','other'],key)
        for(const form of ['one','other']) assert.deepEqual(placeholders(en[key][form]),placeholders(pt[key][form]),key)
    } else {
        assert.notEqual(pt[key],'','Portuguese value: '+key)
        assert.deepEqual(placeholders(en[key]),placeholders(pt[key]),key)
    }
}
assert.equal(Catalog.language('system','pt_PT'),'pt')
assert.equal(Catalog.language('system','pt-BR'),'pt')
assert.equal(Catalog.language('system','de_DE'),'en')
assert.equal(Catalog.language('en','pt_PT'),'en')
assert.equal(Catalog.language('pt','en_US'),'pt')
assert.equal(Catalog.language('invalid','pt_PT'),'en')
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
