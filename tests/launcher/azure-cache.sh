#!/usr/bin/env bash
# Synthetic cache and Podman responses; never start containers or authenticate.
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-azure-cache.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/cache" "$fixture/helper source" "$fixture/providers/web" "$fixture/providers/_common"
cp "$repo_dir/src/services/launcher/providers/web/azure.sh" "$fixture/providers/web/azure.sh"
export AZURE_CACHE_TEST_DIR="$fixture" XDG_CACHE_HOME="$fixture/cache" PATH="$fixture/bin:$PATH"
export AZURE_PICKER_CONTAINER=fixture-container AZURE_PICKER_IMAGE=fixture-image
export AZURE_PICKER_SOURCE="$fixture/helper source" AZURE_PICKER_VOLUME=fixture-volume
export AZURE_PICKER_SCRIPT=/fixture/scripts/list-subs.sh AZURE_PICKER_ENV_FILE="$fixture/fixture.env"
touch "$AZURE_PICKER_ENV_FILE"
cat > "$fixture/bin/podman" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
jq -cn --args '$ARGS.positional' -- "$@" >> "$AZURE_CACHE_TEST_DIR/commands"
case $1 in
    container)
        case ${AZURE_TEST_STATE:-running} in
            running) printf 'true\n' ;;
            stopped) printf 'false\n' ;;
            missing) exit 1 ;;
        esac ;;
    run|start) printf 'fixture-container\n' ;;
    exec)
        case ${AZURE_TEST_RESPONSE:-valid} in
            error) exit 5 ;;
            malformed) printf '[not JSON]\n' ;;
            invalid) printf '[{"name":"Invalid","id":1}]\n' ;;
            empty) printf '[]\n' ;;
            valid) printf 'Checking dependencies... OK\r\nNot requesting login\r\n[
{"name":"Alpha & <test>","id":"sub-a","tenantId":"tenant-a"},
{"name":"Beta","id":"sub-b","tenantId":null}]\r\n' ;;
        esac ;;
    *) exit 9 ;;
esac
BASH
cat > "$fixture/providers/_common/handle.sh" <<'BASH'
#!/usr/bin/env bash
cp -- "$1" "$AZURE_CACHE_TEST_DIR/picked.json"
BASH
chmod +x "$fixture/bin/podman"
provider="$fixture/providers/web/azure.sh"
cache="$fixture/cache/azure_${USER}"
rebuild() { : > "$fixture/commands"; bash "$provider" --rebuild-cache "$@" > "$fixture/output" 2> "$fixture/error"; }
rebuild --pick
jq -e '.items[0].title == "Alpha & <test>" and .items[0].result == "https://portal.azure.com/#@tenant-a/resource/subscriptions/sub-a/resources"
    and .items[1].result == "https://portal.azure.com/#resource/subscriptions/sub-b/resources" and .sort' "$cache" >/dev/null
cmp "$cache" "$fixture/picked.json"
[[ $(stat -c %a "$cache") == 600 ]]
jq -se 'length == 2 and .[1] == ["exec","fixture-container","/fixture/scripts/list-subs.sh"]' "$fixture/commands" >/dev/null
printf 'PASS: Azure rebuild reuses the configured container, validates subscriptions and picks the new private cache\n'

AZURE_TEST_STATE=stopped rebuild
jq -se '.[1] == ["start","fixture-container"] and .[2][0] == "exec"' "$fixture/commands" >/dev/null
AZURE_TEST_STATE=missing rebuild
jq -se --arg source "$AZURE_PICKER_SOURCE:/workspaces/scripts/azure/portkey" --arg env "$AZURE_PICKER_ENV_FILE" '
    .[1][0] == "run" and (.[1] | index("--replace")) == null
    and (.[1] | index($source)) != null and (.[1] | index($env)) != null
    and (.[1] | index("fixture-volume:/home/vscode/.azure")) != null
    and (.[1] | index("fixture-image")) != null and .[2] == ["exec","fixture-container","/fixture/scripts/list-subs.sh"]
' "$fixture/commands" >/dev/null
printf 'PASS: Azure starts stopped containers and creates missing containers with literal configured paths\n'

cp "$cache" "$fixture/previous.json"
for response in error malformed invalid; do
    if AZURE_TEST_RESPONSE="$response" rebuild; then printf 'Azure failure was accepted: %s\n' "$response" >&2; exit 1; fi
    cmp "$cache" "$fixture/previous.json"
    [[ $(find "$fixture/cache" -maxdepth 1 -type f | wc -l) == 1 ]]
done
AZURE_TEST_RESPONSE=empty rebuild
jq -e '.items == []' "$cache" >/dev/null
printf 'PASS: failed Azure rebuilds preserve the previous cache, clean temporary files and accept empty subscription lists\n'

: > "$fixture/commands"
env -u AZURE_PICKER_CONTAINER -u AZURE_PICKER_IMAGE -u AZURE_PICKER_SCRIPT -u AZURE_PICKER_VOLUME -u AZURE_PICKER_ENV_FILE \
    bash "$provider" --rebuild-cache > "$fixture/output" 2> "$fixture/error"
jq -se '.[1] == ["exec","portkey","/workspaces/scripts/azure/portkey/scripts/list-subs.sh"]' "$fixture/commands" >/dev/null
printf 'PASS: Azure defaults match the local Portkey container and helper contract\n'
