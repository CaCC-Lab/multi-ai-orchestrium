#!/usr/bin/env bash
# Worktree Metrics Library for Prometheus
# Version: 1.0.0
# Phase 5 Issue #4: Prometheus Integration

set -euo pipefail

# デフォルト設定
METRICS_DIR="${WORKTREE_METRICS_DIR:-/var/lib/node_exporter/textfile_collector}"
METRICS_FILE="${METRICS_FILE:-$METRICS_DIR/worktree_metrics.prom}"
METRICS_TMP_FILE="${METRICS_FILE}.tmp"

# PROJECT_ROOTの解決
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# メトリクスディレクトリの初期化
init_metrics() {
    mkdir -p "$METRICS_DIR"
    touch "$METRICS_FILE"
    chmod 644 "$METRICS_FILE"
}

# メトリクスファイルへの書き込み（アトミック）
write_metric() {
    local metric_line="$1"
    
    # 一時ファイルに書き込み
    echo "$metric_line" >> "$METRICS_TMP_FILE"
}

# メトリクスファイルのフラッシュ（アトミック更新）
flush_metrics() {
    if [[ -f "$METRICS_TMP_FILE" ]]; then
        # 既存のメトリクスを読み込み
        local existing_metrics=""
        if [[ -f "$METRICS_FILE" ]]; then
            existing_metrics=$(cat "$METRICS_FILE" 2>/dev/null || echo "")
        fi
        
        # 新しいメトリクスを追加
        {
            echo "$existing_metrics"
            cat "$METRICS_TMP_FILE"
        } > "${METRICS_FILE}.new"
        
        # アトミック更新
        mv "${METRICS_FILE}.new" "$METRICS_FILE"
        
        # 一時ファイルをクリア
        rm -f "$METRICS_TMP_FILE"
    fi
}

# カウンターのインクリメント
increment_counter() {
    local metric_name="$1"
    local labels="${2:-}"
    local value="${3:-1}"
    
    local metric_line="${metric_name}${labels:+$labels} ${value}"
    write_metric "$metric_line"
}

# ヒストグラムの記録
record_histogram() {
    local metric_name="$1"
    local labels="${2:-}"
    local value="$3"
    local buckets="${4:-0.01,0.05,0.1,0.5,1.0}"
    
    # バケットの判定（累積カウント）
    IFS=',' read -ra BUCKET_ARRAY <<< "$buckets"
    local bucket_output=""
    
    # 各バケットに対して累積カウントを記録
    for bucket in "${BUCKET_ARRAY[@]}"; do
        local bucket_count=0
        # このバケット以下の値の場合は1、そうでなければ0
        if [[ "$(compare_floats "$value" "<=" "$bucket")" == "1" ]]; then
            bucket_count=1
        fi
        # ラベルの形式を修正（カンマの処理）
        local bucket_label="${labels}"
        if [[ -n "$bucket_label" ]] && [[ "$bucket_label" != *"," ]]; then
            bucket_label="${bucket_label},"
        fi
        # ラベルが空の場合はカンマなし
        if [[ -z "$bucket_label" ]]; then
            bucket_output="${bucket_output}${metric_name}_bucket{le=\"$bucket\"} ${bucket_count}"$'\n'
        else
            bucket_output="${bucket_output}${metric_name}_bucket{${bucket_label}le=\"$bucket\"} ${bucket_count}"$'\n'
        fi
    done
    
    # +Infバケット（常に1）
    local inf_label="${labels}"
    if [[ -n "$inf_label" ]] && [[ "$inf_label" != *"," ]]; then
        inf_label="${inf_label},"
    fi
    if [[ -z "$inf_label" ]]; then
        bucket_output="${bucket_output}${metric_name}_bucket{le=\"+Inf\"} 1"$'\n'
    else
        bucket_output="${bucket_output}${metric_name}_bucket{${inf_label}le=\"+Inf\"} 1"$'\n'
    fi
    
    # sumとcount（ラベルを適切にフォーマット）
    if [[ -n "$labels" ]]; then
        bucket_output="${bucket_output}${metric_name}_sum{${labels}} $value"$'\n'
        bucket_output="${bucket_output}${metric_name}_count{${labels}} 1"
    else
        bucket_output="${bucket_output}${metric_name}_sum $value"$'\n'
        bucket_output="${bucket_output}${metric_name}_count 1"
    fi
    
    write_metric "$bucket_output"
}

# Worktree作成メトリクス
record_worktree_create() {
    local ai_name="$1"
    local duration="$2"
    local status="${3:-success}"
    local error_type="${4:-}"
    
    # カウンター（ラベル形式を修正）
    increment_counter "worktree_create_total" "{ai=\"$ai_name\",status=\"$status\"}"
    
    # ヒストグラム（成功時のみ）
    if [[ "$status" == "success" ]]; then
        record_histogram "worktree_create_duration_seconds" "ai=\"$ai_name\"" "$duration" "0.01,0.05,0.1,0.5,1.0"
    fi
    
    # エラーカウンター
    if [[ "$status" == "error" ]] && [[ -n "$error_type" ]]; then
        increment_counter "worktree_create_errors_total" "{ai=\"$ai_name\",error_type=\"$error_type\"}"
    fi
    
    flush_metrics
}

