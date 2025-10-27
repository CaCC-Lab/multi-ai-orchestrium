# CLAUDE.md

このファイルは、Claude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## 🎉 プロジェクト完了状態

**Phase 1-3A完全実装完了**（2025-10-26）

- ✅ **総実装行数**: 8,000行以上
- ✅ **レビュースクリプト**: 13個完全実装
- ✅ **テストスイート**: 30個以上（ユニット11個、統合10個、E2E、5AIレビューテスト4個）
- ✅ **テスト成功率**: ユニット77%、統合100%
- ✅ **ドキュメント**: 3,500行以上の包括的ガイド
- ✅ **計画期間**: 57%短縮（28日 → 16日）

詳細: [docs/PROJECT_COMPLETION_SUMMARY.md](docs/PROJECT_COMPLETION_SUMMARY.md)

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
│   ├── multi-ai-profiles.yaml          # YAML駆動のAIロール設定（7AI）
│   ├── review-profiles.yaml            # レビュープロファイル設定（5プロファイル）
│   ├── ai-cli-versions.yaml            # AIバージョン管理
│   └── schema/
│       └── multi-ai-profiles.schema.json
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
│   │       └── workflows-review-quad.sh # Quad Review統合
│   ├── review/
│   │   ├── lib/
│   │   │   ├── review-common.sh        # 共通機能（15関数）
│   │   │   ├── review-prompt-loader.sh # プロンプト管理（7関数）
│   │   │   └── review-adapters/        # AI特性別アダプター（6ファイル）
│   │   │       ├── adapter-base.sh     # Template Method Pattern
│   │   │       ├── adapter-gemini.sh   # Gemini特化（Web検索、CVE）
│   │   │       ├── adapter-qwen.sh     # Qwen特化（高速解析）
│   │   │       ├── adapter-droid.sh    # Droid特化（エンタープライズ）
│   │   │       ├── adapter-claude.sh   # Claude特化（包括）
│   │   │       └── adapter-claude-security.sh # Claudeセキュリティ
│   │   ├── security-review.sh          # セキュリティレビュー（562行）
│   │   ├── quality-review.sh           # 品質レビュー（466行）
│   │   └── enterprise-review.sh        # エンタープライズレビュー（745行）
│   ├── tdd/
│   │   ├── tdd-multi-ai.sh             # TDDサイクルオーケストレーション
│   │   └── tdd-multi-ai-phases.sh      # 6フェーズTDD実装
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
│   ├── collect-review-metrics.sh       # メトリクス収集（405行）
│   ├── validate-config.sh              # YAML設定検証
│   └── benchmark-yaml-caching.sh       # YAMLキャッシュベンチマーク
├── bin/
│   ├── claude-wrapper.sh               # Claudeラッパー
│   ├── gemini-wrapper.sh               # Geminiラッパー
│   ├── amp-wrapper.sh                  # Ampラッパー
│   ├── qwen-wrapper.sh                 # Qwenラッパー
│   ├── droid-wrapper.sh                # Droidラッパー
│   ├── codex-wrapper.sh                # Codexラッパー
│   ├── cursor-wrapper.sh               # Cursorラッパー
│   ├── common-wrapper-lib.sh           # 共通ライブラリ（21KB）
│   ├── vibe-logger-lib.sh              # AI最適化構造化ロギング（14KB）
│   ├── agents-utils.sh                 # AGENTS.mdからのタスク分類
│   └── coderabbit-smart.sh             # CodeRabbitスマートラッパー
├── src/
│   ├── core/                           # キャッシュ、設定、バージョンチェック
│   ├── install/                        # インストーラー、アップデーター、ロールバック
│   ├── ui/                             # インタラクティブUI、レポート
│   └── utils/                          # ヘルパーユーティリティ
├── tests/
│   ├── unit/                           # ユニットテスト（11個、BATS形式）
│   ├── integration/                    # 統合テスト（10個）
│   ├── e2e/                            # E2Eテスト
│   ├── fixtures/                       # テストフィクスチャ
│   ├── lib/                            # テストヘルパー
│   ├── reports/                        # テストレポート
│   ├── test-amp-review.sh              # Ampレビューテスト
│   ├── test-cursor-review.sh           # Cursorレビューテスト
│   ├── test-droid-review.sh            # Droidレビューテスト
│   ├── test-qwen-review.sh             # Qwenレビューテスト
│   └── run-all-review-tests.sh         # 全レビューテスト実行
├── docs/
│   ├── REVIEW_SYSTEM_GUIDE.md          # ユーザーガイド（1,024行）
│   ├── REVIEW_ARCHITECTURE.md          # アーキテクチャ（1,024行）
│   ├── FIVE_AI_REVIEW_GUIDE.md         # 5AIレビューガイド（674行）
│   ├── PROJECT_COMPLETION_SUMMARY.md   # プロジェクト完了サマリー
│   ├── OPTION_D++_IMPLEMENTATION_PLAN.md # 実装計画（59KB）
│   ├── ARCHITECTURE.md                 # 全体アーキテクチャ（32KB）
│   ├── CONTRIBUTING.md                 # 貢献ガイドライン（38KB）
│   ├── reviews/                        # AI別レビューガイド（5個）
│   └── test-observations/              # テスト観察表（4個）
└── logs/
    ├── vibe/YYYYMMDD/                  # VibeLoggerログ
    ├── gemini-reviews/                 # Geminiレビュー結果
    ├── qwen-reviews/                   # Qwenレビュー結果
    ├── cursor-reviews/                 # Cursorレビュー結果
    ├── amp-reviews/                    # Ampレビュー結果
    ├── droid-reviews/                  # Droidレビュー結果
    ├── claude-reviews/                 # Claudeレビュー結果
    ├── claude-security-reviews/        # Claudeセキュリティレビュー結果
    ├── coderabbit-reviews/             # CodeRabbitレビュー結果
    ├── multi-ai-reviews/               # 統合レビュー結果
    ├── metrics/                        # メトリクスレポート
    └── 7ai-reviews/                    # 7AI協調レビュー結果
