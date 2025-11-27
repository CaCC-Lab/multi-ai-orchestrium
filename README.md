# Multi-AI Orchestrium

**複数のAIを協調させる次世代開発フレームワーク**

ChatDevとChain-of-Agentsを統合し、Claude、Gemini、Amp、Qwen、Droid、Codex、Cursorの7つのAIツールを並列・順次実行で協調させ、高速かつ高品質な開発を実現します。

[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)]()
[![Version](https://img.shields.io/badge/Version-v3.1-blue)]()
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-47%2B%20passing-success)]()
[![Worktree](https://img.shields.io/badge/Worktree-Integrated-blueviolet)]()
[![Lite Mode](https://img.shields.io/badge/Lite%20Mode-1--7%20AIs-orange)]()
[![CI](https://img.shields.io/badge/CI-GitHub%20Actions-2088FF?logo=github-actions&logoColor=white)](.github/workflows/worktree-test.yml)

## 🌟 主な特徴

- **🆕 Lite Mode**: 1-3 AIでも動作！全7AI不要で段階的に導入可能
- **YAML駆動設計**: スクリプト変更なしで役割分担を変更可能
- **2つの協調パターン**: ChatDev（役割ベース）+ Chain-of-Agents（分割統治）
- **Git Worktrees統合**: ファイル競合なしの完全並列実行、クリーンアップ成功率100%
- **13個のレビューシステム**: 5AI個別 + 3コア + Claude専用2 + その他2 + 統一IF + 自動ルーティング
- **Primary/Fallback機構**: 高可用性98%以上
- **VibeLogger統合**: AI最適化された構造化ログ
- **フォールトトレランス**: 一部AIが失敗しても処理継続

## 🚀 クイックスタート

### 事前準備

以下のAI CLIツールをインストールしてください：

- [Claude Code](https://docs.claude.com/ja/docs/claude-code/overview)
- [Gemini CLI](https://github.com/google-gemini/gemini-cli)
- [Qwen Code](https://github.com/QwenLM/qwen-code)
- [Codex CLI](https://developers.openai.com/codex/cli/)
- [Cursor CLI](https://cursor.com/ja/docs/cli/overview)
- [CodeRabbit CLI](https://www.coderabbit.ai/ja/cli)
- [Amp](https://ampcode.com/manual)
- [Droid CLI](https://docs.factory.ai/cli/getting-started/quickstart)

### インストール

```bash
# 1) リポジトリをクローン
git clone https://github.com/CaCC-Lab/multi-ai-orchestrium
cd multi-ai-orchestrium

# 2) 実行権限を一括付与
./setup-permissions.sh

# 3) Python依存関係をインストール（オプション）
pip install -r requirements.txt

# 4) AIツールの可用性確認
./check-multi-ai-tools.sh
```

## 🔹 Lite Mode（1-3 AIで始める）

**全7AI不要！** 1つのAIからでも始められます。

```bash
# AI可用性チェック
./scripts/lite-mode/lite-mode-checker.sh

# セットアップウィザード（インタラクティブ）
./scripts/lite-mode/setup-wizard.sh

# Lite Modeでタスク実行
source scripts/lite-mode/lite-mode-orchestrator.sh
lite_orchestrate "implement user authentication"
```

### モード一覧

| モード | AI数 | 機能 |
|--------|------|------|
| 🔹 Single | 1 | 基本操作、シンプルなタスク |
| 🔸 Basic | 2-3 | コアワークフロー、フォールバック |
| 🔶 Standard | 4-5 | 並列実行、TDDワークフロー |
| ✅ Full | 6-7 | 全機能、7AI合意形成 |

詳細: [docs/LITE_MODE_GUIDE.md](docs/LITE_MODE_GUIDE.md)

## 📋 基本的な使用方法

### レビューシステム

#### 1. 自動ルーティング（推奨）

Git diff解析により最適なレビューを自動選択：

```bash
bash scripts/review-dispatcher.sh
```

#### 2. 統一インターフェース

```bash
# セキュリティレビュー
bash scripts/multi-ai-review.sh --type security

# 品質レビュー（高速モード: 300秒）
bash scripts/multi-ai-review.sh --profile fast

# 全レビュー統合
bash scripts/multi-ai-review.sh --type all
```

#### 3. AI個別レビュー

```bash
# Geminiによるセキュリティレビュー
bash scripts/gemini-review.sh --commit abc123

# Qwenによる品質レビュー
bash scripts/qwen-review.sh --commit abc123

# Droidによるエンタープライズレビュー
bash scripts/droid-review.sh --commit abc123
```

### オーケストレーションワークフロー

```bash
# スクリプトをソース
source scripts/orchestrate/orchestrate-multi-ai.sh

# フル開発ワークフロー（5-8分）
multi-ai-full-orchestrate "新機能開発"

# ChatDev開発ワークフロー
multi-ai-chatdev-develop "Eコマースサイト"

# 実装前ディスカッション
multi-ai-discuss-before "実装計画"

# 実装後レビュー
multi-ai-review-after "コード"

# Quad Review（最も包括的、約30分）
multi-ai-quad-review "徹底レビュー"
```

### TDDワークフロー

```bash
# TDDスクリプトをソース
source scripts/tdd/tdd-multi-ai.sh

# プロファイル選択
export TDD_PROFILE=balanced  # classic_cycle, speed_first, quality_first

# TDDサイクル実行
tdd-multi-ai-cycle "新機能"
```

### Git Worktrees統合（完全並列実行）

7AIが独立したGit Worktreeで並列実行。ファイル競合なしで開発できます。

```bash
# Worktree統合モードを有効化
export ENABLE_WORKTREES=true

# ワークフロー実行
source scripts/orchestrate/orchestrate-multi-ai.sh
multi-ai-speed-prototype "機能の説明"

# 全ワークフロー統合テスト
bash scripts/test-all-worktree-workflows.sh
```

**利点:**
- ✅ ファイル競合なしの完全並列実行
- ✅ 異常終了時の自動クリーンアップ（trap管理）
- ✅ クリーンアップ成功率100%

詳細: [WORKTREE_TEST_PROCEDURE.md](WORKTREE_TEST_PROCEDURE.md)

## 📚 レビューシステム概要

Multi-AI Orchestriumは、13個のレビュースクリプトで構成される包括的レビューシステムを提供します。

### レビュー階層

```
自動ルーティング (review-dispatcher.sh)
    ↓
統一インターフェース (multi-ai-review.sh)
    ↓
┌────────────┬──────────────┬─────────────┐
│セキュリティ│   品質       │エンタープライズ│
│ (Gemini)   │  (Claude)    │  (Droid)     │
└────────────┴──────────────┴─────────────┘
    ↓
AI特性別アダプター (Template Method Pattern)
    ↓
5AI個別レビュー + Claude専用レビュー
```

### レビュータイプ

| タイプ | AI | 専門領域 | タイムアウト |
|--------|-----|---------|------------|
| Security | Gemini | OWASP Top 10、CVE検索 | 1200秒 |
| Quality | Claude | コード品質、リファクタリング | 1200秒 |
| Enterprise | Droid | エンタープライズ基準、コンプライアンス | 1200秒 |

### レビュープロファイル

| プロファイル | 特徴 | タイムアウト |
|-------------|------|------------|
| `fast` | P0-P1のみ、並列実行（Quality: 120秒 + Security: 300秒） | 最大300秒 |
| `balanced` | 全レビュー統合 | 900秒 |
| `security-focused` | セキュリティ特化 | 600秒 |
| `quality-focused` | 品質・テスト特化 | 300秒 |
| `enterprise-focused` | エンタープライズ基準 | 900秒 |

## 🔧 トラブルシューティング

### 権限エラー

```bash
# 実行権限の一括付与
./setup-permissions.sh
```

### タイムアウトエラー

```bash
# タイムアウト値を延長
bash scripts/multi-ai-review.sh --timeout 1200
```

### 出力ファイルが生成されない

```bash
# ディレクトリを作成
mkdir -p logs/{gemini,qwen,cursor,amp,droid,claude,codex,coderabbit}-reviews
chmod 755 logs/*-reviews
```

### jq not found

```bash
# Linux
sudo apt-get install jq

# macOS
brew install jq
```

## 📄 ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

Copyright (c) 2025 Multi-AI Orchestrium Contributors

💖 **Support development:** [Become a sponsor](https://github.com/sponsors/CaCC-Lab)

---

**Version**: v3.1
**Status**: ✅ Production Ready
**Last Updated**: 2025-11-27
