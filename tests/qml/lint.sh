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
# Skip editing aliases only when their canonical source is also included.
# Links to external settings must still be linted.
declare -A included_sources=()
for qml_file in "${qml_files[@]}"; do
    if [[ ! -L $qml_file ]]; then included_sources["$(realpath -m -- "$qml_file")"]=1; fi
done
# Singletons can live below their exporting qmldir. Lint them with their own
# registration, without injecting unrelated UI names into every file's scope.
declare -A singleton_owners=()
mapfile -d '' -t qmldirs < <(rg --files -0 -g qmldir src)
for qmldir in "${qmldirs[@]}"; do
    while read -r directive type_name version relative_file remainder || [[ -n ${directive:-} ]]; do
        [[ $directive == singleton ]] || continue
        singleton_file=$(realpath -m -- "${qmldir%/*}/$relative_file")
        # Prefer local metadata over another module's re-export of the same file.
        if [[ -z ${singleton_owners["$singleton_file"]:-} || ${singleton_file%/*} == "$(realpath -m -- "${qmldir%/*}")" ]]; then
            singleton_owners["$singleton_file"]=$qmldir
        fi
    done < "$qmldir"
done
regular_files=()
singleton_files=()
native_shortcut_files=()
for qml_file in "${qml_files[@]}"; do
    # The installed GlobalShortcut metadata omits its private PostReloadHook base.
    if [[ $qml_file == src/services/hyprland/GlobalShortcutRegistry.qml ]]; then
        native_shortcut_files+=("$qml_file")
        continue
    fi
    if [[ -L $qml_file && -n ${included_sources["$(realpath -m -- "$qml_file")"]:-} ]]; then continue; fi
    if rg -q '^pragma Singleton' "$qml_file"; then
        owner=${singleton_owners["$(realpath -m -- "$qml_file")"]:-}
        [[ -n $owner ]] || { printf 'Singleton is missing from qmldir: %s\n' "$qml_file" >&2; exit 1; }
        singleton_files+=("$qml_file")
    else regular_files+=("$qml_file"); fi
done
lint_options=(--max-warnings 0 --unused-imports warning)
"$qmllint_bin" "${lint_options[@]}" "${regular_files[@]}"
# Keep this upstream metadata diagnostic visible as info for this one component.
if ((${#native_shortcut_files[@]})); then
    "$qmllint_bin" "${lint_options[@]}" --import info "${native_shortcut_files[@]}"
fi
for qmldir in "${qmldirs[@]}"; do
    module_files=()
    for qml_file in "${singleton_files[@]}"; do
        [[ ${singleton_owners["$(realpath -m -- "$qml_file")"]} != "$qmldir" ]] || module_files+=("$qml_file")
    done
    if ((${#module_files[@]})); then "$qmllint_bin" "${lint_options[@]}" -i "$qmldir" "${module_files[@]}"; fi
done
printf 'PASS: %s QML files with no lint warnings\n' "$(( ${#regular_files[@]} + ${#singleton_files[@]} + ${#native_shortcut_files[@]} ))"
