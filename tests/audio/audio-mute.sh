#!/usr/bin/env bash
# Synthetic PulseAudio and tray state only; never touches desktop audio or D-Bus.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-audio-mute.XXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime" "$fixture/bin"
export AUDIO_TEST_STATE="$fixture" XDG_RUNTIME_DIR="$fixture/runtime"
export PATH="$fixture/bin:$PATH"
cat >"$fixture/mock.cjs" <<'NODE'
const fs=require('fs');
const root=process.env.AUDIO_TEST_STATE;
const [tool,...args]=process.argv.slice(2);
const state=JSON.parse(fs.readFileSync(root+'/state.json'));
function output(value) { console.log(JSON.stringify(value)); }
function save() { fs.writeFileSync(root+'/state.json',JSON.stringify(state)); }
fs.appendFileSync(root+'/calls',JSON.stringify([tool,...args])+'\n');
if(tool==='pactl') {
 const [action,name,value]=args;
 switch(action) {
  case 'get-default-source': console.log('mic $(literal) name'); break;
  case 'get-default-sink': console.log('speaker $(literal) name'); break;
  case 'get-source-mute': console.log('Mute: '+(state.mic?'yes':'no')); break;
  case 'get-sink-mute': console.log('Mute: '+(state.sink?'yes':'no')); break;
  case 'set-source-mute':
   if(name!=='mic $(literal) name') throw Error('Corrupted source argv');
   state.mic=Number(value);save();break;
  case 'set-sink-mute':
   if(name!=='speaker $(literal) name') throw Error('Corrupted sink argv');
   state.sink=Number(value);save();break;
  default: throw Error('Unexpected pactl request: '+args);
 }
} else {
 const request=args.slice(args.indexOf('--')+1);
 const [action,service,path,iface,method,...values]=request;
 const accessibility=args.some(arg=>arg.startsWith('--address='));
 const clients=state.clients??(state.absent?[]:['discord']);
 const vesktopService='org.freedesktop.StatusNotifierItem-'+(state.pid??456)+'-1';
 const voice=accessibility?state.vesktop:state;
 function toggle(control) {
  voice[control]=1-voice[control];
  if(control==='deafen') {
   if(voice.deafen) { voice.previous=voice.mute;voice.mute=1; }
   else voice.mute=voice.previous??0;
  }
  if(state.overrideMic!==undefined) state.mic=state.overrideMic;
  if(state.overrideSink!==undefined) state.sink=state.overrideSink;
  save();
 }
 if(method==='GetAddress') output({data:['unix:path=/synthetic/accessibility-bus']});
 else if(method==='GetConnectionUnixProcessID') {
  const name=values[1];
  output({data:[name===vesktopService||name===':1.vesktop'?(state.pid??456):999999]});
 }
 else if(accessibility) {
  if(method==='GetChildren') output({data:[[
   [':1.other','/org/a11y/atspi/accessible/root'],
   ...(state.inaccessible?[]:[[':1.vesktop','/org/a11y/atspi/accessible/root']])
  ]]});
  else if(service!==':1.vesktop') throw Error('Selected unrelated Electron app');
  else if(method==='GetMatches') {
   if(values.join(' ')!=='(aiia{ss}iaiiasib)uib 2 0 512 1 0 1 2 0 1073741824 2 1 Action 1 false 1 0 true')
    throw Error('Expected only checkable, actionable toggle buttons');
   output({data:[[
    ...(state.staleControl?[[':1.vesktop','/stale/mute']]:[]),
    [':1.vesktop','/voice/mute'],[':1.vesktop','/voice/deafen']
   ]]});
  }
  else if(action==='get-property'&&method==='Name') output({data:path.endsWith('/mute')?'Mute':'Deafen'});
  else if(method==='GetState') {
   if(path.startsWith('/stale/')) output({data:[state.staleFlags??[64,0]]});
   else output({data:[[1124075776+(voice[path.endsWith('/mute')?'mute':'deafen']?16:0),512]]});
  }
  else if(method==='DoAction') {
   if(path.startsWith('/stale/')) throw Error('Acted on a defunct voice control');
   if(state.failVesktop) output({data:[false]});
   else { toggle(path.endsWith('/mute')?'mute':'deafen');output({data:[true]}); }
  }
  else throw Error('Unexpected accessibility request: '+request);
 }
 else if(method==='ListNames') {
  for(const [key,value]of Object.entries(state.expectedBeforeSync??{})) {
   if(state[key]!==value) {
    console.error('System '+key+' must be '+value+' before client discovery; got '+state[key]);
    process.exit(1);
   }
  }
  output({data:[clients.map(client=>client==='discord'?'org.freedesktop.StatusNotifierItem-123-1':vesktopService)]});
 }
 else if(action==='get-property') output({data:method==='Id'?(service===vesktopService?'vesktop_status_icon_1':'discord_status_icon_1'):'/com/canonical/dbusmenu'});
 else if(method==='AboutToShow') output({data:[false]});
 else if(method==='GetLayout') output({data:[1,[0,{},[
  {type:'(ia{sv}av)',data:[1,{label:{data:'_Mute'},'toggle-state':{data:state.mute}},[]]},
  {type:'(ia{sv}av)',data:[2,{label:{data:'Deafen'},'toggle-state':{data:state.deafen}},[]]}
 ]]]});
 else if(method==='Event') {
  if(state.fail||state.failDiscord) { console.error('Synthetic Discord failure');process.exit(1); }
  if(values[1]==='1') toggle('mute');
  else if(values[1]==='2') toggle('deafen');
  else throw Error('Unexpected menu item: '+values);
  output({data:[]});
 } else throw Error('Unexpected bus request: '+request);
}
NODE
for tool in pactl busctl; do
    printf '#!/usr/bin/env bash\nexec node "$AUDIO_TEST_STATE/mock.cjs" %s "$@"\n' "$tool" >"$fixture/bin/$tool"
    chmod +x "$fixture/bin/$tool"
