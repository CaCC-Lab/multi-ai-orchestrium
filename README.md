# Multi-AI Orchestrium

**複数のAIを協調させる次世代開発フレームワーク**

ChatDevとChain-of-Agentsを統合し、Claude、Gemini、Amp、Qwen、Droid、Codex、Cursorの7つのAIツールを並列・順次実行で協調させ、高速かつ高品質な開発を実現します。

[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)]()
[![Version](https://img.shields.io/badge/Version-v3.0-blue)]()
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 🌟 主な特徴

- **YAML駆動設計**: スクリプト変更なしで役割分担を変更可能
- **2つの協調パターン**: ChatDev（役割ベース）+ Chain-of-Agents（分割統治）
- **13個のレビューシステム**: 5AI個別 + 3コア + 統合インターフェース + 自動ルーティング
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

# 品質レビュー（高速モード: 120秒）
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
│ (Gemini)   │  (Qwen)      │  (Droid)     │
└────────────┴──────────────┴─────────────┘
    ↓
AI特性別アダプター (Template Method Pattern)
    ↓
5AI個別レビュー + Claude専用レビュー
```

### レビュータイプ

| タイプ | AI | 専門領域 | タイムアウト |
|--------|-----|---------|------------|
| Security | Gemini | OWASP Top 10、CVE検索 | 900秒 |
| Quality | Qwen | コード品質、リファクタリング | 600秒 |
| Enterprise | Droid | エンタープライズ基準、コンプライアンス | 900秒 |

### レビュープロファイル

| プロファイル | 特徴 | タイムアウト |
|-------------|------|------------|
| `fast` | P0-P1のみ、高速 | 120秒 |
| `balanced` | 全レビュー統合 | 900秒 |
| `security-focused` | セキュリティ特化 | 900秒 |
| `quality-focused` | 品質・テスト特化 | 600秒 |
| `enterprise-focused` | エンタープライズ基準 | 900秒 |

## 📖 詳細ドキュメント

詳細な情報は以下のドキュメントを参照してください（`.archived/documentation/docs/`に保存されています）：

### ユーザーガイド

- **REVIEW_SYSTEM_GUIDE.md** - レビューシステム包括ガイド（1,024行）
  - クイックスタート、全レビュータイプの詳細説明
  - 統一インターフェース、自動ルーティング
  - トラブルシューティング、CI/CD統合

- **FIVE_AI_REVIEW_GUIDE.md** - 5AI個別レビューガイド（674行）
  - Gemini、Qwen、Cursor、Amp、Droidの詳細
  - フォーカスオプション、使用例、推奨シナリオ

### 技術ドキュメント

- **REVIEW_ARCHITECTURE.md** - アーキテクチャ仕様（1,024行）
  - アーキテクチャ概要、共通ライブラリ
  - Primary/Fallbackメカニズム、拡張ガイド

- **ARCHITECTURE.md** - 全体アーキテクチャ（32KB）
  - オーケストレーションシステム、TDDワークフロー
  - 7AI協調パターン

### プロジェクトドキュメント

- **PROJECT_COMPLETION_SUMMARY.md** - プロジェクト完了サマリー
  - Phase 1-3A完了詳細、テスト結果
  - パフォーマンス指標、達成率

- **OPTION_D++_IMPLEMENTATION_PLAN.md** - 実装計画（59KB）
  - 7AI合意形成、Option D++設計
  - フェーズ別実装詳細

- **CONTRIBUTING.md** - 貢献ガイドライン（38KB）
  - 開発環境セットアップ、コーディング規約
  - テスト要件、PRワークフロー

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

**Version**: v3.0
**Status**: ✅ Production Ready
**Last Updated**: 2025-10-28

**詳細なドキュメント**: `.archived/documentation/docs/` または [完全版README](.archived/README-FULL.md)
