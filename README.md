# Multi-AI Orchestrium

**複数のAIを協調させる次世代開発フレームワーク**

ChatDevとChain-of-Agentsを統合し、Claude、Gemini、Amp、Qwen、Droid、Codex、Cursorの
複数のAIツールを並列・順次実行で協調させ、高速かつ高品質な開発を実現します。

## 🌟 主な特徴

- **YAML駆動設計**: スクリプト変更なしで役割分担を変更可能
- **2つの協調パターン**: ChatDev（役割ベース）+ CoA（分割統治）
- **フォールトトレランス**: 一部AIが失敗しても処理継続
- **VibeLogger統合**: AI最適化された構造化ログ
- **柔軟なタイムアウト制御**: AI毎に最適化された実行時間管理

## 事前準備
 各AIツールの公式サイトを参考にインストールしてください。
- [**Claude Code**](https://docs.claude.com/ja/docs/claude-code/overview)
- [**Gemini CLI**](https://github.com/google-gemini/gemini-cli)
- [**Qwen Code**](https://github.com/QwenLM/qwen-code)
- [**Codex CLI**](https://developers.openai.com/codex/cli/)
- [**Cursor ClI**](https://cursor.com/ja/docs/cli/overview)
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

# 4) スクリプトをソースして実行
source scripts/orchestrate/orchestrate-multi-ai.sh

# 5) ワークフロー実行（例：ChatDev開発ワークフロー）
multi-ai-chatdev-develop "新プロジェクトの概要"
```

### 📝 setup-permissions.sh について

`setup-permissions.sh` は、プロジェクト内の全シェルスクリプト（36個）に実行権限を一括付与するユーティリティです。

**機能:**
- 全 `.sh` ファイルを自動検出
- 実行権限がないファイルに `chmod +x` を実行
- カラー付きの進捗表示とサマリーレポート

**実行方法:**

このリポジトリをcloneした直後は、`setup-permissions.sh`自身に実行権限が付与されているため、以下のコマンドで直接実行できます：

```bash
./setup-permissions.sh
```

万が一、実行権限がない場合（`Permission denied`エラーが出る場合）は、以下のいずれかの方法で実行してください：

```bash
# 方法1: bashコマンド経由で実行
bash setup-permissions.sh

# 方法2: 先に実行権限を付与してから実行
chmod +x setup-permissions.sh
./setup-permissions.sh
```

これにより、以下のディレクトリ内の全スクリプトが実行可能になります：
- `bin/` - AI CLIラッパー（7ファイル）
- `scripts/orchestrate/` - オーケストレーションスクリプト（5ファイル）
- `scripts/tdd/` - TDDワークフロー（2ファイル）
- `scripts/lib/` - 共通ライブラリ（2ファイル）
- `src/` - コアユーティリティ（14ファイル）

### 📋 check-multi-ai-tools.sh について

`check-multi-ai-tools.sh` は、必要なAI CLIツールがインストールされているかを確認するユーティリティです。

**確認対象:**
- Claude Code (`claude`)
- Gemini CLI (`gemini`)
- Amp (`amp`)
- Qwen Code (`qwen`)
- Droid CLI (`droid`)
- Codex CLI (`codex`)
- Cursor (`cursor`)
- yq (YAML parser)

**実行方法:**
```bash
./check-multi-ai-tools.sh
```

**出力例:**
```
✓ claude: Found (version 1.2.3)
✗ gemini: Not found - Install: pip install google-generativeai-cli
✓ yq: Found (version 4.35.1)
...
```

未インストールのツールがあれば、インストールコマンドが表示されます。

ディレクトリ構造はそのままで、ご自身のプロジェクトに追加するだけでOKです。

## 📁 プロジェクト構造

```
multi-ai-orchestrium/
├── config/
│   └── multi-ai-profiles.yaml    # YAML駆動のAIロール設定
├── scripts/
│   ├── orchestrate/
│   │   ├── orchestrate-multi-ai.sh       # メインオーケストレーター（軽量ローダー）
│   │   └── lib/                          # モジュール化ライブラリ（4ファイル）
│   │       ├── multi-ai-core.sh          # ロギング、タイムスタンプ、ユーティリティ（15関数）
│   │       ├── multi-ai-ai-interface.sh  # AI呼び出し、フォールバック（5関数）
│   │       ├── multi-ai-config.sh        # YAML解析、フェーズ実行（16関数）
│   │       └── multi-ai-workflows.sh     # ワークフロー実装（13関数）
│   ├── tdd/
│   │   ├── tdd-multi-ai.sh               # TDDサイクルオーケストレーション
│   │   └── tdd-multi-ai-phases.sh        # 6フェーズTDD実装
│   ├── lib/
│   │   ├── sanitize.sh                   # 入力検証、セキュリティ
│   │   └── tdd-multi-ai-common.sh        # TDD共通関数
│   ├── codex-review.sh            # Codexレビュー
│   └── coderabbit-review.sh       # CodeRabbitレビュー
├── bin/
│   ├── *-wrapper.sh               # AI CLIラッパー（7ファイル）
│   ├── agents-utils.sh            # AGENTS.mdからのタスク分類
│   └── vibe-logger-lib.sh         # AI最適化構造化ロギング
├── src/
│   ├── core/                      # キャッシュ、設定、バージョンチェック
│   ├── install/                   # インストーラー、アップデーター、ロールバック
│   └── ui/                        # インタラクティブUI、レポート
└── logs/
    └── vibe/YYYYMMDD/             # VibeLoggerログ保存先
```
  
## 🎯 メインワークフロー関数

**モジュール構成** (総計49関数、3009行):
- `orchestrate-multi-ai.sh` - 軽量ローダー（131行）
- `lib/multi-ai-core.sh` - コア機能（15関数）
- `lib/multi-ai-ai-interface.sh` - AI統合（5関数）
- `lib/multi-ai-config.sh` - YAML設定（16関数）
- `lib/multi-ai-workflows.sh` - ワークフロー（13関数）

| 関数名                      | 説明                          | 使用AI    | 実行時間   |
|--------------------------|-----------------------------|---------| --------|
| multi-ai-full-orchestrate   | フルオーケストレーション (YAML駆動)       | 全7AI    | 5-8分   |
| multi-ai-speed-prototype    | 高速プロトタイプ生成                  | 全7AI    | 2-4分   |
| multi-ai-enterprise-quality | エンタープライズ品質実装                | 全7AI    | 15-20分 |
| multi-ai-hybrid-development | ハイブリッド開発 (適応的選択)            | 動的選択    | 5-15分  |
| multi-ai-chatdev-develop    | ChatDev役割ベース開発              | 全7AI    | 5-8分   |
| multi-ai-discuss-before     | 実装前ディスカッション                 | 全7AI    | 10分    |
| multi-ai-review-after       | 実装後レビュー                     | 全7AI    | 5-8分   |
| multi-ai-coa-analyze        | Chain-of-Agents解析           | 全7AI    | 3-5分   |
| multi-ai-consensus-review   | 合意形成レビュー                    | 全7AI    | 15-20分 |
| multi-ai-code-review        | コードレビュー (Codex+CodeRabbit) | レビュー特化 | 10-15分 |
 

## 🎯 使用例

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

# TDD実行
source scripts/tdd/tdd-multi-ai.sh
export TDD_PROFILE=balanced  # classic_cycle, speed_first, quality_first, balanced, six_phases

tdd-multi-ai-cycle "ログイン機能"
tdd-multi-ai-red "テスト作成"
tdd-multi-ai-green "実装"
tdd-multi-ai-refactor "最適化"
tdd-multi-ai-review "レビュー"
```

### 🎯 各AIの役割変更

各AIの役割・タイムアウト・実行順序・並列/順次・blocking などをスクリプトを一切変えずに、YAML編集だけで役割分担を入れ替えられます。
実行スクリプトは毎回 YAML を読み込むため、再起動不要で即反映されます。
変更可能なパラメータは以下の通りです。

- AI割り当て: `ai: claude | gemini | amp | qwen | droid | codex | cursor`
- 役割定義: `role: ceo-product-vision`（自由に追加可）
- タイムアウト: `timeout: 300`（秒）
- 実行モード: 並列は `parallel:`、順次は `ai:` のみ
- ブロッキング: `blocking: true|false`
- 入力参照: `input_from: ["qwen", "droid"]`

## 既知の課題

- タイムアウト: 長時間タスクや外部依存での処理待ちが発生しやすい。
- コンテキスト: ツール間でのコンテキスト引き継ぎや上限管理が難しい。
- MCP やサブエージェント: 現状ではタイムアウトとコンテキストの制約をクリアできず、手堅く制御しやすい Bash スクリプト構成に落ち着きました。


## 謝辞
このプロジェクトは以下の研究・プロジェクトから着想を得ています：

- [ChatDev](https://arxiv.org/abs/2307.07924) - AI協調開発の先駆的研究
- [Chain-of-Agents](https://arxiv.org/abs/2406.02818) - 大規模マルチエージェント協調
- [A Critical Perspective on Multi-Agent Systems](https://cognition.ai/blog/dont-build-multi-agents) - マルチエージェントシステムの課題と適切な使用場面に関する考察
- [Vibe Logger](https://github.com/fladdict/vibe-logger) - AI用構造化ロギング
- [kinopeee/cursorrules](https://github.com/kinopeee/cursorrules) - Cursor AI の効果的な活用ルールとベストプラクティス集

## 📄 ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

Copyright (c) 2025 Multi-AI Orchestrium Contributors

💖 **Support development:** [Become a sponsor](https://github.com/sponsors/CaCC-Lab)
