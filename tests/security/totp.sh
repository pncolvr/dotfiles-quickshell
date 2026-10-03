#!/usr/bin/env bash
# Uses only RFC/public test seeds and a fake keyring; never touches desktop secrets.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
source "$project_root/services/security/totp.sh"
set -e

assert() { [[ $1 == "$2" ]] || { printf 'FAIL: %s\n' "$3" >&2; exit 1; }; }
reject_token() { if parse_token "$1"; then printf 'FAIL: accepted invalid token\n' >&2; exit 1; fi; }

# RFC 6238 Appendix B, including corrected SHA256 and SHA512 seed lengths.
times=(59 1111111109 1111111111 1234567890 2000000000 20000000000)
sha1=(94287082 07081804 14050471 89005924 69279037 65353130)
sha256=(46119246 68084774 67062674 91819424 90698825 77737706)
sha512=(90693936 25091201 99943326 93441116 38618901 47863826)
for algorithm in SHA1 SHA256 SHA512; do
    case $algorithm in
        SHA1) seed=12345678901234567890; expected=("${sha1[@]}") ;;
        SHA256) seed=12345678901234567890123456789012; expected=("${sha256[@]}") ;;
        SHA512) seed=1234567890123456789012345678901234567890123456789012345678901234; expected=("${sha512[@]}") ;;
    esac
    encoded=$(printf '%s' "$seed" | base32 --wrap=0)
    parse_token "otpauth://totp/Test?secret=$encoded&algorithm=$algorithm&digits=8"
    for i in "${!times[@]}"; do
        generate_code "${times[$i]}"
        assert "$CODE" "${expected[$i]}" "RFC vector $algorithm ${times[$i]}"
    done
done

parse_token ' jbsw-y3dp ehpk3pxp '
assert "$TOKEN_SECRET" JBSWY3DPEHPK3PXP 'Base32 normalization'
parse_token 'otpauth://totp/Test?secret=JBSW%20Y3DP%20EHPK3PXP&period=60&digits=8&algorithm=sha256'
assert "$TOKEN_PERIOD:$TOKEN_DIGITS:$TOKEN_ALGORITHM" 60:8:SHA256 'URI parameters'
for invalid in '' INVALID0 A MZ 'otpauth://hotp/Test?secret=JBSWY3DPEHPK3PXP' \
    'otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&period=0' \
    'otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&digits=9' \
    'otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&secret=MY' \
    'otpauth://totp/Test?secret=%00'; do reject_token "$invalid"; done

sandbox_dir=$(mktemp -d /tmp/quickshell-totp-test.XXXXXX)
smoke_entry=''
trap 'rm -rf -- "$sandbox_dir"; if [[ -n $smoke_entry ]]; then rm -f -- "$smoke_entry"; fi' EXIT
export TOTP_TEST_STORE=$sandbox_dir/store
mkdir -p "$TOTP_TEST_STORE" "$sandbox_dir/bin"
cat > "$sandbox_dir/bin/secret-tool" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case $1 in
    search)
        [[ ! -f $TOTP_TEST_STORE/locked ]] || { printf '[locked]\n'; exit 0; }
        for file in "$TOTP_TEST_STORE"/*.json; do
            [[ -f $file ]] || continue
            printf '[%s]\nsecret = ' "${file##*/}"
            cat "$file"
            printf '\n'
        done ;;
    store)
        [[ ! -f $TOTP_TEST_STORE/fail ]] || exit 1
        cat > "$TOTP_TEST_STORE/${!#}.json" ;;
    clear) rm -- "$TOTP_TEST_STORE/${!#}.json" ;;
    *) exit 1 ;;
esac
MOCK
chmod +x "$sandbox_dir/bin/secret-tool"
secret_tool=$sandbox_dir/bin/secret-tool
attributes=(application quickshell type totp vault default)
entries='[]'
loaded=false

handle '{"action":"load"}'
assert "$(json "$RESPONSE" -r '.entries | length')" 0 'empty keyring'
handle '{"action":"save","name":"Zulu","token":"JBSWY3DPEHPK3PXP"}'
zulu=$(json "$RESPONSE" -r .id)
handle '{"action":"save","name":"alpha","token":"JBSWY3DPEHPK3PXP"}'
alpha=$(json "$RESPONSE" -r .id)
assert "$(json "$RESPONSE" -r '.entries[0].name')" alpha 'alphabetical ordering'
assert "$(json "$RESPONSE" -r 'any(.entries[]; has("token") or has("secret"))')" false 'snapshot excludes seeds'

handle "{\"action\":\"edit\",\"id\":\"$alpha\"}"
assert "$(json "$RESPONSE" -r .type)" edit 'load editor'
assert "$(json "$RESPONSE" -r '.token | startswith("otpauth://totp/")')" true 'canonical editor token'
handle "{\"action\":\"save\",\"id\":\"$alpha\",\"name\":\"Beta\",\"token\":\"MY\"}"
assert "$(json "$RESPONSE" -r '.entries[0].name')" Beta 'edit name and token'

