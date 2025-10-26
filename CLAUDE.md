# CLAUDE.md

このファイルは、Claude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## アーキテクチャ概要

Multi-AI Orchestriumは、7つのAIツール（Claude、Gemini、Amp、Qwen、Droid、Codex、Cursor）をYAML駆動ワークフローで協調させる次世代開発フレームワークです。ChatDevのロールベース協調とChain-of-Agentsの分割統治戦略を統合しています。

**コアアーキテクチャパターン:**
- **戦略レイヤー** (Claude, Gemini, Amp): アーキテクチャ、調査、プロジェクト管理
- **実装レイヤー** (Qwen, Droid): 高速プロトタイピング（37秒） + エンタープライズ品質（180秒）の並列実行
- **統合レイヤー** (Codex, Cursor): コードレビュー、最適化、IDE統合

**主要パフォーマンス指標:**
- Qwen: 品質スコア94/100、実行時間37秒（5倍高速）
- Droid: 品質スコア84/100、実行時間180秒（エンタープライズグレード）
- 総合成功率: 98%（冗長性により88%から向上）

## プロジェクト構造

```
multi-ai-orchestrium/
├── config/
│   └── multi-ai-profiles.yaml    # YAML駆動のAIロール設定
├── scripts/
│   ├── orchestrate/
│   │   ├── orchestrate-multi-ai.sh       # メインオーケストレーター（49関数）
│   │   └── lib/                          # モジュール化ライブラリ（8ファイル）
│   │       ├── multi-ai-core.sh          # ロギング、タイムスタンプ、ユーティリティ（15関数）
│   │       ├── multi-ai-ai-interface.sh  # AI呼び出し、フォールバック（5関数）
│   │       ├── multi-ai-config.sh        # YAML解析、フェーズ実行（16関数）
│   │       ├── multi-ai-workflows.sh     # ワークフローローダー（64行、以下4モジュールを統合）
│   │       ├── workflows-core.sh         # コアワークフロー（375行、6関数）
│   │       ├── workflows-discussion.sh   # ディスカッションワークフロー（55行、2関数）
│   │       ├── workflows-coa.sh          # Chain-of-Agentsワークフロー（36行、1関数）
│   │       └── workflows-review.sh       # コードレビューワークフロー（1533行、4関数）
│   ├── tdd/
│   │   ├── tdd-multi-ai.sh               # TDDサイクルオーケストレーション
│   │   └── tdd-multi-ai-phases.sh        # 6フェーズTDD実装
│   └── lib/
│       ├── sanitize.sh                   # 入力検証、セキュリティ
│       └── tdd-multi-ai-common.sh        # TDD共通関数
├── bin/
│   ├── *-wrapper.sh                      # AI CLIラッパー（7ファイル）
│   ├── agents-utils.sh                   # AGENTS.mdからのタスク分類
│   └── vibe-logger-lib.sh                # AI最適化構造化ロギング
└── src/
    ├── core/                              # キャッシュ、設定、バージョンチェック
    ├── install/                           # インストーラー、アップデーター、ロールバック
    └── ui/                                # インタラクティブUI、レポート
```

## ワークフローの実行

### メインオーケストレーションコマンド

すべてのワークフローは`config/multi-ai-profiles.yaml`からYAML駆動で実行されます。オーケストレータースクリプトから呼び出します:

```bash
# オーケストレーターをソースしてワークフロー関数にアクセス
cd /path/to/multi-ai-orchestrium
source scripts/orchestrate/orchestrate-multi-ai.sh

# ワークフローの実行
multi-ai-full-orchestrate "機能の説明"          # 5-8分のバランス型ワークフロー
multi-ai-speed-prototype "簡易機能"             # 2-4分の高速プロトタイプ
multi-ai-enterprise-quality "本番機能"          # 15-20分のエンタープライズグレード
multi-ai-hybrid-development "適応型機能"        # 5-15分のハイブリッド型

# ディスカッション & レビュー
multi-ai-discuss-before "実装計画"              # 実装前ディスカッション
multi-ai-review-after "コードまたはファイル"     # 実装後レビュー
multi-ai-consensus-review "複雑な意思決定"      # 7AI合意形成レビュー
multi-ai-coa-analyze "長文ドキュメントや複雑なトピック" # Chain-of-Agents解析

# ChatDev形式の開発
multi-ai-chatdev-develop "プロジェクトの説明"   # ロールベース開発サイクル
```

### TDDワークフロー

TDDサイクルは`config/multi-ai-profiles.yaml`のプロファイルベース設定を使用します:

```bash
# TDDスクリプトをソース
source scripts/tdd/tdd-multi-ai.sh

# 利用可能なプロファイル: classic_cycle, speed_first, quality_first, balanced, six_phases
export TDD_PROFILE=balanced  # デフォルト

# TDDサイクルの実行
tdd-multi-ai-cycle "機能名" [profile]           # 一時停止ありのインタラクティブサイクル
tdd-multi-ai-fast "機能名" [profile]            # 高速サイクル（一時停止なし）

# 個別フェーズ
tdd-multi-ai-plan "機能"                        # フェーズ0: 計画
tdd-multi-ai-red "機能"                         # フェーズ1: 失敗するテストの作成
tdd-multi-ai-green "テストの説明"               # フェーズ2: テストを通す
tdd-multi-ai-refactor "コード"                  # フェーズ3: 最適化
tdd-multi-ai-review "実装"                      # フェーズ4: レビュー

# ペアプログラミング
pair-multi-ai-driver "タスク"                   # ドライバーモード（Qwen + Droid）
pair-multi-ai-navigator "コード"                # ナビゲーターモード（Gemini + Amp）
```

