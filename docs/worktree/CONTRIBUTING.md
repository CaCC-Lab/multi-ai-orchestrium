# Git Worktrees 貢献ガイド

**バージョン:** v1.0
**最終更新:** 2025-11-08

Multi-AI Orchestrium Git Worktrees統合システムへの貢献を歓迎します！

---

## 📋 目次

1. [開発環境セットアップ](#開発環境セットアップ)
2. [コーディング規約](#コーディング規約)
3. [PR作成ガイド](#pr作成ガイド)
4. [テスト方法](#テスト方法)
5. [ドキュメント更新](#ドキュメント更新)
6. [リリースプロセス](#リリースプロセス)
7. [コミュニティ](#コミュニティ)

---

## 開発環境セットアップ

### 前提条件

| ツール | バージョン | 必須 | インストール方法 |
|-------|----------|------|----------------|
| Bash | 4.0+ | ✅ 必須 | プリインストール済み |
| Git | 2.5+ | ✅ 必須 | `sudo apt-get install git` |
| jq | 1.5+ | ✅ 必須 | `sudo apt-get install jq` |
| ShellCheck | 0.7+ | ❌ 推奨 | `sudo apt-get install shellcheck` |
| BATS | 1.0+ | ❌ 推奨 | `npm install -g bats` |

### クローンとセットアップ

```bash
# 1. リポジトリをクローン
git clone https://github.com/CaCC-Lab/multi-ai-orchestrium
cd multi-ai-orchestrium

# 2. 実行権限を付与
chmod +x scripts/orchestrate/lib/worktree-*.sh
chmod +x scripts/test-worktree-*.sh
chmod +x scripts/run-all-worktree-tests.sh

# 3. 依存関係の確認
bash -c '
  echo "Checking dependencies..."
  command -v git >/dev/null 2>&1 || { echo "❌ Git not found"; exit 1; }
  command -v jq >/dev/null 2>&1 || { echo "❌ jq not found"; exit 1; }
  command -v timeout >/dev/null 2>&1 || { echo "❌ timeout not found"; exit 1; }
  echo "✅ All dependencies installed"
'

# 4. テスト実行（開発環境確認）
bash scripts/run-all-worktree-tests.sh
```

### IDEセットアップ

#### VS Code推奨拡張機能

```json
{
  "recommendations": [
    "timonwong.shellcheck",        // Shell script linter
    "foxundermoon.shell-format",   // Shell script formatter
    "mkhl.shfmt"                   // Shell formatter
  ]
}
```

#### ShellCheck設定（`.shellcheckrc`）

```bash
# ディレクトリにあるsource文を許可
source-path=SCRIPTDIR

# 除外するチェック
disable=SC1090  # Can't follow non-constant source
disable=SC2034  # Unused variable (状態管理で使用)
disable=SC2154  # Variable is referenced but not assigned
```

---

## コーディング規約

### Bashスタイルガイド

**基本原則:**
```bash
#!/usr/bin/env bash
# スクリプト名.sh - 簡潔な説明
# 責務: 具体的な責務を記載

set -euo pipefail  # 厳格なエラーハンドリング
```

### 命名規則

| 種類 | 規則 | 例 |
|------|------|-----|
| 関数名 | snake_case | `create_worktree()` |
| 変数（ローカル） | snake_case | `local ai_name="qwen"` |
| 変数（グローバル） | UPPER_SNAKE_CASE | `WORKTREE_BASE_DIR` |
| 定数 | UPPER_SNAKE_CASE | `MAX_PARALLEL_WORKTREES` |
| ファイル名 | kebab-case.sh | `worktree-core.sh` |

### 関数定義

**テンプレート:**
```bash
##
# 関数の簡潔な説明（1行）
#
# より詳細な説明（必要に応じて複数行）
#
# 引数:
#   $1 - AI名（claude|gemini|amp|qwen|droid|codex|cursor）
#   $2 - Worktreeパス
#   $3 - ブランチ名（省略可）
#
# 戻り値:
#   0 - 成功
#   1 - 失敗（エラーメッセージをstderrに出力）
#
# 使用例:
#   create_worktree "qwen" "worktrees/qwen"
#   create_worktree "claude" "worktrees/claude" "feature/custom"
##
create_worktree() {
  local ai="$1"
  local worktree_path="$2"
  local branch="${3:-ai/$ai/$(date +%Y%m%d-%H%M%S)}"

  # 実装...
}
```

### エラーハンドリング

**What/Why/How形式:**
```bash
error_with_details() {
  cat <<EOF >&2
ERROR [$error_code]: $error_title

What: $what_happened
Why:  $why_it_happened
How:  $how_to_fix

$additional_details
EOF
  return 1
}
```

### コメント

**ドキュメントコメント:**
```bash
##
# 複数行のドキュメントコメント
# Markdownとして処理される
##
```

**実装コメント:**
```bash
# 単一行コメント（実装の説明）
```

**TODOコメント:**
```bash
# TODO(username): 将来の改善点
# FIXME(username): 既知の問題
# NOTE: 重要な注意事項
```

### インデント

- **インデント:** 2スペース（タブ禁止）
- **最大行長:** 100文字（推奨）
- **関数間:** 2行の空行

**例:**
```bash
function_a() {
  local var="value"

  if [[ condition ]]; then
    echo "indented 2 spaces"
  fi
}


function_b() {
  # 2行の空行で区切る
}
```

---

## PR作成ガイド

### ブランチ戦略

**ブランチ命名規則:**
```
feature/<feature-name>    # 新機能
fix/<bug-name>            # バグ修正
refactor/<refactor-name>  # リファクタリング
docs/<doc-name>           # ドキュメント更新
test/<test-name>          # テスト追加
```

**例:**
```bash
git checkout -b feature/add-parallel-merge-strategy
git checkout -b fix/cleanup-trap-timing
git checkout -b docs/update-api-reference
```

### コミットメッセージ

**Conventional Commits形式:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**タイプ:**
- `feat`: 新機能
- `fix`: バグ修正
- `refactor`: リファクタリング
- `docs`: ドキュメント更新
- `test`: テスト追加・修正
- `chore`: ビルド・設定変更

**スコープ（Worktree関連）:**
- `core`: worktree-core.sh
- `state`: worktree-state.sh
- `history`: worktree-history.sh
- `metrics`: worktree-metrics.sh
- `merge`: worktree-merge.sh
- `execution`: worktree-execution.sh
- `cleanup`: worktree-cleanup.sh
- `errors`: worktree-errors.sh

**例:**
```
feat(merge): Add parallel merge strategy for multiple AIs

Implement parallel merge support to merge multiple AI branches
simultaneously while detecting and resolving conflicts.

Features:
- Parallel conflict detection (xargs -P)
- Automatic conflict resolution (best strategy)
- Merge coordination (sequential fallback)

Closes #123
```

### PRチェックリスト

**PR作成前:**
```bash
# 1. コードスタイルチェック
shellcheck scripts/orchestrate/lib/worktree-*.sh

# 2. テスト実行
bash scripts/run-all-worktree-tests.sh

# 3. ドキュメント更新
# - API_REFERENCE.md（新関数追加時）
# - TROUBLESHOOTING.md（新エラー追加時）
# - ARCHITECTURE.md（設計変更時）

# 4. コミット整理（必要に応じて）
git rebase -i origin/main
```

**PRテンプレート:**
```markdown
## 概要
このPRは...を実装/修正します。

## 変更内容
- [ ] 新機能の追加
- [ ] バグ修正
- [ ] ドキュメント更新
- [ ] テスト追加

## 影響範囲
- 影響を受けるライブラリ: worktree-core.sh, worktree-merge.sh
- 破壊的変更: あり/なし

## テスト
- [ ] ユニットテスト追加
- [ ] 統合テスト追加
- [ ] 手動テスト実施

## 関連Issue
Closes #123
```

### レビュープロセス

1. **自動チェック** - GitHub Actions CI
   - ShellCheck linting
   - テスト実行（47テスト）
   - レポート生成

2. **コードレビュー** - メンテナー/コントリビューター
   - コードスタイル
   - ロジック検証
   - パフォーマンス影響

3. **承認とマージ**
   - 2名以上の承認が必要
   - Squash mergeを推奨

---

## テスト方法

### テストスイート構成

| テストスイート | ファイル | テスト数 | カバレッジ |
|--------------|---------|---------|----------|
| Phase 2.3: マージ戦略 | test-worktree-merge.sh | 16 | 100% |
| Phase 2.1: 状態管理 | test-worktree-state-management.sh | 21 | 100% |
| Phase 2.2: リカバリー | test-worktree-recovery.sh | 10 | 90% |
| **合計** | | **47** | **97.9%** |

### ローカルテスト実行

**全テストスイート:**
```bash
bash scripts/run-all-worktree-tests.sh
```

**個別テストスイート:**
```bash
# Phase 2.3
bash scripts/test-worktree-merge.sh

# Phase 2.1
bash scripts/test-worktree-state-management.sh

# Phase 2.2
bash scripts/test-worktree-recovery.sh
```

### テスト作成ガイド

**テンプレート:**
```bash
#!/usr/bin/env bash
# test-worktree-<feature>.sh - <feature>のテスト

set -euo pipefail

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# テスト結果カウンター
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# テストヘルパー関数
assert_success() {
  local cmd="$1"
  local test_name="$2"

  TOTAL_TESTS=$((TOTAL_TESTS + 1))

  if eval "$cmd" >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} $test_name"
    PASSED_TESTS=$((PASSED_TESTS + 1))
    return 0
  else
    echo -e "${RED}✗${NC} $test_name"
    FAILED_TESTS=$((FAILED_TESTS + 1))
    return 1
  fi
}

# テスト環境セットアップ
setup() {
  # テスト用の一時ディレクトリ作成
  TEST_DIR="$(mktemp -d)"
  export WORKTREE_BASE_DIR="$TEST_DIR/worktrees"

  # ライブラリロード
  source scripts/orchestrate/lib/worktree-core.sh
}

# テストケース
test_basic_functionality() {
  setup

  assert_success "create_worktree qwen $WORKTREE_BASE_DIR/qwen" \
    "Basic worktree creation"

  assert_success "verify_worktree qwen" \
    "Worktree verification"

  assert_success "cleanup_worktree qwen" \
    "Worktree cleanup"

  # クリーンアップ
  rm -rf "$TEST_DIR"
}

# テスト実行
test_basic_functionality

# サマリー出力
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 Test Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Total:   $TOTAL_TESTS"
echo -e "  ${GREEN}Passed:  $PASSED_TESTS${NC}"
echo -e "  ${RED}Failed:  $FAILED_TESTS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 終了コード
[[ $FAILED_TESTS -eq 0 ]] && exit 0 || exit 1
```

### CI/CDでのテスト

**GitHub Actions設定（`.github/workflows/worktree-test.yml`）:**
```yaml
name: Worktree Integration Tests

on: [push, pull_request]

env:
  NON_INTERACTIVE: true
  MAX_PARALLEL_WORKTREES: 2

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: sudo apt-get install -y jq

      - name: Run tests
        run: bash scripts/run-all-worktree-tests.sh

      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: logs/worktree-test-reports/
```

---

## ドキュメント更新

### ドキュメント構成

| ドキュメント | 対象読者 | 更新タイミング |
|------------|---------|--------------|
| API_REFERENCE.md | 開発者 | 新関数追加時 |
| TROUBLESHOOTING.md | ユーザー | 新エラー追加時 |
| ARCHITECTURE.md | アーキテクト | 設計変更時 |
| CONTRIBUTING.md | コントリビューター | プロセス変更時 |

### ドキュメント更新ガイドライン

**新関数追加時:**
```markdown
### function_name()

関数の説明

**シグネチャ:**
` ``bash
function_name <arg1> <arg2> [optional-arg3]
` ``

**引数:**
- `$1` - 引数の説明
- `$2` - 引数の説明

**戻り値:**
- `0` - 成功
- `1` - 失敗

**使用例:**
` ``bash
function_name "value1" "value2"
` ``
```

**新エラーコード追加時:**
```markdown
| WT###  | エラー名 | 原因 | 対処方法 |
| WT501 | 状態遷移エラー | 不正な状態遷移 | 状態ファイルリセット |
```

---

## リリースプロセス

### バージョニング

**Semantic Versioning (SemVer):**
```
MAJOR.MINOR.PATCH

例: v1.2.3
```

- **MAJOR** - 破壊的変更
- **MINOR** - 後方互換性のある機能追加
- **PATCH** - 後方互換性のあるバグ修正

### リリース手順

**1. バージョン番号決定:**
```bash
# 現在のバージョン確認
git tag | sort -V | tail -1

# 次のバージョン決定
# - 破壊的変更あり → MAJOR+1
# - 新機能追加 → MINOR+1
# - バグ修正のみ → PATCH+1
```

**2. CHANGELOG更新:**
```bash
# CHANGELOG.md に追記
## [v1.2.0] - 2025-11-08

### Added
- Parallel merge strategy for multiple AIs
- Automatic conflict resolution

### Changed
- Improved cleanup success rate to 100%

### Fixed
- Trap cleanup timing issue (#45)
```

**3. テスト実行:**
```bash
# 全テスト実行
bash scripts/run-all-worktree-tests.sh

# 成功率確認: 97.9%以上
```

**4. タグ作成:**
```bash
git tag -a v1.2.0 -m "Release v1.2.0

Features:
- Parallel merge strategy
- Automatic conflict resolution

Fixes:
- Trap cleanup timing issue

Test Results: 47/47 tests passing (97.9%)
"

git push origin v1.2.0
```

**5. GitHub Release作成:**
- タイトル: `v1.2.0 - Parallel Merge Support`
- 説明: CHANGELOGから転記
- アーティファクト: テストレポート添付

---

## コミュニティ

### コミュニケーション

- **GitHub Issues**: バグ報告、機能リクエスト
- **GitHub Discussions**: 質問、アイデア共有
- **Pull Requests**: コード貢献

### コントリビューター行動規範

1. **尊重** - 全ての参加者を尊重する
2. **建設的** - 建設的なフィードバックを提供する
3. **協力的** - チームとして協力する
4. **包括的** - 多様な視点を歓迎する

### 質問する前に

1. **ドキュメント確認** - API_REFERENCE.md, TROUBLESHOOTING.md
2. **既存Issue確認** - 同じ問題が報告されていないか
3. **検索** - Discussions, StackOverflow

### Issue報告

**バグ報告テンプレート:**
```markdown
## 環境
- OS: Ubuntu 22.04
- Bash: 5.1.16
- Git: 2.34.1
- jq: 1.6

## 再現手順
1. `create_worktree "qwen" "worktrees/qwen"`
2. `execute_in_worktree "qwen" "bash script.sh"`
3. エラー発生

## 期待される動作
Worktreeが正常に作成され、スクリプトが実行される

## 実際の動作
ERROR [WT101]: Worktree creation failed

## ログ
` ``
git worktree add -b ai/qwen/20251108-120000 worktrees/qwen
fatal: 'worktrees/qwen' already exists
` ``
```

---

## 謝辞

Multi-AI Orchestrium Git Worktrees統合システムへの貢献に感謝します！

**主要コントリビューター:**
- Phase 0修正: trap管理の改善
- Phase 2.1: 状態管理NDJSON実装
- Phase 2.2: エラーリカバリー機構
- Phase 2.3: マージ戦略と非対話モード
- Phase 2.4: CI/CD統合
- Phase 2.5: ドキュメント完全整備

---

## 関連リンク

- [APIリファレンス](API_REFERENCE.md)
- [トラブルシューティング](TROUBLESHOOTING.md)
- [アーキテクチャ](ARCHITECTURE.md)
- [GitHub Repository](https://github.com/CaCC-Lab/multi-ai-orchestrium)
- [License](../../LICENSE)

---

**最終更新:** 2025-11-08
**バージョン:** v1.0
**メンテナー:** Multi-AI Orchestrium Contributors
