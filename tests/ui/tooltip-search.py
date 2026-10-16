"""Exercise shared panel lifecycle offscreen, without moving desktop focus or the cursor."""
import os
import pathlib
import subprocess
import tempfile

project = pathlib.Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="quickshell-panel-lifecycle-") as temporary:
    directory = pathlib.Path(temporary)
    runtime = directory / "runtime"
    runtime.mkdir(mode=0o700)
    (directory / "src").symlink_to(project / "src", target_is_directory=True)
    entry = directory / "shell.qml"
    entry.write_text((project / "tests/ui/tooltip-search-smoke.qml").read_text().replace('"../../src', '"src'))
    env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software",
           "XDG_RUNTIME_DIR": str(runtime), "XDG_CACHE_HOME": str(directory / "cache"),
           "XDG_DATA_HOME": str(directory / "data")}
    env.pop("WAYLAND_DISPLAY", None)
    result = subprocess.run(["qs", "-p", str(entry)], env=env, capture_output=True, text=True, timeout=15)
    output = result.stdout + result.stderr
    assert result.returncode == 0 and "PASS: scoped panel" in output and not any(
        error in output for error in ["LIFECYCLE FAIL:", "TypeError:", "ReferenceError:",
                                      "Binding loop", "Failed to load configuration"]), output
    print(next(line for line in output.splitlines() if "PASS:" in line))
