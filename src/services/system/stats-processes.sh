#!/usr/bin/env bash
# Full process snapshots; resolve network PIDs from connection socket ownership.
set -euo pipefail
shopt -s nullglob
resource=${1:-}
[[ $# -gt 0 ]] && shift
proc_root=/proc
bandwhich=bandwhich
fail() { jq -n --arg error "$1" '{processes: [], error: $error}'; exit 1; }
while (($#)); do
    case $1 in
        --proc|--bandwhich)
            (($# >= 2)) || fail 'Missing collector option value.'
            if [[ $1 == --proc ]]; then proc_root=$2; else bandwhich=$2; fi
            shift 2 ;;
        *) fail 'Unknown collector option.' ;;
    esac
done
[[ $resource == cpu || $resource == memory || $resource == network ]] || fail 'Unknown Stats resource.'
[[ -d $proc_root && -r $proc_root ]] || fail 'Process information is unavailable.'
umask 077
work_dir=$(mktemp -d)
collector_pid=''
cleanup() {
    if [[ -n $collector_pid ]]; then kill "$collector_pid" 2>/dev/null || true; wait "$collector_pid" 2>/dev/null || true; fi
    rm -rf -- "$work_dir"
}
trap cleanup EXIT
trap 'exit 0' TERM INT
page_size=$(getconf PAGESIZE)
clock_ticks=$(getconf CLK_TCK)
read -r timestamp _ < /proc/uptime
declare -A names parents owners sockets sent received traffic_names traffic_pids
pid_paths=()
: > "$work_dir/rows"
: > "$work_dir/applications"
read_processes() {
for directory in "$proc_root"/[0-9]*; do
    pid=${directory##*/}
    [[ $pid =~ ^[0-9]+$ && -r $directory/stat ]] || continue
    stat=$(<"$directory/stat") 2>/dev/null || continue
    read -ra fields <<< "${stat##*) }"
    ((${#fields[@]} >= 22)) || continue
    [[ ${fields[1]} =~ ^[0-9]+$ && ${fields[11]} =~ ^[0-9]+$ && ${fields[12]} =~ ^[0-9]+$ && ${fields[19]} =~ ^[0-9]+$ && ${fields[21]} =~ ^-?[0-9]+$ ]] || continue
    name=${stat%)*}; name=${name#*(}
    names[$pid]=$name
    parents[$pid]=${fields[1]}
    [[ ! -d $directory/fd ]] || pid_paths+=("$directory/fd")
    if [[ $resource != network ]]; then
        rss=${fields[21]}; ((rss >= 0)) || rss=0
        printf '%s\0%s\0%s\0%s\0%s\0' "$pid" "$name" "$((fields[11] + fields[12]))" "${fields[19]}" "$((rss * page_size))" >> "$work_dir/rows"
    fi
done
return 0
}
[[ $resource == network ]] || read_processes

# Stop at session launchers, shells and terminals rather than folding independent
# applications into the compositor or terminal that launched them.
application_boundary() {
    case ${1,,} in
        systemd|init|hyprland|sway|wayfire|kwin*|plasmashell|gnome-shell|niri|labwc|river|weston) return 0 ;;
        bash|zsh|sh|dash|fish|nu|sudo|doas|env|timeout|setsid) return 0 ;;
        ghostty|kitty|alacritty|foot|wezterm*|konsole|gnome-terminal*|xfce4-terminal|xterm) return 0 ;;
        flatpak|bwrap|qs|quickshell) return 0 ;;
        *) return 1 ;;
    esac
}
# Read only process-role flags; command lines are never included in the report.
read_process_role() {
    local pid=$1 root=$2 type='' utility='' argument
    local -a arguments=()
    role=''
    if [[ $pid == "$root" ]]; then role='Main process'; return; fi
    if [[ -r $proc_root/$pid/cmdline ]]; then
        mapfile -d '' -t arguments 2>/dev/null < "$proc_root/$pid/cmdline" || arguments=()
    fi
    for argument in "${arguments[@]}"; do
        case $argument in
            --type=*) type=${argument#--type=} ;;
            --utility-sub-type=*) utility=${argument#--utility-sub-type=} ;;
        esac
    done
    case $type in
        renderer) role='Renderer' ;;
        gpu-process) role='GPU process' ;;
        zygote) role='Zygote' ;;
        utility)
            case $utility in
                *NetworkService) role='Network service' ;;
                *AudioService) role='Audio service' ;;
                *) role='Utility process' ;;
            esac ;;
        *) role='' ;;
    esac
}

