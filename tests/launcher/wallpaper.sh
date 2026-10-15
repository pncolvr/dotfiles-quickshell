#!/usr/bin/env bash
# Preserve saved wallpaper choices without controlling the desktop or real mode manager.
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-wallpaper-test.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m 700 "$test_dir/runtime"
mkdir -p "$test_dir/bin" "$test_dir/src/services/launcher/providers/_common" "$test_dir/home/Pictures/wallpapers/nested"
export HOME="$test_dir/home" XDG_RUNTIME_DIR="$test_dir/runtime" WALL_TEST_DIR="$test_dir"
export QS_PICKER_CONFIG="$test_dir" QS_PICKER_TIMEOUT=4 QS_PICKER_EXECUTABLE="$test_dir/bin/qs"
export PATH="$test_dir/bin:$PATH"
cp "$project_root/src/services/launcher/launcher.sh" "$test_dir/src/services/launcher/"
cp "$project_root/src/services/launcher/providers/wallpaper.sh" "$test_dir/src/services/launcher/providers/"
cp "$project_root/src/services/launcher/providers/_common/utils.sh" "$test_dir/src/services/launcher/providers/_common/"
picker="$test_dir/src/services/launcher/launcher.sh"
folder="$HOME/Pictures/wallpapers"
state="$HOME/Pictures/.runtime"
printf '%s\n' '[{"name":"DP-1","description":"Main monitor","focused":false},{"name":"HDMI-A-1","description":"Second monitor","focused":true},{"name":"eDP-1","description":"Laptop"}]' > "$test_dir/monitors"
cat > "$test_dir/bin/qs" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${5:-} == alerts ]]; then
    jq -nc --arg message "$8" --arg kind "$9" '{message:$message,kind:$kind}' >> "$WALL_TEST_DIR/alerts"
elif [[ ${6:-} == wallpaperConfig ]]; then
    touch "$WALL_TEST_DIR/config-read"
    [[ ${WALL_TEST_CONFIG_FAIL:-0} == 0 ]] || exit 2
    jq -nc --arg directory "${WALL_TEST_FOLDER-$HOME/Pictures/wallpapers}" '{directory:$directory}'
elif [[ ${6:-} == open ]]; then
    request=$7/request.json
    if jq -e '.previewImages == true' "$request" >/dev/null; then
        stage=image
        count=0
        [[ ! -f $WALL_TEST_DIR/image-count ]] || count=$(<"$WALL_TEST_DIR/image-count")
        printf '%s' "$((count+1))" > "$WALL_TEST_DIR/image-count"
        path=${WALL_TEST_IMAGE:-}
        if [[ $count -gt 0 && -n ${WALL_TEST_NEXT_IMAGE:-} ]]; then path=$WALL_TEST_NEXT_IMAGE; fi
        index=$(jq --arg path "$path" 'if $path == "" then 0 else .items | map(.result) | index($path) end' "$request")
    elif jq -e '.selectionKey == "wallpaper.mode"' "$request" >/dev/null; then
        stage=mode
        mode=${WALL_TEST_MODE:-personal}
        if [[ $(<"$WALL_TEST_DIR/image-count") -gt 1 && -n ${WALL_TEST_NEXT_MODE:-} ]]; then mode=$WALL_TEST_NEXT_MODE; fi
        index=$(jq --arg mode "$mode" '.items | map(.result) | index($mode)' "$request")
    else
        stage=monitor
        index=$(jq --arg output "${WALL_TEST_OUTPUT:-DP-1}" '.items | map(.result) | index($output)' "$request")
    fi
    printf '%s\n' "$stage" >> "$WALL_TEST_DIR/steps"
    cp "$request" "$WALL_TEST_DIR/$stage.json"
    if [[ ${WALL_TEST_CANCEL:-} == "$stage" ]] || {
        [[ $stage == image ]] && [[ $(<"$WALL_TEST_DIR/image-count") -gt ${WALL_TEST_CYCLES:-1} ]]
    }; then
        printf '%s\n' '{"status":"cancelled"}' > "$7/reply"
    else
        jq -c --argjson index "$index" --arg query "${WALL_TEST_QUERY:-}" '{status:"accepted",items:[.items[$index]],query:$query,exitCode:0}' "$request" > "$7/reply"
    fi
fi
BASH
cat > "$test_dir/bin/hyprctl" <<'BASH'
#!/usr/bin/env bash
[[ ${WALL_TEST_MONITORS_FAIL:-0} == 0 ]] || exit 1
cat "$WALL_TEST_DIR/monitors"
BASH
cat > "$test_dir/bin/awww" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
jq -nc --args '$ARGS.positional' -- "$@" >> "$WALL_TEST_DIR/commands"
if [[ $1 == query ]]; then
    count=0
    [[ ! -f $WALL_TEST_DIR/query-count ]] || count=$(<"$WALL_TEST_DIR/query-count")
    printf '%s' "$((count+1))" > "$WALL_TEST_DIR/query-count"
    [[ $count -ge ${WALL_TEST_QUERY_FAILURES:-0} ]]