## Claude Code Review CLIスクリプト

プロジェクトには、Claude MCPを活用した2つの独立したコードレビュースクリプトが含まれています。

### claude-review.sh - 包括的コードレビュー

コミット単位でコードの品質、設計、パフォーマンスを包括的にレビューします。

**基本使用法:**
```bash
# 最新コミットをレビュー
bash scripts/claude-review.sh

# 特定コミットをレビュー
bash scripts/claude-review.sh --commit abc123

# カスタムタイムアウト（デフォルト: 600秒）
bash scripts/claude-review.sh --timeout 900
```

**レビュー項目:**
- コード品質（可読性、保守性、一貫性）
- 設計パターン（アーキテクチャ、モジュール性）
- パフォーマンス（アルゴリズム効率、リソース使用）
- ベストプラクティス（言語固有の推奨事項）
- テストカバレッジ（テストの適切性）

**出力形式:**
- `logs/claude-reviews/{timestamp}_{commit}_claude.json` - JSON形式レポート
- `logs/claude-reviews/{timestamp}_{commit}_claude.md` - Markdown形式レポート
- `logs/ai-coop/{YYYYMMDD}/claude_review_{HH}.jsonl` - VibeLoggerログ

### claude-security-review.sh - セキュリティ特化レビュー

OWASP Top 10とCWEベースのセキュリティ脆弱性を検出します。

**基本使用法:**
```bash
# セキュリティレビュー実行
bash scripts/claude-security-review.sh

# 重要度フィルタリング
bash scripts/claude-security-review.sh --severity Critical

# カスタムタイムアウト（デフォルト: 900秒）
bash scripts/claude-security-review.sh --timeout 1200
```

**チェック項目:**
- SQLインジェクション（CWE-89）
- XSS（CWE-79）
- コマンドインジェクション（CWE-77, CWE-78）
- パストラバーサル（CWE-22）
- ハードコードされた秘密情報（CWE-798）
- 不安全な暗号化（CWE-327）
- その他OWASP Top 10対応

**出力形式:**
- JSON形式レポート（CVSS v3.1スコア付き）
- Markdown形式レポート
- SARIF形式レポート（IDE統合用）

### レビューワークフローの統合

これらのスクリプトは、Multi-AI Orchestriumのワークフローと統合できます：

```bash
# 実装前ディスカッション → 実装 → セキュリティレビュー → 包括レビュー
multi-ai-discuss-before "新機能の実装計画"

# コード実装（手動またはワークフローで）
# ...

# セキュリティレビューを実行
bash scripts/claude-security-review.sh

# セキュリティ問題が無ければ、包括的レビューを実行
bash scripts/claude-review.sh

# 最終的な7AI合意形成レビュー
multi-ai-consensus-review "実装完了コード"
```

**推奨ワークフロー:**
1. **実装前**: `multi-ai-discuss-before` で設計レビュー
2. **実装中**: TDDサイクル（`tdd-multi-ai-cycle`）で開発
3. **実装後（第1段階）**: `claude-security-review.sh` でセキュリティチェック
4. **実装後（第2段階）**: `claude-review.sh` で品質チェック
5. **最終確認**: `multi-ai-consensus-review` で7AI合意形成

これにより、セキュリティ → 品質 → 合意形成の3段階レビュープロセスを実現します。

### Multi-AI Quad Review（4ツール統合レビュー）

**NEW**: Codex、CodeRabbit、Claude包括レビュー、Claudeセキュリティレビューの4つの自動レビューツールを統合した最も包括的なレビューワークフローです。

**基本使用法:**
```bash
# オーケストレーターをソース
source scripts/orchestrate/orchestrate-multi-ai.sh

# Quad Review実行
multi-ai-quad-review "最新コミットの徹底レビュー"
```

**実行フロー:**
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

**出力:**
- `logs/multi-ai-reviews/{timestamp}-quad-review/QUAD_REVIEW_REPORT.md` - 統合レポート
- `logs/multi-ai-reviews/{timestamp}-quad-review/output/` - 各ツールの詳細結果
  - `codex/` - Codexレビュー結果
  - `coderabbit/` - CodeRabbitレビュー結果
  - `claude_comprehensive/` - Claude包括レビュー結果
  - `claude_security/` - Claudeセキュリティレビュー結果
  - `*_security_validation.txt` - 6AI協調分析結果

**使用例:**
```bash
# 重要な本番リリース前の徹底レビュー
multi-ai-quad-review "v2.0.0リリース前の最終レビュー"

# セキュリティクリティカルな変更のレビュー
multi-ai-quad-review "認証システムの全面改修レビュー"

# 大規模リファクタリングのレビュー
multi-ai-quad-review "アーキテクチャ変更の包括的レビュー"
```

**vs Dual Review:**
| 項目 | Dual Review | Quad Review |
|------|------------|------------|
| レビューツール数 | 2（Codex + CodeRabbit） | 4（+ Claude comprehensive + Claude security） |
| セキュリティ特化 | なし | Claude security review |
| 品質チェック | Codex + CodeRabbit | Codex + CodeRabbit + Claude |
| 所要時間 | 約15分 | 約30分 |
| 推奨用途 | 通常のコミットレビュー | 重要リリース、セキュリティクリティカル変更 |