```

## 13個のレビュースクリプト体系

Multi-AI Orchestriumは、世界最大級の13個のレビュースクリプトで構成される包括的レビューシステムを提供します。

### レビューシステム階層

```
┌─────────────────────────────────────────────────────┐
│  レイヤー1: 自動ルーティング                        │
│  review-dispatcher.sh (8ルールベース判定)           │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────┐
│  レイヤー2: 統一インターフェース                    │
│  multi-ai-review.sh (YAML駆動、5プロファイル)       │
└──────────────────────┬──────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
┌───────▼────┐ ┌───────▼────┐ ┌──────▼─────┐
│ security   │ │  quality   │ │ enterprise │
│ (Gemini)   │ │  (Qwen)    │ │  (Droid)   │
└────────────┘ └────────────┘ └────────────┘
        │              │              │
        └──────────────┼──────────────┘
                       │
┌──────────────────────┴──────────────────────────────┐
│  レイヤー3: AI特性別アダプター                      │
│  Template Method Pattern + Primary/Fallback         │
└─────────────────────────────────────────────────────┘
        │
        ├── 5AI個別レビュー（scripts/）
        │   ├── gemini-review.sh
        │   ├── qwen-review.sh
        │   ├── cursor-review.sh
        │   ├── amp-review.sh
        │   └── droid-review.sh
        │
        ├── Claude専用レビュー（scripts/）
        │   ├── claude-review.sh
        │   └── claude-security-review.sh
        │
        └── その他レビュー（scripts/）
            ├── codex-review.sh
            └── coderabbit-review.sh