else
    [[ ${WALL_TEST_APPLY_FAIL:-0} == 0 ]]
fi
BASH
printf '#!/usr/bin/env bash\nexit 0\n' > "$test_dir/bin/sleep"
chmod +x "$test_dir/bin/"*
reset_actions() {
    rm -f "$test_dir/commands" "$test_dir/alerts" "$test_dir/image.json" "$test_dir/mode.json" "$test_dir/monitor.json" "$test_dir/query-count" "$test_dir/image-count" "$test_dir/steps" "$test_dir/config-read"
}
check_cleanup() {
    [[ -z $(find "$test_dir/runtime" -mindepth 1 -type f -print -quit) ]]
    [[ -z $(find "$test_dir/runtime" -maxdepth 1 -name 'wallpaper.*' -print -quit) ]]
}
expect_error() { jq -se 'length == 1 and .[0].kind == "error"' "$test_dir/alerts" >/dev/null; check_cleanup; }

image="$folder/quote ' \" \$(touch injected) #%.PNG"
second_image="$folder/nested/second"$'\n'"line.jpg"
touch "$image" "$second_image" "$folder/animation.gif" "$folder/ignored.mp4" "$folder/ignored.txt"
for mode in personal work; do
    reset_actions
    WALL_TEST_IMAGE="$image" WALL_TEST_QUERY=quote WALL_TEST_MODE="$mode" bash "$picker" provider wallpaper
    [[ $(readlink "$state/wallpaper_${mode}_1") == "$image" ]]
    jq -e --arg image "$image" '.allowTyped == false and .previewImages and (.items|length)==3
        and any(.items[]; .result==$image and (.image|contains("%23%25.PNG")))' "$test_dir/image.json" >/dev/null
    jq -e '[.items[].result]==["personal","work"] and .showPrompt!=true' "$test_dir/mode.json" >/dev/null
    jq -e '[.items[].result]==["HDMI-A-1","DP-1","eDP-1"] and .showPrompt!=true' "$test_dir/monitor.json" >/dev/null
    jq -e --arg image "$image" '.query=="quote" and .selectedResult==$image' "$test_dir/image.json" >/dev/null
    [[ $(cat "$test_dir/steps") == $'image\nmode\nmonitor\nimage' ]]
    jq -se --arg image "$image" '. == [["img",$image,"--outputs","DP-1","--transition-type","any","--transition-duration","2"]]' "$test_dir/commands" >/dev/null
    jq -se 'length==1 and .[0].kind=="success"' "$test_dir/alerts" >/dev/null
    check_cleanup
done
printf 'PASS: native image/target menus preserve personal/work slots, live monitors, literal paths and encoded preview URLs\n'

reset_actions
WALL_TEST_IMAGE="$second_image" WALL_TEST_OUTPUT=HDMI-A-1 bash "$picker" provider wallpaper
[[ $(readlink "$state/wallpaper_personal_2"; printf '.') == "$second_image"$'\n.' ]]
reset_actions
bash "$picker" provider wallpaper set eDP-1 work "$image"
[[ $(readlink "$state/wallpaper_work_eDP-1") == "$image" ]]
printf 'PASS: newline paths survive picker replies; additional monitors save independent choices\n'

for stage in image mode monitor; do
    reset_actions
    before=$(readlink "$state/wallpaper_personal_1")
    WALL_TEST_CANCEL="$stage" bash "$picker" provider wallpaper
    [[ ! -f $test_dir/commands && ! -f $test_dir/alerts ]]
    [[ $(readlink "$state/wallpaper_personal_1") == "$before" ]]
    check_cleanup
done
printf 'PASS: mode/monitor cancellation returns to images; image cancellation exits without changing wallpaper\n'

reset_actions
before=$(readlink "$state/wallpaper_personal_1")
if WALL_TEST_APPLY_FAIL=1 bash "$picker" provider wallpaper set 1 personal "$second_image" 2> "$test_dir/error"; then exit 1; fi
[[ $(readlink "$state/wallpaper_personal_1") == "$before" ]]
expect_error
printf 'PASS: failed wallpaper application preserves the previous saved choice\n'

for arguments in 'DP-1 invalid' 'missing personal'; do
    reset_actions
    read -r output mode <<< "$arguments"
    if bash "$picker" provider wallpaper set "$output" "$mode" "$image" 2> "$test_dir/error"; then exit 1; fi
    [[ ! -f $test_dir/commands ]]
    expect_error
