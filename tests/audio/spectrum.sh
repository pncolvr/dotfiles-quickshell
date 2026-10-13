#!/usr/bin/env bash
set -euo pipefail
project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d /tmp/quickshell-spectrum-test.XXXXXXXX)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -m700 "$test_dir/runtime"
export XDG_RUNTIME_DIR="$test_dir/runtime"
export LC_ALL=C
binary=$(bash "$project_root/src/services/audio/audio-spectrum.sh" --build)

fail() { printf 'SPECTRUM FAIL: %s\n' "$*" >&2; exit 1; }

analyse() {
    local name=$1 frequency=$2 opposite=$3
    # Two seconds of signed, little-endian stereo PCM at 48 kHz. The C locale
    # makes awk's %c output individual bytes, including NUL and bytes above 127.
    awk -v frequency="$frequency" -v opposite="$opposite" '
        function sample(value) {
            if (value < 0) value += 65536;
            printf "%c%c", value % 256, int(value / 256);
        }
        BEGIN {
            pi = atan2(0, -1);
            for (i = 0; i < 48000 * 2; i++) {
                value = 11000 * sin(i * 2 * pi * frequency / 48000);
                value = int(value + (value < 0 ? -0.5 : 0.5));
                sample(value);
                sample(opposite ? -value : value);
            }
        }
    ' | timeout 15 "$binary" --stdin 64 30 > "$test_dir/$name.frames" \
        || fail "$name analysis failed"

    awk -F '|' -v name="$name" -v audible="$((frequency != 0 && opposite == 0))" '
        function fail(message) {
            print "SPECTRUM FAIL: " name ": " message > "/dev/stderr";
            failed = 1;
            exit 1;
        }
        {
            if (NF != 2 || split($1, bands, ";") != 64 || split($2, waveform, ";") != 64)
                fail("expected 64 spectrum bands and 64 waveform samples");
            for (i = 1; i <= 64; i++) {
                if (bands[i] !~ /^[0-9]+$/ || bands[i] < 0 || bands[i] > 1000)
                    fail("spectrum value outside normalized bounds");
                if (waveform[i] !~ /^-?[0-9]+$/ || waveform[i] < -1000 || waveform[i] > 1000)
                    fail("waveform value outside signed bounds");
                magnitude = waveform[i] < 0 ? -waveform[i] : waveform[i];
                if (magnitude > waveformPeak) waveformPeak = magnitude;
                if (NR > 45) sums[i] += bands[i];
            }
        }
        END {
            if (failed) exit 1;
            if (NR != 60) fail("expected 60 frames");
            if (audible ? waveformPeak <= 100 : waveformPeak != 0)
                fail("unexpected PCM waveform amplitude");
            # Sum the final 15 frames; integer sums preserve the original mean
            # comparisons without rounding or floating-point shell arithmetic.
            for (i = 1; i <= 64; i++) {
                if (sums[i] > peak) { peak = sums[i]; peakIndex = i - 1; }
                if (i <= 25 && sums[i] > lowPeak) lowPeak = sums[i];
                if (i >= 41 && sums[i] > highPeak) highPeak = sums[i];
            }
            printf "%d %d %d %d\n", peakIndex, peak, lowPeak, highPeak;
        }
    ' "$test_dir/$name.frames" > "$test_dir/$name.summary"
}

analyse bass 220 0
analyse treble 4400 0
analyse opposite 220 1
analyse silence 0 0

read -r bass_index bass_peak bass_low bass_high < "$test_dir/bass.summary"
read -r treble_index treble_peak treble_low treble_high < "$test_dir/treble.summary"
read -r opposite_index opposite_peak opposite_low opposite_high < "$test_dir/opposite.summary"
read -r silence_index silence_peak silence_low silence_high < "$test_dir/silence.summary"
((bass_index < 30 && bass_peak > 1500)) || fail 'bass frequency peak'
((treble_index > 35 && treble_peak > 1500)) || fail 'treble frequency peak'
((bass_high * 10 < bass_peak)) || fail 'bass leaked into high bands'
((treble_low * 10 < treble_peak)) || fail 'treble leaked into low bands'
((opposite_index == bass_index && opposite_peak > 1500)) || fail 'opposite-phase stereo lost its spectrum'
((silence_peak == 0)) || fail 'silence produced a spectrum'

invalid_status=0
"$binary" auto 64 30 > "$test_dir/invalid.stdout" 2> "$test_dir/invalid.stderr" || invalid_status=$?
((invalid_status == 2)) || fail 'default-output target was not rejected'
printf 'PASS: cavacore frequency separation, independent bands, stereo phase, silence and frame bounds\n'
