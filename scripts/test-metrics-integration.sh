#!/usr/bin/env bash
# test-metrics-integration.sh - メトリクス統合テスト
# Phase 2.1.3実装の統合テスト

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Phase 2.1.3: メトリクス収集統合テスト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================================================================
# テスト1: worktree-metrics.shのロード確認
# ============================================================================

echo "🧪 テスト1: worktree-metrics.shのロード確認"

if [[ -f "$SCRIPT_DIR/orchestrate/lib/worktree-metrics.sh" ]]; then
    source "$SCRIPT_DIR/orchestrate/lib/worktree-metrics.sh"
    echo "✅ worktree-metrics.shロード成功"
else
    echo "❌ worktree-metrics.shが見つかりません"
    exit 1
fi

echo ""

# ============================================================================
# テスト2: メトリクス収集関数の動作確認
# ============================================================================

echo "🧪 テスト2: メトリクス収集関数の動作確認"

# テスト用の履歴データ作成
mkdir -p "$PROJECT_ROOT/logs/worktree-history/$(date +%Y%m%d)"
cat > "$PROJECT_ROOT/logs/worktree-history/$(date +%Y%m%d)/history.ndjson" << 'EOF'
{"timestamp":"2025-11-08T10:00:00Z","event":"execution_start","workflow_id":"test-workflow-001","task":"テストタスク","ais":["claude","gemini","qwen"]}
{"timestamp":"2025-11-08T10:05:00Z","event":"execution_end","workflow_id":"test-workflow-001","status":"success","duration":300,"metrics":{"worktrees_created":3,"errors":0}}
{"timestamp":"2025-11-08T11:00:00Z","event":"execution_start","workflow_id":"test-workflow-002","task":"テストタスク2","ais":["claude","amp"]}
{"timestamp":"2025-11-08T11:03:00Z","event":"execution_end","workflow_id":"test-workflow-002","status":"success","duration":180,"metrics":{"worktrees_created":2,"errors":0}}
EOF

echo "✅ テスト用履歴データ作成完了"

# メトリクス収集実行
if metrics_file=$(collect_all_metrics "$(date +%Y%m%d)" "$(date +%Y%m%d)"); then
    echo "✅ メトリクス収集成功: $metrics_file"
else
    echo "❌ メトリクス収集失敗"
    exit 1
fi

echo ""

# ============================================================================
# テスト3: メトリクスデータの検証
# ============================================================================

echo "🧪 テスト3: メトリクスデータの検証"

if [[ -f "$metrics_file" ]]; then
    # JSONフォーマット検証
    if jq empty "$metrics_file" 2>/dev/null; then
        echo "✅ メトリクスデータはJSONフォーマット有効"
        
        # 主要フィールドの存在確認
        if jq -e '.execution_time' "$metrics_file" >/dev/null 2>&1; then
            echo "✅ execution_time フィールド存在"
        else
            echo "❌ execution_time フィールドが見つかりません"
        fi
        
        if jq -e '.resources' "$metrics_file" >/dev/null 2>&1; then
            echo "✅ resources フィールド存在"
        else
            echo "❌ resources フィールドが見つかりません"
        fi
        
        if jq -e '.success_rate' "$metrics_file" >/dev/null 2>&1; then
            echo "✅ success_rate フィールド存在"
        else
            echo "❌ success_rate フィールドが見つかりません"
        fi
    else
        echo "❌ メトリクスデータのJSONフォーマットエラー"
        exit 1
    fi
else
    echo "❌ メトリクスファイルが見つかりません"
    exit 1
fi

echo ""

# ============================================================================
# テスト4: ダッシュボード生成確認
# ============================================================================

echo "🧪 テスト4: ダッシュボード生成確認"

if [[ -x "$SCRIPT_DIR/generate-metrics-dashboard.sh" ]]; then
    if "$SCRIPT_DIR/generate-metrics-dashboard.sh" "$(date +%Y%m%d)" "$(date +%Y%m%d)"; then
        echo "✅ ダッシュボード生成成功"
        
        dashboard_file="$PROJECT_ROOT/logs/worktree-metrics/dashboard.html"
        if [[ -f "$dashboard_file" ]]; then
            echo "✅ ダッシュボードファイル生成確認: $dashboard_file"
            
            # HTMLファイルサイズチェック
            file_size=$(stat -f%z "$dashboard_file" 2>/dev/null || stat -c%s "$dashboard_file" 2>/dev/null || echo "0")
            if [[ $file_size -gt 1000 ]]; then
                echo "✅ ダッシュボードファイルサイズ: ${file_size} bytes"
            else
                echo "⚠️  ダッシュボードファイルサイズが小さすぎます: ${file_size} bytes"
            fi
        else
            echo "❌ ダッシュボードファイルが見つかりません"
        fi
    else
        echo "❌ ダッシュボード生成失敗"
        exit 1
    fi
else
    echo "❌ generate-metrics-dashboard.shが実行できません"
    exit 1
fi

echo ""

# ============================================================================
# テスト5: メトリクスフック統合確認
# ============================================================================

echo "🧪 テスト5: メトリクスフック統合確認"

# worktree-core.shのロード
if [[ -f "$SCRIPT_DIR/orchestrate/lib/worktree-core.sh" ]]; then
    if grep -q "metrics_hook_worktree_created" "$SCRIPT_DIR/orchestrate/lib/worktree-core.sh"; then
        echo "✅ worktree-core.shにメトリクスフック統合済み"
    else
        echo "❌ worktree-core.shにメトリクスフックが見つかりません"
    fi
else
    echo "❌ worktree-core.shが見つかりません"
fi

# worktree-history.shのロード
if [[ -f "$SCRIPT_DIR/orchestrate/lib/worktree-history.sh" ]]; then
    if grep -q "metrics_hook_execution_completed" "$SCRIPT_DIR/orchestrate/lib/worktree-history.sh"; then
        echo "✅ worktree-history.shにメトリクスフック統合済み"
    else
        echo "❌ worktree-history.shにメトリクスフックが見つかりません"
    fi
else
    echo "❌ worktree-history.shが見つかりません"
fi

echo ""

# ============================================================================
# テスト結果サマリー
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Phase 2.1.3: メトリクス収集統合テスト完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 生成されたファイル:"
echo "  - メトリクスキャッシュ: $metrics_file"
echo "  - ダッシュボード: $dashboard_file"
echo ""
echo "🌐 ダッシュボードをブラウザで開く:"
echo "  file://$dashboard_file"
echo ""