## Multi-AI統合レビューインターフェース

**NEW (v2.0.0)**: `scripts/multi-ai-review.sh`は、3つのレビュータイプ（セキュリティ、品質、エンタープライズ）を統一インターフェースで実行し、YAMLプロファイルベースの設定に対応しています。

### 基本使用法

```bash
# レビュータイプ指定（--type）
bash scripts/multi-ai-review.sh --type TYPE [OPTIONS]

# プロファイル指定（--profile）
bash scripts/multi-ai-review.sh --profile PROFILE [OPTIONS]
```

### レビュータイプ（--type）

| タイプ | 主要AI | 対象領域 | タイムアウト |
|--------|--------|---------|------------|
| `security` | Gemini | セキュリティ脆弱性、OWASP Top 10 | 900秒 |
| `quality` | Qwen | コード品質、テスト、パフォーマンス | 600秒 |
| `enterprise` | Droid | エンタープライズ基準、保守性 | 900秒 |
| `all` | 全AI | 3つのレビューを並列実行 + 統合レポート | 900秒 |

### プロファイル（--profile）

`config/review-profiles.yaml`で定義された事前設定プロファイル:

| プロファイル | レビュータイプ | 特徴 | タイムアウト |
|-------------|--------------|-----|------------|
| `security-focused` | security | セキュリティ特化 | 900秒 |
| `quality-focused` | quality | 品質・テスト特化 | 600秒 |
| `enterprise-focused` | enterprise | エンタープライズ基準 | 900秒 |
| `balanced` | all | 全レビュー統合 | 900秒 |
| `fast` | quality (--fast) | P0-P1のみ、高速 | 120秒 |

### 共通オプション

```bash
--commit HASH         # レビュー対象コミット（デフォルト: HEAD）
--timeout SECONDS     # タイムアウト秒数
--output-dir PATH     # 出力ディレクトリ（デフォルト: logs/multi-ai-reviews）
--format FORMAT       # 出力形式: json | markdown | sarif | html | all
```

### タイプ固有オプション

```bash
--fast                # (quality only) 高速モード - P0-P1のみ、120秒タイムアウト
--compliance          # (enterprise only) コンプライアンスモード（GDPR, SOC2等）
```

### 使用例

```bash
# セキュリティレビュー（Gemini）
bash scripts/multi-ai-review.sh --type security

# 品質レビュー（Qwen）with 高速モード
bash scripts/multi-ai-review.sh --type quality --fast

# エンタープライズレビュー（Droid）with コンプライアンス
bash scripts/multi-ai-review.sh --type enterprise --compliance

# 全レビュータイプを並列実行 + 統合レポート
bash scripts/multi-ai-review.sh --type all --commit abc123

# プロファイル使用例
bash scripts/multi-ai-review.sh --profile balanced
bash scripts/multi-ai-review.sh --profile fast
bash scripts/multi-ai-review.sh --profile security-focused

# カスタム出力
bash scripts/multi-ai-review.sh --type security --output-dir ./my-reports --format json
```

### 出力形式

**個別レビュー（--type security/quality/enterprise）:**
- `{output-dir}/{timestamp}_{commit}_{ai}.json` - JSON形式レポート
- `{output-dir}/{timestamp}_{commit}_{ai}.md` - Markdown形式レポート
- `{output-dir}/{timestamp}_{commit}_{ai}.sarif` - SARIF形式（IDE統合用）
- `{output-dir}/{timestamp}_{commit}_{ai}.html` - HTML形式レポート

**統合レポート（--type all）:**
- `{output-dir}/{timestamp}_unified.json` - 統合JSONレポート
  - 3つのレビュー結果をマージ
  - 重複findings除去（title + file + line）
  - 優先度ソート
- `{output-dir}/{timestamp}_unified.html` - タブ型HTMLダッシュボード
  - 全レビュータイプの結果を1つのUIで表示
  - 統合ステータス、信頼度スコア、findings数

### プロファイル設定ガイド

プロファイルは`config/review-profiles.yaml`で定義されます:

```yaml
profiles:
  my-custom-profile:
    type: quality
    timeout: 600
    features:
      fast_mode: false
      compliance_mode: false
    format: all
    output_dir: logs/custom-reviews
```

**設定項目:**
- `type`: security | quality | enterprise | all
- `timeout`: タイムアウト秒数
- `features.fast_mode`: 高速モード（quality typeのみ）
- `features.compliance_mode`: コンプライアンスモード（enterprise typeのみ）
- `format`: 出力形式（json | markdown | sarif | html | all）
- `output_dir`: 出力ディレクトリパス

### ワークフロー統合

Multi-AI Orchestriumの他のワークフローと組み合わせることができます:

```bash
# 実装前 → 実装 → レビュー
multi-ai-discuss-before "新機能の実装計画"
# ... 実装作業 ...
bash scripts/multi-ai-review.sh --profile balanced

# TDDサイクル → レビュー
tdd-multi-ai-cycle "認証機能"
bash scripts/multi-ai-review.sh --type quality --fast

# 全レビュー → Quad Review（追加検証）
bash scripts/multi-ai-review.sh --type all
multi-ai-quad-review "追加検証"
```

## 5AI個別レビュースクリプト

