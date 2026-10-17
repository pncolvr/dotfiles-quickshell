# Normalize named shell/QML checkpoints, QtTest cases and TAP records to TSV.
function report(status, name) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
    gsub(/[\t\r]/, " ", name)
    if (name == "") name = "Unnamed test"
    print status, mode, suite, name, log_path
    count++
    if (status == "FAIL") failures++
}
BEGIN { OFS = "\t" }
{
    # Quickshell and QtTest can decorate log prefixes with terminal colors.
    gsub(/\033\[[0-9;]*[[:alpha:]]/, "")
    line = $0
    if (line ~ /^(PASS|FAIL!|SKIP)[[:space:]]+:/) {
        status = line ~ /^PASS/ ? "PASS" : line ~ /^SKIP/ ? "SKIP" : "FAIL"
        sub(/^[^:]+:[[:space:]]*/, "", line)
        report(status, line)
    } else if (line ~ /^[[:space:]]*(not ok|ok)[[:space:]]+[0-9]+([[:space:]]|$)/) {
        status = line ~ /^[[:space:]]*not ok/ ? "FAIL" : "PASS"
        if (line ~ /#[[:space:]]*(SKIP|TODO)/) status = "SKIP"
        sub(/^[[:space:]]*(not ok|ok)[[:space:]]+[0-9]+[[:space:]]*(-[[:space:]]*)?/, "", line)
        sub(/[[:space:]]+#[[:space:]]*(SKIP|TODO).*$/, "", line)
        report(status, line)
    } else if (match(line, /(^|[[:space:]])(PASS|SKIP|([[:alnum:]_-]+[[:space:]]+)?FAIL):[[:space:]]*/)) {
        marker = substr(line, RSTART, RLENGTH)
        status = marker ~ /PASS:/ ? "PASS" : marker ~ /SKIP:/ ? "SKIP" : "FAIL"
        report(status, substr(line, RSTART + RLENGTH))
    }
}
END {
    if (exit_status != 0 && failures == 0) {
        if (exit_status == 124) report("FAIL", "Suite execution timed out after " limit " seconds")
        else report("FAIL", "Suite execution exited with status " exit_status)
    } else if (count == 0) {
        # Success without a named result violates the reporting contract.
        report("FAIL", "Suite execution produced no named test results")
    }
}
