#!/usr/bin/env bash
# test-parallel-performance.sh
# Phase 1.3.4: パフォーマンステスト（並列度2,4,7比較）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Output directory
PERF_DIR="logs/worktree-performance"
mkdir -p "$PERF_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PERF_REPORT="$PERF_DIR/performance-comparison-$TIMESTAMP.md"

# Source libraries
source scripts/orchestrate/lib/worktree-core.sh

# AI list
AIS=(claude gemini amp qwen droid codex cursor)

# Initialize report
cat > "$PERF_REPORT" <<EOF
# Worktree並列度パフォーマンス比較

**実行日時**: $(date '+%Y-%m-%d %H:%M:%S')
**テスト対象**: 並列度 2 vs 4 vs 7

## システム情報

- **OS**: $(uname -s) $(uname -r)
- **CPU**: $(nproc) cores
- **メモリ**: $(free -h | awk '/^Mem:/ {print $2}')

## テスト結果

| 並列度 | 実行時間 | 平均時間/AI | メモリ使用量 | CPU使用率 |
|--------|---------|-------------|-------------|----------|
EOF

# Test function
run_perf_test() {
    local parallelism=$1
    local iteration=$2

    log_info "Test: 並列度=$parallelism (実行回数: $iteration/3)"

    # Cleanup
    git worktree prune -v >/dev/null 2>&1 || true
    rm -rf worktrees/ || true
    sleep 1

    # Measure before
    local mem_before=$(free -m | awk '/^Mem:/ {print $3}')
    local cpu_before=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)

    # Set parallelism
    export MAX_PARALLEL_WORKTREES=$parallelism

    # Measure execution time
    local start_time=$(date +%s%3N)

    create_worktrees_parallel "${AIS[@]}" >/dev/null 2>&1 || log_warning "Some worktrees failed"

    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    # Measure after
    local mem_after=$(free -m | awk '/^Mem:/ {print $3}')
    local cpu_after=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)

    local mem_used=$((mem_after - mem_before))
    local cpu_avg=$(awk "BEGIN {printf \"%.1f\", ($cpu_before + $cpu_after) / 2}")
    local time_per_ai=$(awk "BEGIN {printf \"%.0f\", $duration / 7}")

    # Cleanup
    git worktree prune -v >/dev/null 2>&1 || true
    rm -rf worktrees/ || true

    # Return results
    echo "$duration $time_per_ai $mem_used $cpu_avg"
}

# Run tests for each parallelism level (3 iterations each)
declare -A results

for parallelism in 2 4 7; do
    log_info "並列度 $parallelism のテスト開始（3回実行）"

    total_time=0
    total_per_ai=0
    total_mem=0
    total_cpu=0

    for i in 1 2 3; do
        result=$(run_perf_test $parallelism $i)
        read -r duration time_per_ai mem_used cpu_avg <<< "$result"

        total_time=$((total_time + duration))
        total_per_ai=$((total_per_ai + time_per_ai))
        total_mem=$((total_mem + mem_used))
        total_cpu=$(awk "BEGIN {printf \"%.1f\", $total_cpu + $cpu_avg}")
    done

    # Calculate averages
    avg_time=$((total_time / 3))
    avg_per_ai=$((total_per_ai / 3))
    avg_mem=$((total_mem / 3))
    avg_cpu=$(awk "BEGIN {printf \"%.1f\", $total_cpu / 3}")

    results[$parallelism]="$avg_time $avg_per_ai $avg_mem $avg_cpu"

    log_success "並列度 $parallelism 完了: 平均${avg_time}ms"
done

# Write results to report
for parallelism in 2 4 7; do
    read -r avg_time avg_per_ai avg_mem avg_cpu <<< "${results[$parallelism]}"

    echo "| $parallelism | ${avg_time}ms | ${avg_per_ai}ms | ${avg_mem}MB | ${avg_cpu}% |" >> "$PERF_REPORT"
done

# Analysis
cat >> "$PERF_REPORT" <<EOF

## 分析

### 実行時間

\`\`\`
並列度2: $(echo "${results[2]}" | awk '{print $1}')ms
並列度4: $(echo "${results[4]}" | awk '{print $1}')ms
並列度7: $(echo "${results[7]}" | awk '{print $1}')ms
\`\`\`

### 推奨設定

EOF

# Determine best parallelism
p2_time=$(echo "${results[2]}" | awk '{print $1}')
p4_time=$(echo "${results[4]}" | awk '{print $1}')
p7_time=$(echo "${results[7]}" | awk '{print $1}')

if [[ $p4_time -le $p2_time ]] && [[ $p4_time -le $p7_time ]]; then
    recommendation=4
    reason="バランスの取れたパフォーマンス"
elif [[ $p7_time -lt $p4_time ]]; then
    recommendation=7
    reason="最高速度（リソースに余裕がある場合）"
else
    recommendation=2
    reason="安定性重視（リソース制約がある場合）"
fi

cat >> "$PERF_REPORT" <<EOF
**推奨並列度**: $recommendation

**理由**: $reason

### 使用方法

\`\`\`bash
# 推奨設定
export MAX_PARALLEL_WORKTREES=$recommendation

# または、ワークフロー実行時に指定
MAX_PARALLEL_WORKTREES=$recommendation bash -c '
source scripts/orchestrate/orchestrate-multi-ai.sh
multi-ai-full-orchestrate "タスク"
'
\`\`\`

---

**テスト完了**: $(date '+%Y-%m-%d %H:%M:%S')
EOF

log_success "パフォーマンステスト完了: $PERF_REPORT"

# Display summary
echo ""
log_info "結果サマリー:"
echo "  並列度2: ${p2_time}ms"
echo "  並列度4: ${p4_time}ms"
echo "  並列度7: ${p7_time}ms"
echo ""
log_success "推奨並列度: $recommendation ($reason)"

exit 0