**NEW (v3.1.0)**: 各AIの特性を最大限に活かした5つの専用レビュースクリプトが利用可能です。これらは`scripts/`ディレクトリに配置され、REVIEW-PROMPT.mdをベースに各AIの強みに特化したレビューを提供します。

### 概要

5つのAI（Gemini, Qwen, Cursor, Amp, Droid）それぞれに専用のレビュースクリプトがあり、異なる観点からコードをレビューします：

| スクリプト | AI | 専門領域 | 推奨用途 | タイムアウト |
|-----------|-----|---------|---------|------------|
| `gemini-review.sh` | Gemini 2.5 | セキュリティ & アーキテクチャ | セキュリティクリティカルな変更 | 900秒 |
| `qwen-review.sh` | Qwen3-Coder | コード品質 & パターン | 実装品質の検証 | 600秒 |
| `cursor-review.sh` | Cursor | IDE統合 & DX | 開発者体験の改善 | 600秒 |
| `amp-review.sh` | Amp | プロジェクト管理 & ドキュメント | ドキュメント・計画の検証 | 600秒 |
| `droid-review.sh` | Droid | エンタープライズ基準 | 本番リリース前の検証 | 900秒 |

### 基本使用法

すべてのスクリプトは同じインターフェースを持ち、以下のオプションをサポートします：

```bash
# 基本形式
bash scripts/{ai}-review.sh [OPTIONS]

# 共通オプション
--commit HASH       # レビュー対象コミット（デフォルト: HEAD）
--timeout SECONDS   # タイムアウト秒数
--output PATH       # 出力ディレクトリパス
--help              # ヘルプメッセージを表示
```

#### AI固有オプション

各スクリプトは、専門領域に特化したカスタムオプションを提供します：

**qwen-review.sh（コード品質特化）:**
```bash
--focus AREA        # フォーカス領域: patterns | quality | performance
```

**cursor-review.sh（開発者体験特化）:**
```bash
--focus AREA        # フォーカス領域: readability | ide-friendliness | completion
```

**amp-review.sh（プロジェクト管理特化）:**
```bash
--focus AREA        # フォーカス領域: docs | communication | planning
```

**droid-review.sh（エンタープライズ特化）:**
```bash
--focus AREA           # フォーカス領域: compliance | scalability | reliability
--compliance-mode      # コンプライアンスモード有効化（GDPR, SOC2, HIPAA）
```

### 使用例

```bash
# Gemini - セキュリティレビュー
bash scripts/gemini-review.sh --commit abc123 --timeout 900

# Qwen - コード品質レビュー（パターンにフォーカス）
bash scripts/qwen-review.sh --focus patterns

# Cursor - 開発者体験レビュー（可読性にフォーカス）
bash scripts/cursor-review.sh --focus readability

# Amp - ドキュメントレビュー
bash scripts/amp-review.sh --focus docs

# Droid - エンタープライズレビュー（コンプライアンスモード）
bash scripts/droid-review.sh --compliance-mode --timeout 900
```

### 出力形式

各スクリプトは、以下の形式で結果を出力します：

**JSON形式:**
```
logs/{ai}-reviews/{timestamp}_{commit}_{ai}.json
```
- 構造化されたレビュー結果
- Priority（P0-P3）付きfindings
- 重要度（Critical, High, Medium, Low）
- 信頼度スコア

**Markdown形式:**
```
logs/{ai}-reviews/{timestamp}_{commit}_{ai}.md
```
- 人間が読みやすいレポート
- エグゼクティブサマリー
- 詳細なfindings
- 推奨アクション

**VibeLoggerログ:**
```
logs/vibe/{YYYYMMDD}/{ai}_review_{HH}.jsonl
```
- AI最適化構造化ログ
- 実行メトリクス
- デバッグ情報

**シンボリックリンク（最新）:**
```
logs/{ai}-reviews/latest_{ai}.json
logs/{ai}-reviews/latest_{ai}.md
```

### 各AIの専門領域と特徴

#### Gemini (gemini-review.sh) - セキュリティ & アーキテクチャ

**専門領域:**
- OWASP Top 10脆弱性検出
- セキュリティベストプラクティス検証
- アーキテクチャ設計レビュー
- スケーラビリティ評価

**推奨シナリオ:**
- セキュリティクリティカルな変更
- 認証・認可システムの実装
- 外部APIとの統合
- データ処理パイプライン

**出力例:**
- CWE番号付きセキュリティfinding
- CVSS v3.1スコア
- アーキテクチャ改善提案
- パフォーマンス最適化案

#### Qwen (qwen-review.sh) - コード品質 & パターン

**専門領域:**
- コード品質評価（93.9% HumanEval精度）
- デザインパターン検出
- パフォーマンス最適化
- 技術的負債評価

**推奨シナリオ:**
- 新機能の実装レビュー
- リファクタリング検証
- アルゴリズム最適化
- コード複雑度の削減

**出力例:**
- 保守性インデックス
- 循環的複雑度
- パターン適合度
- 技術的負債見積もり

#### Cursor (cursor-review.sh) - IDE統合 & 開発者体験

**専門領域:**
- コード可読性評価
- IDE統合性チェック
- 自動補完フレンドリー度
- リファクタリング機会検出

**推奨シナリオ:**
- UI/UXコードのレビュー
- APIクライアント実装
- 開発者向けライブラリ
- チーム開発のコード標準化

