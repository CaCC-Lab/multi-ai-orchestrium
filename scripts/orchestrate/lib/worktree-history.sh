#!/usr/bin/env bash
# worktree-history.sh - 実行履歴追跡
# 責務：Worktree実行履歴の記録、照会、可視化
# Phase 2.1.2実装

set -euo pipefail

# ============================================================================
# 依存関係のロード
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# VibeLoggerのロード
if [[ -f "$SCRIPT_DIR/../../../bin/vibe-logger-lib.sh" ]]; then
    source "$SCRIPT_DIR/../../../bin/vibe-logger-lib.sh"
fi

# worktree-state.shのロード（状態照会に使用）
if [[ -f "$SCRIPT_DIR/worktree-state.sh" ]]; then
    source "$SCRIPT_DIR/worktree-state.sh"
fi

# プロジェクトルートの検出
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

# ============================================================================
# 設定
# ============================================================================

# 履歴ログディレクトリ
HISTORY_LOG_DIR="${PROJECT_ROOT}/logs/worktree-history"

# ============================================================================
# 履歴ファイル管理
# ============================================================================

# 履歴ファイルパスを取得
# Usage: get_history_file_path [date_string]
get_history_file_path() {
    local date_string="${1:-$(date +%Y%m%d)}"
    local history_dir="$HISTORY_LOG_DIR/$date_string"
    
    # ディレクトリ作成
    mkdir -p "$history_dir"
    
    echo "$history_dir/history.ndjson"
}

# ============================================================================
# 履歴記録関数
# ============================================================================

# 実行開始を記録
# Usage: record_worktree_execution_start <workflow_id> <task> <ais_json_array>
# Example: record_worktree_execution_start "multi-ai-full-orchestrate-1234" "新機能実装" '["claude","gemini","qwen"]'
record_worktree_execution_start() {
    local workflow_id="$1"
    local task="$2"
    local ais_json="$3"  # JSON配列形式: '["ai1","ai2"]'
    
    # タスクのエスケープ処理（JSONとして安全に）
    local escaped_task
    escaped_task=$(echo "$task" | sed 's/\\/\\\\/g; s/"/\\"/g')
    
    # タイムスタンプ（ISO 8601形式）
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # 履歴ファイルパス
    local history_file
    history_file=$(get_history_file_path)
    
    # NDJSON形式で記録
    cat >> "$history_file" << EOF
{"timestamp":"$timestamp","event":"execution_start","workflow_id":"$workflow_id","task":"$escaped_task","ais":$ais_json}
EOF
    
    # VibeLogger統合
    if command -v vibe_log >/dev/null 2>&1; then
        local metadata
        metadata=$(cat << VIBEEOF
{
  "workflow_id": "$workflow_id",
  "task": "$escaped_task",
  "ais": $ais_json,
  "timestamp": "$timestamp"
}
VIBEEOF
)
        vibe_log "worktree.execution.start" "workflow_execution" "$metadata" \
            "Worktree実行開始: $workflow_id" \
            "create_worktrees,execute_ais,track_progress" \
            "Worktree-History"
    fi
    
    # 標準ログ出力
    if command -v log_info >/dev/null 2>&1; then
        log_info "📝 履歴記録: 実行開始 - $workflow_id"
    fi
    
    return 0
}

# 実行終了を記録
# Usage: record_worktree_execution_end <workflow_id> <status> <duration_seconds> <metrics_json>
# Example: record_worktree_execution_end "multi-ai-full-orchestrate-1234" "success" 323 '{"worktrees_created":3,"errors":0}'
record_worktree_execution_end() {
    local workflow_id="$1"
    local status="$2"  # "success" | "failure" | "partial"
    local duration="$3"  # 秒数
    local metrics_json="$4"  # JSON形式のメトリクス: '{"key":"value"}'
    
    # タイムスタンプ（ISO 8601形式）
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # 履歴ファイルパス
    local history_file
    history_file=$(get_history_file_path)
    
    # NDJSON形式で記録
    cat >> "$history_file" << EOF
{"timestamp":"$timestamp","event":"execution_end","workflow_id":"$workflow_id","status":"$status","duration":$duration,"metrics":$metrics_json}
EOF
    
    # VibeLogger統合
    if command -v vibe_log >/dev/null 2>&1; then
        local metadata
        metadata=$(cat << VIBEEOF
{
  "workflow_id": "$workflow_id",
  "status": "$status",
  "duration": $duration,
  "metrics": $metrics_json,
  "timestamp": "$timestamp"
}
VIBEEOF
)
        vibe_log "worktree.execution.end" "workflow_execution" "$metadata" \
            "Worktree実行終了: $workflow_id ($status, ${duration}s)" \
            "cleanup_worktrees,generate_report,update_metrics" \
            "Worktree-History"
    fi
    
    # 標準ログ出力
    if command -v log_info >/dev/null 2>&1; then
        log_info "📝 履歴記録: 実行終了 - $workflow_id ($status, ${duration}s)"
    fi
    
    # Phase 2.1.3: メトリクス収集フック
    if command -v metrics_hook_execution_completed >/dev/null 2>&1; then
        metrics_hook_execution_completed "$workflow_id" "$duration" "$status"
    fi
    
    return 0
}

