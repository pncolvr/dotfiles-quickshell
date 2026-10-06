"""Exercise the real notification protocol and isolated QML/storage through IPC."""
import json
import os
import pathlib
import sqlite3
import subprocess
import time

import dbus
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib

DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
directory = pathlib.Path(os.environ["NOTIFICATION_TEST_DIR"])
entry = directory / "config/shell.qml"
database = directory / "config/data/quickshell.db"
log = directory / "qs.log"
process = None
events = []
bus.add_signal_receiver(lambda *args: events.append(("action", *args)), signal_name="ActionInvoked", dbus_interface="org.freedesktop.Notifications")
bus.add_signal_receiver(lambda *args: events.append(("closed", *args)), signal_name="NotificationClosed", dbus_interface="org.freedesktop.Notifications")


def pump():
    while GLib.MainContext.default().pending():
        GLib.MainContext.default().iteration(False)


def wait(predicate, message, seconds=5):
    until = time.monotonic() + seconds
    while time.monotonic() < until:
        pump()
        try:
            if predicate():
                return
        except (json.JSONDecodeError, KeyError):
            # IPC targets are briefly absent while an asynchronous Loader reloads.
            pass
        time.sleep(0.03)
    raise AssertionError(message)


def ipc(method, *args, target="notificationstest"):
    result = subprocess.run(["qs", "ipc", "-p", str(entry), "call", target, method, *map(str, args)], capture_output=True, text=True, timeout=5)
    assert result.returncode == 0, result.stderr
    return result.stdout.strip()


def state():
    return json.loads(ipc("snapshot"))


def rows(key="desktop:test"):
    return json.loads(ipc("entries", key, 100, 0))


def preference(field, value, key="desktop:test"):
    assert ipc("preference", key, field, str(value).lower()) == "true"


def start():
    global process
    with log.open("a") as output:
        process = subprocess.Popen(["qs", "-p", str(entry)], stdout=output, stderr=subprocess.STDOUT)
    wait(lambda: bus.name_has_owner("org.freedesktop.Notifications"), "native server owns private bus")
    wait(lambda: subprocess.run(["qs", "ipc", "-p", str(entry), "show"], capture_output=True, text=True).stdout.find("notificationstest") >= 0, "test IPC available")


def stop():
    global process
    if process:
        process.terminate()
        process.wait(timeout=5)
        process = None
    wait(lambda: not bus.name_has_owner("org.freedesktop.Notifications"), "private bus released")


