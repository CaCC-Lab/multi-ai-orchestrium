#!/usr/bin/env bash
# Execute 7AI Discussion on Naming Integration Strategy
# Created: 2025-11-05
# Purpose: Launch comprehensive 7AI debate on integrating naming consistency analysis into refactoring strategy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load orchestration workflow
source "$PROJECT_ROOT/scripts/orchestrate/orchestrate-multi-ai.sh"

# Discussion prompt file
DISCUSSION_PROMPT_FILE="$PROJECT_ROOT/docs/naming-integration-discussion-prompt.md"

# Output directory for results
OUTPUT_DIR="$PROJECT_ROOT/docs/7ai-discussions"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DISCUSSION_LOG_DIR="$OUTPUT_DIR/$TIMESTAMP"
mkdir -p "$DISCUSSION_LOG_DIR"
OUTPUT_FILE="$DISCUSSION_LOG_DIR/NAMING_INTEGRATION_STRATEGY_REPORT.md"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  7AI Comprehensive Discussion: Naming Integration Strategy     ║"
echo "║  Time: Unlimited | Mode: Thorough | Output: Markdown Report   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Discussion Prompt: docs/naming-integration-discussion-prompt.md"
echo "📂 Discussion Log Dir: $DISCUSSION_LOG_DIR"
echo "📤 Output File: $OUTPUT_FILE"
echo ""
echo "🚀 Launching 7AI discussion workflow..."
echo ""

# Execute multi-ai-discuss-before workflow using file reference
# This will coordinate all 7 AIs to discuss the naming integration strategy
multi-ai-discuss-before "$(cat "$DISCUSSION_PROMPT_FILE")" 2>&1 | tee "$DISCUSSION_LOG_DIR/raw-execution.log"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Discussion Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Find the latest 7ai-reviews log directory
LATEST_LOG=$(find logs/7ai-reviews -name "*-yaml" -type d 2>/dev/null | sort -r | head -1)

if [[ -n "$LATEST_LOG" && -d "$LATEST_LOG" ]]; then
    echo "📂 AI response logs found: $LATEST_LOG"
    echo ""
    echo "🔍 Processing discussion results into comprehensive report..."
    echo ""

    # Copy AI responses to discussion log directory
    cp -r "$LATEST_LOG" "$DISCUSSION_LOG_DIR/ai-responses"

    # Create comprehensive markdown report header
    cat > "$OUTPUT_FILE" <<REPORT_HEADER
# Multi-AI Orchestrium - 命名統合戦略 7AI徹底討論レポート

**討論日時**: $(date +"%Y-%m-%d %H:%M:%S")
**参加AI**: Claude, Gemini, Qwen, Droid, Amp, Codex, Cursor (7AI)
**討論形式**: 時間無制限、徹底討論、並行実行
**ログディレクトリ**: docs/7ai-discussions/$TIMESTAMP/

---

## 📊 エグゼクティブサマリー

### 🎯 最終推奨

**推奨Option**: [要分析: 討論結果を総合して決定]

### 合意形成プロセス

**参加AI**: [実際に応答したAIを記録]

**投票結果**: [各Optionへの投票数を集計]

### 期待ROI

[採用Optionの定量的効果を記載]

### 実装期間

[採用Optionの総期間を記載]

---

## 📋 詳細討論ログ

REPORT_HEADER

    # Process each AI's response and create summaries
    echo "### テーマ別合意形成" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    # Theme 1: Integration Necessity
    echo "#### テーマ1: 統合の必要性と緊急性" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "**各AIの推奨**:" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    for ai_file in "$LATEST_LOG"/*.md; do
        if [[ -f "$ai_file" ]]; then
            ai_name=$(basename "$ai_file" .md | sed 's/_task.*//')
            echo "- **$ai_name**: [分析待ち]" >> "$OUTPUT_FILE"
        fi
    done
    echo "" >> "$OUTPUT_FILE"

    # Add individual AI responses
    echo "---" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "### 各AIの詳細意見" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"

    for ai_file in "$LATEST_LOG"/*.md; do
        if [[ -f "$ai_file" ]]; then
            ai_name=$(basename "$ai_file" .md | sed 's/_task.*//')
            file_size=$(wc -c < "$ai_file")
            line_count=$(wc -l < "$ai_file")

            echo "#### $ai_name の意見（${line_count}行、${file_size} bytes）" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"

            # Include first 200 lines as preview
            echo "<details>" >> "$OUTPUT_FILE"
            echo "<summary>クリックして詳細を表示</summary>" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo '```markdown' >> "$OUTPUT_FILE"
            head -200 "$ai_file" >> "$OUTPUT_FILE"
            if [[ $line_count -gt 200 ]]; then
                echo "" >> "$OUTPUT_FILE"
                echo "[...残り $((line_count - 200)) 行...]" >> "$OUTPUT_FILE"
            fi
            echo '```' >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo "</details>" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            echo "[完全版を見る](./ai-responses/$(basename "$ai_file"))" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
        fi
    done

    # Add discussion prompt as reference
    cat >> "$OUTPUT_FILE" <<PROMPT_SECTION

