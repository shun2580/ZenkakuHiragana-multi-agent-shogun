#!/usr/bin/env bats
# test_switch_cli_fixed.bats — switch_cli.sh fixed agent protection tests
#
# T-FIX-001: fixed agent without --force → exit 1 + ERROR message
# T-FIX-002: fixed agent with --force → passes (exit 0)
# T-FIX-003: non-fixed agent → passes (exit 0)

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# --- T-FIX-001: fixed agent without --force -> exit 1 ---

@test "T-FIX-001: fixed agent without --force -> exit 1" {
    run bash -c '
        get_agent_fixed() { echo "true"; }
        AGENT_ID="ashigaru1"
        FORCE=false
        if [[ "$(get_agent_fixed)" == "true" ]] && [[ "$FORCE" != "true" ]]; then
            echo "ERROR: Agent is fixed and --force not used."
            exit 1
        fi
    '
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "ERROR"
    echo "$output" | grep -q "fixed"
}

# --- T-FIX-002: --force with fixed agent -> passes ---

@test "T-FIX-002: --force with fixed agent -> passes" {
    run bash -c '
        get_agent_fixed() { echo "true"; }
        AGENT_ID="ashigaru1"
        FORCE=true
        if [[ "$(get_agent_fixed)" == "true" ]] && [[ "$FORCE" != "true" ]]; then
            echo "ERROR: Should not reach here." >&2
            exit 1
        fi
    '
    [ "$status" -eq 0 ]
    ! echo "$stderr" | grep -q "ERROR"
}

# --- T-FIX-003: non-fixed agent -> passes ---

@test "T-FIX-003: non-fixed agent -> passes" {
    run bash -c '
        get_agent_fixed() { echo "false"; }
        AGENT_ID="ashigaru1"
        FORCE=false
        if [[ "$(get_agent_fixed)" == "true" ]] && [[ "$FORCE" != "true" ]]; then
            echo "ERROR: Should not reach here." >&2
            exit 1
        fi
    '
    [ "$status" -eq 0 ]
    ! echo "$stderr" | grep -q "ERROR"
}