def notify(summary, *, body="Body", app="Test", desktop="test", urgency=1, timeout=0, replacement=0, transient=False, actions=(), extra=None):
    hints = {"urgency": dbus.Byte(urgency), "desktop-entry": desktop, "transient": dbus.Boolean(transient)}
    hints.update(extra or {})
    server = dbus.Interface(bus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications"), "org.freedesktop.Notifications")
    return int(server.Notify(app, dbus.UInt32(replacement), "", summary, body, dbus.Array(actions, signature="s"), dbus.Dictionary(hints, signature="sv"), dbus.Int32(timeout)))


try:
    mask_check = subprocess.run(["/usr/lib/qt6/bin/qmltestrunner", "-input", str(pathlib.Path(__file__).with_name("tst_image-mask.qml"))],
        env={**os.environ, "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"}, capture_output=True, text=True, timeout=15)
    assert mask_check.returncode == 0, mask_check.stdout + mask_check.stderr
    print("PASS: avatar padding detection, enclosed dark details, transparent and nonsquare images")
    # Exercise a real v1 migration, preserving unrelated data.
    with sqlite3.connect(database) as db:
        db.executescript("CREATE TABLE preferences (key TEXT PRIMARY KEY, value_json TEXT NOT NULL); INSERT INTO preferences VALUES ('preserve', '42'); PRAGMA user_version=1;")
    start()
    assert not state()["dnd"] and not state()["groups"]
    low = notify("Low", urgency=0)
    transient = notify("Transient", transient=True)
    normal = notify("Normal")
    critical = notify("Critical", urgency=2)
    wait(lambda: len(state()["live"]) == 4, "all notifications tracked")
    assert len(rows()) == 3, "all urgencies saved; transient excluded"
    assert any(r["summary"] == "Low" and r["urgency"] == 0 for r in rows()), "low urgency archived"
    assert rows()[0]["summary"] == "Critical"
    emitter = state()["emitters"]["desktop:test"]
    assert not any(emitter[key] for key in ("muted", "allowDuringDnd", "excludeFromHistory"))
    other = notify("Other emitter", app="Other", desktop="other")
    assert state()["groups"][0]["emitterKey"] == "desktop:other", "groups ordered by latest receipt"
    ipc("clearEmitter", "desktop:other")
    assert len(rows()) == 3 and "desktop:other" in state()["emitters"]
    assert all(p["id"] != other for p in state()["live"])
    deleted_key = "desktop:delete-test"
    delete_saved = notify("Delete saved", app="Delete test", desktop="delete-test")
    delete_transient = notify("Delete transient", app="Delete test", desktop="delete-test", transient=True)
    assert len(rows(deleted_key)) == 1
    for field in ("muted", "allowDuringDnd", "excludeFromHistory"):
        preference(field, True, key=deleted_key)
    ipc("filter", "All")
    assert json.loads(ipc("searchEmitters", " DELETE TEST ")) == [deleted_key], "search matches emitter name without case or surrounding spaces"
    assert json.loads(ipc("searchEmitters", "delete-test")) == [deleted_key], "search matches application ID"
    assert json.loads(ipc("searchEmitters", "missing-emitter")) == [], "unmatched emitter search is empty"
    ipc("searchEmitters", "test")
    assert json.loads(ipc("filter", "Hidden")) == [deleted_key], "search composes with the existing emitter filter"
    assert ipc("clearEmitterSearch") == "true", "emitter search clears without persistence"
    untouched_emitters = {key: value for key, value in state()["emitters"].items() if key != deleted_key}
    untouched_live = {entry["id"] for entry in state()["live"] if entry["id"] not in (delete_saved, delete_transient)}
    ipc("prepareSettings", "History off")
    wait(lambda: ipc("settingsButton", "notificationDeleteEmitter_" + deleted_key) == "true", "emitter delete button created and clicked")
    wait(lambda: deleted_key not in state()["emitters"], "emitter and preferences deleted")
    wait(lambda: all(entry["id"] not in (delete_saved, delete_transient) for entry in state()["live"]), "saved and transient notifications dismissed")
    wait(lambda: all(any(event[0] == "closed" and event[1] == identifier and event[2] == 2 for event in events)
        for identifier in (delete_saved, delete_transient)), "emitter deletion emits dismissal signals")
    assert not rows(deleted_key) and all(group["emitterKey"] != deleted_key for group in state()["groups"])
    assert state()["emitters"] == untouched_emitters and not state()["dnd"], "deletion preserves other emitters and DND"
    assert {entry["id"] for entry in state()["live"]} == untouched_live and len(rows()) == 3
    with sqlite3.connect(database) as db:
        assert not db.execute("SELECT 1 FROM notification_live WHERE live_token LIKE ? OR live_token LIKE ?",
            (f"%/{delete_saved}", f"%/{delete_transient}")).fetchone(), "deleted emitter leaves no saved live state"
    if os.environ.get("NOTIFICATION_TEST_WAYLAND") == "1":
        wait(lambda: json.loads(ipc("nativeUi")).get("managerVisible"), "native manager opens")
        native = json.loads(ipc("nativeUi"))
        assert native["popupVisible"]
        assert not native["regularTooltipVisible"], "notification manager does not also open the shared tooltip"
        assert native["popupNamespace"] == native["managerNamespace"] == "quickshell-private"
        assert 0 < native["popupWidth"] <= native["screenWidth"]
        assert 0 < native["managerHeight"] <= native["screenHeight"]
        assert native["managerTab"] == "History"
        assert ipc("managerTab", 1) == "true"
        wait(lambda: json.loads(ipc("nativeUi"))["managerTab"] == "Emitters", "shared tabs open emitter settings")
        assert ipc("managerTab", 0) == "true"
        wait(lambda: json.loads(ipc("nativeUi"))["managerTab"] == "History", "shared tabs return to notification history")
        assert ipc("preview", "/tmp/quickshell-notifications-preview.png") == "true"
    ipc("toggle", target="notifications")
    assert state()["dnd"] and not state()["popups"], "DND hides current popups"
    blocked = notify("Critical blocked", urgency=2, extra={"SWAYNC_BYPASS_DND": dbus.Boolean(True)})
    assert not state()["popups"], "critical urgency and sender hint cannot bypass whitelist"
    preference("allowDuringDnd", True)
    assert not state()["popups"], "whitelisting does not replay backlog"
    allowed = notify("Allowed")
    assert [p["id"] for p in state()["popups"]] == [allowed]
    preference("muted", True)
    assert json.loads(ipc("filter", "Hidden")) == ["desktop:test"]
    silent = notify("Muted but saved")
    assert not state()["popups"] and rows()[0]["summary"] == "Muted but saved"
    preference("muted", False)
    assert not state()["popups"], "unmuting does not replay"
    preference("excludeFromHistory", True)
    before = len(rows())
    excluded = notify("Never saved")
    assert len(rows()) == before
    notify("Excluded replacement", replacement=silent)
    wait(lambda: any(p["summary"] == "Excluded replacement" for p in state()["popups"]), "replacement received")
    assert all(r["summary"] != "Excluded replacement" for r in rows()), "excluded replacement does not overwrite archive"
    assert json.loads(ipc("filter", "History off")) == ["desktop:test"]
    assert json.loads(ipc("filter", "DND allowed")) == ["desktop:test"]
    preference("excludeFromHistory", False)
    replacement = notify("Updated", replacement=allowed)
    wait(lambda: any(r["summary"] == "Updated" for r in rows()), "replacement archived")
    assert replacement == allowed and len(rows()) == before
    ipc("toggle", target="notifications")
    assert not state()["dnd"]
    timed = notify("Timed", timeout=150)
    wait(lambda: all(p["id"] != timed for p in state()["live"]), "expiry closes live notification")
    assert any(r["summary"] == "Timed" for r in rows())
    wait(lambda: any(e[0] == "closed" and e[1] == timed and e[2] == 1 for e in events), "expiry close reason")
    hovered = notify("Hover timer", timeout=1200)
    ipc("prepareCard", hovered, "false")
    ipc("cardHover", "true")
    wait(lambda: state()["card"]["paused"], "hover pauses the popup timer")
    paused_progress = state()["card"]["progress"]
    time.sleep(1.4)
    assert any(p["id"] == hovered for p in state()["live"]), "hovered notification outlives its original timeout"
    assert abs(state()["card"]["progress"] - paused_progress) < 0.001, "hover freezes the visible countdown"
    ipc("cardHoverClose")
    assert state()["card"]["paused"], "hovering the close button keeps expiry paused"
    notify("Hover replacement", replacement=hovered, timeout=1000)
    wait(lambda: -1000 <= next(p["deadline"] for p in state()["live"] if p["id"] == hovered) < 0,
         "replacement resets its timeout while remaining paused")
    ipc("cardHover", "false")
    wait(lambda: next(p["deadline"] for p in state()["live"] if p["id"] == hovered) > 0, "leaving resumes the timer")
    wait(lambda: all(p["id"] != hovered for p in state()["live"]), "resumed notification expires")
    assert any(r["summary"] == "Hover replacement" for r in rows()), "hover expiry retains history"
    # Use the real CLI: an omitted body can reach Qt's SQL binding as NULL.
    sent = subprocess.run(["notify-send", "--print-id", "--expire-time=150", "Title only"], capture_output=True, text=True, timeout=5)
    assert sent.returncode == 0, sent.stderr
    title_only = int(sent.stdout.strip())
    wait(lambda: any(r["summary"] == "Title only" for r in rows("app:notify-send")), "title-only notify-send saved")
    assert rows("app:notify-send")[0]["body"] == ""
    wait(lambda: all(p["id"] != title_only for p in state()["live"]), "title-only notification expired")
    assert len(rows("app:notify-send")) == 1, "expiry retains title-only history"
    if os.environ.get("NOTIFICATION_TEST_WAYLAND") == "1":
        wait(lambda: any(g["emitterKey"] == "app:notify-send" for g in json.loads(ipc("nativeUi"))["groups"]), "notify-send group appears in open manager")
    # libnotify exposes file icons as image-data; they belong in the icon slot.
    ipc("twitchNotify", "streamer_online")
    wait(lambda: any(p["summary"] == "Live" for p in state()["live"]), "TwitchService notification received")
    twitch_id = next(p["id"] for p in state()["live"] if p["summary"] == "Live")
    ipc("prepareCard", twitch_id, "false")
    wait(lambda: state()["card"]["imageIsIcon"] and state()["card"]["icon"], "Twitch image appears in app icon slot")
    assert state()["emitters"]["app:twitch"]["name"] == "Twitch"
    wait(lambda: any(r["summary"] == "Live" and r["image"].startswith("data:image/png;base64,") for r in rows("app:twitch")), "Twitch notification and icon saved in history")
    if os.environ.get("NOTIFICATION_TEST_WAYLAND") == "1":
        assert ipc("preview", "/tmp/quickshell-notifications-twitch-preview.png") == "true"
    twitch_archive = next(r for r in rows("app:twitch") if r["summary"] == "Live")
    assert twitch_archive["urgency"] == 1, "Twitch notifications use normal urgency"
    assert twitch_archive["body"] == "`streamer_online`", twitch_archive["body"]
    assert twitch_archive["actions"] == [], "new Twitch notifications have no view action"
    assert state()["card"]["actionStates"] == [], "Twitch popup has no view button"
    assert ipc("prepareHistory", twitch_archive["archiveId"]) == "true"
    time.sleep(0.1)
    assert state()["card"]["actionStates"] == [], "Twitch history has no view button"
    ipc("dismiss", twitch_id)
    body_only = notify("", body="Body without title", timeout=150)
    wait(lambda: any(r["summary"] == "" and r["body"] == "Body without title" for r in rows()), "empty summary saved")
    wait(lambda: all(p["id"] != body_only for p in state()["live"]), "body-only notification expired")
    acted = notify("Default action", actions=("default", "Open", "custom", "Custom"))
    ipc("cardClick", acted, "false")
    wait(lambda: any(e[0] == "action" and e[1] == acted and e[2] == "default" for e in events), "left-click invokes default")
    assert sum(e[0] == "action" and e[1] == acted for e in events) == 1
    assert all(p["id"] != acted for p in state()["live"])
    archived_action = next(r for r in rows() if r["summary"] == "Default action")
    assert archived_action["actions"] == [{"identifier": "default", "text": "Open"}, {"identifier": "custom", "text": "Custom"}]
    assert ipc("prepareHistory", archived_action["archiveId"]) == "true"
    time.sleep(0.1)
    assert state()["card"]["actionStates"] == []
    assert not state()["card"]["buttonFound"], "expired actions are hidden in history"
    assert ipc("historyAction", archived_action["archiveId"], "custom") == "false", "expired callback cannot invoke reused protocol IDs"
    assert ipc("historyButton", "notificationAction_custom") == "false", "history contains no action button"
    action_update = notify("Action replacement", actions=("first", "First"))
    action_archive = next(r for r in rows() if r["summary"] == "Action replacement")["archiveId"]
    notify("Action replacement updated", replacement=action_update, actions=("second", "Second"))
    wait(lambda: any(r["archiveId"] == action_archive and r["actions"] == [{"identifier": "second", "text": "Second"}] for r in rows()), "replacement updates saved action metadata")
    ipc("dismiss", action_update)
    resident = notify("Resident", actions=("default", "Open", "custom", "Custom"), extra={"resident": dbus.Boolean(True)})
    ipc("prepareCard", resident, "true")
    assert state()["card"]["actionStates"] == [], "history hides actions even while the notification is live"
    ipc("prepareCard", resident, "false")
    time.sleep(0.1)  # Let positioners polish the newly created action delegate.
    wait(lambda: ipc("cardButton", resident, "notificationAction_custom", "false") == "true", "action button created")
    wait(lambda: any(e[0] == "action" and e[1] == resident and e[2] == "custom" for e in events), "action button invokes specific action")
    assert sum(e[0] == "action" and e[1] == resident for e in events) == 1, "action button does not also invoke card default"
    assert any(p["id"] == resident for p in state()["live"]), "resident action keeps live notification"
    ipc("cardClick", resident, "true")
    wait(lambda: all(p["id"] != resident for p in state()["live"]), "right-click dismisses")
    assert any(r["summary"] == "Resident" for r in rows())
    source = notify("Source controls", actions=("default", "Open"))
    ipc("prepareEmitter", source)
    time.sleep(0.1)
    wait(lambda: ipc("emitterButton", "notificationMute") == "true", "emitter header control created")
    assert state()["emitters"]["desktop:test"]["muted"]
    assert not any(e[0] == "action" and e[1] == source for e in events), "emitter controls do not activate a notification"
    preference("muted", False)
    assert ipc("focusFallback") == "true"
    unmatched = notify("Unmatched window", app="Unmatched", desktop="unmatched")
    ipc("activate", unmatched)
    assert state()["focusMessage"] == "No matching application window is available."
    time.sleep(1.7)
    ipc("activate", unmatched)
    time.sleep(1.7)
    assert state()["focusMessage"], "another failed click restarts the feedback timer"
    wait(lambda: not state()["focusMessage"], "focus feedback clears three seconds after the last click")
    ipc("activate", unmatched)
    ipc("activate", source)
    assert not state()["focusMessage"], "a usable default action clears previous focus feedback"
    ipc("dismiss", unmatched)
    closed = notify("Client close")
    server = dbus.Interface(bus.get_object("org.freedesktop.Notifications", "/org/freedesktop/Notifications"), "org.freedesktop.Notifications")
    server.CloseNotification(closed)
    wait(lambda: all(p["id"] != closed for p in state()["live"]), "client closure tracked")
    assert any(r["summary"] == "Client close" for r in rows())
    # Raw protocol image must survive the notification object's destruction/restart.
    image = dbus.Struct((dbus.Int32(1), dbus.Int32(1), dbus.Int32(4), dbus.Boolean(True), dbus.Int32(8), dbus.Int32(4), dbus.ByteArray(b"\xff\x00\x00\xff")), signature="iiibiiay")
    imaged = notify("Image", extra={"image-data": image})
    wait(lambda: any(r["summary"] == "Image" and r["image"].startswith("data:image/png;base64,") for r in rows()), "image payload persisted")
    assert len(json.loads(ipc("entries", "desktop:test", 2, 0))) == 2
    assert len(json.loads(ipc("entries", "desktop:test", 2, 2))) == 2, "older pages accessible"
    # Hot reload keeps IDs, archive count and the original finite deadline.
    reload_id = notify("Reload timer", timeout=5000)
    before_state = state()
    deadline = next(p["deadline"] for p in before_state["live"] if p["id"] == reload_id)
    entry.write_text(entry.read_text() + "\n// reload probe\n")
    wait(lambda: log.read_text().count("Configuration Loaded") >= 2, "hot reload")
    wait(lambda: any(p["id"] == reload_id for p in state()["live"]), "carried live notification reconciled")
    after = state()
    assert next(p["deadline"] for p in after["live"] if p["id"] == reload_id) == deadline
    assert sum(g["count"] for g in after["groups"]) == sum(g["count"] for g in before_state["groups"])
    ipc("toggle", target="notifications")
    preference("muted", True)
    preference("excludeFromHistory", True)
    saved_count = len(rows())
    stop()
    start()
    assert len(rows()) == saved_count and state()["dnd"] and not state()["popups"] and not state()["live"]
    assert deleted_key not in state()["emitters"] and not rows(deleted_key), "emitter deletion survives restart"
    returned = notify("Returned emitter", app="Delete test", desktop="delete-test")
    assert not any(state()["emitters"][deleted_key][field] for field in ("muted", "allowDuringDnd", "excludeFromHistory")), "new notification recreates emitter with defaults"
    assert rows(deleted_key)[0]["summary"] == "Returned emitter"
    assert all(entry["id"] != returned for entry in state()["popups"]), "recreated emitter is blocked during DND by default"
    ipc("dismiss", returned)
    assert rows("app:notify-send")[0]["summary"] == "Title only" and rows("app:notify-send")[0]["body"] == "", "CLI history survives restart"
    assert any(r["summary"] == "Low" and r["urgency"] == 0 for r in rows()), "low urgency history survives restart"
    assert any(r["summary"] == "Live" and r["image"].startswith("data:image/png;base64,") for r in rows("app:twitch")), "Twitch history and icon survive restart"
    assert ipc("prepareHistory", archived_action["archiveId"]) == "true"
    assert state()["card"]["actionStates"] == [], "archived app actions remain hidden after restart"
    assert ipc("prepareHistory", twitch_archive["archiveId"]) == "true"
    time.sleep(0.1)
    assert state()["card"]["actionStates"] == [], "Twitch history remains free of view buttons after restart"
    assert state()["emitters"]["desktop:test"]["muted"]
    assert state()["emitters"]["desktop:test"]["excludeFromHistory"]
    assert any(r["summary"] == "Image" and r["image"].startswith("data:image/png;base64,") for r in rows())
    ipc("clearAll")
    assert not rows() and "desktop:test" in state()["emitters"] and state()["dnd"]
    stop()
    start()
    assert not rows() and state()["emitters"]["desktop:test"]["excludeFromHistory"]
    with sqlite3.connect(database) as db:
        assert db.execute("PRAGMA user_version").fetchone()[0] == 4
        assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
        assert db.execute("SELECT value_json FROM preferences WHERE key='preserve'").fetchone()[0] == "42"
    stop()
    # Migrate an existing v2 archive without losing content or source settings.
    with sqlite3.connect(database) as db:
        db.executescript("ALTER TABLE notifications DROP COLUMN actions_json; ALTER TABLE notifications DROP COLUMN action_handler; PRAGMA user_version=2;")
        db.execute("INSERT INTO notifications VALUES (?, ?, ?, ?, ?, ?, ?, ?)", ("legacy-twitch", "app:twitch", "Legacy Twitch", "Preserved", 0, 1, 1, ""))
        db.execute("INSERT INTO notifications VALUES (?, ?, ?, ?, ?, ?, ?, ?)", ("legacy-generic", "desktop:test", "Legacy app", "Preserved", 1, 2, 2, ""))
    start()
    assert rows("app:twitch")[0]["body"] == "Preserved"
    assert rows()[0]["body"] == "Preserved" and rows()[0]["actions"] == [], "missing generic callbacks are not invented"
    assert state()["emitters"]["desktop:test"]["excludeFromHistory"] and state()["dnd"], "v2 migration keeps preferences"
    assert ipc("prepareHistory", "legacy-twitch") == "true"
    time.sleep(0.1)
    assert state()["card"]["actionStates"] == [], "legacy Twitch action buttons are also hidden in history"
    ipc("historyClick")
    opened_urls = directory / "opened-urls"
    wait(lambda: opened_urls.exists() and opened_urls.read_text().splitlines() == ["https://www.twitch.tv/"], "legacy Twitch history retains its known local action")
    stop()
    text = log.read_text()
    for problem in ("Failed to load configuration", "Binding loop detected", "TypeError:", "ReferenceError:", "NOTIFICATION FAIL:", "Local database:"):
        assert problem not in text, text
    print("PASS: private D-Bus lifecycle, policy, actions/clicks, image archive, hot reload, migration and restart persistence")
except Exception:
    if process and process.poll() is None:
        print(subprocess.run(["qs", "ipc", "-p", str(entry), "show"], capture_output=True, text=True).stdout)
        print(subprocess.run(["qs", "ipc", "-p", str(entry), "call", "notificationstest", "snapshot"], capture_output=True, text=True))
        try:
            print(json.dumps(state(), indent=2))
        except Exception:
            pass
    print(log.read_text() if log.exists() else "No QML log")
    raise
finally:
    if process:
        process.terminate()
        process.wait(timeout=5)