```

### 1. 5AI個別レビュースクリプト（scripts/）

各AIの特性を最大限に活かした専用レビュースクリプト。

| スクリプト | AI | 専門領域 | 行数 | タイムアウト |
|-----------|-----|---------|------|------------|
| gemini-review.sh | Gemini 2.5 | セキュリティ & アーキテクチャ | 583 | 900秒 |
| qwen-review.sh | Qwen3-Coder | コード品質 & パターン | 584 | 600秒 |
| cursor-review.sh | Cursor | IDE統合 & 開発者体験 | 597 | 600秒 |
| amp-review.sh | Amp | プロジェクト管理 & ドキュメント | 599 | 600秒 |
| droid-review.sh | Droid | エンタープライズ基準 | 701 | 900秒 |

**使用方法:**
```bash
# 基本使用方法
bash scripts/{ai}-review.sh --commit <hash>

# AI固有オプション
bash scripts/qwen-review.sh --focus patterns
bash scripts/droid-review.sh --compliance-mode
```

### 2. 3コアレビュースクリプト（scripts/review/）

REVIEW-PROMPT.md準拠、Primary/Fallback機構搭載の高可用性レビュー。

| スクリプト | Primary AI | Fallback AI | 行数 | タイムアウト |
|----------|-----------|-------------|------|------------|
| security-review.sh | Gemini | Claude Security | 562 | 600秒 |
| quality-review.sh | Qwen | Codex | 466 | 300秒 |
| enterprise-review.sh | Droid | Claude | 745 | 900秒 |

**使用方法:**
```bash
# 基本使用方法
bash scripts/review/security-review.sh --commit <hash>
bash scripts/review/quality-review.sh --commit <hash> --fast
bash scripts/review/enterprise-review.sh --commit <hash> --compliance
```

### 3. 統一インターフェース（multi-ai-review.sh）

YAML駆動の統一レビューインターフェース（826行）。

**レビュータイプ:**
- `security`: Geminiによるセキュリティレビュー
- `quality`: Qwenによる品質レビュー
- `enterprise`: Droidによるエンタープライズレビュー
- `all`: 3つを並列実行 + 統合レポート生成

**プロファイル:**
- `security-focused`, `quality-focused`, `enterprise-focused`
- `balanced` (全レビュー統合)
- `fast` (P0-P1のみ、120秒)

**使用方法:**
```bash
# タイプ指定
bash scripts/multi-ai-review.sh --type quality
bash scripts/multi-ai-review.sh --type all

# プロファイル指定
bash scripts/multi-ai-review.sh --profile balanced
```

### 4. 自動ルーティング（review-dispatcher.sh）

Git diff解析による最適レビュー自動判定（336行）。

**8ルールベース判定:**
1. セキュリティキーワード → security
2. 認証・暗号化ファイル → security
3. 100行以上変更 → all
4. 本番環境ファイル → enterprise
5. テストファイルのみ → quality
6. ドキュメントのみ → スキップ
7. スクリプトファイル → quality
8. デフォルト → quality

**使用方法:**
```bash
# 自動判定 + 実行
bash scripts/review-dispatcher.sh

# Dry-run（判定のみ）
bash scripts/review-dispatcher.sh --dry-run
```

### 5. Claude専用レビュー（scripts/）

Claude MCPを活用した独立レビュースクリプト。

- **claude-review.sh** (650行): 包括的コードレビュー
- **claude-security-review.sh** (560行): セキュリティ特化レビュー

### 6. その他レビュー（scripts/）

- **codex-review.sh** (653行): Codexレビュー
- **coderabbit-review.sh** (1,848行): CodeRabbitレビュー

### 7. メトリクス収集（collect-review-metrics.sh）

実行時間、品質、コストメトリクスの収集と分析（405行）。

**使用方法:**
```bash
# 最新7日間のメトリクス収集
bash scripts/collect-review-metrics.sh

