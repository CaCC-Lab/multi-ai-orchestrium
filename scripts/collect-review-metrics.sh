#!/usr/bin/env bash
# collect-review-metrics.sh - メトリクス収集スクリプト
# Version: 1.0.0
# Purpose: レビューシステムのパフォーマンスと品質メトリクスを収集・分析
# Reference: OPTION_D++_IMPLEMENTATION_PLAN.md Phase 3A.1.1

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Log directories
REVIEW_LOGS_DIR="${PROJECT_ROOT}/logs/review-tests"
VIBE_LOGS_DIR="${PROJECT_ROOT}/logs/vibe"
METRICS_OUTPUT_DIR="${PROJECT_ROOT}/logs/metrics"

# Output files
METRICS_JSON="${METRICS_OUTPUT_DIR}/review-metrics.json"
METRICS_MD="${METRICS_OUTPUT_DIR}/review-metrics.md"
METRICS_HTML="${METRICS_OUTPUT_DIR}/review-metrics.html"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# ============================================================================
# P3.1.1.1: 実行時間計測
# ============================================================================

collect_execution_time_metrics() {
    log_info "Collecting execution time metrics..."

    local total_reviews=0
    local total_duration=0
    local fallback_count=0
    local timeout_count=0

    # AI別の集計用連想配列
    declare -A ai_count
    declare -A ai_duration
    declare -A ai_timeout

    # レビューログファイルを解析
    while IFS= read -r json_file; do
        if [[ ! -f "$json_file" ]]; then
            continue
        fi

        # JSON解析（jqが必要）
        if ! command -v jq &> /dev/null; then
            log_error "jq is required for metrics collection"
            return 1
        fi

        local ai_reviewer=$(jq -r '.metadata.ai_reviewer // "unknown"' "$json_file")
        local review_duration=$(jq -r '.metadata.review_duration_ms // 0' "$json_file")
        local used_fallback=$(jq -r '.metadata.used_fallback // false' "$json_file")
        local timeout_occurred=$(jq -r '.metadata.timeout_occurred // false' "$json_file")

        # 全体集計
        total_reviews=$((total_reviews + 1))
        total_duration=$((total_duration + review_duration))

        # Fallback発生カウント
        if [[ "$used_fallback" == "true" ]]; then
            fallback_count=$((fallback_count + 1))
        fi

        # タイムアウト発生カウント
        if [[ "$timeout_occurred" == "true" ]]; then
            timeout_count=$((timeout_count + 1))
        fi

        # AI別集計
        ai_count[$ai_reviewer]=$((${ai_count[$ai_reviewer]:-0} + 1))
        ai_duration[$ai_reviewer]=$((${ai_duration[$ai_reviewer]:-0} + review_duration))

        if [[ "$timeout_occurred" == "true" ]]; then
            ai_timeout[$ai_reviewer]=$((${ai_timeout[$ai_reviewer]:-0} + 1))
        fi

    done < <(find "$REVIEW_LOGS_DIR" -name "*.json" -type f 2>/dev/null || true)

    # 結果を出力
    local fallback_rate="0.00"
    local timeout_rate="0.00"
    if [[ $total_reviews -gt 0 ]]; then
        fallback_rate=$(echo "scale=2; ($fallback_count * 100.0) / $total_reviews" | bc)
        timeout_rate=$(echo "scale=2; ($timeout_count * 100.0) / $total_reviews" | bc)
    fi

    echo "{" > /tmp/execution_metrics.json
    echo "  \"total_reviews\": $total_reviews," >> /tmp/execution_metrics.json
    echo "  \"total_duration_ms\": $total_duration," >> /tmp/execution_metrics.json
    echo "  \"average_duration_ms\": $((total_reviews > 0 ? total_duration / total_reviews : 0))," >> /tmp/execution_metrics.json
    echo "  \"fallback_count\": $fallback_count," >> /tmp/execution_metrics.json
    echo "  \"fallback_rate\": $fallback_rate," >> /tmp/execution_metrics.json
    echo "  \"timeout_count\": $timeout_count," >> /tmp/execution_metrics.json
    echo "  \"timeout_rate\": $timeout_rate," >> /tmp/execution_metrics.json
    echo "  \"ai_metrics\": {" >> /tmp/execution_metrics.json

    local first=true
    for ai in "${!ai_count[@]}"; do
        if [[ "$first" == "false" ]]; then
            echo "," >> /tmp/execution_metrics.json
        fi
        first=false

        local count=${ai_count[$ai]}
        local duration=${ai_duration[$ai]}
        local timeout=${ai_timeout[$ai]:-0}
        local avg=$((count > 0 ? duration / count : 0))
        local ai_timeout_rate="0.00"
        if [[ $count -gt 0 ]]; then
            ai_timeout_rate=$(echo "scale=2; ($timeout * 100.0) / $count" | bc)
        fi

        echo -n "    \"$ai\": {" >> /tmp/execution_metrics.json
        echo -n "\"count\": $count, " >> /tmp/execution_metrics.json
        echo -n "\"total_duration_ms\": $duration, " >> /tmp/execution_metrics.json
        echo -n "\"average_duration_ms\": $avg, " >> /tmp/execution_metrics.json
        echo -n "\"timeout_count\": $timeout, " >> /tmp/execution_metrics.json
        echo -n "\"timeout_rate\": $ai_timeout_rate" >> /tmp/execution_metrics.json
        echo -n "}" >> /tmp/execution_metrics.json
    done

    echo "" >> /tmp/execution_metrics.json
    echo "  }" >> /tmp/execution_metrics.json
    echo "}" >> /tmp/execution_metrics.json

    log_success "Execution time metrics collected: $total_reviews reviews analyzed"
}