---

## 📝 討論プロンプト（参照用）

<details>
<summary>クリックして表示</summary>

\`\`\`markdown
$(cat "$PROJECT_ROOT/docs/naming-integration-discussion-prompt.md")
\`\`\`

</details>

---

PROMPT_SECTION

    # Add synthesis section template
    cat >> "$OUTPUT_FILE" <<SYNTHESIS

## 🎯 統合分析と最終推奨

### 必須決定事項

#### 1. 統合オプションの選択

**投票結果**:
- Option 1 (Phase 1のみ統合、8週間): [X票]
- Option 2 (Phase 1+2統合、11週間): [X票]
- Option 3 (Phase 1+2+3統合、23週間): [X票]
- Option 4 (統合しない): [X票]

**採用Option**: [要分析]

**理由**: [要分析]

#### 2. 命名規則の選択

**投票結果**:
- 選択肢A (役割に応じた使い分け): [X票]
- 選択肢B (アンダースコア統一): [X票]
- 選択肢C (現状維持+明文化): [X票]

**採用命名規則**: [要分析]

**理由**: [要分析]

#### 3. Week 1の詳細計画

[要分析: 採用Optionに基づく詳細タスクリスト]

#### 4. ファイル分割の優先順位

1. **review-common.sh**: [Week X], [理由]
2. **multi-ai-workflows.sh**: [Week X], [理由]
3. **workflows-core.sh**: [Week X], [理由]

#### 5. 検証ゲートの基準

- **テスト成功率**: ≥ 95%
- **パフォーマンス劣化上限**: < +10%
- **ロールバック時間**: < 4時間

### 推奨事項

#### 6. Phase 2の実施判断

[要分析]

#### 7. Phase 3の実施判断

[要分析]

#### 8. ドキュメント戦略

[要分析]

#### 9. リスク軽減策の追加

[要分析]

#### 10. 最終ROI試算

**投資額**: [要計算]
**年間削減**: [要計算]
**投資回収期間**: [要計算]
**3年ROI**: [要計算]

---

## ✅ 全AI合意事項

[要分析: 全AIが一致した項目をリスト化]

---

## ⚠️ 意見が分かれた項目

[要分析: 投票が分かれた項目と各AIの立場]

---

## 💭 Minority意見

[要分析: 少数派意見とその根拠]

---

## 📅 詳細実装計画（週次タイムライン）

[要分析: 採用Optionの週次実装計画を記載]

### Week 1: [タイトル]
**タスク**:
- Day 1: [...]
- Day 2: [...]
- Day 3: [...]
- Day 4: [...]
- Day 5: [...]

**検証ゲート**:
- [ ] [基準1]
- [ ] [基準2]

**ロールバック手順**:
\`\`\`bash
# [手順]
\`\`\`

**工数**: [X日]

[Week 2-8も同様に記載]

---

## ⚠️ リスク管理

### リスクマトリクス

| フェーズ | リスクレベル | 主要リスク | 軽減策 | ロールバック時間 |
|---------|------------|----------|--------|----------------|
| Week 1 | [🟢/🟡/🔴] | [リスク] | [軽減策] | < [X]時間 |
| Week 2 | [🟢/🟡/🔴] | [リスク] | [軽減策] | < [X]時間 |

[Week 3-8も同様に記載]

---

## 💰 ROI詳細

### 投資額

| 項目 | 工数 | コスト（\$150/h） |
|------|------|-----------------|
| Week 1 | [X時間] | [Y] |
| Week 2 | [X時間] | [Y] |
| **合計** | [X時間] | [Y] |

### 年間削減

| 効果 | 削減額/年 |
|------|----------|
| [効果1] | [削減額] |
| [効果2] | [削減額] |
| **合計削減** | [合計] |

### 投資回収

- **投資額**: [X]
- **年間削減**: [Y]
- **投資回収期間**: [Z]ヶ月
- **3年ROI**: [ROI]%

---

## 🚀 次のアクション

### 即座実行（本日中）

- [ ] **ステークホルダーレビュー**: このレポートを提示し、採用Option承認を得る
- [ ] **Week 0キックオフ**: 準備タスクの開始
- [ ] **実装方針確定**: 命名規則、ファイル分割優先順位の最終決定

### Week 1開始前の準備（3日以内）

- [ ] **テストカバレッジ+20%達成**: E2Eテスト拡充完了
- [ ] **フィーチャーフラグ実装**: 環境変数ベース実装完了
- [ ] **SAST CI/CD統合**: ShellCheck, Bandit, Semgrepパイプライン追加
- [ ] **バックアップ作成**: 全スクリプト・ログのGitタグ作成（v3.0-pre-refactor）
- [ ] **ロールバック手順文書化**: ROLLBACK.md作成

### Week 1開始（承認後）

- [ ] **Week 1タスク実行**: [採用Optionに基づくタスク]
- [ ] **デイリースタンドアップ**: 毎日進捗確認、ブロッカー解消
- [ ] **検証ゲート通過**: Week 1末の検証ゲート（テスト成功率≥95%）

---

## 📊 付録

### A. 各AIの最終推奨と理由

[要分析: 各AIの推奨Optionと詳細理由をまとめる]

#### Claude（アーキテクチャ & 戦略）
**推奨**: [Option X]
**理由**: [...]

#### Gemini（セキュリティ & ベストプラクティス）
**推奨**: [Option X]
**理由**: [...]

#### Qwen（実装 & パフォーマンス）
**推奨**: [Option X]
**理由**: [...]

#### Droid（エンタープライズ & QA）
**推奨**: [Option X]
**理由**: [...]

#### Amp（プロジェクト管理 & ドキュメント）
**推奨**: [Option X]
**理由**: [...]

#### Codex（コードレビュー & 最適化）
**推奨**: [Option X]
**理由**: [...]

#### Cursor（開発者体験 & IDE統合）
**推奨**: [Option X]
**理由**: [...]

### B. 詳細タイムライン（ガントチャート形式）

\`\`\`
[Week 0-8のガントチャート]
\`\`\`

### C. 参加AI詳細レスポンスログ

**完全な討論ログは以下のディレクトリに保存されています**:
\`\`\`
docs/7ai-discussions/$TIMESTAMP/
├── NAMING_INTEGRATION_STRATEGY_REPORT.md (このファイル)
├── raw-execution.log (実行ログ)
├── ai-responses/ (各AIの完全レスポンス)
│   ├── claude-response.md
│   ├── gemini-response.md
│   ├── qwen-response.md
│   ├── droid-response.md
│   ├── amp-response.md
│   ├── codex-response.md
│   └── cursor-response.md
└── naming-integration-discussion-prompt.md (討論プロンプト)
\`\`\`

---

**レポート生成**: $(date +"%Y-%m-%d %H:%M:%S")
**生成者**: Claude Code (synthesizing 7AI discussion results)
**最終承認**: Pending Stakeholder Review
**次の承認者**: プロジェクトマネージャー、技術リード、CTO

---

**注意**: このレポートの「要分析」箇所は、各AIの応答を精読して手動で記入する必要があります。
各AIの完全なレスポンスは \`ai-responses/\` ディレクトリに保存されています。

SYNTHESIS

    echo "✅ Comprehensive report template generated: $OUTPUT_FILE"
    echo ""
    echo "📊 Report Summary:"
    wc -l "$OUTPUT_FILE"
    echo ""
    echo "📁 Discussion files:"
    ls -lh "$DISCUSSION_LOG_DIR"
    echo ""
    echo "📖 Next Steps:"
    echo "   1. Review individual AI responses in: $DISCUSSION_LOG_DIR/ai-responses/"
    echo "   2. Analyze consensus and disagreements across all 7 AIs"
    echo "   3. Fill in synthesis section with final recommendations"
    echo "   4. Calculate final ROI and create detailed timeline"
    echo "   5. Present to stakeholders for approval"
    echo ""
else
    echo "⚠️  Warning: No discussion logs found in logs/7ai-reviews/"
    echo "   The discussion may have failed or logs are in a different location."
    echo ""
    echo "📝 Creating basic report from raw logs..."

    cat > "$OUTPUT_FILE" <<BASIC_REPORT
# Multi-AI Orchestrium - 命名統合戦略 7AI討論レポート

**討論日時**: $(date +"%Y-%m-%d %H:%M:%S")
**ステータス**: ⚠️ ログ処理中

## Raw Discussion Logs

\`\`\`
$(cat "$DISCUSSION_LOG_DIR/raw-execution.log")
\`\`\`

---

**Note**: Full markdown report generation pending. Check logs/7ai-reviews/ for detailed AI responses.
BASIC_REPORT

    echo "✅ Basic report created: $OUTPUT_FILE"
fi

# Copy discussion prompt to log directory for reference
cp "$PROJECT_ROOT/docs/naming-integration-discussion-prompt.md" "$DISCUSSION_LOG_DIR/"

echo ""
echo "🎉 Discussion workflow completed!"
echo "📄 Final Report: $OUTPUT_FILE"
echo "📂 Log Directory: $DISCUSSION_LOG_DIR"
echo ""
echo "📋 Report Status: Template generated - requires manual synthesis"
echo "🔍 Next: Analyze AI responses and complete synthesis section"
echo ""