**出力例:**
- 可読性スコア
- IDEナビゲーション効率
- 自動補完カバレッジ
- リファクタリング影響分析

#### Amp (amp-review.sh) - プロジェクト管理 & ドキュメント

**専門領域:**
- ドキュメント品質評価
- ステークホルダーコミュニケーション
- 技術的負債追跡
- スプリント計画整合性

**推奨シナリオ:**
- APIドキュメント作成
- README/ガイドの更新
- プロジェクト計画の検証
- リリースノート作成

**出力例:**
- ドキュメントカバレッジスコア
- コミュニケーション明確度
- スプリント整合性チェック
- リスク評価

#### Droid (droid-review.sh) - エンタープライズ基準

**専門領域:**
- エンタープライズ品質基準
- コンプライアンス検証（GDPR, SOC2, HIPAA）
- スケーラビリティ評価
- 本番環境適合性

**推奨シナリオ:**
- 本番リリース前の最終検証
- エンタープライズ顧客向け機能
- 規制対応が必要な実装
- ミッションクリティカルなシステム

**出力例:**
- エンタープライズチェックリストスコア
- コンプライアンス違反検出
- スケーラビリティボトルネック
- SLA/SLO影響分析

### ワークフロー統合例

5AI個別レビュースクリプトは、既存のワークフローと組み合わせて使用できます：

**段階的レビューワークフロー:**
```bash
# 1. 実装前ディスカッション
multi-ai-discuss-before "新機能の実装計画"

# 2. TDDサイクルで実装
tdd-multi-ai-cycle "新機能"

# 3. コード品質レビュー（Qwen）
bash scripts/qwen-review.sh --focus quality

# 4. セキュリティレビュー（Gemini）
bash scripts/gemini-review.sh

# 5. 開発者体験レビュー（Cursor）
bash scripts/cursor-review.sh --focus readability

# 6. ドキュメントレビュー（Amp）
bash scripts/amp-review.sh --focus docs

# 7. エンタープライズレビュー（Droid）
bash scripts/droid-review.sh --compliance-mode

# 8. 最終的な統合レビュー
bash scripts/multi-ai-review.sh --type all
```

**選択的レビューワークフロー:**
```bash
# セキュリティクリティカルな変更 → Geminiのみ
bash scripts/gemini-review.sh --timeout 900

# コード実装 → Qwenのみ
bash scripts/qwen-review.sh --focus patterns

# ドキュメント変更 → Ampのみ
bash scripts/amp-review.sh --focus docs

# 本番リリース → Droidのみ
bash scripts/droid-review.sh --compliance-mode
```

### 推奨レビュー戦略

**変更タイプ別の推奨AI:**

| 変更タイプ | 推奨AI | 理由 |
|----------|--------|------|
| セキュリティパッチ | Gemini + Droid | セキュリティ検証 + エンタープライズ基準 |
| 新機能実装 | Qwen + Cursor | コード品質 + 開発者体験 |
| リファクタリング | Qwen + Droid | パターン改善 + 保守性 |
| ドキュメント更新 | Amp + Cursor | ドキュメント品質 + 可読性 |
| 本番リリース | 全5AI | 包括的検証 |

**レビュー深度別の推奨:**

- **高速チェック（5-10分）**: Qwen単体
- **標準レビュー（15-20分）**: Qwen + Gemini
- **包括レビュー（30-40分）**: 全5AI並列実行
- **最大品質（60分+）**: 全5AI + Quad Review

### テスト状況

すべてのスクリプトは包括的なテストスイートでカバーされています：

- **テストカバレッジ**: 70-80% ブランチカバレッジ（本番利用可能レベル）
- **テストケース数**: 104テスト（各スクリプト26テスト）
- **テスト実行**: `bash tests/run-all-review-tests.sh`
- **個別テスト**: `bash tests/test-{ai}-review.sh`

詳細なテストドキュメントは`docs/test-observations/`を参照してください。

### 関連ドキュメント

- **実装計画**: `docs/FIVE_AI_REVIEW_SCRIPTS_IMPLEMENTATION_PLAN.md`
- **テスト観察表**: `docs/test-observations/test-{ai}-review-observation.md`
- **個別ガイド**: `docs/reviews/{ai}-review-guide.md`（作成予定）
- **包括ガイド**: `docs/FIVE_AI_REVIEW_GUIDE.md`（作成予定）

## 設定システム

### YAMLプロファイル構造

プロファイルはAIロール、タイムアウト、実行順序、並列性を定義します:

```yaml
profiles:
  balanced-multi-ai:
    workflows:
      multi-ai-full-orchestrate:
        phases:
          - name: "戦略的計画 & リサーチ"
            parallel:
              - name: "Claude - アーキテクチャ設計"
                ai: claude
                role: architecture-design
                timeout: 300
                blocking: false
              - name: "Gemini - 要件 & 最新技術"
                ai: gemini
                role: requirements-research
                timeout: 300
          - name: "並列実装 - 速度 vs 品質"
            parallel:
              - {ai: qwen, role: fast-prototype, timeout: 300}
              - {ai: droid, role: enterprise-implementation, timeout: 900}
```

**主要設定パラメータ:**
- `ai`: claude | gemini | amp | qwen | droid | codex | cursor
- `role`: AIのタスクに対する自由形式のロール説明
- `timeout`: 秒数（300s=5分、600s=10分、900s=15分）
- `parallel`: 並列実行用の配列
- `blocking`: true/false（完了を待つかどうか）
- `input_from`: 出力を受け取るAI名の配列

