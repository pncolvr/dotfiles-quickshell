#!/usr/bin/env bash
# Exercise relocated providers without reading private config or running desktop actions.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-providers-test.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin" "$test_dir/home" "$test_dir/cache" "$test_dir/runtime"
chmod 700 "$test_dir/runtime"
tar -C "$project_root" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$test_dir" -xf -
export HOME="$test_dir/home" ZDOTDIR="$test_dir/zsh"
export XDG_CACHE_HOME="$test_dir/cache" XDG_RUNTIME_DIR="$test_dir/runtime"
export QS_PICKER_CONFIG="$test_dir" QS_PICKER_TIMEOUT=4
export QS_PICKER_EXECUTABLE="$test_dir/bin/qs"
export PROVIDER_TEST_DIR="$test_dir"
export PATH="$test_dir/bin:$PATH"
picker="$test_dir/src/services/launcher/launcher.sh"
providers="$test_dir/src/services/launcher/providers"
mkdir -p "$HOME/Alpha" "$HOME/Beta" "$HOME/Pictures" "$HOME/Videos"
touch "$test_dir/actions" "$test_dir/menus"
cat > "$test_dir/bin/qs" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${5:-} == status && ${6:-} == pause ]]; then exit 0; fi
if [[ ${5:-} == recording ]]; then
    printf 'recording <%s>\n' "$6" >> "$PROVIDER_TEST_DIR/actions"
    exit 0
fi
if [[ ${5:-} == alerts ]]; then
    printf 'alerts' >> "$PROVIDER_TEST_DIR/actions"
    printf ' <%s>' "${@:6}" >> "$PROVIDER_TEST_DIR/actions"
    printf '\n' >> "$PROVIDER_TEST_DIR/actions"
    exit 0
fi
if [[ ${6:-} == screenshot || ${6:-} == wallpaper || ${6:-} == encodeQr || ${6:-} == bookmarks || ${6:-} == power || ${6:-} == projects || ${6:-} == projectUrls || ${6:-} == directories || ${6:-} == webapps || ${6:-} == remotes || ${6:-} == n8n ]]; then
    printf 'native <%s>\n' "$6" >> "$PROVIDER_TEST_DIR/actions"
    exit 0
fi
# Any return to the removed interactive provider path is a regression.
printf 'unexpected IPC %s\n' "$*" >> "$PROVIDER_TEST_DIR/menus"
exit 2
BASH
cat > "$test_dir/bin/action" <<'BASH'
#!/usr/bin/env bash
name=${0##*/}
printf -v action_args ' <%s>' "$@"
printf '%s%s\n' "$name" "$action_args" >> "$PROVIDER_TEST_DIR/actions"
jq -nc --arg tool "$name" --args '{tool:$tool,args:$ARGS.positional}' -- "$@" >> "$PROVIDER_TEST_DIR/action-arguments"
BASH
chmod +x "$test_dir/bin/qs" "$test_dir/bin/action"
for command in hyprctl xdg-open dbus-send pcmanfm-qt systemctl loginctl; do
    ln -s action "$test_dir/bin/$command"
done
for old_config in "$providers/screenshot.env" "$providers/recording.env" "$providers/_common/utils.env"; do
    printf 'touch %q\n' "$test_dir/env-executed" > "$old_config"
done
expect_action() {
    local expected=$1
    for ((attempt=0;attempt<50;attempt++)); do
        if rg -Fq -- "$expected" "$test_dir/actions"; then return; fi
        /usr/bin/sleep 0.02
    done
    printf 'Missing action: %s\n' "$expected" >&2
    cat "$test_dir/error" >&2
    exit 1
}
for provider in code github directories webapps remotes n8n power bookmarks encode-qrcode wallpaper screenshot; do
    : > "$test_dir/actions"; : > "$test_dir/menus"
    bash "$picker" provider "$provider"
    case $provider in
        code) expect_action 'native <projects>' ;;
        github) expect_action 'native <projectUrls>' ;;
        encode-qrcode) expect_action 'native <encodeQr>' ;;
        *) expect_action "native <$provider>" ;;
    esac
    [[ ! -s $test_dir/menus ]]
done
printf 'PASS: projects, GitHub, directories, Webapps, Remotes, n8n, Power, Bookmarks, QR encoding and Wallpaper dispatch to native IPC without a JSON cache\n'
# Capture tools and offline prepared execution are covered by screenshot.sh.
# Native recording choices are covered by tests/recording/setup.sh.
# Non-menu callers must keep working after the original scripts are removed.
: > "$test_dir/actions"; : > "$test_dir/menus"
bash "$picker" provider power Lock
bash "$picker" provider screenshot ocr >/dev/null
bash "$picker" provider screenshot qrcode >/dev/null
bash "$picker" provider recording
expect_action 'loginctl <lock-session>'
expect_action 'native <screenshot>'
expect_action 'recording <toggle>'
! rg -q '^notify-send |^hyprctl <notify>' "$test_dir/actions"
[[ ! -s $test_dir/menus ]]
printf 'PASS: idle lock, OCR, QR and recording-stop calls bypass selection\n'

[[ ! -d $test_dir/runtime/quickshell-picker || -z $(find "$test_dir/runtime/quickshell-picker" -mindepth 1 -print -quit) ]]
printf 'PASS: provider request directories are cleaned up\n'

[[ ! -e $test_dir/env-executed ]]
printf 'PASS: obsolete provider .env files are never executed\n'

# Exercise the same reveal helper used by detached screenshots and recordings.
node - "$project_root" "$test_dir" <<'JS'
const fs=require('fs'),cp=require('child_process'),assert=require('node:assert/strict');
const {fileURLToPath}=require('node:url');
const [repo,fixture]=process.argv.slice(2), log=fixture+'/action-arguments';
const focus={tool:'hyprctl',args:['dispatch','hl.dsp.focus({ window = "class:pcmanfm-qt" })']};
function reveal(path) {
    fs.writeFileSync(log,'');
    const result=cp.spawnSync('bash',['-euc','source "$1"; open_file_explorer "$2"','bash',repo+'/src/services/launcher/providers/_common/utils.sh',path],{encoding:'utf8'});
    assert.equal(result.status,0,result.stderr);assert.equal(result.stderr,'');
    return fs.readFileSync(log,'utf8').trim().split('\n').map(line=>JSON.parse(line));
}
for(const name of ['Screenshot #1 100% ?,comma "quote".png','Recording Olá 日本語\nnext line.mp4']) {
    const path=fixture+'/'+name;fs.writeFileSync(path,'saved');
    const calls=reveal(path);
    assert.equal(calls.length,2);
    assert.equal(calls[0].tool,'dbus-send');
    const args=calls[0].args;
    assert.ok(args.includes('org.freedesktop.FileManager1.ShowItems'));
    const uri=args.find(value=>value.startsWith('array:string:')).slice('array:string:'.length);
    assert.equal(fileURLToPath(uri),path);
    assert.ok(!/[ #?,"\n]/.test(uri),'file URI is safe as a single D-Bus array entry');
    assert.deepEqual(calls[1],focus,'focus happens after revealing the file');
}
const directory=fixture+'/folder #100%';fs.mkdirSync(directory);
assert.deepEqual(reveal(directory),[{tool:'xdg-open',args:[directory]},focus]);
const missing=fixture+'/missing literal #file';
assert.deepEqual(reveal(missing),[{tool:'pcmanfm-qt',args:[missing]},focus]);
console.log('PASS: shared screenshot/recording reveal encodes special-character paths and preserves directory opening and focus order');
JS
