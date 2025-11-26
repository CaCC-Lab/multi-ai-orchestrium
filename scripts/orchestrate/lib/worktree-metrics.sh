#!/usr/bin/env bash
# worktree-metrics.sh - メトリクス収集と分析
# 責務：実行時間、リソース、成功率の自動収集・分析
# Phase 2.1.3実装

set -euo pipefail

# ============================================================================
# 依存関係のロード
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# VibeLoggerのロード
if [[ -f "$SCRIPT_DIR/../../../bin/vibe-logger-lib.sh" ]]; then
    source "$SCRIPT_DIR/../../../bin/vibe-logger-lib.sh"
fi

# worktree-history.shのロード
if [[ -f "$SCRIPT_DIR/worktree-history.sh" ]]; then
    source "$SCRIPT_DIR/worktree-history.sh"
fi

# プロジェクトルートの検出
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

# ============================================================================
# 設定
# ============================================================================

# メトリクスログディレクトリ
METRICS_LOG_DIR="${PROJECT_ROOT}/logs/worktree-metrics"

# メトリクスファイルパス
METRICS_FILE="$METRICS_LOG_DIR/metrics.ndjson"

# ============================================================================
# リソース収集関数
# ============================================================================

# 現在のシステムリソース使用量を取得
get_current_resource_usage() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # ディスク使用量（worktreesディレクトリ）
    local disk_usage=0
    if [[ -d "$PROJECT_ROOT/worktrees" ]]; then
        disk_usage=$(du -sb "$PROJECT_ROOT/worktrees" 2>/dev/null | cut -f1 || echo 0)
    fi

    # メモリ使用量（KB）
    local mem_usage
    mem_usage=$(free -k | awk '/^Mem:/ {print $3}')

    # メモリ合計（KB）
    local mem_total
    mem_total=$(free -k | awk '/^Mem:/ {print $2}')

    # CPU負荷（1分平均）
    local cpu_load
    cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')

    # JSON出力
    cat << EOF
{"timestamp":"$timestamp","disk_usage_bytes":$disk_usage,"memory_usage_kb":$mem_usage,"memory_total_kb":$mem_total,"cpu_load_1min":$cpu_load}
EOF
}

# リソース使用量を記録
record_resource_usage() {
    local label="${1:-general}"

    mkdir -p "$METRICS_LOG_DIR"

    local resource_json
    resource_json=$(get_current_resource_usage)

    echo "{\"event\":\"resource_snapshot\",\"label\":\"$label\",${resource_json#\{}" >> "$METRICS_FILE"

    return 0
}

# ============================================================================
# 実行時間メトリクス関数
# ============================================================================

# ワークフロー別平均実行時間を取得
get_workflow_avg_duration() {
    local workflow="$1"
    local days="${2:-7}"

    local total_duration=0
    local count=0

    for d in $(seq 0 $days); do
        local check_date
        check_date=$(date -d "$d days ago" +%Y%m%d)
        local history_file="$PROJECT_ROOT/logs/worktree-history/$check_date/history.ndjson"

        if [[ -f "$history_file" ]]; then
            while IFS= read -r line; do
                if echo "$line" | grep -q "\"event\":\"execution_end\"" && \
                   echo "$line" | grep -q "\"workflow_id\":\"$workflow"; then
                    local duration
                    duration=$(echo "$line" | grep -o '"duration":[0-9]*' | cut -d':' -f2)
                    total_duration=$((total_duration + duration))
                    count=$((count + 1))
                fi
            done < "$history_file"
        fi
    done

    if [[ $count -gt 0 ]]; then
        echo "$((total_duration / count))"
    else
        echo "0"
    fi
}