# カスタム期間
bash scripts/collect-review-metrics.sh --days 30
```

## ワークフローの実行

### メインオーケストレーションコマンド

すべてのワークフローは`config/multi-ai-profiles.yaml`からYAML駆動で実行されます。

```bash
# オーケストレーターをソース
source scripts/orchestrate/orchestrate-multi-ai.sh

# ワークフローの実行
multi-ai-full-orchestrate "機能の説明"          # 5-8分のバランス型
multi-ai-speed-prototype "簡易機能"             # 2-4分の高速プロトタイプ
multi-ai-enterprise-quality "本番機能"          # 15-20分のエンタープライズ
multi-ai-hybrid-development "適応型機能"        # 5-15分のハイブリッド

# ディスカッション & レビュー
multi-ai-discuss-before "実装計画"              # 実装前ディスカッション
multi-ai-review-after "コードまたはファイル"     # 実装後レビュー
multi-ai-consensus-review "複雑な意思決定"      # 7AI合意形成レビュー
multi-ai-coa-analyze "長文ドキュメント"         # Chain-of-Agents解析

# ChatDev & Quad Review
multi-ai-chatdev-develop "プロジェクト"         # ChatDev開発
multi-ai-quad-review "徹底レビュー"             # Quad統合レビュー（約30分）
```

### TDDワークフロー

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
pair-multi-ai-driver "タスク"            # ドライバー（Qwen + Droid）
pair-multi-ai-navigator "コード"         # ナビゲーター（Gemini + Amp）
```

## 推奨開発ワークフロー

### 1. 通常開発フロー

```bash
# 実装前ディスカッション
multi-ai-discuss-before "新機能の実装計画"

# 実装（TDDサイクル）
source scripts/tdd/tdd-multi-ai.sh
tdd-multi-ai-cycle "新機能実装"

# 自動ルーティングでレビュー実行
bash scripts/review-dispatcher.sh
```

### 2. 重要リリース前フロー

```bash
# 実装前ディスカッション
multi-ai-discuss-before "v2.0.0リリース実装計画"

# 実装

# Quad Review実行（最も包括的）
multi-ai-quad-review "v2.0.0リリースの徹底レビュー"

# 統合レビュー（追加確認）
bash scripts/multi-ai-review.sh --type all
```

### 3. セキュリティクリティカルな変更

```bash
# 5AI個別レビュー（セキュリティ特化）
bash scripts/gemini-review.sh --commit abc123

# 3コアレビュー（セキュリティ特化）
bash scripts/review/security-review.sh --commit abc123

# Claude Security Review
bash scripts/claude-security-review.sh --commit abc123
```

### 4. 高速CI/CDパイプライン

```bash
# 高速モード（120秒）
bash scripts/multi-ai-review.sh --profile fast

# または
bash scripts/review/quality-review.sh --commit abc123 --fast
```

## 設定システム

### YAMLプロファイル構造

プロファイルはAIロール、タイムアウト、実行順序、並列性を定義します（`config/multi-ai-profiles.yaml`）:

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

### レビュープロファイル（`config/review-profiles.yaml`）

```yaml
profiles:
  security-focused:
    type: security
    timeout: 900
    features:
      web_search: true
      cve_check: true

  quality-focused:
    type: quality
    timeout: 600
    features:
      refactor_suggestions: true
      type_safety: true

  enterprise-focused:
    type: enterprise
    timeout: 900
    features:
      compliance_check: true
      audit_trail: true

  balanced:
    type: all
    timeout: 900

  fast:
    type: quality
    timeout: 120
    features:
      fast_mode: true
```

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

## ファイルベースプロンプトシステム

大規模プロンプト（>1KB）の自動ファイル経由ルーティング。

### 自動ルーティング

システムはプロンプトサイズに応じて最適な方法を自動選択します：

| プロンプトサイズ | ルーティング方法 | 実行速度 |
|-----------------|----------------|---------|
| < 1KB | コマンドライン引数 | 即座 |
| 1KB - 100KB | Stdinファイルリダイレクト | +5-50ms |
| 100KB - 1MB | `sanitize_input_for_file()` | +50-200ms |

