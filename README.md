# Multi-AI Orchestrium

**複数のAIを協調させる次世代開発フレームワーク**

ChatDevとChain-of-Agentsを統合し、Claude、Gemini、Amp、Qwen、Droid、Codex、Cursorの7つのAIツールを並列・順次実行で協調させ、高速かつ高品質な開発を実現します。

[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)]()
[![Version](https://img.shields.io/badge/Version-v3.0-blue)]()
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 🎉 プロジェクト完了状態

**Phase 1-3A完全実装完了**（2025-10-26）
- ✅ **総実装行数**: 8,000行以上
- ✅ **レビュースクリプト**: 13個完全実装
- ✅ **テスト成功率**: ユニット77%、統合100%
- ✅ **ドキュメント**: 3,500行以上の包括的ガイド
- ✅ **計画期間**: 57%短縮（28日 → 16日）

詳細: [docs/PROJECT_COMPLETION_SUMMARY.md](docs/PROJECT_COMPLETION_SUMMARY.md)

## 🌟 主な特徴

- **YAML駆動設計**: スクリプト変更なしで役割分担を変更可能
- **2つの協調パターン**: ChatDev（役割ベース）+ CoA（分割統治）
- **13個のレビューシステム**: 5AI個別 + 3コア + 統合インターフェース
- **Primary/Fallback機構**: 高可用性98%以上
- **VibeLogger統合**: AI最適化された構造化ログ
- **フォールトトレランス**: 一部AIが失敗しても処理継続

## 📋 目次

- [事前準備](#事前準備)
- [導入手順](#導入手順)
- [プロジェクト構造](#📁-プロジェクト構造)
- [レビューシステム](#🔍-包括的レビューシステム)
  - [5AI個別レビュースクリプト](#1-5ai個別レビュースクリプト最も柔軟)
  - [3コアレビュースクリプト](#2-3コアレビュースクリプトreview-prompt準拠)
  - [統一インターフェース](#3-統一インターフェースmulti-ai-reviewsh)
  - [自動ルーティング](#4-自動ルーティングreview-dispatchersh)
  - [Claude専用レビュー](#5-claude専用レビュー)
  - [Quad Review](#6-quad-review4ツール統合レビュー)
- [オーケストレーションワークフロー](#🎯-オーケストレーションワークフロー)
- [TDDワークフロー](#🧪-tddワークフロー)
- [使用例](#🎯-使用例)
- [トラブルシューティング](#🔧-トラブルシューティング)
- [ライセンス](#📄-ライセンス)

## 事前準備

各AIツールの公式サイトを参考にインストールしてください。

- [**Claude Code**](https://docs.claude.com/ja/docs/claude-code/overview)
- [**Gemini CLI**](https://github.com/google-gemini/gemini-cli)
- [**Qwen Code**](https://github.com/QwenLM/qwen-code)
- [**Codex CLI**](https://developers.openai.com/codex/cli/)
- [**Cursor CLI**](https://cursor.com/ja/docs/cli/overview)
- [**CodeRabbit CLI**](https://www.coderabbit.ai/ja/cli)
- [**Amp**](https://ampcode.com/manual)
- [**Droid CLI**](https://docs.factory.ai/cli/getting-started/quickstart)

## 導入手順

```bash
# 1) リポジトリをクローン
git clone https://github.com/CaCC-Lab/multi-ai-orchestrium
cd multi-ai-orchestrium

# 2) 実行権限を一括付与（重要！）
./setup-permissions.sh

# 3) Python依存関係をインストール（オプション）
pip install -r requirements.txt

# 4) AIツールの可用性確認
./check-multi-ai-tools.sh

# 5) スクリプトをソースして実行
source scripts/orchestrate/orchestrate-multi-ai.sh

# 6) ワークフロー実行（例：ChatDev開発ワークフロー）
multi-ai-chatdev-develop "新プロジェクトの概要"
```

### 📝 setup-permissions.sh について

`setup-permissions.sh` は、プロジェクト内の全シェルスクリプト（39個）に実行権限を一括付与するユーティリティです。

**実行方法:**
```bash
./setup-permissions.sh
```

### 📋 check-multi-ai-tools.sh について

`check-multi-ai-tools.sh` は、必要なAI CLIツールがインストールされているかを確認します。

**実行方法:**
```bash
./check-multi-ai-tools.sh
```

## 📁 プロジェクト構造

```
multi-ai-orchestrium/
├── config/
│   ├── multi-ai-profiles.yaml          # YAML駆動のAIロール設定（7AI）
│   ├── review-profiles.yaml            # レビュープロファイル設定
│   └── ai-cli-versions.yaml            # AIバージョン管理
├── scripts/
│   ├── orchestrate/
│   │   ├── orchestrate-multi-ai.sh     # メインオーケストレーター
│   │   └── lib/                        # モジュール化ライブラリ（10ファイル）
│   │       ├── multi-ai-core.sh        # コア機能（15関数）
│   │       ├── multi-ai-ai-interface.sh # AI統合（5関数）
│   │       ├── multi-ai-config.sh      # YAML設定（16関数）
│   │       ├── multi-ai-workflows.sh   # ワークフローローダー
│   │       ├── workflows-core.sh       # コアワークフロー
│   │       ├── workflows-discussion.sh # ディスカッション
│   │       ├── workflows-coa.sh        # Chain-of-Agents
│   │       ├── workflows-review.sh     # レビューワークフロー
│   │       └── workflows-review-quad.sh # Quad Review
│   ├── review/
│   │   ├── lib/
│   │   │   ├── review-common.sh        # 共通機能（15関数）
│   │   │   ├── review-prompt-loader.sh # プロンプト管理（7関数）
│   │   │   └── review-adapters/        # AI特性別アダプター
│   │   │       ├── adapter-base.sh     # Template Method Pattern
│   │   │       ├── adapter-gemini.sh   # Gemini特化
│   │   │       ├── adapter-qwen.sh     # Qwen特化
│   │   │       ├── adapter-droid.sh    # Droid特化
│   │   │       ├── adapter-claude.sh   # Claude特化
│   │   │       └── adapter-claude-security.sh # Claude Security
│   │   ├── security-review.sh          # セキュリティレビュー（562行）
│   │   ├── quality-review.sh           # 品質レビュー（466行）
│   │   └── enterprise-review.sh        # エンタープライズレビュー（745行）
│   ├── tdd/
│   │   ├── tdd-multi-ai.sh             # TDDサイクル
│   │   └── tdd-multi-ai-phases.sh      # 6フェーズTDD
│   ├── lib/
│   │   ├── sanitize.sh                 # 入力検証、セキュリティ
│   │   └── tdd-multi-ai-common.sh      # TDD共通関数
│   ├── amp-review.sh                   # Ampレビュー（599行）
│   ├── cursor-review.sh                # Cursorレビュー（597行）
│   ├── droid-review.sh                 # Droidレビュー（701行）
│   ├── gemini-review.sh                # Geminiレビュー（583行）
│   ├── qwen-review.sh                  # Qwenレビュー（584行）
│   ├── claude-review.sh                # Claude包括レビュー（650行）
│   ├── claude-security-review.sh       # Claudeセキュリティレビュー（560行）
│   ├── codex-review.sh                 # Codexレビュー（653行）
│   ├── coderabbit-review.sh            # CodeRabbitレビュー（1,848行）
│   ├── multi-ai-review.sh              # 統一インターフェース（826行）
│   ├── review-dispatcher.sh            # 自動ルーティング（336行）
│   └── collect-review-metrics.sh       # メトリクス収集（405行）
├── bin/
│   ├── *-wrapper.sh                    # AI CLIラッパー（7個）
│   ├── agents-utils.sh                 # タスク分類
│   ├── vibe-logger-lib.sh              # 構造化ロギング
│   └── common-wrapper-lib.sh           # 共通ライブラリ
├── src/
│   ├── core/                           # キャッシュ、設定、バージョンチェック
│   ├── install/                        # インストーラー、アップデーター
│   └── ui/                             # UI、レポート
├── tests/
│   ├── unit/                           # ユニットテスト（11個）
│   ├── integration/                    # 統合テスト（10個）
│   ├── e2e/                            # E2Eテスト
│   └── test-*-review.sh                # 5AIレビューテスト（4個）
├── docs/
│   ├── REVIEW_SYSTEM_GUIDE.md          # ユーザーガイド（1,024行）
│   ├── REVIEW_ARCHITECTURE.md          # アーキテクチャ（1,024行）
│   ├── FIVE_AI_REVIEW_GUIDE.md         # 5AIレビューガイド（674行）
│   ├── PROJECT_COMPLETION_SUMMARY.md   # プロジェクト完了サマリー
│   └── OPTION_D++_IMPLEMENTATION_PLAN.md # 実装計画
└── logs/
    ├── vibe/YYYYMMDD/                  # VibeLoggerログ
    ├── *-reviews/                      # レビュー結果（JSON/Markdown）
    └── metrics/                        # メトリクスレポート
```

## 🔍 包括的レビューシステム

Multi-AI Orchestriumは、13個のレビュースクリプトで構成される世界最大級のAI協調レビューシステムを提供します。

### レビューシステム階層

```
┌─────────────────────────────────────────────────────┐
│  レイヤー1: 自動ルーティング                        │
│  ├─ review-dispatcher.sh (8ルールベース判定)        │
│  └─ Git diff解析による最適レビュー選択              │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────┐
│  レイヤー2: 統一インターフェース                    │
│  ├─ multi-ai-review.sh (YAML駆動)                   │
│  ├─ 5プロファイル対応                               │
│  └─ 統合レポート生成（JSON/HTML）                   │
└──────────────────────┬──────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
┌───────▼────┐ ┌───────▼────┐ ┌──────▼─────┐
│ セキュリティ│ │   品質     │ │エンタープラ│
│   レビュー  │ │ レビュー   │ │イズレビュー│
│ (Gemini)   │ │  (Qwen)    │ │  (Droid)   │
└────────────┘ └────────────┘ └────────────┘
        │              │              │
        └──────────────┼──────────────┘
                       │
┌──────────────────────┴──────────────────────────────┐
│  レイヤー3: AI特性別アダプター                      │
│  ├─ adapter-base.sh (Template Method Pattern)       │
│  ├─ adapter-gemini.sh (Web検索、CVEキャッシング)   │
│  ├─ adapter-qwen.sh (高速解析、リファクタ提案)     │
│  ├─ adapter-droid.sh (エンタープライズ、コンプラ)  │
│  ├─ adapter-claude.sh (包括レビュー)               │
│  └─ adapter-claude-security.sh (セキュリティ特化)  │
└─────────────────────────────────────────────────────┘
```

### 1. 5AI個別レビュースクリプト（最も柔軟）

各AIの特性を最大限に活かした専用レビュースクリプト。

#### gemini-review.sh - セキュリティ & アーキテクチャ

**専門領域**: OWASP Top 10、CVE検索、アーキテクチャ設計

```bash
# 基本使用方法
bash scripts/gemini-review.sh --commit abc123

# 出力形式指定
bash scripts/gemini-review.sh --commit abc123 --format json
```

**検出項目**:
- OWASP Top 10脆弱性
- CVE既知脆弱性（Web検索）
- アーキテクチャ設計問題
- スケーラビリティリスク

**特徴**:
- Web検索統合でCVE情報を自動取得
- CVSS v3.1スコア付き
- タイムアウト: 900秒

**出力**: `logs/gemini-reviews/{timestamp}_{commit}_gemini.json|md`

---

#### qwen-review.sh - コード品質 & パターン

**専門領域**: コード品質、デザインパターン、リファクタリング

```bash
# 基本使用方法
bash scripts/qwen-review.sh --commit abc123

# フォーカス指定
bash scripts/qwen-review.sh --commit abc123 --focus patterns
```

**検出項目**:
- 保守性インデックス
- 循環的複雑度
- デザインパターン検出
- 技術的負債評価
- パフォーマンス最適化提案

**フォーカスオプション**: `patterns`, `quality`, `performance`

**特徴**:
- 93.9% HumanEval精度
- 具体的なリファクタリングコード例付き
- タイムアウト: 600秒

**出力**: `logs/qwen-reviews/{timestamp}_{commit}_qwen.json|md`

---

#### cursor-review.sh - IDE統合 & 開発者体験

**専門領域**: 可読性、IDE統合性、開発者体験

```bash
# 基本使用方法
bash scripts/cursor-review.sh --commit abc123

# フォーカス指定
bash scripts/cursor-review.sh --commit abc123 --focus readability
```

**検出項目**:
- 可読性スコア（0.0-1.0）
- リファクタリング機会
- IDE navigation効率
- 自動補完カバレッジ
- 変数命名レビュー

**フォーカスオプション**: `readability`, `ide-friendliness`, `completion`, `refactoring`, `naming`, `structure`

**特徴**:
- 可読性スコア計算（8要素）
- IDEフレンドリー度評価
- タイムアウト: 600秒

**出力**: `logs/cursor-reviews/{timestamp}_{commit}_cursor.json|md`

---

#### amp-review.sh - プロジェクト管理 & ドキュメント

**専門領域**: ドキュメント、コミュニケーション、技術的負債

```bash
# 基本使用方法
bash scripts/amp-review.sh --commit abc123

# フォーカス指定
bash scripts/amp-review.sh --commit abc123 --focus docs
```

**検出項目**:
- ドキュメントカバレッジ（0.0-1.0）
- ステークホルダー影響分析
- 技術的負債追跡
- スプリント整合性
- リスク評価
- Changelog生成ヒント

**フォーカスオプション**: `docs`, `communication`, `planning`, `debt`, `risk`, `changelog`

**特徴**:
- ステークホルダー6グループ分析
- ドキュメントカバレッジ6要素評価
- タイムアウト: 600秒

**出力**: `logs/amp-reviews/{timestamp}_{commit}_amp.json|md`

---

#### droid-review.sh - エンタープライズ基準

**専門領域**: エンタープライズ品質、コンプライアンス、本番適合性

```bash
# 基本使用方法
bash scripts/droid-review.sh --commit abc123

# コンプライアンスモード
bash scripts/droid-review.sh --commit abc123 --compliance-mode

# フォーカス指定
bash scripts/droid-review.sh --commit abc123 --focus compliance
```

**検出項目**:
- エンタープライズチェックリスト（0-100）
- コンプライアンス検証（GDPR, SOC2, HIPAA, PCI-DSS）
- スケーラビリティボトルネック
- 信頼性スコア（0.0-1.0）
- SLA/SLO影響分析

**フォーカスオプション**: `compliance`, `scalability`, `reliability`, `maintainability`, `production`, `sla`

**特徴**:
- 本番デプロイ基準: ≥80/100
- コンプライアンスチェックリスト
- 最長タイムアウト: 900秒

**出力**: `logs/droid-reviews/{timestamp}_{commit}_droid.json|md`

---

### 2. 3コアレビュースクリプト（REVIEW-PROMPT準拠）

REVIEW-PROMPT.md準拠の統一フォーマットで、Primary/Fallback機構を備えた高可用性レビュー。

#### security-review.sh - セキュリティ特化

**Primary AI**: Gemini（Web検索でCVE情報取得）
**Fallback AI**: Claude Security

```bash
# 基本使用方法
bash scripts/review/security-review.sh --commit abc123

# 出力形式指定
bash scripts/review/security-review.sh --commit abc123 --format sarif
```

**検出項目**:
- SQLインジェクション（CWE-89）
- XSS（CWE-79）
- コマンドインジェクション（CWE-77, 78）
- パストラバーサル（CWE-22）
- ハードコードされた秘密情報（CWE-798）
- 不安全な暗号化（CWE-327）

**タイムアウト**: 600秒
**出力形式**: JSON, Markdown, SARIF

---

#### quality-review.sh - 品質特化

**Primary AI**: Qwen（93.9% HumanEval）
**Fallback AI**: Codex

```bash
# 基本使用方法
bash scripts/review/quality-review.sh --commit abc123

# 高速モード（120秒、P0-P1のみ）
bash scripts/review/quality-review.sh --commit abc123 --fast
```

**検出項目**:
- コード可読性、保守性
- 型安全性
- パフォーマンス問題
- リファクタリング提案（具体コード例付き）
- ベストプラクティス違反

**タイムアウト**: 300秒（高速モード: 120秒）
**出力形式**: JSON, Markdown

---

#### enterprise-review.sh - エンタープライズ特化

**Primary AI**: Droid
**Fallback AI**: Claude Comprehensive

```bash
# 基本使用方法
bash scripts/review/enterprise-review.sh --commit abc123

# コンプライアンスモード
bash scripts/review/enterprise-review.sh --commit abc123 --compliance
```

**検出項目**:
- SLA適合性（可用性、パフォーマンス、信頼性）
- 監査ログの十分性
- セキュリティ標準遵守（NIST、ISO27001）
- スケーラビリティリスク
- 技術的負債評価

**タイムアウト**: 900秒
**出力形式**: JSON, Markdown, HTML

---

### 3. 統一インターフェース（multi-ai-review.sh）

**NEW (v2.0.0)**: YAML駆動の統一レビューインターフェース

```bash
# レビュータイプ指定
bash scripts/multi-ai-review.sh --type TYPE [OPTIONS]

# プロファイル指定
bash scripts/multi-ai-review.sh --profile PROFILE [OPTIONS]
```

#### レビュータイプ（--type）

| タイプ | 主要AI | 対象領域 | タイムアウト |
|--------|--------|---------|------------|
| `security` | Gemini | セキュリティ脆弱性 | 900秒 |
| `quality` | Qwen | コード品質、テスト | 600秒 |
| `enterprise` | Droid | エンタープライズ基準 | 900秒 |
| `all` | 全AI | 3つのレビューを並列実行 + 統合レポート | 900秒 |

#### プロファイル（--profile）

`config/review-profiles.yaml`で定義された事前設定：

| プロファイル | レビュータイプ | 特徴 | タイムアウト |
|-------------|--------------|-----|------------|
| `security-focused` | security | セキュリティ特化 | 900秒 |
| `quality-focused` | quality | 品質・テスト特化 | 600秒 |
| `enterprise-focused` | enterprise | エンタープライズ基準 | 900秒 |
| `balanced` | all | 全レビュー統合 | 900秒 |
| `fast` | quality (--fast) | P0-P1のみ、高速 | 120秒 |

#### 共通オプション

```bash
--commit HASH         # レビュー対象コミット（デフォルト: HEAD）
--timeout SECONDS     # タイムアウト秒数
--output-dir PATH     # 出力ディレクトリ
--format FORMAT       # 出力形式: json | markdown | sarif | html | all
```

#### 使用例

```bash
# セキュリティレビュー
bash scripts/multi-ai-review.sh --type security

# 品質レビュー（高速モード）
bash scripts/multi-ai-review.sh --type quality --fast

# 全レビュー統合
bash scripts/multi-ai-review.sh --type all --commit abc123

# プロファイル使用
bash scripts/multi-ai-review.sh --profile balanced
```

#### 統合レポート

`--type all`実行時、統合レポートが生成されます：

- **JSON形式**: 3レビュー結果をマージ、重複除去、優先度ソート
- **HTML形式**: タブ型ダッシュボード、統合ステータス表示

---

### 4. 自動ルーティング（review-dispatcher.sh）

Git diff解析により最適なレビュータイプを自動判定します。

```bash
# 基本使用方法（自動判定 + 実行）
bash scripts/review-dispatcher.sh

# Dry-run（判定のみ、実行なし）
bash scripts/review-dispatcher.sh --dry-run

# カスタムコミット
bash scripts/review-dispatcher.sh --commit abc123
```

#### 8ルールベース判定

| 優先度 | 条件 | 選択レビュー |
|--------|------|-------------|
| P0 | セキュリティキーワード検出 | security |
| P0 | 認証・暗号化ファイル変更 | security |
| P1 | 100行以上変更 | all |
| P1 | 本番環境ファイル変更 | enterprise |
| P2 | テストファイルのみ変更 | quality |
| P2 | ドキュメントのみ変更 | （レビュースキップ） |
| P3 | スクリプトファイル変更 | quality |
| P4 | デフォルト | quality |

#### クリティカル条件

以下の場合、常に全レビュー（`--type all`）が実行されます：

- セキュリティキーワード: `password`, `secret`, `token`, `auth`, `crypto`
- 本番環境ファイル: `.env.production`, `docker-compose.prod.yml`
- 大規模変更: 100行以上の変更

---

### 5. Claude専用レビュー

#### claude-review.sh - 包括的コードレビュー

```bash
# 最新コミットをレビュー
bash scripts/claude-review.sh

# 特定コミットをレビュー
bash scripts/claude-review.sh --commit abc123

# カスタムタイムアウト
bash scripts/claude-review.sh --timeout 900
```

**レビュー項目**:
- コード品質（可読性、保守性、一貫性）
- 設計パターン（アーキテクチャ、モジュール性）
- パフォーマンス（アルゴリズム効率）
- ベストプラクティス
- テストカバレッジ

**タイムアウト**: 600秒（デフォルト）

---

#### claude-security-review.sh - セキュリティ特化レビュー

```bash
# セキュリティレビュー実行
bash scripts/claude-security-review.sh

# 重要度フィルタリング
bash scripts/claude-security-review.sh --severity Critical
```

**チェック項目**:
- OWASP Top 10対応
- CWE脆弱性検出（10項目以上）
- CVSS v3.1スコア付き

**タイムアウト**: 900秒（デフォルト）

**出力形式**: JSON, Markdown, SARIF

---

### 6. Quad Review（4ツール統合レビュー）

**最も包括的なレビューワークフロー**

```bash
# オーケストレーターをソース
source scripts/orchestrate/orchestrate-multi-ai.sh

# Quad Review実行（約30分）
multi-ai-quad-review "最新コミットの徹底レビュー"
```

#### 実行フロー（3フェーズ）

```
Phase 1: 4つの自動レビュー（並列実行、約15分）
  ├─ Codex自動レビュー（10分タイムアウト）
  ├─ CodeRabbit自動レビュー（15分タイムアウト）
  ├─ Claude包括レビュー（10分タイムアウト）
  └─ Claudeセキュリティレビュー（15分タイムアウト）

Phase 2: 6AI協調分析（約10分）
  ├─ Gemini: セキュリティ検証
  ├─ Amp: メンテナンス性評価
  ├─ Qwen: 代替実装提案
  ├─ Droid: エンタープライズ基準評価
  ├─ Codex: 最適化提案
  └─ Cursor: 開発者体験評価

Phase 3: 統合レポート生成（約5分）
  └─ Claude: 10個のレビュー結果を統合

合計所要時間: 約30分
```

#### vs Dual Review比較

| 項目 | Dual Review | Quad Review |
|------|------------|------------|
| レビューツール数 | 2 | 4 |
| セキュリティ特化 | なし | ✅ |
| 6AI協調分析 | なし | ✅ |
| 統合レポート | なし | ✅ |
| 所要時間 | 約15分 | 約30分 |
| 推奨用途 | 通常コミット | 重要リリース |

---

## 🎯 オーケストレーションワークフロー

### メインワークフロー関数

すべてのワークフローは`config/multi-ai-profiles.yaml`からYAML駆動で実行されます。

| 関数名 | 説明 | 使用AI | 実行時間 |
|--------|------|--------|---------|
| multi-ai-full-orchestrate | フルオーケストレーション | 全7AI | 5-8分 |
| multi-ai-speed-prototype | 高速プロトタイプ生成 | 全7AI | 2-4分 |
| multi-ai-enterprise-quality | エンタープライズ品質実装 | 全7AI | 15-20分 |
| multi-ai-hybrid-development | ハイブリッド開発（適応的選択） | 動的選択 | 5-15分 |
| multi-ai-chatdev-develop | ChatDev役割ベース開発 | 全7AI | 5-8分 |
| multi-ai-discuss-before | 実装前ディスカッション | 全7AI | 10分 |
| multi-ai-review-after | 実装後レビュー | 全7AI | 5-8分 |
| multi-ai-coa-analyze | Chain-of-Agents解析 | 全7AI | 3-5分 |
| multi-ai-consensus-review | 合意形成レビュー | 全7AI | 15-20分 |
| multi-ai-code-review | コードレビュー（Codex+CodeRabbit） | レビュー特化 | 10-15分 |
| multi-ai-quad-review | Quad統合レビュー（4ツール+6AI） | 4ツール+6AI | 約30分 |

### オーケストレーションスクリプトのソース

```bash
# オーケストレーターをソース
source scripts/orchestrate/orchestrate-multi-ai.sh

# ワークフロー実行
multi-ai-full-orchestrate "新機能開発"
```

---

## 🧪 TDDワークフロー

TDDサイクルは`config/multi-ai-profiles.yaml`のプロファイルベース設定を使用します。

```bash
# TDDスクリプトをソース
source scripts/tdd/tdd-multi-ai.sh

# 利用可能なプロファイル
export TDD_PROFILE=balanced  # classic_cycle, speed_first, quality_first, balanced, six_phases

# TDDサイクルの実行
tdd-multi-ai-cycle "機能名"              # インタラクティブ（一時停止あり）
tdd-multi-ai-fast "機能名"               # 高速（一時停止なし）

# 個別フェーズ
tdd-multi-ai-plan "機能"                 # Phase 0: 計画
tdd-multi-ai-red "機能"                  # Phase 1: 失敗するテスト作成
tdd-multi-ai-green "テストの説明"        # Phase 2: テストを通す
tdd-multi-ai-refactor "コード"           # Phase 3: 最適化
tdd-multi-ai-review "実装"               # Phase 4: レビュー

# ペアプログラミング
pair-multi-ai-driver "タスク"            # ドライバーモード（Qwen + Droid）
pair-multi-ai-navigator "コード"         # ナビゲーターモード（Gemini + Amp）
```

---

## 🎯 使用例

### レビューシステムの推奨ワークフロー

#### 1. 通常開発フロー

```bash
# 実装前ディスカッション
multi-ai-discuss-before "新機能の実装計画"

# 実装（TDDサイクル）
source scripts/tdd/tdd-multi-ai.sh
tdd-multi-ai-cycle "新機能実装"

# 自動ルーティングでレビュー実行
bash scripts/review-dispatcher.sh
```

#### 2. 重要リリース前フロー

```bash
# 実装前ディスカッション
multi-ai-discuss-before "v2.0.0リリース実装計画"

# 実装

# Quad Review実行（最も包括的）
multi-ai-quad-review "v2.0.0リリースの徹底レビュー"

# 統合レビュー（追加確認）
bash scripts/multi-ai-review.sh --type all
```

#### 3. セキュリティクリティカルな変更

```bash
# 5AI個別レビュー（セキュリティ特化）
bash scripts/gemini-review.sh --commit abc123

# 3コアレビュー（セキュリティ特化）
bash scripts/review/security-review.sh --commit abc123

# Claude Security Review
bash scripts/claude-security-review.sh --commit abc123
```

#### 4. 高速CI/CDパイプライン

```bash
# 高速モード（120秒）
bash scripts/multi-ai-review.sh --profile fast

# または
bash scripts/review/quality-review.sh --commit abc123 --fast
```

### オーケストレーションワークフローの例

```bash
# スクリプトをソース
source scripts/orchestrate/orchestrate-multi-ai.sh

# ワークフロー実行
multi-ai-full-orchestrate "新機能開発"
multi-ai-chatdev-develop "Eコマースサイト"
multi-ai-coa-analyze "技術ドキュメント解析"

# ディスカッション & レビュー
multi-ai-discuss-before "実装計画"
multi-ai-review-after "コードまたはファイル"
multi-ai-consensus-review "複雑な意思決定"
```

### 各AIの役割変更

YAML編集だけで役割分担を入れ替え可能。スクリプト変更不要、即反映。

変更可能なパラメータ:
- **AI割り当て**: `ai: claude | gemini | amp | qwen | droid | codex | cursor`
- **役割定義**: `role: ceo-product-vision`（自由に追加可）
- **タイムアウト**: `timeout: 300`（秒）
- **実行モード**: 並列は `parallel:`、順次は `ai:` のみ
- **ブロッキング**: `blocking: true|false`
- **入力参照**: `input_from: ["qwen", "droid"]`

---

## 🔧 トラブルシューティング

### Claude MCP接続エラー

**症状**: `Error: MCP server not responding`

**解決策**:
```bash
# MCPサーバーの状態確認
ps aux | grep claude

# MCPサーバーの再起動
killall claude-mcp-server
claude-mcp-server start

# 接続テスト
echo "test" | claude chat
```

### タイムアウトエラー

**症状**: スクリプトが完了前にタイムアウト

**解決策**:
```bash
# タイムアウト値を延長
bash scripts/review/quality-review.sh --timeout 1200

# 複雑なレビューには1800秒（30分）を推奨
bash scripts/review/enterprise-review.sh --timeout 1800
```

### 出力ファイルが生成されない

**症状**: `logs/*-reviews/`ディレクトリが空

**解決策**:
```bash
# ディレクトリの存在と権限を確認
ls -ld logs/gemini-reviews/

# 必要に応じてディレクトリを作成
mkdir -p logs/{gemini,qwen,cursor,amp,droid}-reviews logs/ai-coop

# 権限設定
chmod 755 logs/*-reviews logs/ai-coop
```

### jq: command not found

**症状**: `jq: command not found` または `Invalid SARIF format`

**解決策**:
```bash
# jqのインストール（Linux）
sudo apt-get install jq

# jqのインストール（macOS）
brew install jq
```

### 権限エラー

**症状**: `Permission denied` when running scripts

**解決策**:
```bash
# 実行権限の一括付与
./setup-permissions.sh

# 個別に権限付与
chmod +x scripts/*.sh scripts/**/*.sh
```

---

## 📚 ドキュメント

### ユーザー向けドキュメント

- **[REVIEW_SYSTEM_GUIDE.md](docs/REVIEW_SYSTEM_GUIDE.md)** - 包括的ユーザーガイド（1,024行）
  - イントロダクション & クイックスタート
  - 3レビュータイプ（Security/Quality/Enterprise）
  - 統一インターフェース & プロファイル
  - 自動ルーティング & メトリクス
  - トラブルシューティング & CI/CD統合

- **[FIVE_AI_REVIEW_GUIDE.md](docs/FIVE_AI_REVIEW_GUIDE.md)** - 5AIレビューガイド（674行）
  - Gemini, Qwen, Cursor, Amp, Droid各レビュースクリプトの詳細
  - フォーカスオプション、使用例、推奨シナリオ

### 技術ドキュメント

- **[REVIEW_ARCHITECTURE.md](docs/REVIEW_ARCHITECTURE.md)** - アーキテクチャ仕様（1,024行）
  - アーキテクチャ概要 & 図解
  - 共通ライブラリ & アダプター
  - Primary/Fallbackメカニズム
  - REVIEW-PROMPT準拠
  - 拡張ガイド

- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Multi-AI Orchestrium全体アーキテクチャ（32KB）
  - オーケストレーションシステム
  - TDDワークフロー
  - 7AI協調パターン

### プロジェクトドキュメント

- **[PROJECT_COMPLETION_SUMMARY.md](docs/PROJECT_COMPLETION_SUMMARY.md)** - プロジェクト完了サマリー
  - Phase 1-3A完了詳細
  - 実装行数、テスト結果、メトリクス
  - 達成率、パフォーマンス指標

- **[OPTION_D++_IMPLEMENTATION_PLAN.md](docs/OPTION_D++_IMPLEMENTATION_PLAN.md)** - 実装計画（59KB）
  - 7AI合意形成 & Option D++設計
  - フェーズ別実装詳細
  - Pre-Phase 1フィードバック統合

- **[CONTRIBUTING.md](docs/CONTRIBUTING.md)** - 貢献ガイドライン（38KB）
  - 開発環境セットアップ
  - コーディング規約
  - テスト要件
  - PRワークフロー

---

## 既知の課題

- **タイムアウト**: 長時間タスクや外部依存での処理待ちが発生しやすい。
- **コンテキスト**: ツール間でのコンテキスト引き継ぎや上限管理が難しい。
- **MCP やサブエージェント**: 現状ではタイムアウトとコンテキストの制約をクリアできず、手堅く制御しやすい Bash スクリプト構成に落ち着きました。

---

## 謝辞

このプロジェクトは以下の研究・プロジェクトから着想を得ています：

- [ChatDev](https://arxiv.org/abs/2307.07924) - AI協調開発の先駆的研究
- [Chain-of-Agents](https://arxiv.org/abs/2406.02818) - 大規模マルチエージェント協調
- [A Critical Perspective on Multi-Agent Systems](https://cognition.ai/blog/dont-build-multi-agents) - マルチエージェントシステムの課題と適切な使用場面に関する考察
- [Vibe Logger](https://github.com/fladdict/vibe-logger) - AI用構造化ロギング
- [kinopeee/cursorrules](https://github.com/kinopeee/cursorrules) - Cursor AI の効果的な活用ルールとベストプラクティス集

---

## 📄 ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

Copyright (c) 2025 Multi-AI Orchestrium Contributors

💖 **Support development:** [Become a sponsor](https://github.com/sponsors/CaCC-Lab)

---

**Version**: v3.0
**Status**: ✅ Production Ready
**Last Updated**: 2025-10-28
