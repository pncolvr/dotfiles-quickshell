#!/usr/bin/env bash
# Synthetic project files and mocked editors; never opens a real project.
set -euo pipefail
root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/quickshell-project-launchers-test.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
mkdir -p "$fixture/bin" "$fixture/Game \$literal; folder" "$fixture/data" "$fixture/Standalone" "$fixture/Plain"
tar -C "$root_dir" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed -i 's/clipboardMonitorEnabled: true/clipboardMonitorEnabled: false/' "$fixture/src/config/Config.qml"
node - "$fixture/src/config/Config.qml" <<'JSCONFIG'
const fs = require('node:fs'), file = process.argv[2];
const source = fs.readFileSync(file, 'utf8');
const declaration = /readonly property var projectApps:\s*\[/g;
if ([...source.matchAll(declaration)].length !== 1)
    throw new Error('Expected exactly one projectApps declaration');
const custom = {
    id: 'custom',
    name: 'Custom editor',
    extensions: ['.sampleproj'],
    command: ['custom-editor'],
    profiles: {personal: 'Custom personal'},
    arguments: ['--open', '{path}', '--root', '{project}'],
    profileArguments: ['--profile', '{profile}']
};
fs.writeFileSync(file, source.replace(declaration, match =>
    `${match}\n${JSON.stringify(custom, null, 4)},`));
JSCONFIG
sed 's@"../../src@"src@g' "$root_dir/tests/projects/launchers.qml" > "$fixture/shell.qml"
printf '{}' > "$fixture/Standalone/project.godot"
for name in project.godot Mixed.code-workspace Game.sampleproj; do printf '{}' > "$fixture/Game \$literal; folder/$name"; done
cat > "$fixture/bin/editor" <<'MOCK'
#!/usr/bin/env bash
jq -cn --arg program "${0##*/}" --args '{program:$program,args:$ARGS.positional}' -- "$@" >> "$PROJECT_LAUNCH_TEST_DIR/actions"
MOCK
chmod +x "$fixture/bin/editor"
for name in code godot custom-editor; do ln -s editor "$fixture/bin/$name"; done
for phase in setup restart; do
    PROJECT_LAUNCH_PHASE="$phase" PROJECT_LAUNCH_TEST_DIR="$fixture" PATH="$fixture/bin:$PATH" \
        XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/local" XDG_CACHE_HOME="$fixture/cache" \
        QT_QPA_PLATFORM=offscreen timeout 20 qs -p "$fixture" > "$fixture/log" 2>&1 || { cat "$fixture/log"; exit 1; }
    if ! rg -q 'PASS: ' "$fixture/log" || rg -q 'LAUNCHER FAIL:|TypeError:|ReferenceError:|Failed to load configuration' "$fixture/log"; then cat "$fixture/log"; exit 1; fi
    rg 'PASS: ' "$fixture/log"
done
jq -se --arg folder "$fixture/Game \$literal; folder" 'length == 6
    and any(.program=="godot" and .args==["--editor",($folder+"/project.godot")])
    and any(.program=="godot" and .args==["--editor",($folder | rtrimstr("/Game $literal; folder"))+"/Standalone/project.godot"])
    and any(.program=="code" and .args==[$folder,"--profile","Personal"])
    and any(.program=="code" and .args==[($folder+"/Mixed.code-workspace"),"--profile","Personal"])
    and any(.program=="custom-editor" and .args==["--open",($folder+"/Game.sampleproj"),"--root",$folder,"--profile","Custom personal"])' "$fixture/actions" >/dev/null
printf 'PASS: editor-specific argv, per-app profiles, configurable file types and literal project paths\n'
