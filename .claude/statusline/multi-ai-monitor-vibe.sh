#!/bin/bash
# 7AI Task Monitor Statusline - Vibe Logger版
# 7AI Team: Amp, Gemini, Qwen, Droid, Codex, Cursor, Claude

# Dependency check
check_dependencies() {
    local missing=()
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v ps >/dev/null 2>&1 || missing+=("ps")
    command -v grep >/dev/null 2>&1 || missing+=("grep")
    command -v find >/dev/null 2>&1 || missing+=("find")

    if [ ${#missing[@]} -gt 0 ]; then
        echo "⚠️ Missing: ${missing[*]}"
        return 1
    fi
    return 0
}

# Check dependencies before proceeding
check_dependencies || exit 1

# JSONからセッション情報を取得
SESSION_ID=$(echo "$1" | jq -r '.sessionId' 2>/dev/null || echo "unknown")
WORKDIR=$(echo "$1" | jq -r '.workingDirectory' 2>/dev/null || echo ".")

# 実行中のバックグラウンドプロセスを確認（7AI対応）
RUNNING_TASKS=$(ps aux | grep -E "7ai-orchestrate|7ai-full|7ai-fast|7ai-hybrid|discuss-before|slash.py run" | grep -v grep | wc -l)

if [ "$RUNNING_TASKS" -gt 0 ]; then
    # 最新のVibe Loggerファイルから状態を取得
    # Search recursively with time-based sorting (handles subdirectories like logs/vibe/20251020/)
    LATEST_LOG=$(find "$WORKDIR/logs/ai-coop" -type f -name "*.log" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    # Fallback to logs/vibe if ai-coop is empty
    if [ -z "$LATEST_LOG" ]; then
        LATEST_LOG=$(find "$WORKDIR/logs/vibe" -type f -name "*.jsonl" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
    fi

    if [ -n "$LATEST_LOG" ] && [ -f "$LATEST_LOG" ]; then
        # Validate JSON format before parsing
        if head -1 "$LATEST_LOG" 2>/dev/null | jq empty 2>/dev/null; then
            # 最後のoperationを確認
            LAST_OP=$(tail -1 "$LATEST_LOG" 2>/dev/null | jq -r '.operation' 2>/dev/null || echo "unknown")
        else
            LAST_OP="invalid_format"
        fi
    else
        LAST_OP="no_log"
    fi

    if [ "$LAST_OP" != "no_log" ] && [ "$LAST_OP" != "invalid_format" ]; then

        case "$LAST_OP" in
            *start*)
                echo "🔄 7AI: $RUNNING_TASKS tasks running"
                ;;
            *done*)
                echo "✅ 7AI: Completed"
                ;;
            *error*)
                echo "❌ 7AI: Error"
                ;;
            *)
                echo "🔄 7AI: $RUNNING_TASKS tasks active"
                ;;
        esac
    else
        echo "🔄 7AI: $RUNNING_TASKS tasks (no logs)"
    fi
else
    echo "💤 7AI: Ready"
fi
