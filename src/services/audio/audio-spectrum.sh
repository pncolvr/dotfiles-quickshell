#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
runtime_dir=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/quickshell-spectrum
mkdir -p -m700 "$runtime_dir"
sources=("$source_dir/audio-spectrum.c" "$source_dir/vendor/cavacore/cavacore.c" "$source_dir/vendor/cavacore/cavacore.h")
fingerprint=$(sha256sum "${sources[@]}" | sha256sum)
binary="$runtime_dir/spectrum-${fingerprint%% *}"
if [[ ! -x $binary ]]; then
    exec {compile_lock}>"$runtime_dir/build.lock"
    flock "$compile_lock"
    if [[ ! -x $binary ]]; then
        if ! command -v cc >/dev/null || ! command -v pkg-config >/dev/null \
            || ! pkg-config --exists libpipewire-0.3 fftw3; then
            printf 'Audio spectrum requires a C compiler, pkg-config, PipeWire and FFTW development files.\n' >&2
            exit 1
        fi
        temporary=$(mktemp "$runtime_dir/build.XXXXXXXX")
        trap 'rm -f -- "$temporary"' EXIT
        read -r -a build_flags <<< "$(pkg-config --cflags --libs libpipewire-0.3 fftw3)"
        cc -std=gnu11 -O2 -Wall -Wextra -include stdio.h \
            "$source_dir/audio-spectrum.c" "$source_dir/vendor/cavacore/cavacore.c" \
            "${build_flags[@]}" -lm -o "$temporary"
        chmod 700 "$temporary"
        mv -- "$temporary" "$binary"
        trap - EXIT
    fi
    exec {compile_lock}>&-
fi
if [[ ${1:-} == --build ]]; then printf '%s\n' "$binary"; exit 0; fi
exec "$binary" "$@"
