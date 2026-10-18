import assert from 'node:assert/strict'
import * as Routing from '../../src/services/browser/BrowserRouting.mjs'
import * as Webapps from '../../src/services/webapps/WebappEntries.mjs'
import * as N8n from '../../src/services/n8n/N8nEntries.mjs'
const browsers=[{id:'a',command:['browser-a'],profiles:[{id:'work'}],profileArguments:['--profile={profile}'],reuseArguments:['--target','tab']},{id:'b',command:['browser-b'],windowArguments:['--new-window']}]
assert.equal(Routing.target('/tmp/HTML files/a#b.html'),'file:///tmp/HTML%20files/a%23b.html')
for(const value of ['','   ','https://test/\narg']) assert.throws(()=>Routing.target(value))
for(const value of ['www.google.com','weather tomorrow','relative/file.html','--new-window']) assert.equal(Routing.target(value),value)
const base={...Routing.empty('a'),id:'later',name:'Route',pattern:'example.test',priority:10}
const host={...base,id:'first',match:'host',browser:'b',priority:0}
assert.equal(Routing.choose('https://sub.example.test/path',[base,host],'a').browser,'b')
assert.equal(Routing.choose('https://notexample.test/',[host],'a').browser,'a')
assert.equal(Routing.choose('https://example.test/',[{...host,enabled:false}],'a').browser,'a')
assert(Routing.matches({...base,match:'glob',pattern:'https://*.example.test/a?b'},'https://sub.example.test/axb'))
assert(!Routing.matches({...base,match:'glob',pattern:'https://*.example.test/a?b'},'https://sub.example.test/axxb'))
assert(Routing.matches({...base,match:'glob',pattern:'https://example.test/(literal)+*'},'https://example.test/(literal)+x'))
assert.deepEqual(Routing.command('/tmp/My page.html',{...base,profile:'work'},browsers),['browser-a','--profile=work','--target','tab','file:///tmp/My%20page.html'])
assert.deepEqual(Routing.command('https://example.test/',{...host,windowMode:'window'},browsers),['browser-b','--new-window','https://example.test/'])
assert.deepEqual(Routing.command('www.google.com',Routing.empty('a'),browsers),['browser-a','--target','tab','www.google.com'])
assert.deepEqual(Routing.command('search with spaces',Routing.empty('a'),browsers),['browser-a','--target','tab','search with spaces'])
assert.deepEqual(Routing.command('--new-window',Routing.empty('a'),browsers),['browser-a','--target','tab','--','--new-window'])
assert.throws(()=>Webapps.validate({...Webapps.empty('a'),name:'Search',url:'search with spaces'},browsers))
assert.throws(()=>Routing.validate({...base,browser:'default'},[{id:'default',command:['xdg-open']}]))
assert.throws(()=>Routing.validate({...base,workspace:-1},browsers))
assert.throws(()=>N8n.validate({...N8n.empty('a'),name:'API',url:'file:///tmp/a.html'},browsers))
assert.equal(Webapps.validate({...Webapps.empty('a'),name:'Local',url:'/tmp/index.html'},browsers).url,'file:///tmp/index.html')
assert.equal(Routing.historyQuery('https://example.test/a " OR *'),'"https"* AND "example"* AND "test"* AND "a"* AND "OR"*')
console.log('PASS: routing precedence, literal/glob/host matching, browser argv, local HTML, recursion guards and safe FTS queries')
const application={...Routing.empty('a'),id:'app',name:'Application',pattern:'^https://application.test/item/([0-9]+)',match:'regex',action:'command',command:['application','fixture://item/{1}','{url}'],onlyWhenRunning:'application'}
assert.deepEqual(Routing.command('https://application.test/item/42',Routing.validate(application,browsers),browsers),['application','fixture://item/42','https://application.test/item/42'])
assert.throws(()=>Routing.command('https://application.test/item/42',{...application,command:['application','{2}']},browsers))
assert.throws(()=>Routing.validate({...application,pattern:'('},browsers))
assert.throws(()=>Routing.validate({...application,command:['application','{unknown}']},browsers))
assert.throws(()=>Routing.validate({...application,onlyWhenRunning:'bad process'},browsers))
assert.equal(Routing.validate({...Routing.empty('missing'),name:'Unwrap',pattern:'wrapper.test',action:'query',parameter:'destination'},browsers).parameter,'destination')
assert.equal(Routing.validate({...Routing.empty('missing'),name:'Redirect',pattern:'short.test',action:'redirect'},browsers).action,'redirect')
assert.throws(()=>Routing.validate({...application,action:'query',parameter:''},browsers))
assert.equal(Routing.action({name:'Legacy browser rule'}),'browser')
assert.equal(Routing.choose('https://example.test/',[{...host,id:'used',action:'redirect'}],'a',['used\0https://example.test/']).action,'browser')
console.log('PASS: generic transformation/application actions, regex captures, process guards, templates and legacy browser rules')
const Apps=await import('../../src/services/browser/desktop/DesktopApplications.mjs');
const desktop={id:'test',name:'Test Browser',icon:'test-icon',command:['browser','--flag','%U'],categories:['WebBrowser'],runInTerminal:false,noDisplay:false};
assert.deepEqual(Apps.command(desktop),['browser','--flag','{url}']);
assert.deepEqual(Apps.command({...desktop,command:['browser','--flag']}),['browser','--flag','{url}']);
assert.deepEqual(Apps.applications([desktop,{...desktop,id:'utility',categories:['Utility']}],true).map(value=>value.id),['test']);
assert.equal(Apps.applications([{...desktop,command:['default-browser.sh','%U']}]).length,0);
assert.deepEqual(Routing.command('https://application.test/item/42',{...application,extraArguments:['--profile=Personal Profile','literal $(touch nope)']},browsers),['application','--profile=Personal Profile','literal $(touch nope)','fixture://item/42','https://application.test/item/42']);
assert.throws(()=>Routing.validate({...application,extraArguments:'--bad'},browsers));
console.log('PASS: desktop application filtering, URL fields, literal extra arguments and argument validation');
const containsList=Routing.validate({...base,patterns:[' first.test ','second.test','first.test','']},browsers);
assert.deepEqual(containsList.patterns,['first.test','second.test']);
assert(Routing.matches(containsList,'https://first.test/'));
assert(Routing.matches(containsList,'https://second.test/path'));
assert(!Routing.matches(containsList,'https://unrelated.test/'));
assert(!Routing.matches(containsList,'https://FIRST.test/'));
assert(Routing.matches({...base,patterns:['a+b']},'https://example.test/a+b'));
assert(!Routing.matches({...base,patterns:['a+b']},'https://example.test/ab'));
assert.deepEqual(Routing.validate({...base,pattern:'legacy.test'},browsers).patterns,['legacy.test']);
for(const patterns of [[],[' '],['valid',3],['bad\nvalue'],'not-a-list'])
 assert.throws(()=>Routing.validate({...base,patterns},browsers));
console.log('PASS: multi-value Contains matches any literal value, normalizes lists, rejects invalid input and retains legacy rules');
const steam=Routing.validate({...application,desktopId:'steam',command:['steam','{url}'],pattern:'^https?://store\\.steampowered\\.com/app/([0-9]+)(?:/|[?#]|$)',targetTemplate:'steam://store/{1}'},browsers);
assert.deepEqual(Routing.command('https://store.steampowered.com/app/620/Portal_2/',steam,browsers),['steam','steam://store/620']);
assert.deepEqual(Routing.command('https://store.steampowered.com/app/620/',{...steam,targetTemplate:'{url}'},browsers),['steam','https://store.steampowered.com/app/620/']);
assert.throws(()=>Routing.validate({...steam,targetTemplate:'{unknown}'},browsers));
assert.throws(()=>Routing.validate({...steam,targetTemplate:''},browsers));
assert.throws(()=>Routing.command('https://store.steampowered.com/app/620/',{...steam,targetTemplate:'steam://store/{2}'},browsers));
console.log('PASS: selected application target templates support full URLs and capture-based Steam links without changing the executable');
