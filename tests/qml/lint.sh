#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$project_root"

qmllint_bin=""
for candidate in "${QMLLINT:-}" /usr/lib/qt6/bin/qmllint qmllint6 qmllint; do
    if [[ -n $candidate ]] && command -v "$candidate" >/dev/null 2>&1 \
        && [[ $("$candidate" --version 2>/dev/null) == 'qmllint 6.'* ]]; then
        qmllint_bin=$candidate
        break
    fi
done
if [[ -z $qmllint_bin ]]; then
    printf 'Qt 6 qmllint is required; set QMLLINT to its executable path.\n' >&2
    exit 1
fi

# Smoke tests create hidden entrypoints while running.
mapfile -d '' -t qml_files < <(rg --files -0 -g '*.qml' -g '!.*')
"$qmllint_bin" --max-warnings 0 --unused-imports warning "${qml_files[@]}"
printf 'PASS: %s QML files with no lint warnings\n' "${#qml_files[@]}"