done
reset() {
    printf '%s\n' "$1" >"$fixture/state.json"
    : >"$fixture/calls"
    rm -f "$fixture/runtime/hypr-speaker-mute-${UID}.state"
}
check() { jq -e "$1" "$fixture/state.json" >/dev/null; }
helper="$repo/src/services/audio"
for mic in 0 1; do
    for discord in 0 1; do
        reset "{\"mic\":$mic,\"mute\":$discord,\"sink\":0,\"deafen\":0}"
        bash "$helper/mic.sh"
        target=$((1-mic))
        check ".mic == $target and .mute == $target and .sink == 0 and .deafen == 0"
    done
done
for mic in 0 1; do
    reset "{\"mic\":$mic,\"mute\":$mic,\"sink\":0,\"deafen\":0}"
    bash "$helper/speakers.sh"
    check '.mic == 1 and .sink == 1 and .deafen == 1'
    bash "$helper/speakers.sh"
    check ".mic == $mic and .mute == $mic and .sink == 0 and .deafen == 0"
    [[ ! -e "$fixture/runtime/hypr-speaker-mute-${UID}.state" ]]
done
reset '{"mic":0,"mute":1,"sink":0,"deafen":1,"previous":0}'
bash "$helper/speakers.sh"
check '.mic == 1 and .sink == 1 and .deafen == 1'
! rg -q '"Event"' "$fixture/calls"
reset '{"mic":1,"mute":0,"sink":1,"deafen":0}'
bash "$helper/speakers.sh"
check '.mic == 1 and .sink == 0 and .deafen == 0'
! rg -q '"Event"' "$fixture/calls"
reset '{"mic":0,"mute":0,"sink":0,"deafen":0,"absent":true}'
bash "$helper/mic.sh"
check '.mic == 1 and .mute == 0'
bash "$helper/speakers.sh"
bash "$helper/speakers.sh"
check '.mic == 1 and .sink == 0'
reset '{"mic":0,"mute":0,"sink":0,"deafen":0,"fail":true,"expectedBeforeSync":{"mic":1}}'
bash "$helper/mic.sh" 2>"$fixture/error"
check '.mic == 1 and .mute == 0'
[[ $(jq -r .key "$fixture/error") == audio.errors.discordSync ]]
[[ $(rg -c '"Event"' "$fixture/calls") == 1 ]]
reset '{"mic":0,"sink":0,"clients":["vesktop"],"failVesktop":true,"vesktop":{"mute":0,"deafen":0},"expectedBeforeSync":{"mic":1}}'
bash "$helper/mic.sh" 2>"$fixture/error"
check '.mic == 1 and .vesktop.mute == 0'
[[ $(jq -r .key "$fixture/error") == audio.errors.discordSync ]]
[[ $(rg -c '"DoAction"' "$fixture/calls") == 1 ]]
reset '{"mic":0,"sink":0,"clients":["vesktop"],"failVesktop":true,"vesktop":{"mute":0,"deafen":0},"expectedBeforeSync":{"mic":1,"sink":1}}'
bash "$helper/speakers.sh" 2>"$fixture/error"
check '.mic == 1 and .sink == 1 and .vesktop.deafen == 0'
[[ $(jq -r .key "$fixture/error") == audio.errors.discordSync ]]
[[ $(rg -c '"DoAction"' "$fixture/calls") == 1 ]]
for target in 0 1; do
    initial=$((1-target))
    reset "{\"mic\":$initial,\"mute\":$initial,\"sink\":0,\"deafen\":0,\"expectedBeforeSync\":{\"mic\":$target}}"
    bash "$helper/mic.sh"
    check ".mic == $target and .mute == $target"
    [[ $(rg -c '^\["pactl","set-source-mute"' "$fixture/calls") == 1 ]]
    reset "{\"mic\":0,\"mute\":$initial,\"sink\":$initial,\"deafen\":$initial,\"previous\":0,\"expectedBeforeSync\":{\"mic\":$target,\"sink\":$target}}"
    bash "$helper/speakers.sh"
    check ".mic == $target and .sink == $target and .deafen == $target"
    [[ $(rg -c '^\["pactl","set-source-mute"' "$fixture/calls") == 1 ]]
    [[ $(rg -c '^\["pactl","set-sink-mute"' "$fixture/calls") == 1 ]]