### タイムアウトガイドライン（実測データより）

- **Claude**: 300秒（戦略的/アーキテクチャ作業）
- **Gemini**: 300-600秒（Web検索、セキュリティ分析）
- **Amp**: 600秒（PM分析、ドキュメント作成）
- **Qwen**: 300秒（高速プロトタイピング）
- **Droid**: 900秒（エンタープライズ実装、包括的分析）
- **Codex**: 300秒（コードレビュー、最適化）
- **Cursor**: 300-600秒（IDE統合、テスト）

## AIツール統合

### ラッパースクリプト（`bin/*-wrapper.sh`）

各AIには以下を処理するラッパーがあります:
- `AGENTS.md`によるタスク分類（軽量/標準/重要）
- タスクの複雑さに基づく動的タイムアウト調整
- 構造化ロギングのためのVibeLogger統合
- 重要タスクの承認プロンプト（`--non-interactive`で無効化可能）

**ラッパーの使用方法:**
```bash
# 標準使用方法（AGENTS.md分類あり）
./bin/claude-wrapper.sh --prompt "あなたのタスク"

# タイムアウトの上書き
CLAUDE_MCP_TIMEOUT=600s ./bin/claude-wrapper.sh --prompt "複雑なタスク"

# 非インタラクティブモード（重要タスクを自動承認）
./bin/claude-wrapper.sh --prompt "重要タスク" --non-interactive

# 標準入力から読み込み
echo "あなたのタスク" | ./bin/gemini-wrapper.sh --stdin
```

## ファイルベースプロンプトシステム (Phase 1-2)

**NEW**: 大規模プロンプト（>1KB）の自動ファイル経由ルーティング

### 概要

システムは自動的に以下のルーティングを行います:
- **小規模プロンプト** (<1KB): コマンドライン引数経由（高速）
- **大規模プロンプト** (≥1KB): セキュアな一時ファイル経由（スケーラブル）

### 使用例

```bash
# 小規模プロンプト（自動でコマンドライン引数を使用）
call_ai_with_context "claude" "シンプルなタスク" 300

# 大規模プロンプト（自動でファイル経由を使用）
LARGE_SPEC=$(cat 10kb-specification.txt)
call_ai_with_context "claude" "$LARGE_SPEC" 600

# 従来のcall_ai()も引き続き動作（内部でcall_ai_with_context()を呼ぶ）
call_ai "gemini" "$LARGE_PROMPT" 300
```

### 自動ファイル処理の動作

```
[Phase 1] プロンプト受信
  ↓
[Phase 2] サイズチェック (${#prompt} >= 1024?)
  ↓
  YES → [Phase 3] セキュアファイル作成
    ├─ mktemp で一意ファイル生成
    ├─ chmod 600 で権限設定
    ├─ プロンプト書き込み
    └─ [Phase 4] ラッパー呼び出し（stdin redirect）
      └─ wrapper.sh < /tmp/prompt-ai-XXXXXX
  ↓
  NO → [Phase 5] コマンドライン引数
    └─ wrapper.sh --prompt "..."
  ↓
[Phase 6] 自動クリーンアップ（trap EXIT）
```

### トラブルシューティング

#### 問題: 大規模プロンプトでタイムアウト

```bash
# 解決策: タイムアウトを延長
call_ai_with_context "claude" "$LARGE_PROMPT" 900  # 15分
```

#### 問題: 一時ファイル作成失敗

```bash
# 自動フォールバック: 1KBに切り詰めてコマンドライン引数を使用
# ログに表示: "File creation failed, falling back to truncated command-line"

# 手動対処:
# 1. /tmpの空き容量確認
df -h /tmp

# 2. 権限確認
ls -ld /tmp

# 3. TMPDIR環境変数の設定
export TMPDIR=/path/to/writable/dir
```

#### 問題: 並列実行時のファイル競合

```bash
# 問題なし: mktemp が一意ファイル名を生成
# 各並列プロセスは独立した一時ファイルを使用
```

### パフォーマンスガイドライン

| プロンプトサイズ | 推奨方法 | 実行速度 |
|-----------------|---------|---------|
| < 100B | コマンドライン | 即座 |
| 100B - 1KB | コマンドライン | 即座 |
| 1KB - 10KB | ファイル経由 | +5-10ms (ファイルI/O) |
| 10KB - 100KB | ファイル経由 | +10-50ms |
| > 100KB | ファイル経由 | +50-200ms |

**結論**: ファイル経由のオーバーヘッドは無視できるレベル（<200ms）

### セキュリティ機能

- **chmod 600**: 所有者のみ読み書き可能
- **自動クリーンアップ**: trap でEXIT/INT/TERMシグナル時に削除
- **一意ファイル名**: mktemp で衝突を防止
- **サニタイゼーション**: 依然として`sanitize_input()`を通過

## ロギング: VibeLogger統合

すべてのスクリプトは`bin/vibe-logger-lib.sh`にある**VibeLogger**（AI最適化構造化ロギング）を使用します。

