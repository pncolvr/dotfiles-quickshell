import QtQml
import Quickshell
import Quickshell.Io

// Bounded GET requests. Private headers travel over stdin, never process arguments.
Scope {
    id: root
    readonly property bool busy: pending
    property bool pending: false
    property int timeoutSeconds: 20
    property int maximumBytes: 16777216
    property string input: ''
    signal completed(string json, string error)
    function finish(json,error) {
        if (!pending) return
        pending=false; input=''
        completed(json,error)
    }
    function quoted(value) {
        value=String(value)
        if (/[\x00-\x1f\x7f]/.test(value)) throw new Error('Invalid request parameter.')
        return '"'+value.replace(/\\/g,'\\\\').replace(/"/g,'\\"')+'"'
    }
    function get(url,headers={}) {
        if (busy) return false
        try {
            input='url = '+quoted(url)+'\n'
            for (const name of Object.keys(headers)) {
                if (!/^[A-Za-z0-9-]+$/.test(name)) throw new Error('Invalid request header.')
                input+='header = '+quoted(name+': '+headers[name])+'\n'
            }
        } catch (_) { input=''; completed('','Invalid request parameters.'); return false }
        pending=true
        request.stdinEnabled=true
        startup.restart()
        request.running=true
        return true
    }
    Timer {
        id: startup
        interval:5000
        onTriggered: {
            root.input=''; request.running=false
            root.finish('','Could not start curl. Install curl to load remote data.')
        }
    }
    Process {
        id: request
        // No redirects: credentials must not follow a server to a different address.
        command: ['curl','--disable','--silent','--show-error','--fail-with-body','--proto','=http,https',
            '--connect-timeout','5','--max-time',String(root.timeoutSeconds),
            '--max-filesize',String(root.maximumBytes),'--write-out','\n%{http_code}','--config','-']
        onStarted: { startup.stop(); write(root.input); root.input=''; stdinEnabled=false }
        stdout: StdioCollector { id: output; waitForEnd:true }
        stderr: StdioCollector { waitForEnd:true }
        // qmllint disable signal-handler-parameters
        onExited: (code,status) => {
            startup.stop()
            if (!root.pending) return
            const separator=output.text.lastIndexOf('\n')
            const http=Number(output.text.slice(separator+1))
            if (code || status || http<200 || http>=300) {
                let message
                switch (http) {
                    case 401: case 403: message='Access denied. Check the API key and workflow-list permissions.'; break
                    case 404: message='API not found. Check the instance address and base path.'; break
                    case 301: case 302: case 303: case 307: case 308: message='The API redirected. Use its final instance address.'; break
                    default: message='Request failed or timed out. The saved list was kept.'
                }
                root.finish('',message)
                return
            }
            const json=output.text.slice(0,separator)
            try { JSON.parse(json) }
            catch (_) { root.finish('','The server returned invalid JSON. The saved list was kept.'); return }
            root.finish(json,'')
        }
        // qmllint enable signal-handler-parameters
    }
}