# ============================================================================
# 履歴クエリ関数
# ============================================================================

# 実行履歴をクエリ
# Usage: query_execution_history [date] [ai] [workflow] [status]
# Example: query_execution_history "20251108" "qwen" "multi-ai-full-orchestrate" "success"
#          query_execution_history "20251108" "" "" "failure"  # 日付のみでフィルタ
query_execution_history() {
    local date="${1:-$(date +%Y%m%d)}"
    local ai="${2:-}"
    local workflow="${3:-}"
    local status="${4:-}"
    
    local history_file
    history_file=$(get_history_file_path "$date")
    
    # ファイル存在チェック
    if [[ ! -f "$history_file" ]]; then
        if command -v log_warn >/dev/null 2>&1; then
            log_warn "履歴ファイルが存在しません: $history_file"
        fi
        return 1
    fi
    
    # フィルタ処理（grep連鎖）
    local result
    result=$(cat "$history_file")
    
    # AIフィルタ
    if [[ -n "$ai" ]]; then
        result=$(echo "$result" | grep "\"$ai\"" || true)
    fi
    
    # ワークフローフィルタ
    if [[ -n "$workflow" ]]; then
        result=$(echo "$result" | grep "\"workflow_id\":\"$workflow" || true)
    fi
    
    # ステータスフィルタ
    if [[ -n "$status" ]]; then
        result=$(echo "$result" | grep "\"status\":\"$status\"" || true)
    fi
    
    # 結果出力
    if [[ -n "$result" ]]; then
        echo "$result"
        return 0
    else
        if command -v log_info >/dev/null 2>&1; then
            log_info "クエリ条件に一致する履歴が見つかりません"
        fi
        return 1
    fi
}