read_applications() {
    local pid current parent root steps
    for pid in "${!names[@]}"; do
        current=$pid; root=$pid; steps=0
        while ((steps++ < 64)); do
            parent=${parents[$current]:-0}
            [[ $parent -gt 1 && -n ${names[$parent]:-} ]] || break
            application_boundary "${names[$parent]}" && break
            [[ $parent != "$pid" ]] || break
            root=$parent; current=$parent
        done
        read_process_role "$pid" "$root"
        printf '%s\0%s\0%s\0%s\0' "$pid" "$root" "${names[$root]}" "$role" >> "$work_dir/applications"
    done
}

# Normalize displayed IP addresses to the same hex representation as /proc/net.
address_key() {
    local address=$1 octets left right group missing index word
    local -a groups=() tail=()
    address=${address#[}; address=${address%]}
    if [[ $address != *:* ]]; then
        IFS=. read -ra octets <<< "$address"
        ((${#octets[@]} == 4)) || return 1
        printf -v address_hex '%02x%02x%02x%02x' "${octets[@]}"
        return
    fi
    if [[ $address == *.* ]]; then
        word=${address##*:}
        IFS=. read -ra octets <<< "$word"
        printf -v word '%02x%02x:%02x%02x' "${octets[@]}"
        address=${address%:*}:$word
    fi
    if [[ $address == *::* ]]; then
        left=${address%%::*}; right=${address#*::}
        [[ -z $left ]] || IFS=: read -ra groups <<< "$left"
        [[ -z $right ]] || IFS=: read -ra tail <<< "$right"
        missing=$((8 - ${#groups[@]} - ${#tail[@]}))
        ((missing >= 1)) || return 1
        for ((index=0; index<missing; index++)); do groups+=(0); done
        groups+=("${tail[@]}")
    else
        IFS=: read -ra groups <<< "$address"
    fi
    ((${#groups[@]} == 8)) || return 1
    address_hex=''
    for group in "${groups[@]}"; do
        [[ $group =~ ^[[:xdigit:]]{1,4}$ ]] || return 1
        printf -v word '%04x' "$((16#$group))"
        address_hex+=$word
    done
}

if [[ $resource == network ]]; then
    command -v "$bandwhich" >/dev/null || fail 'bandwhich is unavailable.'
    timeout 2.2 "$bandwhich" --raw --connections --no-resolve > "$work_dir/traffic" 2> "$work_dir/error" &
    collector_pid=$!
    status=0; wait "$collector_pid" || status=$?
    collector_pid=''
    if ((status != 0 && status != 124)) && ! grep -q '^Refreshing:' "$work_dir/traffic"; then
        error=$(<"$work_dir/error")
        fail "${error:-Network process sampling failed.}"
    fi
    read_processes
    if ((${#pid_paths[@]})); then
        while IFS=$'\t' read -r fd target; do
            pid=${fd%/fd/*}; pid=${pid##*/}
            inode=${target#socket:[}; inode=${inode%]}
            [[ $inode =~ ^[0-9]+$ ]] || continue
            existing=${owners[$inode]:-}
            [[ " $existing " == *" $pid "* ]] || owners[$inode]="${existing:+$existing }$pid"
        done < <(find "${pid_paths[@]}" -maxdepth 1 -type l -lname 'socket:*' -printf '%p\t%l\n' 2>/dev/null)
    fi
    for protocol in tcp udp; do
        for family in '' 6; do
            [[ -r $proc_root/net/$protocol$family ]] || continue
            while read -ra fields; do
                ((${#fields[@]} >= 10)) || continue
                inode=${fields[9]}
                [[ -n ${owners[$inode]:-} ]] || continue
                local_port=${fields[1]#*:}; remote_port=${fields[2]#*:}; remote=${fields[2]%:*}
                [[ $local_port =~ ^[[:xdigit:]]+$ && $remote_port =~ ^[[:xdigit:]]+$ ]] || continue
                # Kernel socket addresses use host byte order in each 32-bit word.
                address_hex=''
                for ((index=0; index<${#remote}; index+=8)); do
                    word=${remote:index:8}
                    address_hex+=${word:6:2}${word:4:2}${word:2:2}${word:0:2}
                done
                key="$protocol|$((16#$local_port))|${address_hex,,}|$((16#$remote_port))"
                existing=${sockets[$key]:-}
                for pid in ${owners[$inode]}; do
                    [[ " $existing " == *" $pid "* ]] || existing="${existing:+$existing }$pid"
                done
                sockets[$key]=$existing
            done < "$proc_root/net/$protocol$family"
        done
    done
    pattern='^connection: <[0-9]+> <[^>]+>:([0-9]+) => (.+):([0-9]+) \((tcp|udp)\) up/down Bps: ([0-9]+)/([0-9]+) process: "(.*)"$'
    while IFS= read -r line; do
        if [[ $line == 'Refreshing:' ]]; then sent=(); received=(); traffic_names=(); traffic_pids=(); continue; fi
        [[ $line =~ $pattern ]] || continue
        port=${BASH_REMATCH[1]}; remote=${BASH_REMATCH[2]}; remote_port=${BASH_REMATCH[3]}
        protocol=${BASH_REMATCH[4]}; up=${BASH_REMATCH[5]}; down=${BASH_REMATCH[6]}; program=${BASH_REMATCH[7]}
        address_key "$remote" || continue
        candidates=${sockets["$protocol|$port|$address_hex|$remote_port"]:-}
        if [[ -z $candidates && $protocol == udp ]]; then
            candidates="${sockets["udp|$port|00000000|0"]:-} ${sockets["udp|$port|00000000000000000000000000000000|0"]:-}"
        fi
        read -ra pids <<< "$candidates"
        pid=0
        # Shared sockets or disappeared owners must never produce a guessed PID.
        if ((${#pids[@]} == 1)); then pid=${pids[0]}; fi
        key=$pid
        ((pid > 0)) || key="unknown:$program"
        traffic_pids[$key]=$pid
        traffic_names[$key]=${names[$pid]:-$program}
        sent[$key]=$((${sent[$key]:-0} + up))
        received[$key]=$((${received[$key]:-0} + down))
    done < "$work_dir/traffic"
    for key in "${!sent[@]}"; do
        printf '%s\0%s\0%s\0%s\0' "${traffic_pids[$key]}" "${traffic_names[$key]}" "${sent[$key]}" "${received[$key]}" >> "$work_dir/rows"
    done
fi
read_applications
jq -Rs 'split("\u0000")[:-1] as $fields |
    [range(0; $fields | length; 4) as $i |
        {key: $fields[$i], value: {pid: ($fields[$i+1] | tonumber), name: $fields[$i+2], role: $fields[$i+3]}}] | from_entries' \
    "$work_dir/applications" > "$work_dir/application-map.json"
jq -Rs --slurpfile applications "$work_dir/application-map.json" --arg resource "$resource" --argjson timestamp "$timestamp" --argjson clockTicks "$clock_ticks" '
    split("\u0000")[:-1] as $fields |
    {timestamp: $timestamp, clockTicks: $clockTicks, error: "", processes:
        [range(0; $fields | length; if $resource == "network" then 4 else 5 end) as $i |
            {pid: ($fields[$i] | tonumber), name: $fields[$i+1],
                appPid: ($applications[0][$fields[$i]].pid // ($fields[$i] | tonumber)),
                appName: ($applications[0][$fields[$i]].name // $fields[$i+1]),
                role: ($applications[0][$fields[$i]].role // "")} +
            if $resource == "network" then {up: ($fields[$i+2] | tonumber), down: ($fields[$i+3] | tonumber)}
            else {ticks: ($fields[$i+2] | tonumber), start: $fields[$i+3], memory: ($fields[$i+4] | tonumber)} end]}
' "$work_dir/rows"
