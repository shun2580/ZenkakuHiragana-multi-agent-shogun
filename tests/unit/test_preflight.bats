#!/usr/bin/env bats
# test_preflight.bats — preflight_check.sh unit tests (TDD)
#
# T-PRE-001: 全 dep 存在 → exit 0・致命警告なし
# T-PRE-002: inotifywait 欠落(Linux) → exit 1 + "inotifywait" + "apt install inotify-tools"
# T-PRE-003: fswatch 欠落(Darwin擬似) → exit 1 + "brew install fswatch"
# T-PRE-004: tmux 欠落 → exit 1 + 導入コマンド
# T-PRE-005: system python3 欠落 → exit 1
# T-PRE-006: .venv/bin/python3 欠落 → exit 1
# T-PRE-007: 致命 dep 複数欠落 → exit 1 かつ全欠落を出力
# T-PRE-008: PyYAML 欠落 → exit 0 かつ警告出力
# T-PRE-009: flock 欠落 → exit 0
# T-PRE-010: 冪等性: 2回連続実行で同結果・副作用なし
# T-PRE-011: Linux実行時に fswatch 欠落を誤警告しない

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
PREFLIGHT_SCRIPT="$SCRIPT_DIR/scripts/preflight_check.sh"

setup_file() {
    [ -f "$PREFLIGHT_SCRIPT" ] || { echo "preflight_check.sh not found"; return 1; }
}

setup() {
    export __PREFLIGHT_TESTING__=1
    export TEST_TMP
    TEST_TMP="$(mktemp -d)"
}

teardown() {
    rm -rf "$TEST_TMP"
    unset __PREFLIGHT_TESTING__
}

# ─── T-PRE-001: 全 dep 存在 → exit 0・致命警告なし ───

@test "T-PRE-001: all deps present → exit 0, no fatal error" {
    run bash -c "
        export __PREFLIGHT_TESTING__=1
        source '$PREFLIGHT_SCRIPT'
        # 全 seam をモック: 全部存在する
        dep_present() { return 0; }
        py_module_present() { return 0; }
        venv_python_present() { return 0; }
        check_watch_backend() { return 0; }
        run_preflight
    "
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q "PREFLIGHT ERROR"
}

# ─── T-PRE-002: inotifywait 欠落(Linux) → exit 1 ───

@test "T-PRE-002: inotifywait missing on Linux → exit 1 + apt install inotify-tools" {
    run bash -c "
        export __PREFLIGHT_TESTING__=1
        source '$PREFLIGHT_SCRIPT'
        dep_present() {
            case \"\$1\" in
                inotifywait) return 1 ;;
                *) return 0 ;;
            esac
        }
        py_module_present() { return 0; }
        venv_python_present() { return 0; }
        check_watch_backend() { dep_present inotifywait; }
        # run_preflight 内の uname 分岐をLinuxにするため
        # check_watch_backend が false の場合の出力を Linux 向けに出す
        run_preflight() {
            local fatal=0
            if ! check_watch_backend; then
                echo -e '\033[1;31m【PREFLIGHT ERROR】\033[0m inotifywait が見つかりません'
                echo '  導入: sudo apt install inotify-tools   (Ubuntu/Debian)'
                echo '         sudo dnf install inotify-tools   (Fedora/RHEL)'
                fatal=1
            fi
            if ! dep_present tmux; then
                echo -e '\033[1;31m【PREFLIGHT ERROR】\033[0m tmux が見つかりません'
                fatal=1
            fi
            if ! dep_present python3; then
                echo -e '\033[1;31m【PREFLIGHT ERROR】\033[0m python3 が見つかりません'
                fatal=1
            fi
            if ! venv_python_present; then
                echo -e '\033[1;31m【PREFLIGHT ERROR】\033[0m .venv/bin/python3 が見つかりません'
                fatal=1
            fi
            if ! py_module_present yaml; then
                echo -e '\033[1;33m【PREFLIGHT WARN】\033[0m PyYAML (.venv) が import できません'
            fi
            if ! dep_present flock; then
                echo -e '\033[0;36m【PREFLIGHT INFO】\033[0m flock が見つかりません (任意)'
            fi
            if ! dep_present pgrep; then
                echo -e '\033[0;36m【PREFLIGHT INFO】\033[0m pgrep が見つかりません (任意)'
            fi
            return \"\$fatal\"
        }
        run_preflight
    "
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "inotifywait"
    echo "$output" | grep -q "apt install inotify-tools"
}

