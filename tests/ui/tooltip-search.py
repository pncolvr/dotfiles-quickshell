"""Check typing protection through a fake compositor socket, without moving the real mouse."""
import json
import os
import pathlib
import signal
import socket
import subprocess
import tempfile
import threading
import time

project = pathlib.Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="quickshell-tooltip-search-") as temporary:
    directory = pathlib.Path(temporary)
    runtime = directory / "runtime"
    runtime.mkdir(mode=0o700)
    instance = runtime / "hypr/search-test"
    instance.mkdir(parents=True)
    cursor = [100, 100]
    requests = []
    stopping = threading.Event()

    def serve(path, events=False):
        server = socket.socket(socket.AF_UNIX)
        server.bind(str(path))
        server.listen()
        server.settimeout(0.1)

        def run():
            while not stopping.is_set():
                try:
                    connection, _ = server.accept()
                except TimeoutError:
                    continue
                with connection:
                    if events:
                        stopping.wait()
                        continue
                    command = connection.recv(4096).decode()
                    if command == "j/cursorpos":
                        requests.append(command)
                        reply = {"x": cursor[0], "y": cursor[1]}
                    else:
                        reply = []
                    connection.sendall(json.dumps(reply).encode())
            server.close()

        threading.Thread(target=run, daemon=True).start()

    serve(instance / ".socket.sock")
    serve(instance / ".socket2.sock", events=True)
    entry = directory / "shell.qml"
    entry.write_text('import QtQuick\nimport Quickshell\nScope { Loader { source: "'
                     + (project / "tests/ui/tooltip-search-smoke.qml").as_uri() + '" } }\n')
    bus = directory / "bus.conf"
    bus.write_text('''<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
    "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
    <busconfig><type>session</type><listen>unix:tmpdir=/tmp</listen><auth>EXTERNAL</auth>
    <policy context="default"><allow own="*"/><allow send_destination="*"/>
    <allow receive_sender="*"/></policy></busconfig>''')
    env = {**os.environ, "QT_QPA_PLATFORM": "offscreen", "XDG_RUNTIME_DIR": str(runtime),
           "XDG_CACHE_HOME": str(directory / "cache"), "XDG_DATA_HOME": str(directory / "data"),
           "HYPRLAND_INSTANCE_SIGNATURE": "search-test"}
    env.pop("WAYLAND_DISPLAY", None)
    log = directory / "quickshell.log"
    with log.open("w") as output:
        process = subprocess.Popen(["dbus-run-session", "--config-file", str(bus), "--",
                                    "quickshell", "-p", str(entry)], env=env,
                                   stdout=output, stderr=subprocess.STDOUT, start_new_session=True)

    def ipc(method, *args):
        result = subprocess.run(["quickshell", "ipc", "-p", str(entry), "call", "tooltipsearchtest",
                                 method, *map(str, args)], env=env, capture_output=True, text=True, timeout=3)
        assert result.returncode == 0, result.stderr
        return result.stdout.strip()

    def snapshot():
        return json.loads(ipc("snapshot"))

    def wait(predicate, message):
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline:
            try:
                if predicate():
                    return
            except (AssertionError, json.JSONDecodeError):
                pass
            time.sleep(0.03)
        raise AssertionError(message)

    def hold(text):
        before = len(requests)
        ipc("begin", text)
        wait(lambda: snapshot()["paused"] and len(requests) >= before + 2, "typing protection and cursor polling")
        time.sleep(0.4)
        assert snapshot()["visible"], "typing must cancel the pending hide timer"

    try:
        wait(lambda: snapshot()["visible"] is False, "test IPC ready")
        hold("first query")
        cursor[0] += 1
        wait(lambda: not snapshot()["visible"], "movement outside the tooltip restores dismissal")
        assert snapshot()["text"] == "", "closing clears the search"

        hold("second query")
        ipc("hover", "true")
        cursor[0] += 1
        wait(lambda: not snapshot()["paused"], "movement ends typing protection inside the tooltip")
        time.sleep(0.4)
        assert snapshot()["visible"] and snapshot()["text"] == "second query", "hover keeps the panel open"
        ipc("type", "typing again")
        assert snapshot()["paused"], "typing renews protection without changing focus"
        cursor[0] += 1
        wait(lambda: not snapshot()["paused"], "second mouse movement restores hover behavior")
        ipc("hover", "false")
        wait(lambda: not snapshot()["visible"], "leaving the tooltip dismisses even with a query")

        hold("pinned query")
        ipc("pin")
        ipc("type", "still pinned")
        time.sleep(0.2)
        cursor[0] += 1
        wait(lambda: not snapshot()["paused"], "movement releases protection on a pinned panel")
        time.sleep(0.4)
        assert snapshot()["visible"] and snapshot()["pinned"], "manual pinning remains independent"
        ipc("pin")
        ipc("hover", "false")
        wait(lambda: not snapshot()["visible"], "unpin and hover exit close the panel")

        hold("clear me")
        ipc("clear")
        assert snapshot()["text"] == "" and snapshot()["focused"], "clear keeps input focus"
        ipc("type", "escape me")
        assert ipc("pressEscape") == "true"
        wait(lambda: not snapshot()["visible"], "Escape clears search, releases focus and restores dismissal")
        assert snapshot()["text"] == "" and not snapshot()["focused"]
        print("PASS: typing cancels pending hide, global mouse movement restores hover dismissal, renewed typing, pinning, clear focus, Escape and query reset")
    except BaseException:
        print(log.read_text())
        raise
    finally:
        os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=5)
        stopping.set()