# AI別平均実行時間を取得
get_ai_avg_duration() {
    local ai="$1"
    local days="${2:-7}"

    local total_duration=0
    local count=0

    for d in $(seq 0 $days); do
        local check_date
        check_date=$(date -d "$d days ago" +%Y%m%d)
        local state_file="$PROJECT_ROOT/logs/worktree-states/$check_date/states.ndjson"

        if [[ -f "$state_file" ]]; then
            local creating_time=""
            while IFS= read -r line; do
                if echo "$line" | grep -q "\"ai\":\"$ai\""; then
                    local state
                    state=$(echo "$line" | grep -o '"state":"[^"]*"' | cut -d'"' -f4)
                    local timestamp
                    timestamp=$(echo "$line" | grep -o '"timestamp":"[^"]*"' | cut -d'"' -f4)

                    if [[ "$state" == "creating" ]]; then
                        creating_time="$timestamp"
                    elif [[ "$state" == "cleaning" ]] && [[ -n "$creating_time" ]]; then
                        local start_sec
                        start_sec=$(date -d "$creating_time" +%s 2>/dev/null || echo 0)
                        local end_sec
                        end_sec=$(date -d "$timestamp" +%s 2>/dev/null || echo 0)

                        if [[ $start_sec -gt 0 ]] && [[ $end_sec -gt 0 ]]; then
                            local duration=$((end_sec - start_sec))
                            total_duration=$((total_duration + duration))
                            count=$((count + 1))
                        fi

                        creating_time=""
                    fi
                fi
            done < "$state_file"
        fi
    done

    if [[ $count -gt 0 ]]; then
        echo "$((total_duration / count))"
    else
        echo "0"
    fi
}

# ============================================================================
# 成功率メトリクス関数
# ============================================================================

# ワークフロー別成功率を取得
get_workflow_success_rate() {
    local workflow="$1"
    local days="${2:-7}"

    local success_count=0
    local total_count=0

    for d in $(seq 0 $days); do
        local check_date
        check_date=$(date -d "$d days ago" +%Y%m%d)
        local history_file="$PROJECT_ROOT/logs/worktree-history/$check_date/history.ndjson"

        if [[ -f "$history_file" ]]; then
            while IFS= read -r line; do
                if echo "$line" | grep -q "\"event\":\"execution_end\"" && \
                   echo "$line" | grep -q "\"workflow_id\":\"$workflow"; then
                    total_count=$((total_count + 1))

                    if echo "$line" | grep -q '"status":"success"'; then
                        success_count=$((success_count + 1))
                    fi
                fi
            done < "$history_file"
        fi
    done

    if [[ $total_count -gt 0 ]]; then
        echo "$((success_count * 100 / total_count))"
    else
        echo "0"
    fi
}

# 日別成功率トレンドを取得
get_daily_success_trend() {
    local days="${1:-30}"

    echo "["
    local first=true

    for d in $(seq $days -1 0); do
        local check_date
        check_date=$(date -d "$d days ago" +%Y%m%d)
        local history_file="$PROJECT_ROOT/logs/worktree-history/$check_date/history.ndjson"

        local success_count=0
        local total_count=0

        if [[ -f "$history_file" ]]; then
            while IFS= read -r line; do
                if echo "$line" | grep -q "\"event\":\"execution_end\""; then
                    total_count=$((total_count + 1))

                    if echo "$line" | grep -q '"status":"success"'; then
                        success_count=$((success_count + 1))
                    fi
                fi
            done < "$history_file"
        fi

        local success_rate=0
        if [[ $total_count -gt 0 ]]; then
            success_rate=$((success_count * 100 / total_count))
        fi

        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi

        printf '{"date":"%s","success_rate":%d,"total":%d}' "$check_date" "$success_rate" "$total_count"
    done

    echo "]"
}

# ============================================================================
# 統合メトリクスレポート生成
# ============================================================================

# 全メトリクスを収集してJSON形式で出力
generate_metrics_summary() {
    local days="${1:-7}"

    local current_resources
    current_resources=$(get_current_resource_usage)

    local full_orchestrate_avg
    full_orchestrate_avg=$(get_workflow_avg_duration "multi-ai-full-orchestrate" "$days")

    local qwen_avg
    qwen_avg=$(get_ai_avg_duration "qwen" "$days")

    local daily_trend
    daily_trend=$(get_daily_success_trend "$days")

    cat << EOF
{
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "date_range_days": $days,
  "current_resources": $current_resources,
  "workflow_metrics": {
    "multi_ai_full_orchestrate_avg_sec": $full_orchestrate_avg
  },
  "ai_metrics": {
    "qwen_avg_sec": $qwen_avg
  },
  "success_trend": $daily_trend
}
EOF
}

# エクスポート
export -f get_current_resource_usage
export -f record_resource_usage
export -f get_workflow_avg_duration
export -f get_ai_avg_duration
export -f get_workflow_success_rate
export -f get_daily_success_trend
export -f generate_metrics_summary
