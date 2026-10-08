#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
helper="$project_root/src/services/system/stats-processes.sh"
test_dir=$(mktemp -d /tmp/quickshell-stats-helper.XXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
proc_root="$test_dir/proc space"
mkdir -p "$proc_root/net" "$test_dir/bin"
for protocol in tcp tcp6 udp udp6; do printf 'header\n' > "$proc_root/net/$protocol"; done
process() {
    local pid=$1 name=$2 ticks=$3 pages=${4:-1} parent=${5:-0}
    local -a fields=()
    for ((index=0; index<22; index++)); do fields+=(0); done
    fields[0]=S; fields[1]=$parent; fields[11]=$ticks; fields[12]=2; fields[19]=99; fields[21]=$pages
    mkdir -p "$proc_root/$pid/fd"
    printf '%s (%s) %s\n' "$pid" "$name" "${fields[*]}" > "$proc_root/$pid/stat"
}
socket() {
    local pid=$1 inode=$2 port=$3 remote=${4:-0100007F:01BB} protocol=${5:-tcp}
    ln -s "socket:[$inode]" "$proc_root/$pid/fd/$inode"
    printf '0: 0100007F:%04X %s 01 0:0 0:0 0 1000 0 %s\n' "$port" "$remote" "$inode" >> "$proc_root/net/$protocol"
}
for ((pid=1; pid<=25; pid++)); do process "$pid" app "$pid" "$pid"; done
process 1 'name ) with spaces' 1
mkdir "$proc_root/40" # Exited before the stat read.
result=$(bash "$helper" memory --proc "$proc_root")
jq -e --argjson pages "$(getconf PAGESIZE)" '.error == "" and (.processes | length) == 25
    and any(.processes[]; .pid == 1 and .name == "name ) with spaces" and .ticks == 3 and .memory == $pages)' <<< "$result" >/dev/null
cat > "$test_dir/bin/bandwhich" <<'MOCK'
#!/usr/bin/env bash
cat "$STATS_TEST_TRAFFIC"
MOCK
chmod +x "$test_dir/bin/bandwhich"
export STATS_TEST_TRAFFIC="$test_dir/traffic"
network() { bash "$helper" network --proc "$proc_root" --bandwhich "$test_dir/bin/bandwhich"; }
process 10 browser 1
socket 10 99 1234
cat > "$STATS_TEST_TRAFFIC" <<'TRAFFIC'
Refreshing:
connection: <1> <eth0>:1234 => 127.0.0.1:443 (tcp) up/down Bps: 900/900 process: "browser"
Refreshing:
connection: <2> <eth0>:1234 => 127.0.0.1:443 (tcp) up/down Bps: 20/50 process: "browser"
TRAFFIC
result=$(network)
jq -e '.processes == [{pid:10,name:"browser",appPid:10,appName:"browser",role:"Main process",up:20,down:50}]' <<< "$result" >/dev/null
printf 'Refreshing:\n<NO TRAFFIC>\n' >> "$STATS_TEST_TRAFFIC"
result=$(network)
jq -e '.processes == []' <<< "$result" >/dev/null
# Shared socket descriptors cannot identify the single process responsible.
ln -s 'socket:[99]' "$proc_root/11/fd/99"
cat > "$STATS_TEST_TRAFFIC" <<'TRAFFIC'
Refreshing:
connection: <1> <eth0>:1234 => 127.0.0.1:443 (tcp) up/down Bps: 20/50 process: "browser"
TRAFFIC
result=$(network)
jq -e '.processes[0].pid == 0 and .processes[0].down == 50' <<< "$result" >/dev/null
rm "$proc_root/11/fd/99"
socket 10 100 1235 00000000:0000 udp
cat > "$STATS_TEST_TRAFFIC" <<'TRAFFIC'
Refreshing:
connection: <1> <eth0>:1235 => 127.0.0.1:53 (udp) up/down Bps: 20/50 process: "browser"
connection: <1> <eth0>:1235 => 127.0.0.2:53 (udp) up/down Bps: 30/60 process: "browser"
TRAFFIC
result=$(network)
jq -e '.processes == [{pid:10,name:"browser",appPid:10,appName:"browser",role:"Main process",up:50,down:110}]' <<< "$result" >/dev/null
socket 10 101 1236 00000000000000000000000001000000:0035 tcp6
cat > "$STATS_TEST_TRAFFIC" <<'TRAFFIC'
Refreshing:
connection: <1> <eth0>:1236 => ::1:53 (tcp) up/down Bps: 5/6 process: "browser"
TRAFFIC
result=$(network)
jq -e '.processes == [{pid:10,name:"browser",appPid:10,appName:"browser",role:"Main process",up:5,down:6}]' <<< "$result" >/dev/null
# Helpers inherit their app identity through the process tree, including roots
# which have no network traffic. Shells and the compositor remain boundaries.
process 50 Hyprland 1
process 51 Discord 1 1 50
process 52 'Discord helper' 1 1 51
process 53 qutebrowser 1 1 50
process 54 QtWebEngineProc 1 1 53
process 55 QtWebEngineProc 1 1 54
process 56 zsh 1 1 50
process 57 editor 1 1 56
printf '%s\0' /usr/bin/Discord --type=renderer > "$proc_root/52/cmdline"
printf '%s\0' /usr/lib/QtWebEngineProcess --type=zygote > "$proc_root/54/cmdline"
printf '%s\0' /usr/lib/QtWebEngineProcess --type=renderer > "$proc_root/55/cmdline"
process 58 QtWebEngineProc 1 1 53
printf '%s\0' /usr/lib/QtWebEngineProcess --type=gpu-process > "$proc_root/58/cmdline"
process 59 QtWebEngineProc 1 1 53
printf '%s\0' /usr/lib/QtWebEngineProcess --type=utility --utility-sub-type=network.mojom.NetworkService > "$proc_root/59/cmdline"
process 60 QtWebEngineProc 1 1 53
printf '%s\0' /usr/lib/QtWebEngineProcess --type=utility --utility-sub-type=audio.mojom.AudioService > "$proc_root/60/cmdline"
process 61 helper 1 1 53
result=$(bash "$helper" memory --proc "$proc_root")
jq -e 'any(.processes[]; .pid == 52 and .appPid == 51 and .appName == "Discord")
    and any(.processes[]; .pid == 55 and .appPid == 53 and .appName == "qutebrowser")
    and any(.processes[]; .pid == 57 and .appPid == 57 and .appName == "editor")' <<< "$result" >/dev/null
jq -e 'any(.processes[]; .pid == 51 and .role == "Main process")
    and any(.processes[]; .pid == 52 and .role == "Renderer")
    and any(.processes[]; .pid == 54 and .role == "Zygote")
    and any(.processes[]; .pid == 58 and .role == "GPU process")
    and any(.processes[]; .pid == 59 and .role == "Network service")
    and any(.processes[]; .pid == 60 and .role == "Audio service")
    and any(.processes[]; .pid == 61 and .role == "")' <<< "$result" >/dev/null
socket 55 155 1255
cat > "$STATS_TEST_TRAFFIC" <<'TRAFFIC'
Refreshing:
connection: <1> <eth0>:1255 => 127.0.0.1:443 (tcp) up/down Bps: 5/6 process: "QtWebEngineProc"
TRAFFIC
result=$(network)
jq -e '.processes[0].pid == 55 and .processes[0].appPid == 53 and .processes[0].appName == "qutebrowser" and .processes[0].role == "Renderer"' <<< "$result" >/dev/null
printf '#!/usr/bin/env bash\nprintf "capture failed" >&2\nexit 1\n' > "$test_dir/bin/bandwhich"
status=0
result=$(network) || status=$?
[[ $status == 1 ]]
jq -e '.error == "capture failed"' <<< "$result" >/dev/null
printf 'PASS: Bash Stats snapshots, full lists, unusual names, IPv4/IPv6 sockets, UDP, last traffic frame, ambiguous PIDs and collector errors\n'