touch "$TOTP_TEST_STORE/fail"
if handle "{\"action\":\"save\",\"id\":\"$alpha\",\"name\":\"Lost\",\"token\":\"MY\"}"; then
    printf 'FAIL: save failure accepted\n' >&2; exit 1
fi
assert "$(json "$entries" -r '.[0].name')" Beta 'failed save preserves previous entry'
rm "$TOTP_TEST_STORE/fail"
handle "{\"action\":\"copy\",\"id\":\"$alpha\"}"
assert "$(json "$RESPONSE" -r '.code | length')" 6 'copy code'
handle "{\"action\":\"delete\",\"id\":\"$zulu\"}"
assert "$(json "$RESPONSE" -r '.entries | length')" 1 'delete entry'
handle '{"action":"load"}'
assert "$(json "$RESPONSE" -r '.entries[0].name')" Beta 'reload saved changes'

touch "$TOTP_TEST_STORE/locked"
if load_vault; then printf 'FAIL: locked keyring treated as empty\n' >&2; exit 1; fi
rm "$TOTP_TEST_STORE/locked"
printf '%s' 'corrupt' > "$TOTP_TEST_STORE/corrupt.json"
if load_vault 2>/dev/null; then printf 'FAIL: corrupt keyring accepted\n' >&2; exit 1; fi
rm "$TOTP_TEST_STORE/corrupt.json"

# Exercise the actual newline protocol and graceful shutdown.
protocol=$(printf '%s\n' '{"action":"load"}' '{"action":"refresh"}' '{"action":"quit"}' | \
    bash "$project_root/services/security/totp.sh" --secret-tool "$secret_tool")
assert "$(printf '%s' "$protocol" | jq -s length)" 2 'worker protocol and quit'
printf 'PASS: 18 RFC vectors, URI validation, CRUD, errors, and worker protocol\n'

if [[ ${1:-} == --qml-smoke ]]; then
    mkdir -m 700 "$sandbox_dir/runtime"
    # Keep Quickshell's import scanner rooted in the real project.
    smoke_entry=$(mktemp "$project_root/.totp-smoke.XXXXXX.qml")
    cat > "$smoke_entry" <<'QML'
import QtQuick
import Quickshell
Scope {
    Loader { source: "tests/security/totp-smoke.qml" }
}
QML
    smoke_output=$(PATH="$sandbox_dir/bin:$PATH" QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$sandbox_dir/runtime" \
        timeout 20 qs -p "$smoke_entry" 2>&1) || {
        printf '%s\n' "$smoke_output" >&2
        exit 1
    }
    printf '%s\n' "$smoke_output"
    [[ $smoke_output == *'PASS: QML inline add/edit'* && $smoke_output != *'TOTP SMOKE FAIL:'* ]]
    if [[ ${2:-} == --native-imports ]]; then
        # Compile the complete bar with its Wayland backend, without creating it.
        cat > "$smoke_entry" <<'QML'
import QtQuick
import Quickshell
import "modules/system/totp"
import "bar"
import "services"
Scope {
    id: root
    property int step: 0
    Component { Bar {} }
    Component { id: content; Item { implicitWidth: 320; implicitHeight: 200 } }
    PanelWindow {
        id: probeWindow
        visible: false
        screen: Quickshell.screens[0]
        Totp { id: probeIcon; window: probeWindow }
    }
    TooltipWindow { id: tooltipWindow; screen: probeWindow.screen }
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            if (root.step === 0) {
                TooltipService.togglePin(320, content, probeIcon, false, probeWindow.screen)
                TooltipService.hide()
            } else if (root.step === 3) {
                if (probeIcon.tooltipScreen !== probeWindow.screen || !tooltipWindow.visible || !TooltipService.pinned) {
                    console.error("FAIL: native pinned tooltip or monitor")
                    Qt.quit()
                    return
                }
                console.log("PASS: tooltip source resolves the current monitor")
                TooltipService.togglePin(320, content, probeIcon, false, probeWindow.screen)
                TooltipService.hide()
            } else if (root.step === 6) {
                if (!tooltipWindow.visible && !TooltipService.pinned)
                    console.log("PASS: native tooltip opens, pins, and closes")
                else console.error("FAIL: native tooltip did not close")
                Qt.quit()
            }
            root.step++
        }
    }
}
QML
        native_output=$(PATH="$sandbox_dir/bin:$PATH" QT_QPA_PLATFORM=wayland timeout 10 qs -p "$smoke_entry" 2>&1) || {
            printf '%s\n' "$native_output" >&2
            exit 1
        }
        printf '%s\n' "$native_output"
        [[ $native_output == *'Configuration Loaded'* && $native_output == *'PASS: tooltip source resolves the current monitor'* \
            && $native_output == *'PASS: native tooltip opens, pins, and closes'* \
            && $native_output != *'Failed to load configuration'* && $native_output != *'FAIL:'* \
            && $native_output != *'Binding loop detected'* ]]
        printf 'PASS: complete bar compiles with the native Wayland backend\n'
    fi
fi
