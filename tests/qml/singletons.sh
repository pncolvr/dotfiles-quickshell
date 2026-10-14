#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
qmlls_bin=${QMLLS:-/usr/lib/qt6/bin/qmlls}
command -v node >/dev/null
[[ -x $qmlls_bin ]] || { printf 'Qt QML language server is required; set QMLLS.\n' >&2; exit 1; }
fixture=$(mktemp -d /tmp/quickshell-singletons.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$repo_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/readonly property bool clipboardMonitorEnabled: true/readonly property bool clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
sed 's@"../../src@"src@g' "$repo_dir/tests/qml/singletons-smoke.qml" > "$fixture/shell.qml"
QT_QPA_PLATFORM=offscreen PIPEWIRE_REMOTE=quickshell-singleton-test XDG_RUNTIME_DIR="$fixture/runtime" \
    XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" \
    timeout 15 qs -p "$fixture" > "$fixture/runtime.log" 2>&1 || { cat "$fixture/runtime.log"; exit 1; }
rg 'PASS:|SINGLETON FAIL:' "$fixture/runtime.log"
if ! rg -q 'PASS: local singleton metadata' "$fixture/runtime.log" \
    || rg -q 'SINGLETON FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/runtime.log"; then cat "$fixture/runtime.log"; exit 1; fi
node - "$repo_dir" "$qmlls_bin" <<'JS'
const fs=require('node:fs'), path=require('node:path'), {spawn}=require('node:child_process'), {pathToFileURL}=require('node:url');
const [repo,executable]=process.argv.slice(2), files=[];
function visit(folder) {
    for(const entry of fs.readdirSync(folder,{withFileTypes:true})) {
        const file=path.join(folder,entry.name);
        if(entry.isDirectory())visit(file);
        else if(file.endsWith('.qml') && /^pragma Singleton\b/m.test(fs.readFileSync(file,'utf8'))) files.push(file);
    }
}
visit(path.join(repo,'src'));
const server=spawn(executable,['--no-cmake-calls','-I','/usr/lib/qt6/qml'],{cwd:repo,env:{...process.env,QMLLS_MAX_FILES_TO_SEARCH:'0'}});
const results=new Map();let buffer=Buffer.alloc(0), opened=false, finished=false;
function send(message) { const data=Buffer.from(JSON.stringify(message));server.stdin.write(`Content-Length: ${data.length}\r\n\r\n`);server.stdin.write(data); }
function finish(error) {
    if(finished)return;finished=true;clearTimeout(deadline);clearTimeout(settle);server.kill('SIGTERM');
    if(error){console.error(error);process.exitCode=1;return;}
    for(const file of files) {
        const diagnostics=results.get(pathToFileURL(file).href);
        if(!diagnostics){console.error('SINGLETON FAIL: no editor diagnostics for '+path.relative(repo,file));process.exitCode=1;continue;}
        for(const diagnostic of diagnostics.filter(entry=>entry.severity<=2)) {
            console.error('SINGLETON FAIL: '+path.relative(repo,file)+': '+diagnostic.message);process.exitCode=1;
        }
    }
    if(!process.exitCode)console.log(`PASS: QML language server reports no warnings for ${files.length} singleton files`);
}
const deadline=setTimeout(()=>finish(),30000);let settle;
server.on('error',error=>finish('SINGLETON FAIL: '+error.message));
server.on('exit',()=>{if(!finished)finish('SINGLETON FAIL: language server exited early');});
server.stderr.on('data',()=>{});
server.stdout.on('data',chunk=>{
    buffer=Buffer.concat([buffer,chunk]);
    while(true) {
        const end=buffer.indexOf('\r\n\r\n');if(end<0)return;
        const length=Number(/Content-Length: (\d+)/i.exec(buffer.subarray(0,end).toString())?.[1]);
        if(!Number.isFinite(length)){finish('SINGLETON FAIL: invalid LSP header');return;}
        if(buffer.length<end+4+length)return;
        const message=JSON.parse(buffer.subarray(end+4,end+4+length));buffer=buffer.subarray(end+4+length);
        if(message.id===1&&!opened) {
            opened=true;send({jsonrpc:'2.0',method:'initialized',params:{}});
            for(const file of files)send({jsonrpc:'2.0',method:'textDocument/didOpen',params:{textDocument:{uri:pathToFileURL(file).href,languageId:'qml',version:1,text:fs.readFileSync(file,'utf8')}}});
        }
        if(message.method==='textDocument/publishDiagnostics') {
            results.set(message.params.uri,message.params.diagnostics);
            if(files.every(file=>results.has(pathToFileURL(file).href))){clearTimeout(settle);settle=setTimeout(()=>finish(),1000);}
        }
    }
});
send({jsonrpc:'2.0',id:1,method:'initialize',params:{processId:process.pid,rootUri:pathToFileURL(repo).href,capabilities:{},workspaceFolders:[{uri:pathToFileURL(repo).href,name:'quickshell'}]}});
JS