# 実行統計を取得
# Usage: get_execution_statistics [date_range_start] [date_range_end]
# Example: get_execution_statistics "20251101" "20251108"
get_execution_statistics() {
    local start_date="${1:-$(date -d '7 days ago' +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d 2>/dev/null || date +%Y%m%d)}"
    local end_date="${2:-$(date +%Y%m%d)}"
    
    # 日付範囲内の全履歴ファイルを収集
    local total_executions=0
    local success_count=0
    local failure_count=0
    local partial_count=0
    local total_duration=0
    local total_worktrees=0
    
    # 日付ループ（シンプルな実装：YYYYMMDDディレクトリをスキャン）
    for history_dir in "$HISTORY_LOG_DIR"/*; do
        if [[ ! -d "$history_dir" ]]; then
            continue
        fi
        
        local dir_date
        dir_date=$(basename "$history_dir")
        
        # 日付範囲チェック（文字列比較で十分）
        if [[ "$dir_date" < "$start_date" || "$dir_date" > "$end_date" ]]; then
            continue
        fi
        
        local history_file="$history_dir/history.ndjson"
        if [[ ! -f "$history_file" ]]; then
            continue
        fi
        
        # execution_endイベントのみをカウント
        while IFS= read -r line; do
            if echo "$line" | grep -q '"event":"execution_end"'; then
                total_executions=$((total_executions + 1))
                
                # ステータスカウント
                if echo "$line" | grep -q '"status":"success"'; then
                    success_count=$((success_count + 1))
                elif echo "$line" | grep -q '"status":"failure"'; then
                    failure_count=$((failure_count + 1))
                elif echo "$line" | grep -q '"status":"partial"'; then
                    partial_count=$((partial_count + 1))
                fi
                
                # duration抽出
                local duration
                duration=$(echo "$line" | grep -o '"duration":[0-9]*' | cut -d':' -f2 || echo "0")
                total_duration=$((total_duration + duration))
                
                # worktrees_created抽出
                local worktrees
                worktrees=$(echo "$line" | grep -o '"worktrees_created":[0-9]*' | cut -d':' -f2 || echo "0")
                total_worktrees=$((total_worktrees + worktrees))
            fi
        done < "$history_file"
    done
    
    # 統計計算
    local avg_duration=0
    if [[ $total_executions -gt 0 ]]; then
        avg_duration=$((total_duration / total_executions))
    fi
    
    local success_rate="0.00"
    if [[ $total_executions -gt 0 ]]; then
        success_rate=$(echo "scale=2; $success_count * 100 / $total_executions" | bc)
        success_rate=$(printf "%.2f" "$success_rate")
    fi
    
    # JSON形式で出力
    cat << EOF
{
  "date_range": {
    "start": "$start_date",
    "end": "$end_date"
  },
  "total_executions": $total_executions,
  "status": {
    "success": $success_count,
    "failure": $failure_count,
    "partial": $partial_count
  },
  "success_rate": "$success_rate",
  "duration": {
    "total_seconds": $total_duration,
    "average_seconds": $avg_duration
  },
  "worktrees": {
    "total_created": $total_worktrees
  }
}
EOF
}

# ============================================================================
# 履歴可視化関数
# ============================================================================

# 履歴レポート生成
# Usage: generate_history_report [date_range_start] [date_range_end] [format]
# Example: generate_history_report "20251101" "20251108" "markdown"
#          generate_history_report "20251101" "20251108" "json"
#          generate_history_report "20251101" "20251108" "html"
generate_history_report() {
    local start_date="${1:-$(date -d '7 days ago' +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d 2>/dev/null || date +%Y%m%d)}"
    local end_date="${2:-$(date +%Y%m%d)}"
    local format="${3:-markdown}"  # "json" | "markdown" | "html"
    
    # 統計取得
    local stats
    stats=$(get_execution_statistics "$start_date" "$end_date")
    
    case "$format" in
        "json")
            # JSON形式で出力
            echo "$stats"
            ;;
        "markdown")
            # Markdown形式で出力
            local total_executions
            total_executions=$(echo "$stats" | grep -o '"total_executions":[0-9]*' | cut -d':' -f2)
            local success_count
            success_count=$(echo "$stats" | grep -o '"success":[0-9]*' | head -n1 | cut -d':' -f2)
            local failure_count
            failure_count=$(echo "$stats" | grep -o '"failure":[0-9]*' | head -n1 | cut -d':' -f2)
            local partial_count
            partial_count=$(echo "$stats" | grep -o '"partial":[0-9]*' | head -n1 | cut -d':' -f2)
            local success_rate
            success_rate=$(echo "$stats" | grep -o '"success_rate":"[0-9.]*"' | cut -d'"' -f4)
            local total_duration
            total_duration=$(echo "$stats" | grep -o '"total_seconds":[0-9]*' | cut -d':' -f2)
            local avg_duration
            avg_duration=$(echo "$stats" | grep -o '"average_seconds":[0-9]*' | cut -d':' -f2)
            local total_worktrees
            total_worktrees=$(echo "$stats" | grep -o '"total_created":[0-9]*' | cut -d':' -f2)
            
            cat << EOF
# Worktree実行履歴レポート

**期間**: $start_date - $end_date

## 実行統計

| 指標 | 値 |
|------|-----|
| 総実行回数 | $total_executions |
| 成功 | $success_count |
| 失敗 | $failure_count |
| 部分成功 | $partial_count |
| **成功率** | **${success_rate}%** |

## パフォーマンス

| 指標 | 値 |
|------|-----|
| 総実行時間 | ${total_duration}秒 |
| 平均実行時間 | ${avg_duration}秒 |
| 総Worktree作成数 | $total_worktrees |

## 詳細ログ

詳細な実行ログは以下のディレクトリに保存されています：
\`\`\`
$HISTORY_LOG_DIR/$start_date/ - $HISTORY_LOG_DIR/$end_date/
\`\`\`

## クエリ例

\`\`\`bash
# 特定日の全履歴
query_execution_history "20251108"

# 特定AIの履歴
query_execution_history "20251108" "qwen"

# 失敗した実行のみ
query_execution_history "20251108" "" "" "failure"
\`\`\`
EOF
            ;;
        "html")
            # HTML形式で出力
            local total_executions
            total_executions=$(echo "$stats" | grep -o '"total_executions":[0-9]*' | cut -d':' -f2)
            local success_count
            success_count=$(echo "$stats" | grep -o '"success":[0-9]*' | head -n1 | cut -d':' -f2)
            local failure_count
            failure_count=$(echo "$stats" | grep -o '"failure":[0-9]*' | head -n1 | cut -d':' -f2)
            local partial_count
            partial_count=$(echo "$stats" | grep -o '"partial":[0-9]*' | head -n1 | cut -d':' -f2)
            local success_rate
            success_rate=$(echo "$stats" | grep -o '"success_rate":"[0-9.]*"' | cut -d'"' -f4)
            local total_duration
            total_duration=$(echo "$stats" | grep -o '"total_seconds":[0-9]*' | cut -d':' -f2)
            local avg_duration
            avg_duration=$(echo "$stats" | grep -o '"average_seconds":[0-9]*' | cut -d':' -f2)
            local total_worktrees
            total_worktrees=$(echo "$stats" | grep -o '"total_created":[0-9]*' | cut -d':' -f2)
            
            cat << EOF
<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Worktree実行履歴レポート</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .stat-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; }
        .stat-card.success { background: linear-gradient(135deg, #11998e 0%, #38ef7d 100%); }
        .stat-card.failure { background: linear-gradient(135deg, #ee0979 0%, #ff6a00 100%); }
        .stat-value { font-size: 2em; font-weight: bold; margin: 10px 0; }
        .stat-label { font-size: 0.9em; opacity: 0.9; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #3498db; color: white; font-weight: bold; }
        tr:hover { background-color: #f5f5f5; }
        .period { background-color: #ecf0f1; padding: 10px; border-radius: 4px; margin: 20px 0; }
        code { background-color: #f4f4f4; padding: 2px 6px; border-radius: 3px; font-family: monospace; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Worktree実行履歴レポート</h1>
        
        <div class="period">
            <strong>📅 期間:</strong> $start_date - $end_date
        </div>
        
        <h2>📊 実行統計</h2>
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-label">総実行回数</div>
                <div class="stat-value">$total_executions</div>
            </div>
            <div class="stat-card success">
                <div class="stat-label">成功</div>
                <div class="stat-value">$success_count</div>
            </div>
            <div class="stat-card failure">
                <div class="stat-label">失敗</div>
                <div class="stat-value">$failure_count</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">成功率</div>
                <div class="stat-value">${success_rate}%</div>
            </div>
        </div>
        
        <h2>⚡ パフォーマンス</h2>
        <table>
            <tr>
                <th>指標</th>
                <th>値</th>
            </tr>
            <tr>
                <td>総実行時間</td>
                <td>${total_duration}秒</td>
            </tr>
            <tr>
                <td>平均実行時間</td>
                <td>${avg_duration}秒</td>
            </tr>
            <tr>
                <td>総Worktree作成数</td>
                <td>$total_worktrees</td>
            </tr>
        </table>
        
        <h2>📂 詳細ログ</h2>
        <p>詳細な実行ログは以下のディレクトリに保存されています：</p>
        <code>$HISTORY_LOG_DIR/$start_date/ - $HISTORY_LOG_DIR/$end_date/</code>
    </div>
</body>
</html>
EOF
            ;;
        *)
            if command -v log_error >/dev/null 2>&1; then
                log_error "サポートされていないフォーマット: $format"
            fi
            return 1
            ;;
    esac
}

# 成功率トレンドを取得
# Usage: get_success_rate_trend [date_range_start] [date_range_end]
# Example: get_success_rate_trend "20251101" "20251108"
get_success_rate_trend() {
    local start_date="${1:-$(date -d '7 days ago' +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d 2>/dev/null || date +%Y%m%d)}"
    local end_date="${2:-$(date +%Y%m%d)}"
    
    echo "{"
    echo "  \"trend\": ["
    
    local first=true
    
    # 日付ループ
    for history_dir in "$HISTORY_LOG_DIR"/*; do
        if [[ ! -d "$history_dir" ]]; then
            continue
        fi
        
        local dir_date
        dir_date=$(basename "$history_dir")
        
        # 日付範囲チェック
        if [[ "$dir_date" < "$start_date" || "$dir_date" > "$end_date" ]]; then
            continue
        fi
        
        local history_file="$history_dir/history.ndjson"
        if [[ ! -f "$history_file" ]]; then
            continue
        fi
        
        # その日の統計計算
        local day_total=0
        local day_success=0
        
        while IFS= read -r line; do
            if echo "$line" | grep -q '"event":"execution_end"'; then
                day_total=$((day_total + 1))
                
                if echo "$line" | grep -q '"status":"success"'; then
                    day_success=$((day_success + 1))
                fi
            fi
        done < "$history_file"
        
        # 成功率計算
        local day_success_rate="0.00"
        if [[ $day_total -gt 0 ]]; then
            day_success_rate=$(echo "scale=2; $day_success * 100 / $day_total" | bc)
            day_success_rate=$(printf "%.2f" "$day_success_rate")
        fi
        
        # JSON出力（カンマ処理）
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        
        echo -n "    {\"date\":\"$dir_date\",\"success_rate\":\"$day_success_rate\",\"total\":$day_total,\"success\":$day_success}"
    done
    
    echo ""
    echo "  ]"
    echo "}"
}

# ============================================================================
# 関数エクスポート
# ============================================================================

export -f get_history_file_path
export -f record_worktree_execution_start
export -f record_worktree_execution_end
export -f query_execution_history
export -f get_execution_statistics
export -f generate_history_report
export -f get_success_rate_trend

# ライブラリロード完了フラグ
export WORKTREE_HISTORY_LIB_LOADED=1

# デバッグモード時のログ
if [[ "${WORKTREE_HISTORY_DEBUG:-0}" == "1" ]]; then
    echo "[Worktree-History] Library loaded: $HISTORY_LOG_DIR" >&2
fi