done
reset '{"mic":0,"mute":0,"sink":0,"deafen":0,"overrideMic":0,"expectedBeforeSync":{"mic":1}}'
bash "$helper/mic.sh"
check '.mic == 1 and .mute == 1'
[[ $(rg -c '^\["pactl","set-source-mute"' "$fixture/calls") == 2 ]]
reset '{"mic":0,"mute":0,"sink":0,"deafen":0,"overrideMic":0,"overrideSink":0,"expectedBeforeSync":{"mic":1,"sink":1}}'
bash "$helper/speakers.sh"
check '.mic == 1 and .sink == 1 and .deafen == 1'
[[ $(rg -c '^\["pactl","set-source-mute"' "$fixture/calls") == 2 ]]
[[ $(rg -c '^\["pactl","set-sink-mute"' "$fixture/calls") == 2 ]]
for flags in '[64,0]' '[134217728,512]' '[0,0]'; do
    reset "{\"mic\":1,\"sink\":0,\"clients\":[\"vesktop\"],\"staleControl\":true,\"staleFlags\":$flags,\"vesktop\":{\"mute\":1,\"deafen\":0}}"
    bash "$helper/mic.sh"
    check '.mic == 0 and .vesktop.mute == 0' || {
        printf 'FAIL: invalid accessibility state %s prevented unmuting the live control\n' "$flags" >&2
        exit 1
    }
    [[ $(rg -c '"DoAction"' "$fixture/calls") == 1 ]]
done
for pid in 7654 8765; do
    reset "{\"mic\":0,\"sink\":0,\"clients\":[\"vesktop\"],\"pid\":$pid,\"vesktop\":{\"mute\":0,\"deafen\":0}}"
    bash "$helper/mic.sh"
    check '.mic == 1 and .vesktop.mute == 1'
    : >"$fixture/calls"
    bash "$helper/discord-voice.sh" mute 1
    ! rg -q '"DoAction"' "$fixture/calls"
    bash "$helper/mic.sh"
    check '.mic == 0 and .vesktop.mute == 0'
    bash "$helper/speakers.sh"
    check '.mic == 1 and .sink == 1 and .vesktop.deafen == 1'
    bash "$helper/speakers.sh"
    check '.mic == 0 and .sink == 0 and .vesktop.mute == 0 and .vesktop.deafen == 0'
done
for prior in 0 1; do
    reset "{\"mic\":$prior,\"mute\":1,\"sink\":0,\"deafen\":0,\"clients\":[\"discord\",\"vesktop\"],\"vesktop\":{\"mute\":0,\"deafen\":0}}"
    bash "$helper/mic.sh"
    target=$((1-prior))
    check ".mic == $target and .mute == $target and .vesktop.mute == $target"
    bash "$helper/speakers.sh"
    check '.mic == 1 and .sink == 1 and .deafen == 1 and .vesktop.deafen == 1'
    bash "$helper/speakers.sh"
    check ".mic == $target and .mute == $target and .vesktop.mute == $target and .deafen == 0 and .vesktop.deafen == 0"
done
reset '{"mic":0,"mute":0,"sink":0,"deafen":0,"clients":["discord","vesktop"],"failDiscord":true,"vesktop":{"mute":0,"deafen":0}}'
bash "$helper/mic.sh" 2>"$fixture/error"
check '.mic == 1 and .mute == 0 and .vesktop.mute == 1'
[[ $(jq -r .key "$fixture/error") == audio.errors.discordSync ]]
reset '{"mic":0,"mute":0,"sink":0,"deafen":0,"clients":["vesktop","discord"],"inaccessible":true,"vesktop":{"mute":0,"deafen":0}}'
bash "$helper/mic.sh" 2>"$fixture/error"
check '.mic == 1 and .mute == 1 and .vesktop.mute == 0'
[[ $(jq -r .key "$fixture/error") == audio.errors.discordSync ]]
reset '{"mic":0,"mute":0,"sink":0,"deafen":0}'
(
    exec 9>"$fixture/runtime/hypr-mic-mute-${UID}.lock"
    flock 9
    bash "$helper/mic.sh"
    bash "$helper/speakers.sh"
    : # Keep the lock holder alive instead of exec-optimizing the last command.
)
if [[ -s "$fixture/calls" ]]; then
    printf 'FAIL: overlapping action reached audio commands\n' >&2
    cat "$fixture/calls" >&2
    exit 1
fi
printf 'PASS: system-first mute/unmute, client override recovery, Discord/Vesktop sync, changing PIDs, mic restoration, partial failures and shared lock\n'