# ============================================================================
# P3.1.1.2: 品質メトリクス
# ============================================================================

collect_quality_metrics() {
    log_info "Collecting quality metrics..."

    local total_findings=0
    declare -A priority_count
    declare -A ai_findings_count

    # レビューログファイルを解析
    while IFS= read -r json_file; do
        if [[ ! -f "$json_file" ]]; then
            continue
        fi

        local ai_reviewer=$(jq -r '.metadata.ai_reviewer // "unknown"' "$json_file")
        local findings=$(jq -r '.findings // [] | length' "$json_file")

        total_findings=$((total_findings + findings))
        ai_findings_count[$ai_reviewer]=$((${ai_findings_count[$ai_reviewer]:-0} + findings))

        # 優先度別カウント
        local p0=$(jq -r '[.findings[] | select(.priority == 0)] | length' "$json_file")
        local p1=$(jq -r '[.findings[] | select(.priority == 1)] | length' "$json_file")
        local p2=$(jq -r '[.findings[] | select(.priority == 2)] | length' "$json_file")

        priority_count[P0]=$((${priority_count[P0]:-0} + p0))
        priority_count[P1]=$((${priority_count[P1]:-0} + p1))
        priority_count[P2]=$((${priority_count[P2]:-0} + p2))

    done < <(find "$REVIEW_LOGS_DIR" -name "*.json" -type f 2>/dev/null || true)

    # 結果を出力
    echo "{" > /tmp/quality_metrics.json
    echo "  \"total_findings\": $total_findings," >> /tmp/quality_metrics.json
    echo "  \"findings_by_priority\": {" >> /tmp/quality_metrics.json
    echo "    \"P0\": ${priority_count[P0]:-0}," >> /tmp/quality_metrics.json
    echo "    \"P1\": ${priority_count[P1]:-0}," >> /tmp/quality_metrics.json
    echo "    \"P2\": ${priority_count[P2]:-0}" >> /tmp/quality_metrics.json
    echo "  }," >> /tmp/quality_metrics.json
    echo "  \"findings_by_ai\": {" >> /tmp/quality_metrics.json

    local first=true
    for ai in "${!ai_findings_count[@]}"; do
        if [[ "$first" == "false" ]]; then
            echo "," >> /tmp/quality_metrics.json
        fi
        first=false
        echo -n "    \"$ai\": ${ai_findings_count[$ai]}" >> /tmp/quality_metrics.json
    done

    echo "" >> /tmp/quality_metrics.json
    echo "  }" >> /tmp/quality_metrics.json
    echo "}" >> /tmp/quality_metrics.json

    log_success "Quality metrics collected: $total_findings total findings"
}