**コアロギング関数:**
```bash
# 汎用イベントロギング
vibe_log <event_type> <action> <metadata_json> <human_note> [ai_todo] [tool_name]

# ラッパーライフサイクル
vibe_wrapper_start "Claude" "$prompt" "$timeout"
vibe_wrapper_done "Claude" "success" "$duration_ms" "0"

# TDDライフサイクル
vibe_tdd_cycle_start "認証機能" 5
vibe_tdd_phase_start "RED" 1 3
vibe_tdd_phase_done "RED" 1 3 0 "$duration_ms"
vibe_tdd_cycle_done "認証機能" "success" "$total_ms" 10 10 0

# パイプラインオーケストレーション
vibe_pipeline_start "multi-ai-full-orchestrate" "バランス型ワークフロー" 4
vibe_pipeline_done "multi-ai-full-orchestrate" "success" "$duration_ms" 7
```

**ログ保存場所:** `logs/vibe/YYYYMMDD/*.jsonl`

## 主要開発パターン

### 並列実行 vs 順次実行

フレームワークは両方の実行パターンをサポートします:

**並列実行（独立タスク）:**
```yaml
parallel:
  - {ai: qwen, role: fast-prototype, timeout: 300}
  - {ai: droid, role: enterprise-quality, timeout: 900}
```

**フォールバック付き順次実行:**
```bash
execute_with_fallback "droid" "cursor" "$task" 900
```

### 入出力チェイニング

タスクは前のフェーズの出力を参照できます:

```yaml
- name: "コードレビュー & 最適化"
  ai: codex
  role: compare-optimize
  input_from: ["qwen", "droid"]  # 両方の実装を受け取る
  timeout: 300
```

### フォールトトレランス

一部のAIが失敗してもシステムは継続します:
- 重要フェーズのフォールバック機構
- ノンブロッキング並列実行（`blocking: false`）
- グレースフルデグラデーション付きタイムアウト処理

## テスト

専用のテストスイートは現在存在しません。手動テストワークフロー:

```bash
# AIツールの可用性チェック
bash check-multi-ai-tools.sh

# 個別ラッパーのテスト
./bin/claude-wrapper.sh --prompt "シンプルなテスト"
./bin/qwen-wrapper.sh --prompt "コード生成テスト"

# 小機能でTDDサイクルをテスト
source scripts/tdd/tdd-multi-ai.sh
tdd-multi-ai-fast "シンプルな計算機関数" speed_first
```

## よくある変更

### 新しいワークフローの追加

1. **YAMLで定義**（`config/multi-ai-profiles.yaml`）:
```yaml
profiles:
  my-profile:
    workflows:
      my-new-workflow:
        phases:
          - name: "フェーズ1"
            ai: claude
            role: my-role
            timeout: 300
```

2. **関数を実装**（`scripts/orchestrate/lib/multi-ai-workflows.sh`）:
```bash
my-new-workflow() {
    local task="$1"
    local profile="my-profile"

    log_phase_start "My Workflow" "claude"
    execute_yaml_workflow "$profile" "my-new-workflow" "$task"
    log_phase_end "My Workflow" "success"
}
```

3. **関数をエクスポート**（`multi-ai-workflows.sh`の最後）

### AIロールやタイムアウトの変更

**コード変更不要** - `config/multi-ai-profiles.yaml`を編集するだけ:

```yaml
# Qwenのタイムアウトを300秒から600秒に変更
- name: "Qwen - 高速プロトタイプ"
  ai: qwen
  timeout: 600  # 300から変更

# AI割り当ての入れ替え
- name: "実装"
  ai: droid  # qwenから変更
  role: fast-prototype  # 同じロール、異なるAI
```

変更は即座に有効化されます（YAMLは毎回実行時にロードされます）。

## ファイルベースプロンプトシステム (v3.2新機能)

Multi-AI Orchestriumは、大規模プロンプト（>1KB）を自動的にファイル経由でルーティングし、スケーラビリティとセキュリティを両立させます。

### 自動ルーティング

システムはプロンプトサイズに応じて最適な方法を自動選択します：

| プロンプトサイズ | ルーティング方法 | 実行速度 | セキュリティ |
|-----------------|----------------|---------|------------|
| < 1KB | コマンドライン引数 | 即座 | 厳格 |
| 1KB - 100KB | Stdinファイルリダイレクト | +5-50ms | 安全 |
| 100KB - 1MB | `sanitize_input_for_file()` | +50-200ms | 高 |

### 使用例

```bash
# 小規模プロンプト（自動でコマンドライン引数を使用）
call_ai_with_context "claude" "シンプルなタスク" 300

# 大規模プロンプト（自動でファイル経由を使用）
LARGE_SPEC=$(cat 10kb-specification.txt)
call_ai_with_context "claude" "$LARGE_SPEC" 600

# 従来のcall_ai()も引き続き動作（内部でcall_ai_with_context()を呼ぶ）
call_ai "gemini" "$LARGE_PROMPT" 300
```

### セキュリティ機能

- **chmod 600**: 所有者のみ読み書き可能
- **自動クリーンアップ**: trap でEXIT/INT/TERMシグナル時に削除
- **一意ファイル名**: mktemp で衝突を防止
- **段階的検証**:
  - 小規模プロンプト (<2KB): 厳格な文字検証
  - 中規模プロンプト (2KB-100KB): 緩和された検証
  - 大規模プロンプト (>100KB): ファイルベース専用検証

### パフォーマンスガイドライン

**ファイル経由のオーバーヘッド**: 無視できるレベル（<200ms）

- 1KB プロンプト: +5-10ms
- 10KB プロンプト: +10-50ms
- 100KB プロンプト: +50-200ms