done
reset_actions
if WALL_TEST_MONITORS_FAIL=1 bash "$picker" provider wallpaper set DP-1 personal "$image" 2> "$test_dir/error"; then exit 1; fi
[[ ! -f $test_dir/commands ]]
expect_error
printf 'PASS: invalid modes, disconnected monitors and monitor query failures leave saved choices intact\n'

reset_actions
WALL_TEST_QUERY_FAILURES=2 bash "$picker" provider wallpaper restore personal
[[ ! -f $test_dir/config-read ]]
jq -se --arg state "$state" 'map(select(.[0]=="img")) == [
    ["img",$state+"/wallpaper_personal_2","--outputs","HDMI-A-1","--transition-type","any","--transition-duration","0.5"],
    ["img",$state+"/wallpaper_personal_1","--outputs","DP-1","--transition-type","any","--transition-duration","0.5"]]' "$test_dir/commands" >/dev/null
[[ $(<"$test_dir/query-count") == 3 && ! -f $test_dir/alerts ]]
check_cleanup
reset_actions
bash "$picker" provider wallpaper restore work
jq -se 'map(select(.[0]=="img")) | length==2 and .[1][3]=="eDP-1"' "$test_dir/commands" >/dev/null
reset_actions
if WALL_TEST_QUERY_FAILURES=1000 bash "$picker" provider wallpaper restore personal 2> "$test_dir/error"; then exit 1; fi
jq -se 'all(.[]; .[0]=="query")' "$test_dir/commands" >/dev/null
expect_error
printf 'PASS: restore waits for the daemon, restores both modes per monitor, skips unset choices and reports daemon failure\n'

reset_actions
WALL_TEST_IMAGE="$image" WALL_TEST_NEXT_IMAGE="$second_image" WALL_TEST_NEXT_MODE=work WALL_TEST_CYCLES=2 \
    bash "$picker" provider wallpaper
[[ $(readlink "$state/wallpaper_personal_1") == "$image" ]]
[[ $(readlink "$state/wallpaper_work_1"; printf '.') == "$second_image"$'\n.' ]]
jq -se 'length==2 and all(.[]; .[0]=="img")' "$test_dir/commands" >/dev/null
[[ $(cat "$test_dir/steps") == $'image\nmode\nmonitor\nimage\nmode\nmonitor\nimage' ]]
check_cleanup
printf 'PASS: one browsing session can apply different images and modes repeatedly until image cancellation\n'
reset_actions
WALL_TEST_IMAGE="$image" WALL_TEST_APPLY_FAIL=1 bash "$picker" provider wallpaper 2> "$test_dir/error"
[[ $(cat "$test_dir/steps") == $'image\nmode\nmonitor\nimage' ]]
expect_error
printf 'PASS: failed interactive application returns to the image picker with an error alert\n'

# Direct callers can still set a file whose name ends with a newline.
trailing="$test_dir/trailing.png"$'\n'
touch "$trailing"
bash "$picker" provider wallpaper set 2 work "$trailing"
[[ $(readlink "$state/wallpaper_work_2"; printf '.') == "$trailing"$'\n.' ]]

# A custom root and symlinked image folder remain usable without renaming existing files.
mkdir "$test_dir/empty"
reset_actions
if bash "$picker" provider wallpaper "$test_dir/empty" 2> "$test_dir/error"; then exit 1; fi
[[ ! -f $test_dir/image.json && ! -f $test_dir/commands ]]
expect_error
ln -s "$folder" "$test_dir/linked-images"
WALLPAPER_STATE_DIRECTORY="$test_dir/custom-state" WALL_TEST_IMAGE="$image" \
    bash "$picker" provider wallpaper "$test_dir/linked-images"
[[ $(readlink "$test_dir/custom-state/wallpaper_personal_1") == "$image" ]]
[[ ! -f $test_dir/config-read ]]
printf 'PASS: empty folders report an error; symlinked roots and custom storage work\n'

reset_actions
configured="$test_dir/configured images \"quoted\""
mkdir "$configured"
touch "$configured/only.png"
WALL_TEST_FOLDER="$configured" bash "$picker" provider wallpaper
[[ $(readlink "$state/wallpaper_personal_1") == "$configured/only.png" ]]
[[ -f $test_dir/config-read ]]
check_cleanup
for config_case in unavailable empty; do
    reset_actions
    if [[ $config_case == unavailable ]]; then
        if WALL_TEST_CONFIG_FAIL=1 bash "$picker" provider wallpaper 2> "$test_dir/error"; then exit 1; fi
    else
        if WALL_TEST_FOLDER='' bash "$picker" provider wallpaper 2> "$test_dir/error"; then exit 1; fi
    fi
    [[ ! -f $test_dir/image.json && ! -f $test_dir/commands ]]
    expect_error
done
printf 'PASS: configured wallpaper roots support literal paths; missing settings report errors; explicit roots and restore bypass config IPC\n'
