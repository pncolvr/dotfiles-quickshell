pragma Singleton
import "../"
import "../status/TimeTracking.mjs" as Tracking
import QtQml
import Quickshell

Singleton {
    id: root

    property var sessions: []
    property string error: ''
    readonly property bool ready: DbService.ready

    function reload() {
        const rows = DbService.read('SELECT id,start_ms,end_ms,mode FROM status_sessions ORDER BY start_ms,id');
        if (rows === null) {
            error = DbService.error;
            return false;
        }
        sessions = rows;
        error = '';
        return true;
    }

    function claim(token) {
        // Replacing an old writer never extends its last durable checkpoint.
        return write(tx => {
            return tx.executeSql('INSERT OR REPLACE INTO status_writer(id,token,session_id) VALUES(1,?,NULL)', [token]);
        });
    }

    function write(action) {
        if (!DbService.write(action)) {
            error = DbService.error;
            return false;
        }
        error = '';
        return true;
    }

    function transition(token, mode, now = Date.now(), previousEnd = now) {
        let id = 0;
        if (!write(tx => {
            const owner = tx.executeSql('SELECT token,session_id FROM status_writer WHERE id=1').rows.item(0);
            if (!owner || owner.token !== token)
                throw Error('Writer changed');

            if (owner.session_id) {
                const row = tx.executeSql('SELECT end_ms FROM status_sessions WHERE id=?', [owner.session_id]).rows.item(0);
                const closedAt = Math.max(previousEnd, row.end_ms);
                tx.executeSql('UPDATE status_sessions SET end_ms=? WHERE id=?', [closedAt, owner.session_id]);
            }
            if (mode) {
                if (!['work', 'personal'].includes(mode))
                    throw Error('Invalid tracking mode');

                const last = tx.executeSql('SELECT MAX(end_ms) AS last FROM status_sessions').rows.item(0).last;
                now = Math.max(now, last ?? now);
                const result = tx.executeSql('INSERT INTO status_sessions(start_ms,end_ms,mode) VALUES(?,?,?)', [now, now, mode]);
                id = result.insertId;
            }
            tx.executeSql('UPDATE status_writer SET session_id=? WHERE id=1 AND token=?', [id || null, token]);
        })) {
            return null;
        }
        reload();
        return id;
    }

    function touch(token, id, now = Date.now()) {
        let updated = false;
        if (!write(tx => {
            const result = tx.executeSql('UPDATE status_sessions SET end_ms=MAX(end_ms,?) WHERE id=? AND EXISTS(SELECT 1 FROM status_writer WHERE token=? AND session_id=?)', [now, id, token, id]);
            updated = result.rowsAffected === 1;
        }))
            return false;

        if (!updated) {
            error = 'Tracking writer changed.';
            return false;
        }
        return reload();
    }

    function prune(now = Date.now()) {
        const boundary = Tracking.cutoff(now);
        if (!write(tx => {
            tx.executeSql('DELETE FROM status_sessions WHERE end_ms<=?', [boundary]);
            tx.executeSql('UPDATE status_sessions SET start_ms=? WHERE start_ms<?', [boundary, boundary]);
        }))
            return false;

        return reload();
    }

    Component.onCompleted: reload()

    Connections {
        function onReadyChanged() {
            if (DbService.ready)
                root.reload();
        }

        target: DbService
    }
}