# ============================================================================
# P3.1.1.3: コスト評価
# ============================================================================

collect_cost_metrics() {
    log_info "Collecting cost metrics..."

    local total_api_calls=0
    local estimated_tokens=0

    # VibeLoggerログを解析してAPI呼び出し回数をカウント
    while IFS= read -r log_file; do
        if [[ ! -f "$log_file" ]]; then
            continue
        fi

        # wrapper_start イベントをカウント（API呼び出しを表す）
        local calls=0
        if grep -q '"event":"wrapper_start"' "$log_file" 2>/dev/null; then
            calls=$(grep -c '"event":"wrapper_start"' "$log_file" 2>/dev/null)
        fi
        total_api_calls=$((total_api_calls + calls))

    done < <(find "$VIBE_LOGS_DIR" -name "*.jsonl" -type f 2>/dev/null || true)

    # トークン数の推定（簡易版）
    # 平均プロンプトサイズ × API呼び出し回数 × 1.5（レスポンス込み）
    local avg_prompt_tokens=2000  # 平均プロンプトサイズ推定
    estimated_tokens=$((total_api_calls * avg_prompt_tokens * 3 / 2))

    # 結果を出力
    local estimated_cost="0.00"
    if [[ $estimated_tokens -gt 0 ]]; then
        estimated_cost=$(echo "scale=2; ($estimated_tokens * 0.0001) / 1000" | bc)
    fi

    echo "{" > /tmp/cost_metrics.json
    echo "  \"total_api_calls\": $total_api_calls," >> /tmp/cost_metrics.json
    echo "  \"estimated_total_tokens\": $estimated_tokens," >> /tmp/cost_metrics.json
    echo "  \"estimated_cost_usd\": $estimated_cost" >> /tmp/cost_metrics.json
    echo "}" >> /tmp/cost_metrics.json

    log_success "Cost metrics collected: $total_api_calls API calls"
}

# ============================================================================
# Metrics Aggregation
# ============================================================================

aggregate_metrics() {
    log_info "Aggregating all metrics..."

    # メトリクス出力ディレクトリ作成
    mkdir -p "$METRICS_OUTPUT_DIR"

    # 各メトリクスファイルを統合
    if [[ -f /tmp/execution_metrics.json ]] && \
       [[ -f /tmp/quality_metrics.json ]] && \
       [[ -f /tmp/cost_metrics.json ]]; then

        jq -s '{
            timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            execution_metrics: .[0],
            quality_metrics: .[1],
            cost_metrics: .[2]
        }' /tmp/execution_metrics.json \
           /tmp/quality_metrics.json \
           /tmp/cost_metrics.json > "$METRICS_JSON"

        log_success "Metrics aggregated to: $METRICS_JSON"
    else
        log_error "Failed to aggregate metrics: missing intermediate files"
        return 1
    fi
}

# ============================================================================
# Markdown Report Generation
# ============================================================================

