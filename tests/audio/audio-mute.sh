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
 if(method==='ListNames') output({data:[state.absent?[]:['org.freedesktop.StatusNotifierItem-123-1']]});
 else if(action==='get-property') output({data:method==='Id'?'discord_status_icon_1':'/com/canonical/dbusmenu'});
 else if(method==='AboutToShow') output({data:[false]});
 else if(method==='GetLayout') output({data:[1,[0,{},[
  {type:'(ia{sv}av)',data:[1,{label:{data:'_Mute'},'toggle-state':{data:state.mute}},[]]},
  {type:'(ia{sv}av)',data:[2,{label:{data:'Deafen'},'toggle-state':{data:state.deafen}},[]]}
 ]]]});
 else if(method==='Event') {
  if(state.fail) { console.error('Synthetic Discord failure');process.exit(1); }
  if(values[1]==='1') state.mute=1-state.mute;
  else if(values[1]==='2') {
   state.deafen=1-state.deafen;
   if(state.deafen) { state.previous=state.mute; state.mute=1; }
   else state.mute=state.previous;
  } else throw Error('Unexpected menu item: '+values);
  save();output({data:[]});
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
reset '{"mic":0,"mute":0,"sink":0,"deafen":0,"fail":true}'
bash "$helper/mic.sh" 2>"$fixture/error"
check '.mic == 1 and .mute == 0'
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
printf 'PASS: audio mute sync, both mismatch directions, mic restoration, absent Discord, failure fallback, literal argv and shared lock\n'
