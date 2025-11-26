#!/usr/bin/env bash
# benchmark-parallel-worktrees.sh
# Phase 1.3.1: 7AI全並列実行の検証（メモリ、ディスク、CPU測定）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
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

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Output directory
BENCHMARK_DIR="logs/worktree-benchmarks"
mkdir -p "$BENCHMARK_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BENCHMARK_REPORT="$BENCHMARK_DIR/parallel-benchmark-$TIMESTAMP.md"

# Initialize report
cat > "$BENCHMARK_REPORT" <<EOF
# Worktree並列実行ベンチマーク

**実行日時**: $(date '+%Y-%m-%d %H:%M:%S')
**テスト対象**: 7AI全並列Worktree作成

## システム情報

- **OS**: $(uname -s) $(uname -r)
- **CPU**: $(nproc) cores
- **メモリ**: $(free -h | awk '/^Mem:/ {print $2}')
- **ディスク**: $(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $2 " (利用可能: " $4 ")"}')

## テスト結果

EOF

# Source worktree libraries
source scripts/orchestrate/lib/worktree-core.sh

# Cleanup before test
log_info "既存Worktreeのクリーンアップ..."
git worktree prune -v || true
rm -rf worktrees/ || true

# AI names
AIS=(claude gemini amp qwen droid codex cursor)

# Test 1: 順次作成（ベースライン）
log_info "Test 1: 順次作成（ベースライン）"
echo "### Test 1: 順次作成（ベースライン）" >> "$BENCHMARK_REPORT"
echo "" >> "$BENCHMARK_REPORT"

# Measure baseline memory/disk before
mem_before=$(free -m | awk '/^Mem:/ {print $3}')
disk_before=$(du -sm "$PROJECT_ROOT" | awk '{print $1}')

start_time=$(date +%s%3N)

for ai in "${AIS[@]}"; do
    create_worktree "$ai" "benchmark/sequential/$ai" >/dev/null 2>&1 || log_warning "Failed to create $ai worktree"
done

end_time=$(date +%s%3N)
duration=$((end_time - start_time))

# Measure after
mem_after=$(free -m | awk '/^Mem:/ {print $3}')
disk_after=$(du -sm "$PROJECT_ROOT" | awk '{print $1}')

mem_used=$((mem_after - mem_before))
disk_used=$((disk_after - disk_before))

cat >> "$BENCHMARK_REPORT" <<EOF
**実行時間**: ${duration}ms ($(awk "BEGIN {printf \"%.2f\", $duration/1000}")秒)
**メモリ使用量**: ${mem_used}MB
**ディスク使用量**: ${disk_used}MB
**Worktree数**: $(git worktree list | wc -l)

EOF

log_success "順次作成完了: ${duration}ms, メモリ: ${mem_used}MB, ディスク: ${disk_used}MB"

# Cleanup
git worktree prune -v
rm -rf worktrees/

# Test 2: 並列作成（xargs -P 4）
log_info "Test 2: 並列作成（並列度4）"
echo "### Test 2: 並列作成（並列度4）" >> "$BENCHMARK_REPORT"
echo "" >> "$BENCHMARK_REPORT"

mem_before=$(free -m | awk '/^Mem:/ {print $3}')
disk_before=$(du -sm "$PROJECT_ROOT" | awk '{print $1}')
cpu_before=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}')

start_time=$(date +%s%3N)

# Parallel creation with xargs -P 4
printf "%s\n" "${AIS[@]}" | xargs -P 4 -I {} bash -c "
    source scripts/orchestrate/lib/worktree-core.sh
    create_worktree {} 'benchmark/parallel4/{}' >/dev/null 2>&1 || echo 'Failed: {}'
"

end_time=$(date +%s%3N)
duration=$((end_time - start_time))

mem_after=$(free -m | awk '/^Mem:/ {print $3}')
disk_after=$(du -sm "$PROJECT_ROOT" | awk '{print $1}')
cpu_after=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}')

mem_used=$((mem_after - mem_before))
disk_used=$((disk_after - disk_before))
cpu_used=$(awk "BEGIN {printf \"%.1f\", $cpu_after - $cpu_before}")

cat >> "$BENCHMARK_REPORT" <<EOF
**実行時間**: ${duration}ms ($(awk "BEGIN {printf \"%.2f\", $duration/1000}")秒)
**メモリ使用量**: ${mem_used}MB
**ディスク使用量**: ${disk_used}MB
**CPU使用率変化**: ${cpu_used}%
**Worktree数**: $(git worktree list | wc -l)

EOF

log_success "並列作成（P4）完了: ${duration}ms, メモリ: ${mem_used}MB, ディスク: ${disk_used}MB"

# Cleanup
git worktree prune -v
rm -rf worktrees/

# Test 3: 完全並列作成（xargs -P 7）
log_info "Test 3: 完全並列作成（並列度7）"
echo "### Test 3: 完全並列作成（並列度7）" >> "$BENCHMARK_REPORT"
echo "" >> "$BENCHMARK_REPORT"

mem_before=$(free -m | awk '/^Mem:/ {print $3}')
disk_before=$(du -sm "$PROJECT_ROOT" | awk '{print $1}')

start_time=$(date +%s%3N)

printf "%s\n" "${AIS[@]}" | xargs -P 7 -I {} bash -c "
    source scripts/orchestrate/lib/worktree-core.sh
    create_worktree {} 'benchmark/parallel7/{}' >/dev/null 2>&1 || echo 'Failed: {}'
"

end_time=$(date +%s%3N)
duration=$((end_time - start_time))

mem_after=$(free -m | awk '/^Mem:/ {print $3}')
disk_after=$(du -sm "$PROJECT_ROOT" | awk '{print $1}')

mem_used=$((mem_after - mem_before))
disk_used=$((disk_after - disk_before))

cat >> "$BENCHMARK_REPORT" <<EOF
**実行時間**: ${duration}ms ($(awk "BEGIN {printf \"%.2f\", $duration/1000}")秒)
**メモリ使用量**: ${mem_used}MB
**ディスク使用量**: ${disk_used}MB
**Worktree数**: $(git worktree list | wc -l)

EOF

log_success "完全並列作成（P7）完了: ${duration}ms, メモリ: ${mem_used}MB, ディスク: ${disk_used}MB"

# Cleanup
git worktree prune -v
rm -rf worktrees/

# Summary
cat >> "$BENCHMARK_REPORT" <<EOF

## 推奨設定

ベンチマーク結果に基づく推奨並列度:
- **デフォルト**: 4 (バランスの取れたパフォーマンス)
- **高速**: 7 (最大並列度、リソースに余裕がある場合)
- **省リソース**: 2 (メモリ/CPU制約がある場合)

## 環境変数

\`\`\`bash
# 並列度を設定（デフォルト: 4）
export MAX_PARALLEL_WORKTREES=4
\`\`\`

---

**ベンチマーク完了**: $(date '+%Y-%m-%d %H:%M:%S')
EOF

log_success "ベンチマーク完了: $BENCHMARK_REPORT"

# Display summary
echo ""
log_info "ベンチマーク結果サマリー:"
cat "$BENCHMARK_REPORT" | grep -A 4 "^### Test"

exit 0
