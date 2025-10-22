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
│   │   └── lib/                          # モジュール化ライブラリ（4ファイル）
│   │       ├── multi-ai-core.sh          # ロギング、タイムスタンプ、ユーティリティ（15関数）
│   │       ├── multi-ai-ai-interface.sh  # AI呼び出し、フォールバック（5関数）
│   │       ├── multi-ai-config.sh        # YAML解析、フェーズ実行（16関数）
│   │       └── multi-ai-workflows.sh     # ワークフロー実装（13関数）
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

## セキュリティ & 入力検証

すべてのユーザー入力は`scripts/lib/sanitize.sh`を通過します:
- コマンドインジェクション防止
- パストラバーサル保護
- 特殊文字のエスケープ
- 長さ制限の強制

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
