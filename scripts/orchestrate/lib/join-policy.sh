#!/usr/bin/env bash
# JOIN待機ポリシー実装
# Purpose: AsyncThink Phase 2, Week 15-16
# Responsibilities:
#   - Eager Policy: ブロッキング待機（現行互換）
#   - Lazy Policy: 最初完了優先
#   - Hybrid Policy: Qwen優先 + Droidタイムアウト付き（推奨）
#
# Dependencies:
#   - lib/multi-ai-core.sh (logging)
#
# Usage:
#   source scripts/orchestrate/lib/join-policy.sh
#   join_policy_hybrid $qwen_pid $droid_pid "$temp_file_qwen" "$temp_file_droid" 300

set -euo pipefail

# ============================================================================
# JOIN待機ポリシー（3種類）
# ============================================================================

# Eager Policy: ブロッキング待機（現行互換）
# 両方のタスクが完了するまで待機
#
# Args:
#   $1 - qwen_pid: QwenプロセスID
#   $2 - droid_pid: DroidプロセスID
#   $3 - qwen_output_file: Qwen結果ファイルパス
#   $4 - droid_output_file: Droid結果ファイルパス
#   $5 - qwen_start: Qwen開始時刻（epoch秒）
#   $6 - droid_start: Droid開始時刻（epoch秒）
#
# Returns:
#   0: 両方成功
#   1: 少なくとも1つ失敗
join_policy_eager() {
    local qwen_pid=$1
    local droid_pid=$2
    local qwen_output_file=$3
    local droid_output_file=$4
    local qwen_start=$5
    local droid_start=$6

    log_info "🔗 JOIN Policy: Eager (blocking)"

    # JOIN-1: Qwen完了待ち
    log_info "🔗 JOIN-1: Waiting for Qwen (blocking)..."
    wait $qwen_pid
    local qwen_exit=$?
    local qwen_end=$(date +%s)
    local qwen_duration=$((qwen_end - qwen_start))

    if [[ $qwen_exit -eq 0 ]]; then
        log_info "✅ Qwen completed in ${qwen_duration}s"
    else
        log_error "❌ Qwen failed (exit code: $qwen_exit)"
    fi

    # JOIN-2: Droid完了待ち
    log_info "🔗 JOIN-2: Waiting for Droid (blocking)..."
    wait $droid_pid
    local droid_exit=$?
    local droid_end=$(date +%s)
    local droid_duration=$((droid_end - droid_start))

    if [[ $droid_exit -eq 0 ]]; then
        log_info "✅ Droid completed in ${droid_duration}s"
    else
        log_error "❌ Droid failed (exit code: $droid_exit)"
    fi

    # メトリクス計算
    local total_duration=$((droid_end - qwen_start))
    local critical_path=$((droid_duration > qwen_duration ? droid_duration : qwen_duration))
    local parallelism_efficiency=$(echo "scale=2; ($qwen_duration + $droid_duration) / $total_duration" | bc)

    log_info "📊 Eager Policy Metrics:"
    log_info "  - Qwen duration: ${qwen_duration}s"
    log_info "  - Droid duration: ${droid_duration}s"
    log_info "  - Total wall-clock time: ${total_duration}s"
    log_info "  - Critical-Path: ${critical_path}s"
    log_info "  - Parallelism efficiency: $parallelism_efficiency"

    # 成功判定
    if [[ $qwen_exit -eq 0 && $droid_exit -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Lazy Policy: 最初完了優先
# 最初に完了したタスクの結果を使って次フェーズ開始
#
# Args:
#   同上
#
# Returns:
#   0: 少なくとも1つ成功
#   1: 両方失敗
join_policy_lazy() {
    local qwen_pid=$1
    local droid_pid=$2
    local qwen_output_file=$3
    local droid_output_file=$4
    local qwen_start=$5
    local droid_start=$6

    log_info "🔗 JOIN Policy: Lazy (first-completed priority)"

    # wait -nの可用性チェック
    if ! command -v wait &> /dev/null || [[ $BASH_VERSION < 4.3 ]]; then
        log_warning "⚠️ Bash version < 4.3, 'wait -n' not supported. Falling back to Eager policy..."
        join_policy_eager $qwen_pid $droid_pid "$qwen_output_file" "$droid_output_file" $qwen_start $droid_start
        return $?
    fi

    # JOIN-ANY: 最初に完了したプロセスを待つ
    log_info "🔗 JOIN-ANY: Waiting for first completion..."

    # Bashの制約: wait -nは直接PIDs指定できないため、while loopで実装
    local first_completed_pid=""
    local first_exit_code=0
    local first_completion_time=0

    while true; do
        # Qwenプロセスをチェック
        if ! kill -0 $qwen_pid 2>/dev/null; then
            # Qwen完了
            wait $qwen_pid
            first_exit_code=$?
            first_completed_pid=$qwen_pid
            first_completion_time=$(date +%s)
            log_info "🏁 Qwen completed first!"
            break
        fi

        # Droidプロセスをチェック
        if ! kill -0 $droid_pid 2>/dev/null; then
            # Droid完了
            wait $droid_pid
            first_exit_code=$?
            first_completed_pid=$droid_pid
            first_completion_time=$(date +%s)
            log_info "🏁 Droid completed first (unexpected)!"
            break
        fi

        # 100msスリープ
        sleep 0.1
    done

    # 最初完了タスクの結果を使って次フェーズ開始
    if [[ $first_completed_pid == $qwen_pid ]]; then
        local qwen_duration=$((first_completion_time - qwen_start))
        log_info "✅ Qwen completed in ${qwen_duration}s, starting next phase..."
        # start_next_phase "$qwen_output_file"（Phase 3で実装）
    else
        local droid_duration=$((first_completion_time - droid_start))
        log_info "✅ Droid completed in ${droid_duration}s, starting next phase..."
        # start_next_phase "$droid_output_file"（Phase 3で実装）
    fi

    # 残りのプロセスも待つ
    log_info "🔗 JOIN-REMAINING: Waiting for remaining process..."
    if [[ $first_completed_pid == $qwen_pid ]]; then
        wait $droid_pid
        local droid_exit=$?
        local droid_end=$(date +%s)
        local droid_duration=$((droid_end - droid_start))
        log_info "✅ Droid completed in ${droid_duration}s"
    else
        wait $qwen_pid
        local qwen_exit=$?
        local qwen_end=$(date +%s)
        local qwen_duration=$((qwen_end - qwen_start))
        log_info "✅ Qwen completed in ${qwen_duration}s"
    fi

    # メトリクス計算
    local total_duration=$(($(date +%s) - qwen_start))
    local parallelism_efficiency=$(echo "scale=2; ($qwen_duration + $droid_duration) / $total_duration" | bc)

    log_info "📊 Lazy Policy Metrics:"
    log_info "  - First completion time: $first_completion_time"
    log_info "  - Total wall-clock time: ${total_duration}s"
    log_info "  - Parallelism efficiency: $parallelism_efficiency"

    # 成功判定（少なくとも1つ成功）
    if [[ ${qwen_exit:-$first_exit_code} -eq 0 ]] || [[ ${droid_exit:-$first_exit_code} -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Hybrid Policy: Qwen優先 + Droidタイムアウト付き（推奨）
# Qwen完了後即座に次フェーズ開始、Droidはタイムアウト付き待機
#
# Args:
#   同上
#   $7 - droid_timeout: Droidタイムアウト秒数（デフォルト: 300）
#
# Returns:
#   0: Qwen成功 または 両方成功
#   1: Qwen失敗かつDroid失敗/タイムアウト
join_policy_hybrid() {
    local qwen_pid=$1
    local droid_pid=$2
    local qwen_output_file=$3
    local droid_output_file=$4
    local qwen_start=$5
    local droid_start=$6
    local droid_timeout=${7:-300}

    log_info "🔗 JOIN Policy: Hybrid (Qwen-priority + Droid-timeout)"
    log_info "  - Droid timeout: ${droid_timeout}s"

    # JOIN-1: Qwen完了待ち（優先）
    log_info "🔗 JOIN-1: Waiting for Qwen (priority)..."
    wait $qwen_pid
    local qwen_exit=$?
    local qwen_end=$(date +%s)
    local qwen_duration=$((qwen_end - qwen_start))

    local fallback_to_droid=false

    if [[ $qwen_exit -eq 0 ]]; then
        log_info "✅ Qwen completed successfully in ${qwen_duration}s, starting next phase..."
        # start_next_phase "$qwen_output_file"（Phase 3で実装）
    else
        log_warning "⚠️ Qwen failed (exit code: $qwen_exit), falling back to Droid..."
        fallback_to_droid=true
    fi

    # JOIN-2: Droid完了待ち（タイムアウト付き）
    log_info "🔗 JOIN-2: Waiting for Droid (timeout: ${droid_timeout}s)..."

    local droid_exit=0
    local droid_end=0
    local droid_duration=0
    local droid_timed_out=false

    # タイムアウト付き待機
    if timeout "$droid_timeout" bash -c "wait $droid_pid" 2>/dev/null; then
        # Droid正常完了
        droid_end=$(date +%s)
        droid_duration=$((droid_end - droid_start))
        log_info "✅ Droid completed successfully in ${droid_duration}s"

        if [[ $fallback_to_droid == false ]]; then
            log_info "🔗 Merging Qwen and Droid results..."
            # merge_results "$qwen_output_file" "$droid_output_file"（Phase 3で実装）
        else
            log_info "🔗 Using Droid results (Qwen failed)"
        fi
    else
        # Droidタイムアウト
        droid_timed_out=true
        droid_end=$(date +%s)
        droid_duration=$((droid_end - droid_start))
        log_warning "⏱️ Droid timed out after ${droid_duration}s, continuing with Qwen results..."

        # バックグラウンドプロセスをkill
        kill $droid_pid 2>/dev/null || true
    fi

    # メトリクス計算
    local total_duration=$(($(date +%s) - qwen_start))
    local critical_path=$((droid_duration > qwen_duration ? droid_duration : qwen_duration))
    local parallelism_efficiency=$(echo "scale=2; ($qwen_duration + $droid_duration) / $total_duration" | bc)

    log_info "📊 Hybrid Policy Metrics:"
    log_info "  - Qwen duration: ${qwen_duration}s"
    log_info "  - Droid duration: ${droid_duration}s (timeout: $droid_timed_out)"
    log_info "  - Total wall-clock time: ${total_duration}s"
    log_info "  - Critical-Path: ${critical_path}s"
    log_info "  - Parallelism efficiency: $parallelism_efficiency"

    # 成功判定
    if [[ $qwen_exit -eq 0 ]]; then
        return 0  # Qwen成功で十分
    elif [[ $droid_timed_out == false && $droid_exit -eq 0 ]]; then
        return 0  # Qwen失敗だがDroid成功
    else
        return 1  # 両方失敗
    fi
}

# ============================================================================
# ヘルパー関数（Phase 3で実装予定）
# ============================================================================

# 次フェーズ開始（プレースホルダー）
# Phase 3でゼロショット汎化と統合
start_next_phase() {
    local output_file=$1
    log_info "  → Next phase (placeholder): $output_file"
    # TODO: Phase 3実装
}

# 結果統合（プレースホルダー）
# Phase 3で実装
merge_results() {
    local qwen_output=$1
    local droid_output=$2
    log_info "  → Merging results (placeholder): Qwen=$qwen_output, Droid=$droid_output"
    # TODO: Phase 3実装
}

# ============================================================================
# エクスポート
# ============================================================================

# 関数をエクスポート（サブシェルで使用可能にする）
export -f join_policy_eager
export -f join_policy_lazy
export -f join_policy_hybrid
export -f start_next_phase
export -f merge_results

log_info "✓ JOIN Policy library loaded (eager | lazy | hybrid)"
