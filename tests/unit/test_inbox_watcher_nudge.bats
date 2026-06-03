#!/usr/bin/env bats
# test_inbox_watcher_nudge.bats — inbox_watcher.sh nudge text tests
#
# T-NUDGE-001: opencode CLI のとき nudge テキストに "queue/inbox/" と "yaml を読んで" が含まれること
# T-NUDGE-002: claude CLI のとき nudge テキストが "inbox" + 数字 の形式であること
# T-NUDGE-003: gemini CLI のとき nudge テキストが "inbox" + 数字 の形式であること

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# nudge 生成ロジックをインラインで再現するヘルパー
# 引数: $1=effective_cli_type, $2=unread_count, $3=agent_id
compute_nudge() {
    local effective_cli_for_nudge="$1"
    local unread_count="$2"
    local AGENT_ID="$3"
    local nudge="inbox${unread_count}"

    if [[ "$effective_cli_for_nudge" == "opencode" ]] || [[ "$effective_cli_for_nudge" == "gemini" ]]; then
        nudge="queue/inbox/${AGENT_ID}.yaml と queue/tasks/${AGENT_ID}.yaml を Read してタスクを実行せよ。完了後 scripts/inbox_write.sh で軍師に報告すること。"
    fi

    echo "$nudge"
}

@test "T-NUDGE-001: opencode CLI のとき nudge テキストに queue/inbox/ と Read が含まれる" {
    result=$(compute_nudge "opencode" "1" "ashigaru4")
    echo "nudge: $result"
    echo "$result" | grep -q "queue/inbox/"
    echo "$result" | grep -q "Read して"
}

@test "T-NUDGE-002: claude CLI のとき nudge テキストが inbox + 数字 の形式" {
    result=$(compute_nudge "claude" "2" "ashigaru1")
    echo "nudge: $result"
    echo "$result" | grep -qE "^inbox[0-9]+$"
}

@test "T-NUDGE-003: gemini CLI のとき nudge テキストに queue/inbox/ と Read が含まれる" {
    result=$(compute_nudge "gemini" "1" "ashigaru3")
    echo "nudge: $result"
    echo "$result" | grep -q "queue/inbox/"
    echo "$result" | grep -q "Read して"
}
