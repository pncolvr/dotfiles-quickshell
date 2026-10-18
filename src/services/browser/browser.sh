#!/usr/bin/env bash
# Literal argv only. No shell evaluation or changes to desktop associations.
set -euo pipefail
mode=${1:-}
shift || true
case $mode in
    open)
        [[ ${QS_BROWSER_ROUTER_ACTIVE:-0} != 1 ]] || { printf 'Recursive browser routing refused.\n' >&2; exit 1; }
        [[ ${1:-} == --fallback && $# -ge 4 && ${3:-} == -- ]] || exit 2
        fallback=$2
        shift 3
        jq -e 'type=="array" and length>0 and all(.[];type=="string" and (contains("\u0000")|not)) and (.[0]|length>0 and (startswith("-")|not))' <<< "$fallback" >/dev/null || exit 2
        mapfile -d '' -t fallback_argv < <(jq -j '.[]|.,"\u0000"' <<< "$fallback")
        case ${fallback_argv[0]##*/} in xdg-open|quickshell-browser|default-browser.sh) printf 'Choose a concrete fallback browser.\n' >&2; exit 2;; esac
        repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
        for url in "$@"; do
            [[ $url =~ [^[:space:]] && ! $url =~ [[:cntrl:]] ]] || { printf 'Empty or invalid browser target.\n' >&2; exit 2; }
            response=$(timeout --kill-after=1 3 qs -p "$repo" ipc call browser open "$url" 2>/dev/null) || response=''
            if [[ $response != true ]]; then
                if [[ $url == -* ]]; then
                    QS_BROWSER_ROUTER_ACTIVE=1 "${fallback_argv[@]}" -- "$url" &
                else
                    QS_BROWSER_ROUTER_ACTIVE=1 "${fallback_argv[@]}" "$url" &
                fi
            fi
        done
        wait
        ;;
    resolve)
        IFS= read -r request
        url=$(jq -er '.url|select(type=="string" and length>0)' <<< "$request")
        action=$(jq -r '.action // "browser"' <<< "$request")
        case $action in
            redirect)
                resolved=$(curl --silent --fail --location --max-redirs 5 --connect-timeout 3 --max-time 10 \
                    --proto '=http,https' --proto-redir '=http,https' -o /dev/null -w '%{url_effective}' -- "$url") || resolved=''
                [[ -z $resolved ]] || url=$resolved
                ;;
            query)
                name=$(jq -er '.parameter|select(type=="string" and length>0)' <<< "$request")
                if [[ $url == *\?* ]]; then
                    query=${url#*\?}; query=${query%%\#*}
                    IFS='&' read -r -a parameters <<< "$query"
                    for parameter in "${parameters[@]}"; do
                        [[ ${parameter%%=*} == "$name" && $parameter == *=* ]] || continue
                        encoded=${parameter#*=}; decoded=''
                        while [[ -n $encoded ]]; do
                            if [[ $encoded =~ ^%([0-9A-Fa-f]{2}) ]]; then
                                [[ ${BASH_REMATCH[1]} != 00 ]] || exit 2
                                printf -v character '%b' "\\x${BASH_REMATCH[1]}"
                                decoded+=$character; encoded=${encoded:3}
                            else decoded+=${encoded:0:1}; encoded=${encoded:1}; fi
                        done
                        [[ $decoded == http://* || $decoded == https://* || $decoded == file:///* ]] && url=$decoded
                        break
                    done
                fi
                ;;
        esac
        jq -nc --arg url "$url" '{url:$url}'
        ;;
    dispatch)
        IFS= read -r request
        jq -e '.argv|type=="array" and length>0 and all(.[];type=="string" and (contains("\u0000")|not))' <<< "$request" >/dev/null
        missing=''
        executable=$(jq -er '.argv[0]|select(length>0 and (startswith("-")|not))' <<< "$request")
        if [[ $(jq -r '.application==true' <<< "$request") == true ]] \
            && { [[ $(jq -r '.applicationAvailable==false' <<< "$request") == true ]] || ! command -v "$executable" >/dev/null; }; then
            missing=$(jq -r '.applicationName // .argv[0]' <<< "$request")
            request=$(jq -c '.argv=.missingArgv | .browser=.missingBrowser | .workspace=0 | .onlyWhenRunning="" | .ruleNames=(.missingRuleNames // [])' <<< "$request")
            jq -e '.argv|type=="array" and length>0 and all(.[];type=="string" and (contains("\u0000")|not))' <<< "$request" >/dev/null
        fi
        process=$(jq -r '.onlyWhenRunning // ""' <<< "$request")
        if [[ -n $process ]]; then
            [[ $process =~ ^[A-Za-z0-9_.+-]+$ ]] || exit 2
            process_pattern=${process//./\\.}; process_pattern=${process_pattern//+/\\+}
            if ! pgrep -u "$(id -u)" -x -- "$process_pattern" >/dev/null; then
                request=$(jq -c '.argv=.fallbackArgv | .browser=.fallbackBrowser | .workspace=(.fallbackWorkspace // 0) | .ruleNames=(.fallbackRuleNames // [])' <<< "$request")
            fi
        fi
        executable=$(jq -er '.argv[0]|select(length>0 and (startswith("-")|not))' <<< "$request")
        command -v "$executable" >/dev/null || exit 1
        jq -nc --arg browser "$(jq -r '.browser // ""' <<< "$request")" --arg missing "$missing" \
            --argjson rules "$(jq -c '.ruleNames // []' <<< "$request")" '{browser:$browser,missingApplication:$missing,ruleNames:$rules}'
        (printf '%s\n' "$request" | nohup bash "${BASH_SOURCE[0]}" launch) >/dev/null 2>&1 &
        ;;
    launch)
        IFS= read -r request
        jq -e '.argv|type=="array" and length>0 and all(.[];type=="string" and (contains("\u0000")|not))' <<< "$request" >/dev/null
        mapfile -d '' -t argv < <(jq -j '.argv[]|.,"\u0000"' <<< "$request")
        workspace=$(jq -r '.workspace // 0' <<< "$request")
        if [[ $(jq -r '.focusWorkspace==true' <<< "$request") == true && $workspace =~ ^[1-9][0-9]{0,3}$ \
            && $(cat "${XDG_RUNTIME_DIR:-/tmp}/hypr-autofocus" 2>/dev/null || true) != 0 ]]; then
            hyprctl dispatch "hl.dsp.focus({ workspace = $workspace})" >/dev/null 2>&1 || true
        fi
        exec "${argv[@]}"
        ;;
    *) exit 2 ;;
esac
