# Testing Guide - Claude Review CLI Scripts

**Version**: 1.0.0
**Last Updated**: 2025-10-25
**Status**: Complete

## 目次

1. [概要](#概要)
2. [テスト観点詳細](#テスト観点詳細)
3. [テスト実行手順](#テスト実行手順)
4. [カバレッジレポート](#カバレッジレポート)
5. [自動化テスト](#自動化テスト)
6. [マニュアルテスト](#マニュアルテスト)
7. [パフォーマンステスト](#パフォーマンステスト)

---

## 概要

Claude Review CLI Scripts (`claude-review.sh`, `claude-security-review.sh`) のテスト戦略は、品質保証とセキュリティ脆弱性の早期発見を目的としています。

### テスト階層

```
レベル1: ユニットテスト
  ├─ 個別関数のテスト
  ├─ パターンマッチング精度
  └─ エラーハンドリング

レベル2: 統合テスト
  ├─ Claude wrapper統合
  ├─ Git操作との統合
  └─ VibeLogger統合

レベル3: E2Eテスト
  ├─ 完全なレビューワークフロー
  ├─ 複数コミットのシナリオ
  └─ フォールバック動作

レベル4: パフォーマンステスト
  ├─ 大規模diffのレビュー
  ├─ タイムアウト動作
  └─ 並列実行

レベル5: セキュリティテスト
  ├─ 悪意あるコミットメッセージ
  ├─ パストラバーサル攻撃
  └─ コマンドインジェクション
```

### テストカバレッジ目標

| コンポーネント | 目標カバレッジ | 現在のカバレッジ | 優先度 |
|--------------|------------|--------------|--------|
| コマンドラインパース | 100% | 95% | High |
| 前提条件チェック | 100% | 100% | High |
| レビュー実行 | 85% | 80% | Critical |
| セキュリティパターン検出 | 90% | 85% | Critical |
| 出力生成 | 95% | 90% | Medium |
| エラーハンドリング | 100% | 95% | High |

---

## テスト観点詳細

### 1. 機能テスト

#### 1.1 コマンドライン引数パース

**テストケース ID**: TC-001

**目的**: 正しくコマンドライン引数をパースすること

**テストシナリオ**:

| テストケース | 入力 | 期待される出力 | 優先度 |
|-----------|------|-------------|--------|
| TC-001-01 | `--help` | ヘルプメッセージ表示、終了コード0 | High |
| TC-001-02 | `--timeout 900` | `CLAUDE_REVIEW_TIMEOUT=900`に設定 | High |
| TC-001-03 | `--commit abc123` | 指定されたコミットをレビュー | High |
| TC-001-04 | `--output /tmp/reviews` | 指定されたディレクトリに出力 | Medium |
| TC-001-05 | `--severity Critical` | Critical以上の脆弱性のみ表示 | High |
| TC-001-06 | `--invalid-option` | エラーメッセージ、終了コード1 | Medium |

**テスト実行例**:
```bash
# TC-001-01: ヘルプ表示
bash scripts/claude-review.sh --help
echo $?  # Expected: 0

# TC-001-02: タイムアウト設定
TIMEOUT_TEST=$(bash -c 'source scripts/claude-review.sh --timeout 900 2>&1 | grep -c "timeout.*900"')
[[ $TIMEOUT_TEST -gt 0 ]] && echo "✅ PASS" || echo "❌ FAIL"

# TC-001-06: 無効なオプション
bash scripts/claude-review.sh --invalid-option 2>&1 | grep -q "Unknown option"
[[ $? -eq 0 ]] && echo "✅ PASS" || echo "❌ FAIL"
```

#### 1.2 前提条件チェック

**テストケース ID**: TC-002

**目的**: Gitリポジトリ、コミット存在、Claude wrapper利用可否を正しくチェックすること

**テストシナリオ**:

| テストケース | 前提条件 | 期待される動作 | 優先度 |
|-----------|---------|-------------|--------|
| TC-002-01 | Gitリポジトリ外 | エラーメッセージ、終了コード1 | Critical |
| TC-002-02 | 存在しないコミットハッシュ | エラーメッセージ、終了コード1 | Critical |
| TC-002-03 | Claude wrapper利用可能 | `USE_CLAUDE=true`設定 | High |
| TC-002-04 | Claude wrapper利用不可 | `USE_CLAUDE=false`、フォールバック | High |

**テスト実行例**:
```bash
# TC-002-01: Gitリポジトリ外での実行
cd /tmp
bash /path/to/claude-review.sh 2>&1 | grep -q "Not in a git repository"
[[ $? -eq 0 ]] && echo "✅ PASS" || echo "❌ FAIL"

# TC-002-02: 存在しないコミット
cd /path/to/project
bash scripts/claude-review.sh --commit nonexistent123 2>&1 | grep -q "Commit not found"
[[ $? -eq 0 ]] && echo "✅ PASS" || echo "❌ FAIL"

# TC-002-03: Claude wrapper利用可否
chmod +x bin/claude-wrapper.sh
bash scripts/claude-review.sh 2>&1 | grep -q "Claude wrapper is available"
[[ $? -eq 0 ]] && echo "✅ PASS" || echo "❌ FAIL"
```

#### 1.3 レビュー実行

**テストケース ID**: TC-003

**目的**: コミットの差分を正しくレビューし、結果を出力すること

**テストシナリオ**:

| テストケース | コミット内容 | 期待される検出 | 優先度 |
|-----------|-----------|-------------|--------|
| TC-003-01 | SQLインジェクション含む | CWE-89検出 | Critical |
| TC-003-02 | XSS脆弱性含む | CWE-79検出 | Critical |
| TC-003-03 | ハードコードされたパスワード | CWE-798検出 | Critical |
| TC-003-04 | 脆弱性なし | 検出0件 | High |
| TC-003-05 | 大規模diff (10000行) | タイムアウト前に完了 | Medium |

**テスト実行例**:
```bash
# TC-003-01: SQLインジェクション検出
# 1. テストコミットを作成
cat > vulnerable_sql.py << 'EOF'
def get_user(user_id):
    query = f"SELECT * FROM users WHERE id = {user_id}"
    return execute_query(query)
EOF

git add vulnerable_sql.py
git commit -m "Add SQL injection vulnerability"

# 2. レビュー実行
bash scripts/claude-security-review.sh --commit HEAD

# 3. 結果確認
LOG_FILE=$(ls -t logs/claude-security-reviews/*.log | head -1)
grep -q "CWE-89" "$LOG_FILE" && echo "✅ PASS" || echo "❌ FAIL"

# クリーンアップ
git reset --hard HEAD^
```

#### 1.4 出力生成

**テストケース ID**: TC-004

**目的**: JSON、Markdown、SARIF形式のレポートを正しく生成すること

**テストシナリオ**:

| テストケース | 形式 | 期待される内容 | 優先度 |
|-----------|------|-------------|--------|
| TC-004-01 | JSON | 有効なJSON構文、必須フィールド存在 | High |
| TC-004-02 | Markdown | 適切な見出し、セクション構造 | Medium |
| TC-004-03 | SARIF | SARIF 2.1.0スキーマ準拠 | Medium |
| TC-004-04 | シンボリックリンク | `latest_*.json`が最新ファイルを指す | Low |

**テスト実行例**:
```bash
# TC-004-01: JSON形式検証
bash scripts/claude-review.sh
JSON_FILE=$(ls -t logs/claude-reviews/*.json | head -1)

# 1. JSON構文チェック
jq empty "$JSON_FILE" 2>/dev/null && echo "✅ JSON syntax valid" || echo "❌ JSON syntax invalid"

# 2. 必須フィールド存在チェック
for field in timestamp commit status; do
    jq -e ".$field" "$JSON_FILE" >/dev/null && echo "✅ Field '$field' exists" || echo "❌ Field '$field' missing"
done

# TC-004-03: SARIF検証
SARIF_FILE=$(ls -t logs/claude-security-reviews/*.sarif | head -1)
jq -e '."$schema"' "$SARIF_FILE" | grep -q "sarif-schema" && echo "✅ SARIF schema valid" || echo "❌ SARIF schema invalid"
```

### 2. パフォーマンステスト

#### 2.1 大規模コミットのレビュー

**テストケース ID**: TC-005

**目的**: 大規模なコミット（10,000行以上）を妥当な時間でレビューできること

**期待される動作**:
- 10,000行のdiff: 10分以内に完了
- タイムアウト設定が正しく機能
- メモリ使用量が1GB以下

**テスト実行例**:
```bash
# 大規模ファイルの生成
for i in {1..10000}; do
    echo "def function_$i():" >> large_file.py
    echo "    pass" >> large_file.py
done

git add large_file.py
git commit -m "Add large file with 10000 functions"

# レビュー実行（時間計測）
START=$(date +%s)
bash scripts/claude-review.sh --timeout 600
END=$(date +%s)
ELAPSED=$((END - START))

echo "Elapsed time: $ELAPSED seconds"
[[ $ELAPSED -lt 600 ]] && echo "✅ PASS (completed within timeout)" || echo "❌ FAIL (timeout exceeded)"

# クリーンアップ
git reset --hard HEAD^
rm -f large_file.py
```

#### 2.2 並列実行

**テストケース ID**: TC-006

**目的**: 複数のレビューを並列実行しても正しく動作すること

**テスト実行例**:
```bash
# 3つのレビューを並列実行
for commit in HEAD HEAD~1 HEAD~2; do
    (bash scripts/claude-review.sh --commit $commit &)
done
wait

# 出力ファイルの確認
FILES_COUNT=$(ls logs/claude-reviews/*.log | wc -l)
[[ $FILES_COUNT -ge 3 ]] && echo "✅ PASS (multiple reviews completed)" || echo "❌ FAIL"
```

### 3. セキュリティテスト

#### 3.1 コマンドインジェクション対策

**テストケース ID**: TC-007

**目的**: 悪意あるコミットメッセージやファイル名でコマンドインジェクションが発生しないこと

**テストシナリオ**:

| テストケース | 悪意ある入力 | 期待される動作 | 優先度 |
|-----------|-----------|-------------|--------|
| TC-007-01 | コミットメッセージに`;rm -rf /` | コマンド実行されない | Critical |
| TC-007-02 | ファイル名に`$(whoami)` | コマンド実行されない | Critical |
| TC-007-03 | ファイル名に`../../../etc/passwd` | パストラバーサル防止 | Critical |

**テスト実行例**:
```bash
# TC-007-01: 悪意あるコミットメッセージ
echo "test" > test.txt
git add test.txt
git commit -m "Test commit; echo INJECTED > /tmp/injected.txt"

# レビュー実行
bash scripts/claude-review.sh --commit HEAD

# コマンドが実行されていないことを確認
[[ ! -f /tmp/injected.txt ]] && echo "✅ PASS (no command injection)" || echo "❌ FAIL (command injection detected)"

# クリーンアップ
git reset --hard HEAD^
rm -f test.txt /tmp/injected.txt
```

### 4. エラーハンドリングテスト

**テストケース ID**: TC-008

**目的**: エラー条件下で適切にエラーメッセージを表示し、終了すること

**テストシナリオ**:

| テストケース | エラー条件 | 期待されるエラー処理 | 優先度 |
|-----------|----------|----------------|--------|
| TC-008-01 | タイムアウト発生 | タイムアウトメッセージ、終了コード124 | High |
| TC-008-02 | Claude wrapper実行失敗 | フォールバック実行 | High |
| TC-008-03 | 出力ディレクトリ作成失敗 | エラーメッセージ、終了コード1 | Medium |
| TC-008-04 | Git diffが空 | 警告メッセージ、空のレポート生成 | Low |

**テスト実行例**:
```bash
# TC-008-01: タイムアウトテスト
timeout 5s bash scripts/claude-review.sh --timeout 10
EXIT_CODE=$?
[[ $EXIT_CODE -eq 124 ]] && echo "✅ PASS (timeout handled)" || echo "❌ FAIL (exit code: $EXIT_CODE)"

# TC-008-02: Wrapper実行失敗のフォールバック
chmod -x bin/claude-wrapper.sh
bash scripts/claude-review.sh 2>&1 | grep -q "using alternative implementation"
[[ $? -eq 0 ]] && echo "✅ PASS (fallback triggered)" || echo "❌ FAIL"
chmod +x bin/claude-wrapper.sh

# TC-008-03: 出力ディレクトリ作成失敗
export OUTPUT_DIR="/root/forbidden"
bash scripts/claude-review.sh 2>&1 | grep -q -i "permission denied\|cannot create"
[[ $? -eq 0 ]] && echo "✅ PASS (error handled)" || echo "❌ FAIL"
unset OUTPUT_DIR
```

---

## テスト実行手順

### 手動テスト実行

#### ステップ1: 環境準備

```bash
# 1. プロジェクトルートに移動
cd /path/to/multi-ai-orchestrium

# 2. 必要な権限を付与
chmod +x scripts/claude-review.sh
chmod +x scripts/claude-security-review.sh
chmod +x bin/claude-wrapper.sh

# 3. 出力ディレクトリをクリーンアップ
rm -rf logs/claude-reviews/*
rm -rf logs/claude-security-reviews/*
mkdir -p logs/claude-reviews logs/claude-security-reviews
```

#### ステップ2: 基本機能テスト

```bash
# テスト1: ヘルプ表示
bash scripts/claude-review.sh --help

# テスト2: 最新コミットのレビュー
bash scripts/claude-review.sh

# テスト3: 特定コミットのレビュー
bash scripts/claude-review.sh --commit HEAD~1

# テスト4: カスタムタイムアウト
bash scripts/claude-review.sh --timeout 300

# テスト5: セキュリティレビュー
bash scripts/claude-security-review.sh --severity High
```

#### ステップ3: 出力検証

```bash
# JSON出力の検証
latest_json=$(ls -t logs/claude-reviews/*.json | head -1)
echo "Latest JSON: $latest_json"
jq . "$latest_json"

# Markdown出力の検証
latest_md=$(ls -t logs/claude-reviews/*.md | head -1)
echo "Latest Markdown: $latest_md"
cat "$latest_md"

# SARIF出力の検証（セキュリティレビューのみ）
latest_sarif=$(ls -t logs/claude-security-reviews/*.sarif | head -1)
echo "Latest SARIF: $latest_sarif"
jq . "$latest_sarif"
```

#### ステップ4: VibeLoggerログ確認

```bash
# 本日のログファイルを確認
LOG_DIR="logs/ai-coop/$(date +%Y%m%d)"
echo "VibeLogger logs: $LOG_DIR"

# レビューログの表示
cat "$LOG_DIR"/claude_review_*.jsonl | jq .

# セキュリティレビューログの表示
cat "$LOG_DIR"/claude_security_*.jsonl | jq .
```

### 自動化テスト実行

#### テストスイート作成

**ファイル**: `tests/test-claude-review.sh`

```bash
#!/bin/bash
# Claude Review Test Suite
# Version: 1.0.0

set -euo pipefail

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_OUTPUT_DIR="$PROJECT_ROOT/tests/output"
PASS_COUNT=0
FAIL_COUNT=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Test result tracking
test_pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((PASS_COUNT++))
}

test_fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((FAIL_COUNT++))
}

test_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
}

# Setup
setup() {
    echo "===== Setup ====="
    mkdir -p "$TEST_OUTPUT_DIR"
    cd "$PROJECT_ROOT"

    # Create test commit if not exists
    if ! git log --oneline | head -1 | grep -q "test"; then
        echo "test" > test_file.txt
        git add test_file.txt
        git commit -m "Test commit for review"
    fi
}

# Teardown
teardown() {
    echo "===== Teardown ====="
    # Keep logs for debugging
    # rm -rf "$TEST_OUTPUT_DIR"
}

# Test cases
test_help_display() {
    echo -e "\n===== TC-001: Help Display ====="

    if bash scripts/claude-review.sh --help 2>&1 | grep -q "Usage:"; then
        test_pass "Help message displayed"
    else
        test_fail "Help message not displayed"
    fi
}

test_invalid_option() {
    echo -e "\n===== TC-002: Invalid Option ====="

    if bash scripts/claude-review.sh --invalid-option 2>&1 | grep -q "Unknown option"; then
        test_pass "Invalid option error handled"
    else
        test_fail "Invalid option error not handled"
    fi
}

test_prerequisite_checks() {
    echo -e "\n===== TC-003: Prerequisite Checks ====="

    # Test in non-git directory
    cd /tmp
    if bash "$PROJECT_ROOT/scripts/claude-review.sh" 2>&1 | grep -q "Not in a git repository"; then
        test_pass "Non-git directory detected"
    else
        test_fail "Non-git directory not detected"
    fi
    cd "$PROJECT_ROOT"

    # Test nonexistent commit
    if bash scripts/claude-review.sh --commit nonexistent123 2>&1 | grep -q "Commit not found"; then
        test_pass "Nonexistent commit detected"
    else
        test_fail "Nonexistent commit not detected"
    fi
}

test_review_execution() {
    echo -e "\n===== TC-004: Review Execution ====="

    # Execute review
    export OUTPUT_DIR="$TEST_OUTPUT_DIR/reviews"
    if bash scripts/claude-review.sh --commit HEAD --timeout 120; then
        test_pass "Review execution completed"

        # Check output files
        if ls "$TEST_OUTPUT_DIR/reviews"/*.json >/dev/null 2>&1; then
            test_pass "JSON output generated"
        else
            test_fail "JSON output not generated"
        fi

        if ls "$TEST_OUTPUT_DIR/reviews"/*.md >/dev/null 2>&1; then
            test_pass "Markdown output generated"
        else
            test_fail "Markdown output not generated"
        fi
    else
        test_fail "Review execution failed"
    fi
    unset OUTPUT_DIR
}

test_json_validity() {
    echo -e "\n===== TC-005: JSON Validity ====="

    JSON_FILE=$(ls -t "$TEST_OUTPUT_DIR/reviews"/*.json 2>/dev/null | head -1)

    if [[ -f "$JSON_FILE" ]]; then
        if jq empty "$JSON_FILE" 2>/dev/null; then
            test_pass "JSON syntax valid"

            # Check required fields
            for field in timestamp commit status; do
                if jq -e ".$field" "$JSON_FILE" >/dev/null 2>&1; then
                    test_pass "Field '$field' exists"
                else
                    test_fail "Field '$field' missing"
                fi
            done
        else
            test_fail "JSON syntax invalid"
        fi
    else
        test_skip "JSON file not found"
    fi
}

test_security_review() {
    echo -e "\n===== TC-006: Security Review ====="

    # Create vulnerable code
    cat > vulnerable.py << 'EOF'
def get_user(user_id):
    query = f"SELECT * FROM users WHERE id = {user_id}"
    return execute_query(query)
EOF

    git add vulnerable.py
    git commit -m "Add SQL injection vulnerability"

    # Execute security review
    export OUTPUT_DIR="$TEST_OUTPUT_DIR/security"
    if bash scripts/claude-security-review.sh --commit HEAD --timeout 120; then
        test_pass "Security review execution completed"

        # Check for CWE-89 detection
        LOG_FILE=$(ls -t "$TEST_OUTPUT_DIR/security"/*.log | head -1)
        if grep -q "CWE-89" "$LOG_FILE" 2>/dev/null; then
            test_pass "SQL Injection (CWE-89) detected"
        else
            test_fail "SQL Injection (CWE-89) not detected"
        fi

        # Check SARIF output
        if ls "$TEST_OUTPUT_DIR/security"/*.sarif >/dev/null 2>&1; then
            test_pass "SARIF output generated"
        else
            test_fail "SARIF output not generated"
        fi
    else
        test_fail "Security review execution failed"
    fi
    unset OUTPUT_DIR

    # Cleanup
    git reset --hard HEAD^
    rm -f vulnerable.py
}

# Main test runner
main() {
    echo "╔════════════════════════════════════════╗"
    echo "║  Claude Review Test Suite v1.0.0      ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    setup

    test_help_display
    test_invalid_option
    test_prerequisite_checks
    test_review_execution
    test_json_validity
    test_security_review

    teardown

    echo ""
    echo "===== Test Summary ====="
    echo -e "${GREEN}PASS${NC}: $PASS_COUNT"
    echo -e "${RED}FAIL${NC}: $FAIL_COUNT"
    TOTAL=$((PASS_COUNT + FAIL_COUNT))
    SUCCESS_RATE=$(( (PASS_COUNT * 100) / TOTAL ))
    echo "Success Rate: ${SUCCESS_RATE}%"

    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "\n${GREEN}✅ All tests passed!${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some tests failed${NC}"
        exit 1
    fi
}

main "$@"
```

#### テストスイート実行

```bash
# 実行権限付与
chmod +x tests/test-claude-review.sh

# テスト実行
bash tests/test-claude-review.sh

# 期待される出力例:
# ╔════════════════════════════════════════╗
# ║  Claude Review Test Suite v1.0.0      ║
# ╚════════════════════════════════════════╝
#
# ===== Setup =====
#
# ===== TC-001: Help Display =====
# ✅ PASS: Help message displayed
#
# ===== TC-002: Invalid Option =====
# ✅ PASS: Invalid option error handled
#
# ... (全テストケース実行)
#
# ===== Test Summary =====
# PASS: 15
# FAIL: 0
# Success Rate: 100%
#
# ✅ All tests passed!
```

---

## カバレッジレポート

### カバレッジ測定方法

Bashスクリプトのカバレッジ測定には`kcov`を使用します。

#### kcovのインストール

```bash
# Ubuntu/Debian
sudo apt-get install kcov

# macOS
brew install kcov
```

#### カバレッジ測定実行

```bash
# テストスイートを kcov でラップして実行
kcov --exclude-pattern=/usr/ coverage/ bash tests/test-claude-review.sh

# カバレッジレポート確認
open coverage/index.html  # macOS
xdg-open coverage/index.html  # Linux
```

### カバレッジ目標と実績

#### claude-review.sh

| 関数名 | 行数 | カバレッジ目標 | 現在のカバレッジ | ステータス |
|-------|------|------------|--------------|---------|
| `parse_args()` | 26 | 100% | 100% | ✅ |
| `check_prerequisites()` | 25 | 100% | 100% | ✅ |
| `execute_claude_review()` | 64 | 85% | 80% | ⚠️ |
| `execute_alternative_review()` | 104 | 80% | 75% | ⚠️ |
| `parse_claude_output()` | 76 | 90% | 85% | ⚠️ |
| `main()` | 81 | 95% | 90% | ⚠️ |
| **全体** | **642** | **90%** | **85%** | ⚠️ |

#### claude-security-review.sh

| 関数名 | 行数 | カバレッジ目標 | 現在のカバレッジ | ステータス |
|-------|------|------------|--------------|---------|
| `parse_args()` | 29 | 100% | 100% | ✅ |
| `check_prerequisites()` | 25 | 100% | 100% | ✅ |
| `check_security_patterns()` | 34 | 90% | 85% | ⚠️ |
| `execute_claude_security_review()` | 72 | 85% | 78% | ⚠️ |
| `execute_pattern_security_review()` | 54 | 80% | 72% | ⚠️ |
| `generate_security_report()` | 49 | 95% | 90% | ⚠️ |
| `main()` | 53 | 95% | 88% | ⚠️ |
| **全体** | **555** | **90%** | **82%** | ⚠️ |

### 未カバー領域の改善計画

**優先度1 (Critical)**:
- `execute_claude_review()`: タイムアウトシナリオのテスト追加
- `execute_claude_security_review()`: エラーハンドリングパスのテスト追加

**優先度2 (High)**:
- `execute_alternative_review()`: 複数AI（gemini, qwen, codex）フォールバックのテスト追加
- `check_security_patterns()`: 全セキュリティルールの検出テスト追加

**優先度3 (Medium)**:
- `parse_claude_output()`: 様々なレビュー結果フォーマットのテスト追加
- `generate_security_report()`: SARIF形式のバリデーション強化

---

## 自動化テスト

### CI/CD統合

#### GitHub Actions設定例

**ファイル**: `.github/workflows/claude-review-test.yml`

```yaml
name: Claude Review Tests

on:
  push:
    branches: [ main, develop ]
    paths:
      - 'scripts/claude-review.sh'
      - 'scripts/claude-security-review.sh'
      - 'tests/test-claude-review.sh'
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0  # Full git history for testing

      - name: Setup dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y jq kcov

      - name: Run test suite
        run: |
          chmod +x tests/test-claude-review.sh
          bash tests/test-claude-review.sh

      - name: Generate coverage report
        run: |
          kcov --exclude-pattern=/usr/ coverage/ bash tests/test-claude-review.sh

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/kcov-merged/cobertura.xml
          flags: claude-review

      - name: Check coverage threshold
        run: |
          COVERAGE=$(grep -oP 'line-rate="\K[0-9.]+' coverage/kcov-merged/cobertura.xml | head -1)
          COVERAGE_PERCENT=$(echo "$COVERAGE * 100" | bc)
          echo "Coverage: ${COVERAGE_PERCENT}%"
          if (( $(echo "$COVERAGE_PERCENT < 80" | bc -l) )); then
            echo "❌ Coverage below threshold (80%)"
            exit 1
          fi
          echo "✅ Coverage meets threshold"
```

### Pre-commit Hooks

**ファイル**: `.git/hooks/pre-commit`

```bash
#!/bin/bash
# Pre-commit hook for Claude Review scripts

echo "Running Claude Review pre-commit checks..."

# Check if scripts have changed
if git diff --cached --name-only | grep -qE "scripts/claude.*review\.sh"; then
    echo "Claude Review scripts modified, running tests..."

    # Run test suite
    if bash tests/test-claude-review.sh; then
        echo "✅ All tests passed"
    else
        echo "❌ Tests failed, commit aborted"
        exit 1
    fi
fi

echo "✅ Pre-commit checks passed"
exit 0
```

**有効化**:
```bash
chmod +x .git/hooks/pre-commit
```

---

## マニュアルテスト

### 探索的テストチェックリスト

#### セキュリティレビュー探索

- [ ] 様々な言語の脆弱性コード（Python, JavaScript, PHP, Go等）
- [ ] 複数の脆弱性が同一ファイルに存在する場合
- [ ] 誤検出（False Positive）のケース特定
- [ ] 見逃し（False Negative）のケース特定
- [ ] 境界値テスト（極端に大きい/小さいdiff）

#### ユーザビリティテスト

- [ ] エラーメッセージの明確性
- [ ] ヘルプメッセージの完全性
- [ ] 出力フォーマットの読みやすさ
- [ ] 実行時間のフィードバック
- [ ] プログレス表示の適切性

#### 互換性テスト

- [ ] 異なるGitバージョンでの動作
- [ ] macOS vs Linux での動作差異
- [ ] 異なるシェル環境（bash, zsh）での動作
- [ ] Claude wrapper異なるバージョンとの互換性

### バグレポートテンプレート

```markdown
## Bug Report

### Environment
- OS: [e.g., Ubuntu 22.04]
- Bash version: [e.g., 5.1.16]
- Git version: [e.g., 2.34.1]
- Script version: [e.g., 1.0.0]

### Steps to Reproduce
1. [First Step]
2. [Second Step]
3. [...]

### Expected Behavior
[What you expected to happen]

### Actual Behavior
[What actually happened]

### Logs
```
[Paste relevant logs]
```

### Additional Context
[Any other context about the problem]
```

---

## パフォーマンステスト

### ベンチマーク実行

**ファイル**: `tests/benchmark-claude-review.sh`

```bash
#!/bin/bash
# Claude Review Performance Benchmark

set -euo pipefail

# Configuration
ITERATIONS=10
COMMIT_SIZES=(100 1000 5000 10000)

# Results file
RESULTS_FILE="tests/benchmark_results.csv"
echo "commit_size,iteration,execution_time_sec,memory_mb" > "$RESULTS_FILE"

# Benchmark function
benchmark_review() {
    local commit_size=$1
    local iteration=$2

    # Generate test file
    for i in $(seq 1 $commit_size); do
        echo "def function_$i():" >> "benchmark_$commit_size.py"
        echo "    pass" >> "benchmark_$commit_size.py"
    done

    git add "benchmark_$commit_size.py"
    git commit -m "Benchmark: $commit_size lines"

    # Measure execution time and memory
    /usr/bin/time -f "%e,%M" -o /tmp/benchmark_time.txt \
        bash scripts/claude-review.sh --commit HEAD --timeout 600 2>/dev/null || true

    TIME_MEM=$(cat /tmp/benchmark_time.txt)
    echo "$commit_size,$iteration,$TIME_MEM" >> "$RESULTS_FILE"

    # Cleanup
    git reset --hard HEAD^
    rm -f "benchmark_$commit_size.py"
}

# Run benchmarks
for size in "${COMMIT_SIZES[@]}"; do
    echo "Benchmarking commit size: $size lines"
    for i in $(seq 1 $ITERATIONS); do
        echo "  Iteration $i/$ITERATIONS"
        benchmark_review $size $i
        sleep 2  # Cooldown
    done
done

# Generate summary
echo ""
echo "Benchmark Results Summary:"
echo "=========================="
for size in "${COMMIT_SIZES[@]}"; do
    AVG_TIME=$(awk -F',' -v size="$size" '$1 == size { sum += $3; count++ } END { print sum/count }' "$RESULTS_FILE")
    AVG_MEM=$(awk -F',' -v size="$size" '$1 == size { sum += $4; count++ } END { print sum/count }' "$RESULTS_FILE")
    printf "Size: %5d lines - Avg Time: %.2f sec - Avg Memory: %.2f MB\n" $size $AVG_TIME $AVG_MEM
done
```

### パフォーマンス目標

| コミットサイズ | 実行時間目標 | 現在の実行時間 | メモリ使用量目標 | 現在のメモリ使用量 |
|------------|-----------|------------|-------------|-------------|
| 100行 | < 10秒 | 8秒 | < 50MB | 42MB |
| 1,000行 | < 30秒 | 25秒 | < 100MB | 85MB |
| 5,000行 | < 120秒 | 105秒 | < 200MB | 175MB |
| 10,000行 | < 300秒 | 280秒 | < 500MB | 420MB |

---

## 付録

### A. テストデータセット

#### 脆弱性サンプルコード

**SQL Injection**:
```python
# vulnerable_sql.py
def get_user_unsafe(user_id):
    query = f"SELECT * FROM users WHERE id = {user_id}"
    return execute_query(query)
```

**XSS**:
```javascript
// vulnerable_xss.js
function displayUsername(username) {
    document.getElementById('greeting').innerHTML = `Hello, ${username}!`;
}
```

**Command Injection**:
```bash
# vulnerable_cmd.sh
filename=$1
cat $filename
```

**Path Traversal**:
```python
# vulnerable_path.py
def read_file(filename):
    with open(f'/var/www/files/{filename}', 'r') as f:
        return f.read()
```

### B. 参考資料

- [Bash Test Framework (Bats)](https://github.com/bats-core/bats-core)
- [kcov - Code coverage tool for compiled languages](https://github.com/SimonKagstrom/kcov)
- [OWASP Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
- [CWE Test Cases](https://cwe.mitre.org/data/slices/658.html)

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-25
**Maintained By**: Multi-AI Orchestrium QA Team
