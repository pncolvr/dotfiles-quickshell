#!/usr/bin/env bash
# A Bash driver exercises the actual browser config, commands and socket checks.
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
source "$rbw_test_root/mock.sh"
export QT_QPA_PLATFORM=offscreen QTWEBENGINE_CHROMIUM_FLAGS=--disable-gpu
export HOME="$test_dir/home"
mkdir -p "$HOME/.local/share/qutebrowser/userscripts"
mkdir -p "$HOME/Downloads"
helper="$HOME/.local/share/qutebrowser/userscripts/qute-rbw"
ln -s "$scripts_root/qute-rbw" "$helper"
user_json=$(jq -nc 'env.RBW_TEST_USER')
secret_json=$(jq -nc 'env.RBW_TEST_SECRET')
cat > "$test_dir/site.html" <<HTML
<!doctype html><html><body><form><input autocomplete="username"><input type="password"></form>
<script>
globalThis.rbwTest = {
    changed: [], submitted: false,
    prepare(mode) {
        const forms = {
            login: '<input id="user" autocomplete="username"><input id="pass" type="password">',
            username: '<input id="only">', password: '<input id="only" type="password">',
            totp: '<input id="only" autocomplete="one-time-code">',
            ambiguous: '<input autocomplete="username"><input type="password"><input type="password">',
            frame: '<iframe srcdoc="&lt;input&gt;"></iframe>'
        };
        document.querySelector('form').innerHTML = forms[mode];
        this.changed = []; this.submitted = false;
        for (const input of document.querySelectorAll('input')) {
            input.addEventListener('input', () => this.changed.push(input.id));
        }
        (document.querySelector('input') || document.querySelector('iframe')).focus();
        console.log('RBW_PREP_' + mode);
    },
    check(mode) {
        const user = $user_json, secret = $secret_json;
        const input = document.getElementById('only');
        const ok = mode === 'login'
            ? document.getElementById('user').value === user && document.getElementById('pass').value === secret && this.changed.join(',') === 'user,pass'
            : input.value === (mode === 'username' ? user : mode === 'password' ? secret : '123456');
        console.log(ok && !this.submitted ? 'RBW_PASS_' + mode : 'RBW_FAIL');
    },
    blank() {
        console.log(Array.from(document.querySelectorAll('input')).every(input => !input.value) ? 'RBW_BLANK' : 'RBW_FAIL');
    }
};
document.querySelector('form').addEventListener('submit', event => { rbwTest.submitted = true; event.preventDefault(); });
addEventListener('load', () => { rbwTest.prepare('login'); console.log('RBW_PAGE_READY'); });
</script></body></html>
HTML
socat -d -d TCP4-LISTEN:0,bind=127.0.0.1,reuseaddr,fork "EXEC:bash $rbw_test_root/http.sh" > /dev/null 2> "$test_dir/http-log" & server_pid=$!
for ((attempt=0;attempt<100;attempt++)); do
    port=$(sed -nE 's/.*127\.0\.0\.1:([0-9]+).*/\1/p' "$test_dir/http-log" | head -n 1)
    [[ -n $port ]] && break
    sleep 0.03
done
[[ -n $port ]]
export RBW_TEST_URL=http://127.0.0.1:$port/test
reset_mock
qutebrowser --basedir "$test_dir/profile" --config-py "$browser_root/config.py" \
    --set confirm_quit '["never"]' --set content.proxy none --set content.blocking.enabled false --loglevel vdebug --json-logging "$RBW_TEST_URL" \
    ":spawn --userscript $rbw_test_root/driver.sh" > "$test_dir/log" 2>&1 & shell_pid=$!
wait_log() {
    local pattern=$1 offset=${2:-0}
    for ((attempt=0;attempt<1000;attempt++)); do
        if tail -n "+$((offset + 1))" "$test_dir/log" | rg -q -- "$pattern"; then return; fi
        kill -0 "$shell_pid" 2>/dev/null || { printf 'FAIL: isolated browser stopped\n' >&2; return 1; }
        sleep 0.03
    done
    printf 'FAIL: isolated browser timeout (%s)\n' "$pattern" >&2; return 1
}
wait_log RBW_PAGE_READY
for ((attempt=0;attempt<100;attempt++)); do
    [[ -f $test_dir/browser-fifo && -f $test_dir/driver-pid ]] && break
    sleep 0.01
done
[[ -f $test_dir/browser-fifo ]]
driver_pid=$(<"$test_dir/driver-pid")
exec {command_fd}>"$(<"$test_dir/browser-fifo")"
command() { printf '%s\n' "$1" >&"$command_fd"; }
offset() { wc -l < "$test_dir/log"; }
js() {
    local code=$1 expected=$2 start
    printf '%s\n' "$code" > "$test_dir/check.js"
    start=$(offset)
    command "jseval --quiet --file --world main $test_dir/check.js"
    wait_log "$expected" "$start"
}
prepare() { js "rbwTest.prepare('$1')" "RBW_PREP_$1"; }
fill() {
    local mode=$1 expected=$2 start
    start=$(offset)
    command "rbw-fill $mode"
    wait_log "$expected" "$start"
}
for mode in login username password totp; do
    prepare "$mode"
    fill "$mode" 'rbw: credentials filled'
    js "rbwTest.check('$mode')" "RBW_PASS_$mode"