**推奨**:
- 10KB未満のワークフロー: 気にする必要なし
- 100KB以上の大規模操作: パフォーマンス影響を考慮

### トラブルシューティング

#### 問題: 大規模プロンプトでタイムアウト

```bash
# 解決策: タイムアウトを延長
call_ai_with_context "claude" "$LARGE_PROMPT" 900  # 15分
```

#### 問題: 一時ファイル作成失敗

```bash
# 自動フォールバック: 1KBに切り詰めてコマンドライン引数を使用
# ログに表示: "File creation failed, falling back to truncated command-line"

# 手動対処:
# 1. /tmpの空き容量確認
df -h /tmp

# 2. TMPDIR環境変数の設定
export TMPDIR=/path/to/writable/dir
```

#### 問題: 並列実行時のファイル競合

**問題なし**: mktemp が一意ファイル名を生成するため、各並列プロセスは独立した一時ファイルを使用します。

### 設定

YAML設定（`config/multi-ai-profiles.yaml`）でカスタマイズ可能：

```yaml
file_based_prompts:
  enabled: true
  thresholds:
    small: 1024          # 1KB
    medium: 102400       # 100KB
    large: 1048576       # 1MB
  routing:
    auto: true
    prefer_file: true
  security:
    file_permissions: "600"
    auto_cleanup: true
```

詳細は `docs/FILE_BASED_PROMPT_SYSTEM.md` を参照してください。

## セキュリティ & 入力検証

すべてのユーザー入力は`scripts/lib/sanitize.sh`を通過します:
- コマンドインジェクション防止
- パストラバーサル保護
- 特殊文字のエスケープ
- 長さ制限の強制（最大100KB、ワークフローは最大1MB）

**Phase 4.5更新**: `sanitize_input()`は2KB以上のプロンプトで文字制限を緩和します（ファイルベースルーティングにより安全）。

**サニタイゼーションを決してバイパスしない** - 外部入力には必ず`sanitize_input()`を使用してください。

## 重要な制約

- **MCP/サブエージェント不使用**: フレームワークは信頼性のためBashを使用（MCPのコンテキスト/タイムアウト課題のため）
- **mainへの直接プッシュ禁止**: すべての変更はPRワークフローが必要
- **YAMLが動作を駆動**: スクリプトにAI割り当てをハードコーディングしない
- **VibeLogger必須**: 構造化ロギングを使用、ステータスメッセージにecho/printfを使わない
- **タイムアウトの規律**: YAMLの実測タイムアウト値を尊重する

## 移行ノート

このプロジェクトは5AIからMulti-AI（v3.0）へ進化しました:
- **追加**: Amp（PM）、Droid（エンタープライズエンジニア）
- **変更**: Qwen（テスター → 高速プロトタイパー）、Codex（実装 → レビュー/最適化）
- **新パターン**: CodexによるQwen+Droid並列実装と統合
- **パフォーマンス**: 開発速度+300%、成功率98%

詳細は`config/multi-ai-profiles.yaml`の移行セクションを参照してください。

---

## 🎊 Multi-AI Review System 完了宣言

**完了日**: 2025-10-26 (Day 16)
**ステータス**: ✅ **Phase 1-3A完全完了**（全必須機能実装完了）

### システム概要

Multi-AI Review Systemは、7つのAIツール（Claude、Gemini、Amp、Qwen、Droid、Codex、Cursor）を活用した、次世代のコードレビューシステムです。Option D++ Implementation Planに基づき、16日間で全必須フェーズを完了しました。

**主要成果物**:
1. **3コアレビュースクリプト** - セキュリティ/品質/エンタープライズ特化レビュー
2. **統一インターフェース** - YAML駆動CLI、5プロファイル対応
3. **自動化ツール** - 自動ルーティング、メトリクス収集、包括的ドキュメント

**総実装行数**: 8,000行以上
**テスト結果**: ユニットテスト77%、統合テスト100%成功率
**パフォーマンス**: 計画比57%短縮（28日→16日）

### クイックスタート

```bash
# 品質レビュー（最も一般的）
bash scripts/multi-ai-review.sh --type quality

# 自動ルーティング（推奨）
bash scripts/review-dispatcher.sh

# 全レビュー統合（重要リリース前）
bash scripts/multi-ai-review.sh --type all
```

### 推奨ワークフロー

1. **実装前**: `multi-ai-discuss-before "機能計画"`
2. **実装中**: `tdd-multi-ai-cycle "機能名"`
3. **実装後**: `bash scripts/multi-ai-review.sh --type all`
4. **最終確認**: `multi-ai-consensus-review "コード"`

### ドキュメント

- **ユーザーガイド**: `docs/REVIEW_SYSTEM_GUIDE.md`（1024行、包括的）
- **技術仕様**: `docs/REVIEW_ARCHITECTURE.md`（内部実装詳細）
- **実装計画**: `docs/OPTION_D++_IMPLEMENTATION_PLAN.md`（設計背景）

### Phase 3B（オプション拡張）

Phase 3Bは実運用での需要に応じて実施判断します。以下の条件で実施を検討：

- 3ヶ月以上の実運用
- 具体的な機能要望（Cursor/Amp追加、ML分類モデル等）
- ルールベース自動ルーティングの精度が80%未満

現行システムで十分な品質とユーザビリティを達成している場合は実施不要です。

---

**最終更新**: 2025-10-26
**バージョン**: v3.0（完了版）