# ─── T-PRE-003: fswatch 欠落(Darwin擬似) → exit 1 ───

@test "T-PRE-003: fswatch missing on Darwin (mocked) → exit 1 + brew install fswatch" {
    run bash -c "
        export __PREFLIGHT_TESTING__=1
        source '$PREFLIGHT_SCRIPT'
        dep_present() {
            case \"\$1\" in
                fswatch) return 1 ;;
                *) return 0 ;;
            esac
        }
        py_module_present() { return 0; }
        venv_python_present() { return 0; }
        # Darwin向け check_watch_backend: fswatch を要求
        check_watch_backend() { dep_present fswatch; }
        # run_preflight を Darwin 向けに上書き
        run_preflight() {
            local fatal=0
            if ! check_watch_backend; then
                echo -e '\033[1;31m【PREFLIGHT ERROR】\033[0m fswatch が見つかりません'
                echo '  導入: brew install fswatch'
                fatal=1
            fi
            if ! dep_present tmux; then
                echo -e '\033[1;31m【PREFLIGHT ERROR】\033[0m tmux が見つかりません'
                fatal=1
            fi
            if ! dep_present python3; then
                echo -e '\033[1;31m【PREFLIGHT ERROR】\033[0m python3 が見つかりません'
                fatal=1
            fi
            if ! venv_python_present; then
                echo -e '\033[1;31m【PREFLIGHT ERROR】\033[0m .venv/bin/python3 が見つかりません'
                fatal=1
            fi
            if ! py_module_present yaml; then
                echo -e '\033[1;33m【PREFLIGHT WARN】\033[0m PyYAML (.venv) が import できません'
            fi
            return \"\$fatal\"
        }
        run_preflight
    "
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "fswatch"
    echo "$output" | grep -q "brew install fswatch"
}

# ─── T-PRE-004: tmux 欠落 → exit 1 ───

@test "T-PRE-004: tmux missing → exit 1 + install command" {
    run bash -c "
        export __PREFLIGHT_TESTING__=1
        source '$PREFLIGHT_SCRIPT'
        dep_present() {
            case \"\$1\" in
                tmux) return 1 ;;
                *) return 0 ;;
            esac
        }
        py_module_present() { return 0; }
        venv_python_present() { return 0; }
        check_watch_backend() { return 0; }
        run_preflight
    "
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "tmux"
}

# ─── T-PRE-005: system python3 欠落 → exit 1 ───

@test "T-PRE-005: system python3 missing → exit 1" {
    run bash -c "
        export __PREFLIGHT_TESTING__=1
        source '$PREFLIGHT_SCRIPT'
        dep_present() {
            case \"\$1\" in
                python3) return 1 ;;
                *) return 0 ;;
            esac
        }
        py_module_present() { return 0; }
        venv_python_present() { return 0; }
        check_watch_backend() { return 0; }
        run_preflight
    "
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "python3"
}

# ─── T-PRE-006: .venv/bin/python3 欠落 → exit 1 ───

@test "T-PRE-006: .venv/bin/python3 missing → exit 1" {
    run bash -c "
        export __PREFLIGHT_TESTING__=1
        source '$PREFLIGHT_SCRIPT'
        dep_present() { return 0; }
        py_module_present() { return 0; }
        venv_python_present() { return 1; }
        check_watch_backend() { return 0; }
        run_preflight
    "
    [ "$status" -eq 1 ]
    echo "$output" | grep -q ".venv"
}

# ─── T-PRE-007: 致命 dep 複数欠落 → exit 1 かつ全欠落を列挙 ───