generate_markdown_report() {
    log_info "Generating Markdown report..."

    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

    cat > "$METRICS_MD" <<EOF
# Review System Metrics Report

**Generated**: $timestamp

## Executive Summary

EOF

    # JSONから値を抽出
    local total_reviews=$(jq -r '.execution_metrics.total_reviews' "$METRICS_JSON")
    local avg_duration=$(jq -r '.execution_metrics.average_duration_ms' "$METRICS_JSON")
    local fallback_rate=$(jq -r '.execution_metrics.fallback_rate' "$METRICS_JSON")
    local total_findings=$(jq -r '.quality_metrics.total_findings' "$METRICS_JSON")
    local total_api_calls=$(jq -r '.cost_metrics.total_api_calls' "$METRICS_JSON")

    local avg_duration_sec=$(echo "scale=1; $avg_duration / 1000" | bc)

    cat >> "$METRICS_MD" <<EOF
- **Total Reviews**: $total_reviews
- **Average Duration**: ${avg_duration}ms (${avg_duration_sec}s)
- **Fallback Rate**: ${fallback_rate}%
- **Total Findings**: $total_findings
- **API Calls**: $total_api_calls

## Execution Time Metrics

### AI Performance

| AI | Reviews | Avg Duration (ms) | Timeout Rate (%) |
|----|---------|-------------------|------------------|
EOF

    # AI別メトリクスを表形式で追加
    jq -r '.execution_metrics.ai_metrics | to_entries[] |
        "| \(.key) | \(.value.count) | \(.value.average_duration_ms) | \(.value.timeout_rate) |"' \
        "$METRICS_JSON" >> "$METRICS_MD"

    cat >> "$METRICS_MD" <<EOF

## Quality Metrics

### Findings by Priority

| Priority | Count | Percentage |
|----------|-------|------------|
EOF

    local p0=$(jq -r '.quality_metrics.findings_by_priority.P0' "$METRICS_JSON")
    local p1=$(jq -r '.quality_metrics.findings_by_priority.P1' "$METRICS_JSON")
    local p2=$(jq -r '.quality_metrics.findings_by_priority.P2' "$METRICS_JSON")

    local p0_pct="0.0"
    local p1_pct="0.0"
    local p2_pct="0.0"
    if [[ $total_findings -gt 0 ]]; then
        p0_pct=$(echo "scale=1; ($p0 * 100.0) / $total_findings" | bc)
        p1_pct=$(echo "scale=1; ($p1 * 100.0) / $total_findings" | bc)
        p2_pct=$(echo "scale=1; ($p2 * 100.0) / $total_findings" | bc)
    fi

    echo "| P0 (Critical) | $p0 | ${p0_pct}% |" >> "$METRICS_MD"
    echo "| P1 (High) | $p1 | ${p1_pct}% |" >> "$METRICS_MD"
    echo "| P2 (Medium) | $p2 | ${p2_pct}% |" >> "$METRICS_MD"

    cat >> "$METRICS_MD" <<EOF

### Findings by AI

| AI | Findings | Avg per Review |
|----|----------|----------------|
EOF

    jq -r '.execution_metrics.ai_metrics | to_entries[] |
        "\(.key) \(.value.count)"' "$METRICS_JSON" | while read ai count; do
        local findings=$(jq -r ".quality_metrics.findings_by_ai.\"$ai\" // 0" "$METRICS_JSON")
        local avg="0.0"
        if [[ $count -gt 0 ]]; then
            avg=$(echo "scale=1; $findings / $count" | bc)
        fi
        echo "| $ai | $findings | $avg |" >> "$METRICS_MD"
    done

    local estimated_tokens=$(jq -r '.cost_metrics.estimated_total_tokens' "$METRICS_JSON")
    local estimated_cost_usd=$(jq -r '.cost_metrics.estimated_cost_usd' "$METRICS_JSON")

    cat >> "$METRICS_MD" <<EOF

## Cost Metrics

- **Total API Calls**: $total_api_calls
- **Estimated Tokens**: $estimated_tokens
- **Estimated Cost**: \$$estimated_cost_usd USD

---

*Report generated by collect-review-metrics.sh v1.0.0*
EOF

    log_success "Markdown report generated: $METRICS_MD"
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║ Review System Metrics Collection                                    ║"
    echo "║ Phase 3A.1.1: Metrics Collection Implementation                     ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""

    # 依存関係チェック
    if ! command -v jq &> /dev/null; then
        log_error "jq is required. Install: sudo apt-get install jq"
        exit 1
    fi

    # メトリクス収集
    collect_execution_time_metrics
    collect_quality_metrics
    collect_cost_metrics

    # 集約とレポート生成
    aggregate_metrics
    generate_markdown_report

    # クリーンアップ
    rm -f /tmp/execution_metrics.json /tmp/quality_metrics.json /tmp/cost_metrics.json

    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║ Metrics Collection Complete                                          ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""
    log_success "JSON metrics: $METRICS_JSON"
    log_success "Markdown report: $METRICS_MD"
    echo ""
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
