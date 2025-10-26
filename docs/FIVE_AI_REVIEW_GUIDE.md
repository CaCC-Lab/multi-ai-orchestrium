# 5AI Review Scripts - ユーザーガイド

**バージョン**: 1.0.0
**作成日**: 2025-10-26
**対象読者**: Multi-AI Orchestriumを使用する開発者、プロジェクトマネージャー

---

## 📋 目次

1. [概要](#概要)
2. [クイックスタート](#クイックスタート)
3. [各AIレビュースクリプトの詳細](#各aiレビュースクリプトの詳細)
4. [使い分けガイド](#使い分けガイド)
5. [ワークフロー推奨事項](#ワークフロー推奨事項)
6. [出力の解釈方法](#出力の解釈方法)
7. [トラブルシューティング](#トラブルシューティング)
8. [よくある質問](#よくある質問)

---

## 概要

5AI Review Scriptsは、Multi-AI Orchestriumプロジェクトの一部として、5つの異なるAI（Gemini, Qwen, Cursor, Amp, Droid）を活用した専用コードレビュースクリプトです。各AIは独自の専門領域を持ち、異なる観点からコードをレビューします。

### なぜ5つのAI？

**多角的視点**: 各AIは異なる強みを持ち、単一のAIでは見逃しがちな問題を検出します。

| AI | 専門領域 | 主な強み |
|----|---------|---------|
| Gemini 2.5 | セキュリティ & アーキテクチャ | OWASP Top 10検出、アーキテクチャ設計評価 |
| Qwen3-Coder | コード品質 & パターン | 93.9% HumanEval精度、デザインパターン検出 |
| Cursor | IDE統合 & 開発者体験 | コード可読性、IDE統合性、リファクタリング機会 |
| Amp | プロジェクト管理 & ドキュメント | ドキュメント品質、ステークホルダーコミュニケーション |
| Droid | エンタープライズ基準 | コンプライアンス検証、本番環境適合性 |

### 主要な特徴

- **統一インターフェース**: すべてのスクリプトが同じCLIオプションをサポート
- **REVIEW-PROMPT.mdベース**: 一貫したレビュー基準を使用
- **VibeLogger統合**: AI最適化された構造化ロギング
- **豊富な出力形式**: JSON、Markdown、VibeLoggerログを生成
- **包括的テスト**: 70-80%のブランチカバレッジ、104テストケース

---

## クイックスタート

### 前提条件

- Multi-AI Orchestriumがインストールされていること
- 各AIのラッパースクリプト（`bin/*-wrapper.sh`）が利用可能であること
- GitリポジトリでREVIEW-PROMPT.mdが存在すること

### 最も簡単な使い方

```bash
# Qwen（コード品質）でレビュー - 最も汎用的
bash scripts/qwen-review.sh

# Gemini（セキュリティ）でレビュー - セキュリティ重視
bash scripts/gemini-review.sh

# 全5AIでレビュー - 包括的検証
bash scripts/multi-ai-review.sh --type all
```

### 基本的なワークフロー

```bash
# 1. コード変更をコミット
git add .
git commit -m "feat: 新機能追加"

# 2. コード品質レビュー（Qwen）
bash scripts/qwen-review.sh

# 3. 結果を確認
cat logs/qwen-reviews/latest_qwen.md

# 4. 必要に応じてセキュリティレビュー（Gemini）
bash scripts/gemini-review.sh

# 5. 結果を確認
cat logs/gemini-reviews/latest_gemini.md
```

---

## 各AIレビュースクリプトの詳細

### 1. Gemini (gemini-review.sh) - セキュリティ & アーキテクチャ

**いつ使うか:**
- セキュリティクリティカルな変更
- 認証・認可システムの実装
- 外部APIとの統合
- パフォーマンスが重要な実装

**基本使用法:**
```bash
# 標準レビュー
bash scripts/gemini-review.sh

# 特定コミットをレビュー
bash scripts/gemini-review.sh --commit abc123

# タイムアウト延長（デフォルト: 900秒）
bash scripts/gemini-review.sh --timeout 1200
```

**レビュー内容:**
- OWASP Top 10脆弱性検出
- セキュリティベストプラクティス検証
- アーキテクチャ設計レビュー
- スケーラビリティ評価
- パフォーマンスボトルネック検出

**出力例:**
```json
{
  "findings": [
    {
      "title": "SQL Injection Vulnerability",
      "severity": "Critical",
      "priority": "P0",
      "cwe": "CWE-89",
      "cvss_score": 9.8,
      "file": "src/database/query.js",
      "line": 42,
      "description": "User input not sanitized before SQL query",
      "recommendation": "Use parameterized queries or ORM"
    }
  ]
}
```

**推奨設定:**
- タイムアウト: 900-1200秒（複雑なセキュリティ分析のため）
- フォーカス: セキュリティクリティカルなファイル（auth, api, database）

---

### 2. Qwen (qwen-review.sh) - コード品質 & パターン

**いつ使うか:**
- 新機能の実装レビュー
- リファクタリング検証
- コード複雑度の削減
- デザインパターンの改善

**基本使用法:**
```bash
# 標準レビュー
bash scripts/qwen-review.sh

# パターンにフォーカス
bash scripts/qwen-review.sh --focus patterns

# 品質にフォーカス
bash scripts/qwen-review.sh --focus quality

# パフォーマンスにフォーカス
bash scripts/qwen-review.sh --focus performance
```

**レビュー内容:**
- コード品質評価（93.9% HumanEval精度）
- デザインパターン検出と推奨
- パフォーマンス最適化提案
- 技術的負債評価
- 循環的複雑度計算
- 保守性インデックス算出

**出力例:**
```json
{
  "metrics": {
    "maintainability_index": 78,
    "cyclomatic_complexity": 12,
    "technical_debt_hours": 4.5,
    "code_quality_score": 85
  },
  "findings": [
    {
      "title": "High Cyclomatic Complexity",
      "severity": "Medium",
      "priority": "P2",
      "file": "src/utils/validator.js",
      "line": 120,
      "description": "Function has complexity of 15, threshold is 10",
      "recommendation": "Extract nested conditions into separate functions"
    }
  ]
}
```

**推奨設定:**
- タイムアウト: 600秒（標準的なコード分析）
- フォーカス:
  - `patterns` - デザインパターン重視
  - `quality` - 全体的な品質評価
  - `performance` - パフォーマンス最適化

---

### 3. Cursor (cursor-review.sh) - IDE統合 & 開発者体験

**いつ使うか:**
- UI/UXコードのレビュー
- APIクライアント実装
- 開発者向けライブラリ
- チーム開発のコード標準化

**基本使用法:**
```bash
# 標準レビュー
bash scripts/cursor-review.sh

# 可読性にフォーカス
bash scripts/cursor-review.sh --focus readability

# IDE統合性にフォーカス
bash scripts/cursor-review.sh --focus ide-friendliness

# 自動補完にフォーカス
bash scripts/cursor-review.sh --focus completion
```

**レビュー内容:**
- コード可読性評価
- IDE統合性チェック
- 自動補完フレンドリー度
- リファクタリング機会検出
- ネーミング規約チェック
- ドキュメントコメント品質

**出力例:**
```json
{
  "metrics": {
    "readability_score": 82,
    "ide_navigation_efficiency": 75,
    "autocomplete_coverage": 90,
    "naming_consistency": 88
  },
  "findings": [
    {
      "title": "Inconsistent Naming Convention",
      "severity": "Low",
      "priority": "P3",
      "file": "src/components/Button.tsx",
      "line": 15,
      "description": "Variable 'user_id' uses snake_case, but project uses camelCase",
      "recommendation": "Rename to 'userId' for consistency"
    }
  ]
}
```

**推奨設定:**
- タイムアウト: 600秒
- フォーカス:
  - `readability` - コード可読性改善
  - `ide-friendliness` - IDE統合性向上
  - `completion` - 自動補完の最適化

---

### 4. Amp (amp-review.sh) - プロジェクト管理 & ドキュメント

**いつ使うか:**
- APIドキュメント作成
- README/ガイドの更新
- プロジェクト計画の検証
- リリースノート作成

**基本使用法:**
```bash
# 標準レビュー
bash scripts/amp-review.sh

# ドキュメントにフォーカス
bash scripts/amp-review.sh --focus docs

# コミュニケーションにフォーカス
bash scripts/amp-review.sh --focus communication

# 計画にフォーカス
bash scripts/amp-review.sh --focus planning
```

**レビュー内容:**
- ドキュメント品質評価
- ステークホルダーコミュニケーション明確度
- 技術的負債追跡
- スプリント計画整合性
- コミットメッセージ品質
- 変更ログの適切性

**出力例:**
```json
{
  "metrics": {
    "documentation_coverage": 65,
    "communication_clarity": 78,
    "sprint_alignment": 85,
    "risk_score": 42
  },
  "findings": [
    {
      "title": "Missing API Documentation",
      "severity": "Medium",
      "priority": "P2",
      "file": "src/api/endpoints.js",
      "line": 0,
      "description": "Public API endpoints lack documentation",
      "recommendation": "Add JSDoc comments with params, returns, and examples"
    }
  ]
}
```

**推奨設定:**
- タイムアウト: 600秒
- フォーカス:
  - `docs` - ドキュメント品質
  - `communication` - コミュニケーション明確度
  - `planning` - プロジェクト計画整合性

---

### 5. Droid (droid-review.sh) - エンタープライズ基準

**いつ使うか:**
- 本番リリース前の最終検証
- エンタープライズ顧客向け機能
- 規制対応が必要な実装
- ミッションクリティカルなシステム

**基本使用法:**
```bash
# 標準レビュー
bash scripts/droid-review.sh

# コンプライアンスモード
bash scripts/droid-review.sh --compliance-mode

# フォーカス設定
bash scripts/droid-review.sh --focus compliance
bash scripts/droid-review.sh --focus scalability
bash scripts/droid-review.sh --focus reliability

# タイムアウト延長（デフォルト: 900秒）
bash scripts/droid-review.sh --timeout 1200
```

**レビュー内容:**
- エンタープライズ品質基準チェック
- コンプライアンス検証（GDPR, SOC2, HIPAA）
- スケーラビリティ評価
- 本番環境適合性
- SLA/SLO影響分析
- 災害復旧計画評価

**出力例:**
```json
{
  "metrics": {
    "enterprise_checklist_score": 88,
    "compliance_violations": 2,
    "scalability_rating": 7.5,
    "production_readiness": 85
  },
  "compliance": {
    "gdpr": {
      "status": "Pass",
      "findings": 0
    },
    "soc2": {
      "status": "Warning",
      "findings": 2
    }
  },
  "findings": [
    {
      "title": "Missing Data Retention Policy",
      "severity": "High",
      "priority": "P1",
      "compliance": ["GDPR", "SOC2"],
      "description": "User data lacks explicit retention policy",
      "recommendation": "Implement automated data purging after 90 days"
    }
  ]
}
```

**推奨設定:**
- タイムアウト: 900-1200秒（包括的な分析のため）
- フォーカス:
  - `compliance` - コンプライアンス重視
  - `scalability` - スケーラビリティ評価
  - `reliability` - 信頼性・可用性

---

## 使い分けガイド

### 変更タイプ別の推奨AI

| 変更タイプ | 推奨AI | 実行順序 | 理由 |
|----------|--------|---------|------|
| **セキュリティパッチ** | Gemini + Droid | 1. Gemini → 2. Droid | セキュリティ検証 + エンタープライズ基準 |
| **新機能実装** | Qwen + Cursor | 1. Qwen → 2. Cursor | コード品質 + 開発者体験 |
| **リファクタリング** | Qwen + Droid | 1. Qwen → 2. Droid | パターン改善 + 保守性 |
| **ドキュメント更新** | Amp + Cursor | 1. Amp → 2. Cursor | ドキュメント品質 + 可読性 |
| **UI/UX変更** | Cursor + Amp | 1. Cursor → 2. Amp | 開発者体験 + ユーザーコミュニケーション |
| **API実装** | Qwen + Gemini + Amp | 1. Qwen → 2. Gemini → 3. Amp | 品質 + セキュリティ + ドキュメント |
| **本番リリース** | 全5AI | 1. Gemini → 2. Qwen → 3. Cursor → 4. Amp → 5. Droid | 包括的検証 |

### プロジェクトフェーズ別の推奨

#### 開発初期（プロトタイプ）
- **推奨**: Qwen単体（高速フィードバック）
- **頻度**: コミットごと
- **タイムアウト**: 600秒

```bash
bash scripts/qwen-review.sh --focus quality
```

#### 開発中期（機能実装）
- **推奨**: Qwen + Cursor（品質 + DX）
- **頻度**: プルリクエストごと
- **タイムアウト**: 600秒 × 2 = 1200秒

```bash
bash scripts/qwen-review.sh --focus patterns
bash scripts/cursor-review.sh --focus readability
```

#### 開発後期（統合テスト）
- **推奨**: Qwen + Gemini + Droid（品質 + セキュリティ + エンタープライズ）
- **頻度**: スプリントごと
- **タイムアウト**: 600 + 900 + 900 = 2400秒

```bash
bash scripts/qwen-review.sh
bash scripts/gemini-review.sh
bash scripts/droid-review.sh
```

#### リリース前（最終検証）
- **推奨**: 全5AI
- **頻度**: リリース前（メジャー/マイナーバージョン）
- **タイムアウト**: 約3600秒（1時間）

```bash
bash scripts/multi-ai-review.sh --type all
```

### レビュー深度別の推奨

#### レベル1: 高速チェック（5-10分）
**目的**: 基本的な品質チェック、迅速なフィードバック

```bash
# Qwen単体（最も高速）
bash scripts/qwen-review.sh --focus quality
```

**適用シーン**:
- コミットごとのチェック
- CI/CDパイプライン
- pre-commitフック

---

#### レベル2: 標準レビュー（15-20分）
**目的**: 品質 + セキュリティの両立

```bash
# Qwen + Gemini
bash scripts/qwen-review.sh
bash scripts/gemini-review.sh
```

**適用シーン**:
- プルリクエスト
- 機能実装完了時
- 週次レビュー

---

#### レベル3: 包括レビュー（30-40分）
**目的**: 多角的な視点からの検証

```bash
# 全5AI並列実行
bash scripts/multi-ai-review.sh --type all
```

**適用シーン**:
- スプリント完了時
- リリース候補ブランチ
- 重要なリファクタリング

---

#### レベル4: 最大品質（60分+）
**目的**: 最も包括的な検証、本番リリース前

```bash
# 全5AI + Quad Review
bash scripts/multi-ai-review.sh --type all
source scripts/orchestrate/orchestrate-multi-ai.sh
multi-ai-quad-review "最終リリースレビュー"
```

**適用シーン**:
- 本番リリース前
- セキュリティクリティカルな変更
- エンタープライズ顧客向けリリース

---

## ワークフロー推奨事項

### 推奨ワークフロー1: 段階的レビュー（最も包括的）

```bash
#!/bin/bash
# scripts/workflows/comprehensive-review.sh

echo "=== Phase 1: 実装前ディスカッション ==="
source scripts/orchestrate/orchestrate-multi-ai.sh
multi-ai-discuss-before "新機能: ユーザー認証システム"

echo "=== Phase 2: TDDサイクルで実装 ==="
# (手動で実装作業)

echo "=== Phase 3: コード品質レビュー (Qwen) ==="
bash scripts/qwen-review.sh --focus quality

echo "=== Phase 4: セキュリティレビュー (Gemini) ==="
bash scripts/gemini-review.sh

echo "=== Phase 5: 開発者体験レビュー (Cursor) ==="
bash scripts/cursor-review.sh --focus readability

echo "=== Phase 6: ドキュメントレビュー (Amp) ==="
bash scripts/amp-review.sh --focus docs

echo "=== Phase 7: エンタープライズレビュー (Droid) ==="
bash scripts/droid-review.sh --compliance-mode

echo "=== Phase 8: 最終的な統合レビュー ==="
bash scripts/multi-ai-review.sh --type all

echo "=== 完了 ==="
echo "結果は logs/multi-ai-reviews/ を確認してください"
```

---

### 推奨ワークフロー2: 選択的レビュー（効率重視）

```bash
#!/bin/bash
# scripts/workflows/selective-review.sh

# 変更タイプを判定
CHANGE_TYPE=$1  # security | implementation | docs | release

case $CHANGE_TYPE in
  security)
    echo "セキュリティクリティカルな変更 → Gemini + Droid"
    bash scripts/gemini-review.sh --timeout 900
    bash scripts/droid-review.sh --compliance-mode
    ;;
  implementation)
    echo "コード実装 → Qwen + Cursor"
    bash scripts/qwen-review.sh --focus patterns
    bash scripts/cursor-review.sh --focus readability
    ;;
  docs)
    echo "ドキュメント変更 → Amp"
    bash scripts/amp-review.sh --focus docs
    ;;
  release)
    echo "本番リリース → 全5AI"
    bash scripts/multi-ai-review.sh --type all
    ;;
  *)
    echo "使用法: $0 {security|implementation|docs|release}"
    exit 1
    ;;
esac
```

**使用例:**
```bash
bash scripts/workflows/selective-review.sh security
bash scripts/workflows/selective-review.sh implementation
bash scripts/workflows/selective-review.sh docs
bash scripts/workflows/selective-review.sh release
```

---

### 推奨ワークフロー3: CI/CD統合（自動化）

**GitHub Actions例:**
```yaml
# .github/workflows/5ai-review.yml
name: 5AI Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  qwen-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Qwen Review
        run: bash scripts/qwen-review.sh --focus quality
      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: qwen-review
          path: logs/qwen-reviews/

  gemini-review:
    runs-on: ubuntu-latest
    if: contains(github.event.pull_request.labels.*.name, 'security')
    steps:
      - uses: actions/checkout@v3
      - name: Run Gemini Security Review
        run: bash scripts/gemini-review.sh --timeout 900
      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: gemini-review
          path: logs/gemini-reviews/

  comprehensive-review:
    runs-on: ubuntu-latest
    if: contains(github.event.pull_request.labels.*.name, 'release')
    steps:
      - uses: actions/checkout@v3
      - name: Run All 5AI Reviews
        run: bash scripts/multi-ai-review.sh --type all --timeout 1800
      - name: Upload Unified Report
        uses: actions/upload-artifact@v3
        with:
          name: unified-review
          path: logs/multi-ai-reviews/
```

---

## 出力の解釈方法

### JSON形式の構造

すべてのレビュースクリプトは、以下の標準的なJSON構造を出力します：

```json
{
  "metadata": {
    "ai": "qwen",
    "commit": "abc123def456",
    "timestamp": "2025-10-26T20:00:00Z",
    "timeout": 600,
    "execution_time": 542
  },
  "summary": {
    "total_findings": 12,
    "critical": 2,
    "high": 4,
    "medium": 5,
    "low": 1,
    "confidence_score": 0.85
  },
  "metrics": {
    "code_quality_score": 78,
    "maintainability_index": 82,
    "technical_debt_hours": 6.5
  },
  "findings": [
    {
      "id": "QWN-001",
      "title": "High Cyclomatic Complexity",
      "severity": "Medium",
      "priority": "P2",
      "confidence": 0.9,
      "file": "src/utils/validator.js",
      "line": 120,
      "description": "Function has complexity of 15, threshold is 10",
      "recommendation": "Extract nested conditions into separate functions",
      "code_snippet": "function validate(data) { ... }",
      "tags": ["complexity", "maintainability"]
    }
  ]
}
```

### 重要度（Severity）の解釈

| 重要度 | 意味 | 対応優先度 | 例 |
|--------|------|----------|-----|
| **Critical** | 即座に修正が必要 | P0（今すぐ） | SQLインジェクション、認証バイパス |
| **High** | 早急に修正すべき | P1（今週中） | XSS脆弱性、高複雑度関数 |
| **Medium** | 計画的に修正 | P2（今月中） | パフォーマンス問題、ドキュメント不足 |
| **Low** | 改善推奨 | P3（次スプリント） | コードスタイル、ネーミング |

### 優先度（Priority）の解釈

- **P0**: ブロッカー、リリース前に必ず修正
- **P1**: 重要、現在のスプリントで修正
- **P2**: 通常、次のスプリントで修正
- **P3**: 低優先、時間があれば修正

### 信頼度スコア（Confidence Score）

- **0.9-1.0**: 高信頼度、確実に問題あり
- **0.7-0.9**: 中信頼度、おそらく問題あり
- **0.5-0.7**: 低信頼度、要確認
- **0.0-0.5**: 非常に低信頼度、誤検出の可能性

### Markdown形式の読み方

Markdown形式は人間が読みやすい形式で、以下のセクションを含みます：

1. **エグゼクティブサマリー**: 全体の概要、主要な問題点
2. **メトリクス**: 数値で見る品質指標
3. **Priority 0 Findings**: 最優先で修正すべき項目
4. **Priority 1 Findings**: 高優先度の項目
5. **Priority 2 Findings**: 中優先度の項目
6. **Priority 3 Findings**: 低優先度の項目
7. **推奨アクション**: 次に取るべき行動

**例:**
```markdown
# Code Review Report - Qwen

**Commit**: abc123def456
**Date**: 2025-10-26 20:00:00
**Execution Time**: 542 seconds

## Executive Summary

Total Findings: 12 (Critical: 2, High: 4, Medium: 5, Low: 1)
Code Quality Score: 78/100
Confidence Score: 85%

### Critical Issues Found:
- SQL Injection vulnerability in database query (src/database/query.js:42)
- Authentication bypass in API endpoint (src/api/auth.js:156)

## Metrics

- Maintainability Index: 82/100
- Cyclomatic Complexity: Average 8.5
- Technical Debt: 6.5 hours
- Test Coverage: 73%

## Priority 0 Findings (Critical)

### QWN-001: SQL Injection Vulnerability
**File**: src/database/query.js:42
**Severity**: Critical
**Confidence**: 95%

**Description**:
User input from `req.body.userId` is directly concatenated into SQL query without sanitization.

**Code Snippet**:
```javascript
const query = `SELECT * FROM users WHERE id = ${req.body.userId}`;
```

**Recommendation**:
Use parameterized queries:
```javascript
const query = `SELECT * FROM users WHERE id = ?`;
db.execute(query, [req.body.userId]);
```

**References**:
- CWE-89: SQL Injection
- OWASP A03:2021 - Injection
```

---

## トラブルシューティング

### 問題1: スクリプトがタイムアウトする

**症状:**
```
Error: Review timed out after 600 seconds
```

**原因:**
- 大規模な変更セット
- AIサービスの応答遅延
- ネットワーク接続の問題

**解決策:**
```bash
# タイムアウトを延長
bash scripts/qwen-review.sh --timeout 1200

# 特定のファイルのみレビュー（該当機能未実装の場合）
git diff --name-only HEAD~1 | grep "src/api" | ...
```

---

### 問題2: JSON出力が不正

**症状:**
```
Error: Invalid JSON output from AI
```

**原因:**
- AI出力がJSON形式でない
- 部分的な出力（タイムアウト途中）
- 特殊文字のエスケープ問題

**解決策:**
```bash
# ログファイルを確認
tail -100 logs/vibe/20251026/qwen_review_20.jsonl

# テキスト形式で確認（フォールバック）
cat logs/qwen-reviews/latest_qwen.md

# 再実行（タイムアウト延長）
bash scripts/qwen-review.sh --timeout 900
```

---

### 問題3: AIラッパーが見つからない

**症状:**
```
Error: qwen-wrapper.sh not found or not executable
```

**原因:**
- ラッパースクリプトが未インストール
- PATH設定の問題
- 実行権限がない

**解決策:**
```bash
# ラッパーの存在確認
ls -la bin/qwen-wrapper.sh

# 実行権限付与
chmod +x bin/qwen-wrapper.sh

# PATHに追加（必要に応じて）
export PATH="$PATH:$(pwd)/bin"
```

---

### 問題4: REVIEW-PROMPT.mdが見つからない

**症状:**
```
Error: REVIEW-PROMPT.md not found
```

**原因:**
- REVIEW-PROMPT.mdがリポジトリに存在しない
- 間違ったディレクトリで実行

**解決策:**
```bash
# REVIEW-PROMPT.mdの作成（存在しない場合）
cp docs/templates/REVIEW-PROMPT.md.template ./REVIEW-PROMPT.md

# 正しいディレクトリで実行
cd /path/to/multi-ai-orchestrium
bash scripts/qwen-review.sh
```

---

### 問題5: 出力ディレクトリの権限エラー

**症状:**
```
Error: Permission denied: logs/qwen-reviews/
```

**原因:**
- logsディレクトリの書き込み権限がない

**解決策:**
```bash
# ディレクトリ作成と権限付与
mkdir -p logs/qwen-reviews
chmod 755 logs/qwen-reviews

# 別の出力ディレクトリを指定
bash scripts/qwen-review.sh --output /tmp/reviews
```

---

## よくある質問

### Q1: どのAIを最初に使うべきですか？

**A**: ほとんどの場合、**Qwen**から始めることをお勧めします。Qwenはコード品質を包括的にレビューし、最も汎用的です。

```bash
bash scripts/qwen-review.sh --focus quality
```

セキュリティが重要な場合は**Gemini**から始めてください。

---

### Q2: 全5AIでレビューするのに何分かかりますか？

**A**: 並列実行で約30-40分です。

- **並列実行**: 30-40分（推奨）
- **順次実行**: 60-90分

```bash
# 並列実行（推奨）
bash scripts/multi-ai-review.sh --type all  # 30-40分
```

---

### Q3: CI/CDパイプラインに組み込むべきですか？

**A**: はい、ただし**Qwen単体**をPRごとに実行し、全5AIはリリース前に実行することを推奨します。

**GitHub Actions例:**
```yaml
# PRごとにQwen
on: pull_request
run: bash scripts/qwen-review.sh --focus quality

# リリース前に全5AI
on: push
  branches: [release/*]
run: bash scripts/multi-ai-review.sh --type all
```

---

### Q4: レビュー結果の誤検出はどう扱うべきですか？

**A**: 信頼度スコア（Confidence Score）を確認してください。0.7未満の場合は誤検出の可能性が高いです。

```json
{
  "confidence": 0.6,  // 低信頼度 → 要確認
  "title": "Potential Issue"
}
```

また、複数のAIで同じ問題が指摘された場合は、誤検出の可能性は低いです。

---

### Q5: カスタムレビュー基準を追加できますか？

**A**: はい、REVIEW-PROMPT.mdを編集することで可能です。

```bash
# REVIEW-PROMPT.mdを編集
vim REVIEW-PROMPT.md

# カスタムセクションを追加
## Custom Review Criteria

- Check for specific coding standards
- Verify project-specific patterns
- ...
```

すべてのAIレビュースクリプトが自動的に新しい基準を使用します。

---

### Q6: 特定のファイルだけレビューできますか？

**A**: 現在の実装では、最新のコミット全体をレビューします。特定のファイルのみレビューする機能は今後追加予定です。

**回避策**:
```bash
# 特定のファイルのみコミット
git add src/specific/file.js
git commit -m "feat: specific change"
bash scripts/qwen-review.sh  # このコミットのみレビュー
```

---

### Q7: レビュー結果をチームで共有するには？

**A**: Markdown形式のレポートが最も共有しやすいです。

```bash
# レビュー実行
bash scripts/qwen-review.sh

# Markdownレポートをコピー
cp logs/qwen-reviews/latest_qwen.md reports/sprint-review.md

# GitHubやConfluenceにアップロード
# または、Slackに投稿
cat logs/qwen-reviews/latest_qwen.md | pbcopy  # macOS
```

---

### Q8: レビュー結果をPRコメントに自動投稿できますか？

**A**: GitHub Actions + `gh` CLIを使って可能です。

```yaml
# .github/workflows/5ai-review.yml
- name: Run Qwen Review
  run: bash scripts/qwen-review.sh

- name: Post Review to PR
  run: |
    REVIEW=$(cat logs/qwen-reviews/latest_qwen.md)
    gh pr comment ${{ github.event.pull_request.number }} --body "$REVIEW"
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## まとめ

5AI Review Scriptsは、Multi-AI Orchestriumの強力なツールです。各AIの特性を理解し、適切に使い分けることで、コード品質、セキュリティ、保守性を大幅に向上させることができます。

**推奨ベストプラクティス:**
1. **日常開発**: Qwen単体（高速フィードバック）
2. **PRレビュー**: Qwen + Gemini（品質 + セキュリティ）
3. **スプリント完了**: Qwen + Gemini + Droid（包括的検証）
4. **リリース前**: 全5AI（最大品質保証）

詳細な技術仕様や開発者向け情報は、`docs/ARCHITECTURE.md`を参照してください。

---

**関連ドキュメント:**
- [実装計画](FIVE_AI_REVIEW_SCRIPTS_IMPLEMENTATION_PLAN.md)
- [CLAUDE.md](../CLAUDE.md)
- [テスト観察表](test-observations/)
- [個別AIガイド](reviews/)（作成予定）

**サポート:**
- Issue: https://github.com/your-org/multi-ai-orchestrium/issues
- Discussion: https://github.com/your-org/multi-ai-orchestrium/discussions
