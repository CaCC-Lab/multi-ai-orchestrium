#!/usr/bin/env bash
# test-worktree-parallelism.sh - Worktree並列作成パフォーマンステスト
# Phase 1.3.4: 並列度 2, 4, 7 での実行時間比較

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# テスト結果保存ディレクトリ
TEST_RESULTS_DIR="$PROJECT_ROOT/logs/worktree-parallelism-tests"
mkdir -p "$TEST_RESULTS_DIR"

# タイムスタンプ
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="$TEST_RESULTS_DIR/test-report-$TIMESTAMP.md"

# カラー出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# レポートヘッダー
init_report() {
  cat > "$REPORT_FILE" <<EOF
# Worktree並列作成パフォーマンステスト

**実行日時:** $(date '+%Y-%m-%d %H:%M:%S')
**ホスト:** $(hostname)
**OS:** $(uname -s)
**CPU:** $(nproc) cores
**メモリ:** $(free -h | awk '/^Mem:/ {print $2}')

---

## テスト概要

並列度を変化させてWorktree作成時間を測定し、最適な並列度を決定する。

- **テスト対象:** 7AI全Worktree作成
- **測定項目:** 実行時間、CPU使用率、メモリ使用量
- **並列度:** 1, 2, 4, 7

---

## システム情報

\`\`\`
$(uname -a)
$(cat /proc/cpuinfo | grep "model name" | head -1)
Total Memory: $(free -h | awk '/^Mem:/ {print $2}')
Available Disk: $(df -h "$PROJECT_ROOT" | awk 'NR==2 {print $4}')
\`\`\`

---

## テスト結果

EOF
}

# クリーンアップ関数
cleanup_worktrees() {
  log_info "Worktreeクリーンアップ中..."
  
  # worktree-cleanup.shを使用
  if [[ -f "$SCRIPT_DIR/orchestrate/lib/worktree-cleanup.sh" ]]; then
    source "$SCRIPT_DIR/orchestrate/lib/worktree-cleanup.sh"
    cleanup_all_worktrees 2>/dev/null || true
  fi
  
  # 念のため手動削除
  if [[ -d "$PROJECT_ROOT/worktrees" ]]; then
    cd "$PROJECT_ROOT"
    for ai in claude gemini amp qwen droid codex cursor; do
      if git worktree list | grep -q "worktrees/$ai"; then
        git worktree remove "worktrees/$ai" --force 2>/dev/null || true
      fi
    done
    rm -rf worktrees
  fi
  
  log_info "クリーンアップ完了"
}

# パフォーマンステスト実行
run_performance_test() {
  local parallelism=$1
  local test_name="並列度${parallelism}"
  
  log_info "=========================================="
  log_info "テスト開始: $test_name"
  log_info "=========================================="
  
  # クリーンアップ
  cleanup_worktrees
  
  # 環境変数設定
  export MAX_PARALLEL_WORKTREES=$parallelism
  export WORKTREE_BASE_DIR="worktrees"
  
  # メモリ・CPU測定開始
  local pid_monitor=""
  local cpu_log="/tmp/worktree-test-cpu-$parallelism.log"
  local mem_log="/tmp/worktree-test-mem-$parallelism.log"
  
  # バックグラウンドでリソース監視
  (
    while true; do
      echo "$(date +%s) $(ps aux | awk '{sum+=$3} END {print sum}')" >> "$cpu_log"
      echo "$(date +%s) $(free -m | awk '/^Mem:/ {print $3}')" >> "$mem_log"
      sleep 0.1
    done
  ) &
  pid_monitor=$!
  
  # 時間測定
  local start_time=$(date +%s.%N)
  
  # Worktree作成実行
  source "$SCRIPT_DIR/orchestrate/lib/worktree-core.sh"
  
  local exit_code=0
  if create_all_worktrees claude gemini amp qwen droid codex cursor; then
    log_info "✅ Worktree作成成功"
  else
    exit_code=$?
    log_error "❌ Worktree作成失敗 (exit code: $exit_code)"
  fi
  
  local end_time=$(date +%s.%N)
  
  # リソース監視停止
  kill $pid_monitor 2>/dev/null || true
  
  # 実行時間計算
  local duration=$(echo "$end_time - $start_time" | bc)
  
  # リソース使用量集計
  local avg_cpu=$(awk '{sum+=$2; count++} END {if(count>0) print sum/count; else print 0}' "$cpu_log")
  local max_mem=$(awk 'BEGIN {max=0} {if($2>max) max=$2} END {print max}' "$mem_log")
  
  # 作成されたWorktree数確認
  local worktree_count=0
  if [[ -d "$PROJECT_ROOT/worktrees" ]]; then
    worktree_count=$(git worktree list | grep -c "worktrees/" || echo 0)
  fi
  
  # レポートに記録
  cat >> "$REPORT_FILE" <<EOF

### $test_name

- **実行時間:** ${duration}秒
- **平均CPU使用率:** ${avg_cpu}%
- **最大メモリ使用量:** ${max_mem}MB
- **作成Worktree数:** $worktree_count/7
- **ステータス:** $(if [[ $exit_code -eq 0 ]]; then echo "✅ 成功"; else echo "❌ 失敗"; fi)

EOF
  
  # コンソール出力
  log_info "実行時間: ${duration}秒"
  log_info "平均CPU: ${avg_cpu}%"
  log_info "最大メモリ: ${max_mem}MB"
  log_info "作成数: $worktree_count/7"
  
  # クリーンアップ
  cleanup_worktrees
  rm -f "$cpu_log" "$mem_log"
  
  # 結果を返す（次のテストで使用）
  echo "$duration"
}

# メイン処理
main() {
  log_info "Worktree並列作成パフォーマンステスト開始"
  log_info "結果保存先: $REPORT_FILE"
  
  # レポート初期化
  init_report
  
  # 並列度別テスト実行
  declare -A results
  
  for parallelism in 1 2 4 7; do
    local duration
    duration=$(run_performance_test "$parallelism")
    results[$parallelism]=$duration
    
    # 次のテストまで待機（システム安定化）
    sleep 2
  done
  
  # 分析と推奨値の決定
  cat >> "$REPORT_FILE" <<EOF

---

## 分析結果

### 実行時間比較

| 並列度 | 実行時間 | 相対速度 |
|--------|----------|----------|
| 1 | ${results[1]}s | 1.00x |
| 2 | ${results[2]}s | $(echo "scale=2; ${results[1]} / ${results[2]}" | bc)x |
| 4 | ${results[4]}s | $(echo "scale=2; ${results[1]} / ${results[4]}" | bc)x |
| 7 | ${results[7]}s | $(echo "scale=2; ${results[1]} / ${results[7]}" | bc)x |

### 推奨設定

EOF
  
  # 最速の並列度を特定
  local fastest_parallelism=1
  local fastest_time=${results[1]}
  
  for parallelism in 2 4 7; do
    if (( $(echo "${results[$parallelism]} < $fastest_time" | bc -l) )); then
      fastest_time=${results[$parallelism]}
      fastest_parallelism=$parallelism
    fi
  done
  
  cat >> "$REPORT_FILE" <<EOF
**推奨並列度:** $fastest_parallelism

- **理由:** 最短実行時間（${fastest_time}秒）
- **設定方法:** \`export MAX_PARALLEL_WORKTREES=$fastest_parallelism\`

---

## 結論

$(if [[ $fastest_parallelism -eq 4 ]]; then
  echo "デフォルト設定（並列度4）が最適です。"
elif [[ $fastest_parallelism -eq 7 ]]; then
  echo "並列度7（全並列）が最速です。デフォルトを7に変更することを推奨します。"
else
  echo "並列度${fastest_parallelism}が最適です。デフォルトを${fastest_parallelism}に変更することを推奨します。"
fi)

**次のステップ:**
1. \`scripts/orchestrate/lib/worktree-core.sh\`のデフォルト値を更新
2. ドキュメント（WORKTREE_IMPLEMENTATION_PLAN.md）に結果を記録
3. CI/CD環境での並列度設定を検討

---

**テスト完了:** $(date '+%Y-%m-%d %H:%M:%S')
EOF
  
  log_info "=========================================="
  log_info "全テスト完了"
  log_info "=========================================="
  log_info "推奨並列度: $fastest_parallelism"
  log_info "レポート: $REPORT_FILE"
  
  # レポート表示
  cat "$REPORT_FILE"
}

# スクリプト実行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
