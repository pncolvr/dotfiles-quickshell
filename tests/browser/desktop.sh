#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
export BROWSER_TEST_QS
BROWSER_TEST_QS=$(command -v qs)
fixture=$(mktemp -d /tmp/quickshell-browser-desktop.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/home with space"
mkdir -m700 "$fixture/runtime"
cat > "$fixture/bin/qs" <<'MOCK'
#!/usr/bin/env bash
if [[ ${*: -1} == */desktop/Discovery.qml ]]; then exec "$BROWSER_TEST_QS" "$@"; fi
printf '%s\n' "${BROWSER_MOCK_RESPONSE:-false}"
MOCK
cat > "$fixture/bin/browser" <<'MOCK'
#!/usr/bin/env bash
jq -nc --args '$ARGS.positional' -- "$@" >> "$BROWSER_TEST_ACTIONS"
MOCK
cat > "$fixture/bin/curl" <<'MOCK'
#!/usr/bin/env bash
printf 'https://resolved.test/path'
MOCK
chmod +x "$fixture/bin/"*
export HOME="$fixture/home with space" XDG_DATA_HOME="$fixture/data"
export PATH="$HOME/.local/bin:$fixture/bin:$PATH"
export BROWSER_TEST_ACTIONS="$fixture/actions"
export XDG_RUNTIME_DIR="$fixture/runtime"
bash "$repo/integrations/browser/install.sh" browser --profile=personal > "$fixture/install.log"
[[ -x $HOME/.local/bin/quickshell-browser && -f $XDG_DATA_HOME/applications/quickshell-browser.desktop ]]
! rg -q '@LAUNCHER@' "$XDG_DATA_HOME/applications/quickshell-browser.desktop"
if command -v desktop-file-validate >/dev/null; then desktop-file-validate "$XDG_DATA_HOME/applications/quickshell-browser.desktop"; fi
mkdir -p "$fixture/config"
env -u BROWSER XDG_CONFIG_HOME="$fixture/config" XDG_CURRENT_DESKTOP=Hyprland \
    xdg-settings set default-web-browser quickshell-browser.desktop
[[ $(env -u BROWSER XDG_CONFIG_HOME="$fixture/config" XDG_CURRENT_DESKTOP=Hyprland \
    xdg-settings check default-web-browser quickshell-browser.desktop) == yes ]]
env -u BROWSER XDG_CONFIG_HOME="$fixture/config" XDG_CURRENT_DESKTOP=Hyprland DISPLAY=:999 \
    xdg-open 'https://xdg-open.test/path?literal=$value&other=two'
jq -se 'length==1 and .[0]==["--profile=personal","https://xdg-open.test/path?literal=$value&other=two"]' "$fixture/actions" >/dev/null
: > "$fixture/actions"
"$HOME/.local/bin/quickshell-browser" 'https://example.test/a?x=$literal' '/tmp/Local page.html'
jq -se 'length==2 and all(.[];.[0]=="--profile=personal") and any(.[1]=="/tmp/Local page.html")' "$fixture/actions" >/dev/null
: > "$fixture/actions"
"$HOME/.local/bin/quickshell-browser" www.google.com 'search with spaces; $(literal)' --new-window
jq -se 'length==3 and any(.[-1]=="www.google.com") and any(.[-1]=="search with spaces; $(literal)") and any(.[-2:]==["--","--new-window"])' "$fixture/actions" >/dev/null
: > "$fixture/actions"
BROWSER_MOCK_RESPONSE=true "$HOME/.local/bin/quickshell-browser" https://handled.test/
[[ ! -s $fixture/actions ]]
if bash "$repo/integrations/browser/install.sh" xdg-open > /dev/null 2>&1; then exit 1; fi
if QS_BROWSER_ROUTER_ACTIVE=1 "$HOME/.local/bin/quickshell-browser" https://loop.test/ > /dev/null 2>&1; then exit 1; fi
resolved=$(printf '%s\n' '{"url":"https://short.fixture.test/test","action":"redirect"}' | bash "$repo/src/services/browser/browser.sh" resolve)
jq -e '.url=="https://resolved.test/path"' <<< "$resolved" >/dev/null
resolved=$(printf '%s\n' '{"url":"https://wrapper.fixture.test/link?destination=https%3A%2F%2Fexample.test%2Fa%3Fx%3D1%26y%3D2","action":"query","parameter":"destination"}' | bash "$repo/src/services/browser/browser.sh" resolve)
jq -e '.url=="https://example.test/a?x=1&y=2"' <<< "$resolved" >/dev/null
cat > "$fixture/bin/pgrep" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "${@: -1}" > "$XDG_RUNTIME_DIR/process-pattern"
[[ ${BROWSER_PROCESS_RUNNING:-1} == 1 ]]
MOCK
cat > "$fixture/bin/application" <<'MOCK'
#!/usr/bin/env bash
jq -nc --args '$ARGS.positional' -- "$@" >> "$BROWSER_TEST_ACTIONS"
MOCK
cat > "$fixture/bin/hyprctl" <<'MOCK'
#!/usr/bin/env bash
jq -nc --args '$ARGS.positional' -- "$@" >> "$XDG_RUNTIME_DIR/workspaces"
MOCK
chmod +x "$fixture/bin/pgrep" "$fixture/bin/application" "$fixture/bin/hyprctl"
: > "$fixture/actions"
request='{"argv":["application","fixture://open/123"],"fallbackArgv":["browser","https://application.fixture.test/item/123"],"onlyWhenRunning":"app.test+tool","browser":"application","fallbackBrowser":"default","workspace":9,"focusWorkspace":true}'
printf '%s\n' "$request" | bash "$repo/src/services/browser/browser.sh" dispatch > "$fixture/dispatched"
for ((attempt=0;attempt<200;attempt++)); do [[ -s $fixture/actions && -s $fixture/runtime/workspaces ]] && break; sleep .01; done
jq -se '.[-1]==["fixture://open/123"]' "$fixture/actions" >/dev/null
jq -e '.browser=="application"' "$fixture/dispatched" >/dev/null
[[ $(cat "$fixture/runtime/process-pattern") == 'app\.test\+tool' ]]
jq -se '.[-1]==["dispatch","hl.dsp.focus({ workspace = 9})"]' "$fixture/runtime/workspaces" >/dev/null
printf 0 > "$fixture/runtime/hypr-autofocus"
: > "$fixture/runtime/workspaces"
: > "$fixture/actions"
printf '%s\n' "$request" | BROWSER_PROCESS_RUNNING=0 bash "$repo/src/services/browser/browser.sh" dispatch > "$fixture/dispatched"
for ((attempt=0;attempt<200;attempt++)); do [[ -s $fixture/actions ]] && break; sleep .01; done
jq -se '.[-1]==["https://application.fixture.test/item/123"]' "$fixture/actions" >/dev/null
jq -e '.browser=="default"' "$fixture/dispatched" >/dev/null
[[ ! -s $fixture/runtime/workspaces ]]
mkdir -p "$fixture/desktop-data/applications"
cat > "$fixture/desktop-data/applications/test-browser.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Test Browser
Exec=$fixture/bin/browser --original %U
Categories=Network;WebBrowser;
DESKTOP
cat > "$fixture/desktop-data/applications/not-browser.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Not A Browser
Exec=$fixture/bin/application %U
Categories=Utility;
DESKTOP
printf '1\n--profile=Personal Profile\n\n' | XDG_DATA_HOME="$fixture/desktop-data" XDG_DATA_DIRS="$fixture/desktop-data" \
    bash "$repo/integrations/browser/install.sh" > "$fixture/interactive.log"
rg -q 'Test Browser' "$fixture/interactive.log"
! rg -q 'Not A Browser' "$fixture/interactive.log"
: > "$fixture/actions"
"$HOME/.local/bin/quickshell-browser" https://interactive.test/
jq -se '.[-1]==["--original","--profile=Personal Profile","https://interactive.test/"]' "$fixture/actions" >/dev/null
: > "$fixture/actions"
missing_request=$(jq -nc --arg executable "$fixture/bin/uninstalled" '{application:true,applicationAvailable:true,applicationName:"Removed App",argv:[$executable,"https://missing.test/"],missingArgv:["browser","https://missing.test/"],missingBrowser:"default"}')
printf '%s\n' "$missing_request" | bash "$repo/src/services/browser/browser.sh" dispatch > "$fixture/dispatched"
for ((attempt=0;attempt<200;attempt++)); do [[ -s $fixture/actions ]] && break; sleep .01; done
jq -e '.browser=="default" and .missingApplication=="Removed App"' "$fixture/dispatched" >/dev/null
jq -se '.[-1]==["https://missing.test/"]' "$fixture/actions" >/dev/null
: > "$fixture/actions"
# A removed desktop entry must fall back even if its executable remains installed.
jq -c '.argv=["application","fixture://should-not-launch"] | .applicationAvailable=false' <<< "$missing_request" \
    | bash "$repo/src/services/browser/browser.sh" dispatch > "$fixture/dispatched"
for ((attempt=0;attempt<200;attempt++)); do [[ -s $fixture/actions ]] && break; sleep .01; done
jq -e '.missingApplication=="Removed App"' "$fixture/dispatched" >/dev/null
jq -se '.[-1]==["https://missing.test/"]' "$fixture/actions" >/dev/null
# Batched decoding must reject invalid argv before emitting an accepted response.
for invalid in '{"argv":[]}' '{"argv":["browser",null]}' '{"argv":["-browser"]}' '{"argv":["browser","bad\u0000argument"]}'; do
    if printf '%s\n' "$invalid" | bash "$repo/src/services/browser/browser.sh" dispatch > "$fixture/rejected" 2>/dev/null; then
        printf 'Invalid browser dispatch was accepted.\n' >&2; exit 1
    fi
    [[ ! -s $fixture/rejected ]]
done
printf 'PASS: interactive browser desktop discovery, literal profile arguments and unavailable-application fallback diagnostics\n'
printf 'PASS: desktop installation, literal fallback argv, IPC handoff, recursion guard and generic redirect/query actions\n'
printf 'PASS: configurable application dispatch, literal process matching, browser fallback and workspace autofocus toggle\n'
