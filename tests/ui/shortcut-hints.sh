#!/usr/bin/env bash
# Offscreen hint layout; no native desktop focus or real user data.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d /tmp/qs-hints.XXXXXXXX)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -m700 "$fixture/runtime"
tar -C "$repo" --exclude='*.env' --exclude='src/services/launcher/providers/*.json' -cf - src | tar -C "$fixture" -xf -
sed 's@"../../src@"src@g' "$repo/tests/ui/shortcut-hints.qml" > "$fixture/shell.qml"
python - "$repo" "$fixture" <<'PY'
import json, sys
from pathlib import Path
repo, fixture = map(Path, sys.argv[1:])
samples = []
for locale in ['en', 'pt']:
    catalog = json.loads((repo / 'src/i18n' / (locale + '.json')).read_text())
    for key, value in catalog.items():
        if '.shortcuts.' not in key:
            continue
        for text in (value.values() if isinstance(value, dict) else [value]):
            for token, replacement in {'%n':'2','%1':'Ctrl+Shift+R','%2':'Open','%3':'Shift+Space','%4':'Ctrl+A','%5':'Ctrl+Shift+A'}.items():
                text = text.replace(token, replacement)
            samples.append(text)
    samples.append(catalog['files.shortcuts.selection'])
    samples.append(catalog['vault.shortcuts.details'] + ' · Ctrl+E: ' + ('Edit' if locale == 'en' else 'Editar'))
(fixture / 'samples.json').write_text(json.dumps(samples, ensure_ascii=False))
PY
env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
    XDG_RUNTIME_DIR="$fixture/runtime" XDG_DATA_HOME="$fixture/data" XDG_CACHE_HOME="$fixture/cache" \
    timeout -k 2 25 qs -p "$fixture" > "$fixture/log" 2>&1 || { tail -100 "$fixture/log"; exit 1; }
if ! rg -q 'PASS: bilingual shortcut' "$fixture/log" || rg -q 'HINTS FAIL:|TypeError:|ReferenceError:|Binding loop|Failed to load configuration' "$fixture/log"; then
    tail -100 "$fixture/log"; exit 1
fi
rg 'PASS:' "$fixture/log"
