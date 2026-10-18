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
        # Validate and decode in one process; the marker also catches jq failure.
        mapfile -d '' -t fallback_argv < <(jq -j '
            if type=="array" and length>0 and all(.[];type=="string" and (contains("\u0000")|not))
                and (.[0]|length>0 and (startswith("-")|not))
            then ("ok", .[]) | ., "\u0000" else error("Invalid fallback argv") end' <<< "$fallback")
        [[ ${#fallback_argv[@]} -gt 1 && ${fallback_argv[0]} == ok ]] || exit 2
        fallback_argv=("${fallback_argv[@]:1}")
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
        # Extract routing checks together; only the selected argv is launched.
        mapfile -d '' -t fields < <(jq -j '
            def word: type=="string" and (contains("\u0000")|not);
            if (.argv|type=="array" and length>0 and all(.[];word)
                and (.[0]|length>0 and (startswith("-")|not)))
                and ((.onlyWhenRunning // "")|word)
                and ((.applicationName // .argv[0])|word)
            then ["ok", .argv[0], (.application==true|tostring),
                (.applicationAvailable==false|tostring), (.applicationName // .argv[0]), (.onlyWhenRunning // "")]
                | .[] | ., "\u0000"
            else error("Invalid dispatch request") end' <<< "$request")
        [[ ${#fields[@]} == 6 && ${fields[0]} == ok ]] || exit 2
        executable=${fields[1]} missing='' choice=primary process=${fields[5]}
        if [[ ${fields[2]} == true ]] \
            && { [[ ${fields[3]} == true ]] || ! command -v "$executable" >/dev/null; }; then
            missing=${fields[4]} choice=missing process=''
        fi
        if [[ -n $process ]]; then
            [[ $process =~ ^[A-Za-z0-9_.+-]+$ ]] || exit 2
            process_pattern=${process//./\\.}; process_pattern=${process_pattern//+/\\+}
            if ! pgrep -u "$UID" -x -- "$process_pattern" >/dev/null; then choice=fallback; fi
        fi
        # Prepare the selected request and response in one pass, preserving argv.
        mapfile -d '' -t selected < <(jq -j --arg choice "$choice" --arg missing "$missing" '
            if $choice=="missing" then
                .argv=.missingArgv | .browser=.missingBrowser | .workspace=0 | .onlyWhenRunning="" | .ruleNames=(.missingRuleNames // [])
            elif $choice=="fallback" then
                .argv=.fallbackArgv | .browser=.fallbackBrowser | .workspace=(.fallbackWorkspace // 0) | .ruleNames=(.fallbackRuleNames // [])
            else . end
            | if (.argv|type=="array" and length>0 and all(.[];type=="string" and (contains("\u0000")|not))
                and (.[0]|length>0 and (startswith("-")|not))) then
                ["ok", .argv[0], tojson,
                    ({browser:(.browser // ""),missingApplication:$missing,ruleNames:(.ruleNames // [])}|tojson)]
                | .[] | ., "\u0000"
            else error("Invalid selected argv") end' <<< "$request")
        [[ ${#selected[@]} == 4 && ${selected[0]} == ok ]] || exit 2
        command -v "${selected[1]}" >/dev/null || exit 1
        printf '%s\n' "${selected[3]}"
        (printf '%s\n' "${selected[2]}" | nohup bash "${BASH_SOURCE[0]}" launch) >/dev/null 2>&1 &
        ;;
    launch)
        IFS= read -r request
        mapfile -d '' -t fields < <(jq -j '
            if (.argv|type=="array" and length>0 and all(.[];type=="string" and (contains("\u0000")|not))
                and (.[0]|length>0 and (startswith("-")|not))) then
                ["ok", ((.workspace // 0)|tostring), (.focusWorkspace==true|tostring)] + .argv
                | .[] | ., "\u0000"
            else error("Invalid launch argv") end' <<< "$request")
        [[ ${#fields[@]} -ge 4 && ${fields[0]} == ok ]] || exit 2
        workspace=${fields[1]}
        if [[ ${fields[2]} == true && $workspace =~ ^[1-9][0-9]{0,3}$ \
            && $(cat "${XDG_RUNTIME_DIR:-/tmp}/hypr-autofocus" 2>/dev/null || true) != 0 ]]; then
            hyprctl dispatch "hl.dsp.focus({ workspace = $workspace})" >/dev/null 2>&1 || true
        fi
        exec "${fields[@]:3}"
        ;;
    *) exit 2 ;;
esac
