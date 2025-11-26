#!/usr/bin/env bash
# Execute 7AI Discussion on Refactoring Integration Strategy
# Created: 2025-11-04
# Purpose: Launch comprehensive 7AI debate using multi-ai-discuss-before workflow

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load orchestration workflow
source "$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh"

# Read discussion prompt
DISCUSSION_PROMPT=$(cat "$PROJECT_ROOT/docs/refactoring-integration-discussion-prompt.md")

# Output file for results
OUTPUT_DIR="$PROJECT_ROOT/docs/7ai-discussions"
mkdir -p "$OUTPUT_DIR"
OUTPUT_FILE="$OUTPUT_DIR/refactoring-integration-strategy-$(date +%Y%m%d-%H%M%S).md"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  7AI Comprehensive Discussion: Refactoring Integration         ║"
echo "║  Time: Unlimited | Mode: Thorough | Output: Markdown Report   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Discussion Prompt: docs/refactoring-integration-discussion-prompt.md"
echo "📤 Output File: $OUTPUT_FILE"
echo ""
echo "🚀 Launching 7AI discussion workflow..."
echo ""

# Execute multi-ai-discuss-before workflow
# This will coordinate all 7 AIs to discuss the refactoring strategy
multi-ai-discuss-before "$DISCUSSION_PROMPT" 2>&1 | tee /tmp/7ai-discussion-raw.log

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Discussion Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Find the latest 7ai-reviews log directory
LATEST_LOG=$(find logs/7ai-reviews -name "*-yaml" -type d | sort -r | head -1)

if [[ -n "$LATEST_LOG" ]]; then
    echo "📂 Discussion logs saved to: $LATEST_LOG"
    echo ""
    echo "🔍 Processing discussion results into comprehensive report..."
    echo ""

    # Create comprehensive markdown report
    cat > "$OUTPUT_FILE" <<'REPORT_HEADER'
# Multi-AI Orchestrium リファクタリング統合戦略 - 7AI徹底討論レポート

**討論日時**: $(date +"%Y-%m-%d %H:%M:%S")
**参加AI**: Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor (7AI)
**討論形式**: 時間無制限、徹底討論、省略禁止
**ログディレクトリ**: $(basename "$LATEST_LOG")

---

## 📊 エグゼクティブサマリー

REPORT_HEADER

    # Process each AI's response
    echo "### 各AIの主要意見" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    for ai_file in "$LATEST_LOG"/*.md; do
        if [[ -f "$ai_file" ]]; then
            ai_name=$(basename "$ai_file" .md | sed 's/_task[0-9]*//')
            echo "#### $ai_name の意見" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo '```' >> "$OUTPUT_FILE"
            head -100 "$ai_file" >> "$OUTPUT_FILE"
            echo '```' >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo "[完全版を見る]($ai_file)" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    done

    # Add full discussion logs as appendix
    cat >> "$OUTPUT_FILE" <<APPENDIX

---

## 📋 詳細討論ログ（全文）

### ディスカッションプロンプト

$(cat "$PROJECT_ROOT/docs/refactoring-integration-discussion-prompt.md")

---

### 7AI個別レスポンス（全文）

APPENDIX

    for ai_file in "$LATEST_LOG"/*.md; do
        if [[ -f "$ai_file" ]]; then
            ai_name=$(basename "$ai_file" .md)
            echo "#### $ai_name" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo '```markdown' >> "$OUTPUT_FILE"
            cat "$ai_file" >> "$OUTPUT_FILE"
            echo '```' >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    done

    # Add synthesis section
    cat >> "$OUTPUT_FILE" <<SYNTHESIS

---

## 🎯 統合分析と最終推奨

### 推奨Option

**[要手動入力: 討論結果を分析して記入]**

### 合意形成プロセス

**[要手動入力: 投票結果、全員一致項目等を記入]**

### 実装詳細計画

**[要手動入力: 採用Optionの詳細タイムライン]**

### リスク管理

**[要手動入力: 主要リスクと軽減策]**

### 次のアクション

- [ ] ステークホルダーレビュー
- [ ] 実装開始承認
- [ ] Week 1キックオフ準備

---

**レポート生成**: $(date +"%Y-%m-%d %H:%M:%S")
**生成スクリプト**: scripts/execute-refactoring-discussion.sh
**最終承認**: [Pending]

SYNTHESIS

    echo "✅ Comprehensive report generated: $OUTPUT_FILE"
    echo ""
    echo "📊 Report Summary:"
    wc -l "$OUTPUT_FILE"
    echo ""
    echo "📖 Next Steps:"
    echo "   1. Review the comprehensive report: $OUTPUT_FILE"
    echo "   2. Analyze 7AI consensus and disagreements"
    echo "   3. Fill in synthesis section with final recommendations"
    echo "   4. Present to stakeholders for approval"
    echo ""
else
    echo "⚠️  Warning: No discussion logs found in logs/7ai-reviews/"
    echo "   The discussion may have failed or logs are in a different location."
    echo ""
    echo "📝 Creating basic report from raw logs..."

    cat > "$OUTPUT_FILE" <<BASIC_REPORT
# Multi-AI Orchestrium リファクタリング統合戦略 - 7AI討論レポート

**討論日時**: $(date +"%Y-%m-%d %H:%M:%S")
**ステータス**: ⚠️ ログ処理中

## Raw Discussion Logs

\`\`\`
$(cat /tmp/7ai-discussion-raw.log)
\`\`\`

---

**Note**: Full markdown report generation pending. Check logs/7ai-reviews/ for detailed AI responses.
BASIC_REPORT

    echo "✅ Basic report created: $OUTPUT_FILE"
fi

echo ""
echo "🎉 Discussion workflow completed!"
echo "📄 Final Report: $OUTPUT_FILE"
echo ""
