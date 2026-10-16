// Local synthetic API only. Never touches a real instance or executes a workflow.
import http from 'node:http'
import fs from 'node:fs'
const directory=process.argv[2]
const server=http.createServer((request,response)=>{
    const url=new URL(request.url,'http://localhost')
    const [,instance,,route]=url.pathname.split('/')
    const entry={instance,path:url.pathname,cursor:url.searchParams.get('cursor'),method:request.method,
        keyCorrect:request.headers['x-n8n-api-key']==='fixture-'+instance}
    fs.appendFileSync(directory+'/requests',JSON.stringify(entry)+'\n')
    const mode=fs.readFileSync(directory+'/mode','utf8').trim()
    const send=(status,body)=>{response.writeHead(status,{'Content-Type':'application/json'});response.end(JSON.stringify(body))}
    if (!entry.keyCorrect || request.method!=='GET' || route!=='v1' || !url.pathname.endsWith('/workflows')) {send(401,{});return}
    switch(mode) {
        case 'timeout': return
        case 'oversize': response.writeHead(200,{'Content-Length':16777217});response.end();return
        case 'redirect': response.writeHead(302,{Location:'/sink'});response.end();return
        case 'denied': send(401,{message:'fixture key must never appear in error'});return
        case 'invalid': send(200,{data:[{id:'missing-name'}]});return
        case 'empty': send(200,{data:[],nextCursor:null});return
        case 'changed': send(200,{data:[{id:'same',name:'Renamed '+instance},{id:'new',name:'Added '+instance}],nextCursor:null});return
        case 'partial':
            if (instance==='b') {send(200,{data:[{id:'same',name:'Updated b'}],nextCursor:null});return}
            if (url.searchParams.has('cursor')) {send(503,{message:'failed final page'});return}
            break
        case 'repeat': send(200,{data:[{id:'same',name:'Repeated'}],nextCursor:'repeat'});return
    }
    if (!url.searchParams.has('cursor')) send(200,{data:[{id:'same',name:'Shared '+instance,nodes:[{private:'discard-me'}]}],nextCursor:'next +&?'})
    else if (url.searchParams.get('cursor')==='next +&?') send(200,{data:[{id:'old',name:'Old '+instance}],nextCursor:null})
    else send(400,{})
})
server.listen(0,'127.0.0.1',()=>fs.writeFileSync(directory+'/port',String(server.address().port)))
