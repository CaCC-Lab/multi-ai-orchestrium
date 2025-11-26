#!/usr/bin/env bash
# generate-worktree-history-report.sh - Worktree実行履歴レポート生成スクリプト
# Purpose: Generate execution history reports in various formats
# Phase 2.1.2実装

set -euo pipefail

# ============================================================================
# プロジェクトルート検出
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================================================
# 依存関係のロード
# ============================================================================

# worktree-history.shのロード
if [[ -f "$SCRIPT_DIR/orchestrate/lib/worktree-history.sh" ]]; then
    source "$SCRIPT_DIR/orchestrate/lib/worktree-history.sh"
else
    echo "❌ エラー: worktree-history.sh が見つかりません" >&2
    exit 1
fi

# multi-ai-core.shのロード（ロギング関数用）
if [[ -f "$SCRIPT_DIR/orchestrate/lib/multi-ai-core.sh" ]]; then
    source "$SCRIPT_DIR/orchestrate/lib/multi-ai-core.sh"
fi

# ============================================================================
# ヘルプメッセージ
# ============================================================================

show_help() {
    cat << EOF
使用方法: $0 [OPTIONS]

Worktree実行履歴レポートを生成します。

オプション:
  --start-date DATE    開始日（YYYYMMDD形式、デフォルト: 7日前）
  --end-date DATE      終了日（YYYYMMDD形式、デフォルト: 今日）
  --format FORMAT      出力形式（json|markdown|html、デフォルト: markdown）
  --output FILE        出力ファイル（指定しない場合は標準出力）
  --trend              成功率トレンドのみを表示
  --stats              統計のみを表示
  --help               このヘルプを表示

使用例:
  # 過去7日間のMarkdownレポート生成
  $0

  # 特定期間のHTMLレポート生成
  $0 --start-date 20251101 --end-date 20251108 --format html

  # JSON形式でファイルに出力
  $0 --format json --output report.json

  # 成功率トレンドのみ表示
  $0 --trend

  # 統計のみ表示
  $0 --stats

EOF
}

# ============================================================================
# デフォルト設定
# ============================================================================

# 日付のデフォルト値（7日前から今日まで）
START_DATE=$(date -d '7 days ago' +%Y%m%d 2>/dev/null || date -v-7d +%Y%m%d 2>/dev/null || date +%Y%m%d)
END_DATE=$(date +%Y%m%d)
FORMAT="markdown"
OUTPUT_FILE=""
SHOW_TREND_ONLY=false
SHOW_STATS_ONLY=false

# ============================================================================
# 引数パース
# ============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --start-date)
            START_DATE="$2"
            shift 2
            ;;
        --end-date)
            END_DATE="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --trend)
            SHOW_TREND_ONLY=true
            shift
            ;;
        --stats)
            SHOW_STATS_ONLY=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "❌ エラー: 不明なオプション: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# ============================================================================
# 入力検証
# ============================================================================

# 日付形式検証（YYYYMMDD）
if ! [[ "$START_DATE" =~ ^[0-9]{8}$ ]]; then
    echo "❌ エラー: 開始日の形式が不正です: $START_DATE（YYYYMMDD形式を使用してください）" >&2
    exit 1
fi

if ! [[ "$END_DATE" =~ ^[0-9]{8}$ ]]; then
    echo "❌ エラー: 終了日の形式が不正です: $END_DATE（YYYYMMDD形式を使用してください）" >&2
    exit 1
fi

# 日付範囲検証
if [[ "$START_DATE" > "$END_DATE" ]]; then
    echo "❌ エラー: 開始日が終了日より後です" >&2
    exit 1
fi

# フォーマット検証
if [[ ! "$FORMAT" =~ ^(json|markdown|html)$ ]]; then
    echo "❌ エラー: サポートされていないフォーマット: $FORMAT" >&2
    echo "使用可能なフォーマット: json, markdown, html" >&2
    exit 1
fi

# ============================================================================
# バナー表示
# ============================================================================

if command -v show_multi_ai_banner >/dev/null 2>&1; then
    show_multi_ai_banner
fi

echo ""
echo "📊 Worktree実行履歴レポート生成"
echo "=================================="
echo ""
echo "期間: $START_DATE - $END_DATE"
echo "フォーマット: $FORMAT"
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "出力先: $OUTPUT_FILE"
else
    echo "出力先: 標準出力"
fi
echo ""

# ============================================================================
# レポート生成
# ============================================================================

if [[ "$SHOW_TREND_ONLY" == "true" ]]; then
    # トレンドのみ表示
    if command -v log_info >/dev/null 2>&1; then
        log_info "成功率トレンドを生成中..."
    fi
    
    REPORT=$(get_success_rate_trend "$START_DATE" "$END_DATE")
    
elif [[ "$SHOW_STATS_ONLY" == "true" ]]; then
    # 統計のみ表示
    if command -v log_info >/dev/null 2>&1; then
        log_info "統計を生成中..."
    fi
    
    REPORT=$(get_execution_statistics "$START_DATE" "$END_DATE")
    
else
    # フルレポート生成
    if command -v log_info >/dev/null 2>&1; then
        log_info "レポートを生成中..."
    fi
    
    REPORT=$(generate_history_report "$START_DATE" "$END_DATE" "$FORMAT")
fi

# ============================================================================
# 出力
# ============================================================================

if [[ -n "$OUTPUT_FILE" ]]; then
    # ファイルに出力
    echo "$REPORT" > "$OUTPUT_FILE"
    
    if command -v log_success >/dev/null 2>&1; then
        log_success "✅ レポートを生成しました: $OUTPUT_FILE"
    else
        echo "✅ レポートを生成しました: $OUTPUT_FILE"
    fi
    
    # ファイルサイズ表示
    if command -v log_info >/dev/null 2>&1; then
        local file_size
        file_size=$(wc -c < "$OUTPUT_FILE" | awk '{print $1}')
        log_info "ファイルサイズ: ${file_size} bytes"
    fi
else
    # 標準出力
    echo ""
    echo "$REPORT"
    echo ""
fi

# ============================================================================
# 追加情報
# ============================================================================

if command -v log_info >/dev/null 2>&1; then
    echo ""
    log_info "📂 詳細ログディレクトリ: $PROJECT_ROOT/logs/worktree-history/"
    echo ""
    log_info "💡 クエリ例:"
    echo "  # 特定日の全履歴"
    echo "  query_execution_history \"$END_DATE\""
    echo ""
    echo "  # 特定AIの履歴"
    echo "  query_execution_history \"$END_DATE\" \"qwen\""
    echo ""
    echo "  # 失敗した実行のみ"
    echo "  query_execution_history \"$END_DATE\" \"\" \"\" \"failure\""
    echo ""
fi

exit 0