# Worktree実行メトリクス
record_worktree_execution() {
    local ai_name="$1"
    local duration="$2"
    local status="${3:-success}"
    local error_type="${4:-}"
    
    local labels="{ai=\"$ai_name\",status=\"$status\"}"
    
    # カウンター
    increment_counter "worktree_execution_total" "$labels"
    
    # ヒストグラム（成功時のみ）
    if [[ "$status" == "success" ]]; then
        record_histogram "worktree_execution_duration_seconds" "ai=\"$ai_name\"" "$duration" "1.0,5.0,10.0,30.0"
    fi
    
    # エラーカウンター
    if [[ "$status" == "error" ]] && [[ -n "$error_type" ]]; then
        increment_counter "worktree_execution_errors_total" "{ai=\"$ai_name\",error_type=\"$error_type\"}"
    fi
    
    flush_metrics
}

# Worktreeマージメトリクス
record_worktree_merge() {
    local ai_name="$1"
    local duration="$2"
    local status="${3:-success}"
    local error_type="${4:-}"
    
    local labels="{ai=\"$ai_name\",status=\"$status\"}"
    
    # カウンター
    increment_counter "worktree_merge_total" "$labels"
    
    # ヒストグラム（成功時のみ）
    if [[ "$status" == "success" ]]; then
        record_histogram "worktree_merge_duration_seconds" "ai=\"$ai_name\"" "$duration" "0.1,0.5,1.0,5.0"
    fi
    
    # エラーカウンター
    if [[ "$status" == "error" ]] && [[ -n "$error_type" ]]; then
        increment_counter "worktree_merge_errors_total" "{ai=\"$ai_name\",error_type=\"$error_type\"}"
    fi
    
    flush_metrics
}

# Worktreeクリーンアップメトリクス
record_worktree_cleanup() {
    local ai_name="$1"
    local duration="$2"
    local status="${3:-success}"
    
    local labels="{ai=\"$ai_name\",status=\"$status\"}"
    
    # カウンター
    increment_counter "worktree_cleanup_total" "$labels"
    
    # ヒストグラム（成功時のみ）
    if [[ "$status" == "success" ]]; then
        record_histogram "worktree_cleanup_duration_seconds" "ai=\"$ai_name\"" "$duration" "0.01,0.05,0.1,0.5"
    fi
    
    flush_metrics
}

# キャッシュメトリクス
record_cache_hit() {
    local ai_name="$1"
    increment_counter "worktree_cache_hits_total" "{ai=\"$ai_name\"}"
    flush_metrics
}

record_cache_miss() {
    local ai_name="$1"
    increment_counter "worktree_cache_misses_total" "{ai=\"$ai_name\"}"
    flush_metrics
}

# メトリクスヘルパー関数（bcコマンドがない場合の代替）
compare_floats() {
    local a="$1"
    local op="$2"
    local b="$3"
    
    if command -v bc &>/dev/null; then
        # bcを使用した比較（結果は1または0）
        local result=$(echo "$a $op $b" | bc -l 2>/dev/null || echo "0")
        if [[ "$result" == "1" ]]; then
            echo "1"
        else
            echo "0"
        fi
    elif command -v awk &>/dev/null; then
        # awkを使用した比較
        awk -v a="$a" -v op="$op" -v b="$b" "BEGIN {if (a $op b) print 1; else print 0}"
    else
        # 簡易比較（bashの算術演算を使用、整数のみ）
        local a_int=$(echo "$a" | cut -d. -f1)
        local b_int=$(echo "$b" | cut -d. -f1)
        case "$op" in
            "<=") if (( $(echo "$a <= $b" | awk '{print ($1 <= $2) ? 1 : 0}') )); then echo "1"; else echo "0"; fi ;;
            ">=") if (( $(echo "$a >= $b" | awk '{print ($1 >= $2) ? 1 : 0}') )); then echo "1"; else echo "0"; fi ;;
            "<")  if (( $(echo "$a < $b" | awk '{print ($1 < $2) ? 1 : 0}') )); then echo "1"; else echo "0"; fi ;;
            ">")  if (( $(echo "$a > $b" | awk '{print ($1 > $2) ? 1 : 0}') )); then echo "1"; else echo "0"; fi ;;
            *) echo "0" ;;
        esac
    fi
}

# エクスポート
export -f init_metrics
export -f write_metric
export -f flush_metrics
export -f increment_counter
export -f record_histogram
export -f record_worktree_create
export -f record_worktree_execution
export -f record_worktree_merge
export -f record_worktree_cleanup
export -f record_cache_hit
export -f record_cache_miss