done
replay=$(rg 'command called: rbw-fill-once' "$test_dir/log" | tail -n 1 | rg -o '[a-f0-9]{32}')
[[ -n $replay ]]
start=$(offset); command "rbw-fill-once $replay"; wait_log 'rbw: request expired' "$start"
printf 'PASS: actual browser full/single-field fills, reactive events, no submission and consumed-handle replay\n'

for control in fail cancel picker-fail; do
    prepare login
    printf '%s\n' "$control" > "$test_dir/control"
    case $control in
        fail) expected='rbw: vault unavailable' ;;
        cancel) expected='rbw: cancelled' ;;
        picker-fail) expected='rbw: entry picker unavailable' ;;
    esac
    fill login "$expected"
    js 'rbwTest.blank()' RBW_BLANK
done
reset_mock
prepare ambiguous
fill login 'rbw: focus a supported login field'
prepare frame
fill login 'rbw: focus a supported login field|rbw: destination changed'
printf 'PASS: subprocess-error privacy, cancelled selection, ambiguous forms and iframe refusal\n'

prepare login
{
    printf 'const fill = '
    cat "$browser_root/src/rbw_form.js"
    printf ';\nconst values = {username:%s,password:%s};\n' "$user_json" "$secret_json"
    cat <<'JS'
try {
    const request = {handle:'synthetic-form-operation',url:location.href,mode:'login'};
    const assert = condition => { if (!condition) throw new Error('Fixed test failure'); };
    const prepare = () => assert(fill({...request,action:'prepare'}) === 'ready');
    const apply = expiresAt => fill({...request,action:'apply',values,expiresAt});
    const blank = () => assert(Array.from(document.querySelectorAll('input')).every(input => !input.value));
    prepare(); assert(apply(Date.now()-1) === 'destination'); blank();
    prepare(); fill({...request,action:'discard'}); assert(apply(Date.now()+1000) === 'destination'); blank();
    prepare(); const password = document.querySelector('[type=password]'); password.type='text';
    assert(apply(Date.now()+1000) === 'form'); blank(); password.type='password';
    prepare(); assert(fill({...request,action:'apply',values:{username:5,password:5},expiresAt:Date.now()+1000}) === 'form'); blank();
    prepare(); const clone = password.cloneNode(); password.replaceWith(clone);
    assert(apply(Date.now()+1000) === 'form'); blank();
    assert(fill({...request,action:'prepare',url:location.href+'/changed'}) === 'destination');
    console.log('RBW_FORM_PASS');
} catch (_) { console.log('RBW_FORM_FAIL'); }
JS
} > "$test_dir/form-check.js"
start=$(offset)
command "jseval --quiet --file --world 42 $test_dir/form-check.js"
wait_log RBW_FORM_PASS "$start"
printf 'PASS: real form helper rejects expiry, discarded handles, changed/removed fields and invalid values\n'

for action in 'reload' 'open -t about:blank' 'config-source'; do
    reset_mock
    prepare login
    printf 'delay\n' > "$test_dir/control"
    start=$(offset); command rbw-fill
    # Wait for the helper to run rather than cancelling before preparation.
    for ((attempt=0;attempt<100;attempt++)); do
        [[ -d $XDG_RUNTIME_DIR/qute-rbw ]] && [[ -n $(find "$XDG_RUNTIME_DIR/qute-rbw" -name commands -print -quit) ]] && break
        sleep 0.01
    done
    command "$action"
    wait_log 'rbw: destination changed|rbw: cancelled' "$start"
    if [[ $action == 'open -t about:blank' ]]; then command tab-prev; sleep 0.1; fi
    if [[ $action == reload ]]; then wait_log RBW_PAGE_READY "$start"; fi
    js 'rbwTest.blank()' RBW_BLANK
done
printf 'PASS: same-URL navigation, tab switch and configuration reload revoke pending fills\n'

ln -sfn "$rbw_test_root/raw-helper.sh" "$helper"
for control in oversized malformed injected permissions peer; do
    prepare login
    printf '%s\n' "$control" > "$test_dir/control"
    fill login 'rbw: vault unavailable'
    js 'rbwTest.blank()' RBW_BLANK
done
! rg -q 'RBW_CREDENTIAL_MARKER|RBW_USERNAME_MARKER|ERROR_MARKER|NEVER_TRANSFER_SEED|NEVER_TRANSFER_HISTORY|RBW_FAIL|RBW_FORM_FAIL' "$test_dir/log"
! rg -Fq "$RBW_TEST_SECRET" "$test_dir/calls"
[[ -z $(find "$XDG_RUNTIME_DIR/qute-rbw" -name 'job.*' -print -quit) ]]
command quit
wait "$shell_pid"; shell_pid=''
kill "$(<"$test_dir/driver-pid")" 2>/dev/null || true
printf 'PASS: malformed/oversized replies, endpoint permissions, peer mismatch and vdebug privacy\n'