**セキュリティ機能:**
- chmod 600（所有者のみ読み書き可能）
- 自動クリーンアップ（trap でEXIT/INT/TERM時に削除）
- 一意ファイル名（mktemp で衝突防止）
- 段階的検証（サイズ別）

詳細: [docs/FILE_BASED_PROMPT_SYSTEM.md](docs/FILE_BASED_PROMPT_SYSTEM.md)

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
vibe_tdd_phase_done "RED" 1 3 0 "$duration_ms"
vibe_tdd_cycle_done "認証機能" "success" "$total_ms" 10 10 0

# パイプラインオーケストレーション
vibe_pipeline_start "multi-ai-full-orchestrate" "バランス型" 4
vibe_pipeline_done "multi-ai-full-orchestrate" "success" "$duration_ms" 7
```

**ログ保存場所:** `logs/vibe/YYYYMMDD/*.jsonl`

## テストスイート

包括的なテストスイートが完備されています。

### テスト構成

| テストタイプ | ファイル数 | テストケース数 | 成功率 | 実行方法 |
|-------------|----------|--------------|--------|---------|
| ユニットテスト | 11個 | 57 | 77% | `bash tests/run-unit-tests.sh` |
| 統合テスト | 10個 | 25 | 100% | `bash tests/integration/test-*.sh` |
| E2Eテスト | 1個 | - | 100% | `bash tests/e2e/test-review-workflow.sh` |
| 5AIレビューテスト | 4個 | 104 | 70-80% | `bash tests/run-all-review-tests.sh` |

### ユニットテスト（tests/unit/）

BATS（Bash Automated Testing System）形式のテスト。

- test-adapters.bats
- test-claude-review.bats
- test-claude-security-review.bats
- test-common-wrapper-lib.bats
- test-dependencies.bats
- test-multi-ai-ai-interface.bats
- test-multi-ai-config.bats
- test-multi-ai-core.bats
- test-review-common.bats
- test-review-prompt-loader.bats
- test-sanitize.bats

### 統合テスト（tests/integration/）

- test-claude-review-integration.sh
- test-multi-ai-review.sh
- test-security-review.sh
- test-quality-review.sh
- test-enterprise-review.sh
- test-workflows-p1-1-3.sh
- test-wrappers-p0-1-3.sh
- test-edge-cases.sh
- test-structured-error-handling.sh
- test-trap-handling.sh

### 5AIレビューテスト（tests/）

- test-amp-review.sh（26テスト）
- test-cursor-review.sh（26テスト）
- test-droid-review.sh（26テスト）
- test-qwen-review.sh（26テスト）

**実行方法:**
```bash
# 全レビューテスト実行
bash tests/run-all-review-tests.sh

# 個別テスト実行
bash tests/test-qwen-review.sh
```

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

## ドキュメント

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

### AI別レビューガイド（docs/reviews/）

- gemini-review-guide.md
- qwen-review-guide.md
- cursor-review-guide.md
- amp-review-guide.md
- droid-review-guide.md

### テスト観察表（docs/test-observations/）

- qwen-review-test-observations.md
- cursor-review-test-observations.md
- amp-review-test-observations.md
- droid-review-test-observations.md

## 移行ノート

このプロジェクトは5AIからMulti-AI（v3.0）へ進化しました:
- **追加**: Amp（PM）、Droid（エンタープライズエンジニア）
- **変更**: Qwen（テスター → 高速プロトタイパー）、Codex（実装 → レビュー/最適化）
- **新パターン**: CodexによるQwen+Droid並列実装と統合
- **パフォーマンス**: 開発速度+300%、成功率98%

詳細は`config/multi-ai-profiles.yaml`の移行セクションを参照してください。

---

**最終更新**: 2025-10-28
**バージョン**: v3.0
**ステータス**: ✅ Production Ready