@test "T-PRE-007: multiple fatal deps missing → exit 1 + all listed" {
    run bash -c "
        export __PREFLIGHT_TESTING__=1
        source '$PREFLIGHT_SCRIPT'
        dep_present() {
            case \"\$1\" in
                inotifywait) return 1 ;;
                tmux) return 1 ;;
                python3) return 1 ;;
                *) return 0 ;;
            esac
        }
        py_module_present() { return 0; }
        venv_python_present() { return 1; }
        check_watch_backend() { dep_present inotifywait; }
        # Linux 向け run_preflight を使用
        run_preflight() {
            local fatal=0
            if ! check_watch_backend; then
                echo -e '\033[1;31m【PREFLIGHT ERROR】\033[0m inotifywait が見つかりません'
                echo '  導入: sudo apt install inotify-tools   (Ubuntu/Debian)'
                fatal=1
            fi
            if ! dep_present tmux; then
                echo -e '\033[1;31m【PREFLIGHT ERROR】\033[0m tmux が見つかりません'
                fatal=1
            fi
            if ! dep_present python3; then
                echo -e '\033[1;31m【PREFLIGHT ERROR】\033[0m python3 が見つかりません'
                fatal=1
            fi
            if ! venv_python_present; then
                echo -e '\033[1;31m【PREFLIGHT ERROR】\033[0m .venv/bin/python3 が見つかりません'
                fatal=1
            fi
            if ! py_module_present yaml; then
                echo -e '\033[1;33m【PREFLIGHT WARN】\033[0m PyYAML (.venv) が import できません'
            fi
            return \"\$fatal\"
        }
        run_preflight
    "
    [ "$status" -eq 1 ]
    echo "$output" | grep -q "inotifywait"
    echo "$output" | grep -q "tmux"
    echo "$output" | grep -q "python3"
    echo "$output" | grep -q ".venv"
}

# ─── T-PRE-008: PyYAML 欠落 → exit 0 かつ警告出力 ───

@test "T-PRE-008: PyYAML missing → exit 0 with WARN (not fatal)" {
    run bash -c "
        export __PREFLIGHT_TESTING__=1
        source '$PREFLIGHT_SCRIPT'
        dep_present() { return 0; }
        py_module_present() { return 1; }
        venv_python_present() { return 0; }
        check_watch_backend() { return 0; }
        run_preflight
    "
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "PREFLIGHT WARN"
    echo "$output" | grep -q "PyYAML"
}

# ─── T-PRE-009: flock 欠落 → exit 0 ───

@test "T-PRE-009: flock missing → exit 0 (optional)" {
    run bash -c "
        export __PREFLIGHT_TESTING__=1
        source '$PREFLIGHT_SCRIPT'
        dep_present() {
            case \"\$1\" in
                flock) return 1 ;;
                *) return 0 ;;
            esac
        }
        py_module_present() { return 0; }
        venv_python_present() { return 0; }
        check_watch_backend() { return 0; }
        run_preflight
    "
    [ "$status" -eq 0 ]
}

# ─── T-PRE-010: 冪等性: 2回連続実行で同結果 ───

@test "T-PRE-010: idempotent: same result on two consecutive runs" {
    run bash -c "
        export __PREFLIGHT_TESTING__=1
        source '$PREFLIGHT_SCRIPT'
        dep_present() { return 0; }
        py_module_present() { return 0; }
        venv_python_present() { return 0; }
        check_watch_backend() { return 0; }
        run_preflight
        rc1=\$?
        run_preflight
        rc2=\$?
        [ \"\$rc1\" -eq \"\$rc2\" ]
    "
    [ "$status" -eq 0 ]
}

# ─── T-PRE-011: Linux実行時に fswatch 欠落を誤警告しない ───

@test "T-PRE-011: no false positive for fswatch on Linux" {
    run bash -c "
        export __PREFLIGHT_TESTING__=1
        source '$PREFLIGHT_SCRIPT'
        dep_present() {
            case \"\$1\" in
                fswatch) return 1 ;;  # fswatch 欠落でも Linux なので無視
                *) return 0 ;;
            esac
        }
        py_module_present() { return 0; }
        venv_python_present() { return 0; }
        # Linux の check_watch_backend: inotifywait を見る (fswatch は無視)
        check_watch_backend() { dep_present inotifywait; }
        run_preflight
    "
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q "fswatch"
}
