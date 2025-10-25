# Claude Review CLIスクリプト - 開発者ガイド

## 目次

1. [概要](#概要)
2. [アーキテクチャ設計](#アーキテクチャ設計)
3. [スクリプトの拡張方法](#スクリプトの拡張方法)
4. [新しいセキュリティルールの追加方法](#新しいセキュリティルールの追加方法)
5. [VibeLogger統合の詳細](#vibelogger統合の詳細)
6. [テスト開発ガイド](#テスト開発ガイド)
7. [ベストプラクティス](#ベストプラクティス)

## 概要

このガイドは、Claude Review CLIスクリプト（`claude-review.sh`、`claude-security-review.sh`）の拡張、カスタマイズ、メンテナンスを行う開発者向けのドキュメントです。

### 前提知識

- Bash scripting (中級〜上級)
- JSON/Markdownフォーマット
- Claude Code MCP API
- VibeLoggerロギングシステム
- OWASP Top 10 & CWE知識（セキュリティレビュー拡張時）

### 開発環境セットアップ

```bash
# プロジェクトのクローン
git clone <repository_url>
cd multi-ai-orchestrium

# 必要なツールのインストール確認
which bash     # Bash 4.0+
which git      # Git 2.0+
which jq       # JSON処理
which yq       # YAML処理（オプション）

# Claude Code MCPのセットアップ
# https://docs.claude.com/ 参照

# VibeLoggerライブラリの確認
ls bin/vibe-logger-lib.sh
```

## アーキテクチャ設計

### スクリプト構造

```
scripts/
├── claude-review.sh              # 包括的コードレビュー
│   ├── Configuration            # 設定・環境変数（Line 10-16）
│   ├── Utility Functions        # ユーティリティ関数（Line 28-56）
│   ├── VibeLogger Functions     # ロギング関数（Line 62-127）
│   ├── CLI Argument Parsing     # コマンドライン引数解析（Line 133-188）
│   ├── Prerequisites Check      # 前提条件チェック（Line 194-234）
│   ├── Review Execution         # レビュー実行（Line 240-322）
│   ├── Alternative Review       # 代替レビュー（Line 328-389）
│   ├── Output Parsing           # 結果解析（Line 395-475）
│   ├── Report Generation        # レポート生成（Line 481-562）
│   └── Main Flow                # メイン実行フロー（Line 568-625）
│
└── claude-security-review.sh     # セキュリティ特化レビュー
    ├── Configuration            # 設定・環境変数（Line 10-17）
    ├── Security Rules           # セキュリティルール定義（Line 29-37）
    ├── Utility Functions        # ユーティリティ関数（Line 39-65）
    ├── VibeLogger Functions     # ロギング関数（Line 71-142）
    ├── Security Checks          # セキュリティチェック関数（Line 148-289）
    ├── CLI Argument Parsing     # コマンドライン引数解析（Line 295-354）
    ├── Prerequisites Check      # 前提条件チェック（Line 360-402）
    ├── Security Review Exec     # セキュリティレビュー実行（Line 408-512）
    ├── Report Generation        # レポート生成（Line 518-668）
    ├── SARIF Export             # SARIF形式出力（Line 674-748）
    └── Main Flow                # メイン実行フロー（Line 754-812）
```

### データフロー

```
┌─────────────────┐
│ CLI Arguments   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Prerequisites   │──► Check git, Claude MCP
│ Check           │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Git Diff        │──► git show <commit>
│ Extraction      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Claude Review   │──► Claude MCP API call
│ Execution       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Output Parsing  │──► JSON/Markdown generation
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Report Files    │──► logs/claude-reviews/*.{json,md}
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ VibeLogger Log  │──► logs/ai-coop/YYYYMMDD/*.jsonl
└─────────────────┘
```

## スクリプトの拡張方法

### 1. 新しいレビュー観点の追加

#### 例: パフォーマンス分析の強化

**ステップ1:** パフォーマンスチェック関数を追加

```bash
# claude-review.sh に追加

check_performance_issues() {
    local code_diff="$1"
    local issues=0

    log_info "Checking performance issues..."

    # ネストしたループの検出
    if echo "$code_diff" | grep -E 'for.*for|while.*while' >/dev/null 2>&1; then
        log_warning "Nested loops detected - potential O(n²) complexity"
        ((issues++))
    fi

    # 大規模配列操作の検出
    if echo "$code_diff" | grep -E 'for.*in.*\$\(' >/dev/null 2>&1; then
        log_warning "Command substitution in loop - consider optimization"
        ((issues++))
    fi

    # 不要なパイプの検出
    if echo "$code_diff" | grep -E 'cat.*\|' >/dev/null 2>&1; then
        log_warning "Useless use of cat - direct redirection recommended"
        ((issues++))
    fi

    echo "$issues"
}
```

**ステップ2:** メイン実行フローに統合

```bash
# execute_claude_review() 関数内に追加

perf_issues=$(check_performance_issues "$DIFF_CONTENT")

if [ "$perf_issues" -gt 0 ]; then
    log_warning "Found $perf_issues performance issue(s)"
fi
```

**ステップ3:** レポート生成に反映

```bash
# parse_claude_output() 関数内のJSON生成部分に追加

{
  "performance_analysis": {
    "total_issues": $perf_issues,
    "categories": {
      "algorithmic_complexity": 3,
      "resource_usage": 2,
      "unnecessary_operations": 1
    }
  }
}
```

### 2. カスタムレビュープロファイルの作成

#### 例: 言語固有のレビュープロファイル

**ステップ1:** プロファイル設定ファイルを作成

```bash
# config/review-profiles/bash-strict.yaml

name: "Bash Strict Profile"
enabled_checks:
  - shellcheck_integration
  - error_handling
  - variable_quoting
  - command_substitution
severity_thresholds:
  critical: "SC1000-SC1999"
  high: "SC2000-SC2099"
  medium: "SC2100-SC2199"
custom_rules:
  - pattern: 'eval.*\$'
    message: "Avoid eval with user input"
    severity: "critical"
```

**ステップ2:** プロファイルローダーを実装

```bash
# scripts/lib/review-profiles.sh

load_review_profile() {
    local profile_name="$1"
    local profile_file="config/review-profiles/${profile_name}.yaml"

    if [ ! -f "$profile_file" ]; then
        log_error "Profile not found: $profile_name"
        return 1
    fi

    # yqでYAMLを読み込み
    ENABLED_CHECKS=$(yq e '.enabled_checks[]' "$profile_file")
    SEVERITY_THRESHOLDS=$(yq e '.severity_thresholds' "$profile_file" -o=json)
    CUSTOM_RULES=$(yq e '.custom_rules' "$profile_file" -o=json)

    export ENABLED_CHECKS SEVERITY_THRESHOLDS CUSTOM_RULES
}
```

**ステップ3:** CLIオプションに追加

```bash
# parse_args() 関数に追加

--profile)
    REVIEW_PROFILE="$2"
    shift 2
    ;;
```

### 3. 外部ツール統合の追加

#### 例: ShellCheckとの統合

```bash
# scripts/claude-review.sh

run_shellcheck_analysis() {
    local file="$1"
    local output_dir="$2"

    log_info "Running ShellCheck analysis..."

    # ShellCheckの実行
    shellcheck --format=json "$file" > "${output_dir}/shellcheck.json" 2>&1

    # 結果の集約
    local sc_issues=$(jq '.| length' "${output_dir}/shellcheck.json")

    vibe_log "tool_integration" "shellcheck" \
        "{\"file\": \"$file\", \"issues\": $sc_issues}" \
        "ShellCheck analysis completed" \
        "Review ShellCheck results"

    echo "$sc_issues"
}
```

## 新しいセキュリティルールの追加方法

### セキュリティルール構造

セキュリティルールは、以下の形式で定義されます：

```bash
SECURITY_RULES[rule_name]="CWE-ID|Description|Regex Pattern 1|Regex Pattern 2|..."
```

### ステップバイステップガイド

#### 例: LDAP Injection検出の追加

**ステップ1:** セキュリティルールの定義

```bash
# claude-security-review.sh のSecurity Rules セクションに追加

SECURITY_RULES[ldap_injection]="CWE-90|LDAP Injection|ldapsearch.*\$|ldap_bind.*\$|ldap_search.*\$"
```

**ステップ2:** チェック関数の実装

```bash
# claude-security-review.sh にチェック関数を追加

check_ldap_injection() {
    local code_diff="$1"
    local output_file="$2"
    local findings=0

    log_info "Checking for LDAP Injection vulnerabilities..."

    # LDAPクエリの検出
    while IFS= read -r line; do
        if echo "$line" | grep -E 'ldapsearch.*\$|ldap_bind.*\$' >/dev/null 2>&1; then
            # 脆弱性を検出
            local file_line=$(echo "$line" | grep -oE '^[^:]+:[0-9]+')

            # JSON形式で記録
            cat >> "$output_file" << EOF
{
  "cwe_id": "CWE-90",
  "severity": "high",
  "cvss_score": 8.2,
  "title": "LDAP Injection Vulnerability",
  "file": "$(echo $file_line | cut -d: -f1)",
  "line": $(echo $file_line | cut -d: -f2),
  "evidence": "$(echo $line | sed 's/"/\\"/g')",
  "impact": "Attacker can manipulate LDAP queries to bypass authentication or access unauthorized data",
  "remediation": {
    "description": "Sanitize all user input before using in LDAP queries. Use parameterized queries or proper escaping.",
    "code_example": "ldap_escape_filter_value(\\$user_input)",
    "references": [
      "https://owasp.org/www-community/attacks/LDAP_Injection",
      "https://cwe.mitre.org/data/definitions/90.html"
    ]
  }
},
EOF
            ((findings++))

            # VibeLoggerに記録
            vibe_vulnerability_found "CWE-90" "high" 8.2 \
                "LDAP Injection in $(echo $file_line | cut -d: -f1)"
        fi
    done <<< "$code_diff"

    log_info "LDAP Injection check completed: $findings finding(s)"
    echo "$findings"
}
```

**ステップ3:** メイン実行フローに統合

```bash
# execute_security_review() 関数内に追加

ldap_findings=$(check_ldap_injection "$DIFF_CONTENT" "$TEMP_FINDINGS")
total_findings=$((total_findings + ldap_findings))
```

**ステップ4:** CVSS スコアリングの追加（オプション）

```bash
# CVSS v3.1スコア計算関数

calculate_cvss_score() {
    local cwe_id="$1"
    local context="$2"

    # CWE-90の場合
    if [ "$cwe_id" = "CWE-90" ]; then
        # Attack Vector: Network (AV:N = 0.85)
        # Attack Complexity: Low (AC:L = 0.77)
        # Privileges Required: Low (PR:L = 0.62)
        # User Interaction: None (UI:N = 0.85)
        # Scope: Unchanged (S:U)
        # Confidentiality: High (C:H = 0.56)
        # Integrity: High (I:H = 0.56)
        # Availability: None (A:N = 0)

        # Base Score = 8.2
        echo "8.2"
    fi
}
```

### セキュリティルールのテスト

```bash
# tests/unit/test-security-rules.bats

@test "LDAP Injection detection - positive case" {
    # テスト用コード
    local test_code='ldapsearch -x -b "dc=example,dc=com" "uid=$user_input"'

    # チェック実行
    run check_ldap_injection "$test_code" "/tmp/findings.json"

    # 検出されることを確認
    [ "$output" -eq 1 ]
}

@test "LDAP Injection detection - negative case" {
    # 安全なコード
    local test_code='ldapsearch -x -b "dc=example,dc=com" "uid=fixed_value"'

    # チェック実行
    run check_ldap_injection "$test_code" "/tmp/findings.json"

    # 検出されないことを確認
    [ "$output" -eq 0 ]
}
```

## VibeLogger統合の詳細

### VibeLoggerアーキテクチャ

VibeLoggerは、AI最適化された構造化ロギングシステムです。以下の特徴があります：

- **AI Context Awareness**: すべてのログエントリにAIコンテキスト情報を含む
- **Human-Readable Notes**: 人間が理解しやすいメモを付与
- **Todo Tracking**: AIが実行すべきアクションを記録
- **JSONL Format**: ストリーミング処理に適したフォーマット

### VibeLogger関数のカスタマイズ

#### 基本ログ関数の拡張

```bash
# bin/vibe-logger-lib.sh を参考に拡張

vibe_review_metric() {
    local metric_name="$1"
    local metric_value="$2"
    local metric_unit="$3"
    local human_note="$4"

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local runid="claude_review_$(date +%s)_$$"

    cat >> "$VIBE_LOG_DIR/claude_review_metrics_$(date +%H).jsonl" << EOF
{
  "timestamp": "$timestamp",
  "runid": "$runid",
  "event": "performance_metric",
  "metric": {
    "name": "$metric_name",
    "value": $metric_value,
    "unit": "$metric_unit"
  },
  "human_note": "$human_note",
  "ai_context": {
    "tool": "Claude",
    "integration": "Multi-AI",
    "analysis_type": "performance"
  }
}
EOF
}
```

#### 使用例

```bash
# レビュー実行時のメトリクス記録

start_time=$(get_timestamp_ms)

# レビュー実行
execute_claude_review

end_time=$(get_timestamp_ms)
duration=$((end_time - start_time))

# メトリクス記録
vibe_review_metric "review_duration" "$duration" "ms" \
    "Code review completed in ${duration}ms"

vibe_review_metric "issues_found" "$total_issues" "count" \
    "Total of $total_issues issues detected"
```

### カスタムイベントタイプの追加

```bash
# 新しいイベントタイプ: AI Collaboration

vibe_ai_collaboration() {
    local ai_tool="$1"
    local collaboration_type="$2"
    local metadata="$3"
    local human_note="$4"

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local runid="ai_collab_$(date +%s)_$$"

    cat >> "$VIBE_LOG_DIR/ai_collaboration_$(date +%H).jsonl" << EOF
{
  "timestamp": "$timestamp",
  "runid": "$runid",
  "event": "ai_collaboration",
  "collaboration": {
    "tool": "$ai_tool",
    "type": "$collaboration_type",
    "metadata": $metadata
  },
  "human_note": "$human_note",
  "ai_context": {
    "integration": "Multi-AI",
    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"]
  }
}
EOF
}
```

### ログ分析ツールの開発

```bash
# scripts/analyze-vibe-logs.sh

#!/bin/bash

analyze_review_logs() {
    local log_dir="$1"

    # 全レビューログを集計
    jq -s '
    {
        total_reviews: length,
        avg_duration_ms: ([.[].metadata.duration_ms] | add / length),
        total_issues: ([.[].metadata.issues_found] | add),
        success_rate: (([.[].metadata.status == "success"] | length) / length * 100)
    }
    ' "$log_dir"/claude_review_*.jsonl
}

# 使用例
analyze_review_logs "logs/ai-coop/$(date +%Y%m%d)"
```

## テスト開発ガイド

### ユニットテストの作成

```bash
# tests/unit/test-claude-review.bats

#!/usr/bin/env bats

# テストセットアップ
setup() {
    # テスト環境の初期化
    export CLAUDE_REVIEW_TIMEOUT=60
    export OUTPUT_DIR="/tmp/test-reviews"
    mkdir -p "$OUTPUT_DIR"
}

# テストクリーンアップ
teardown() {
    rm -rf "$OUTPUT_DIR"
}

@test "check_prerequisites succeeds with git and claude" {
    # モック関数
    which() {
        case "$1" in
            git|claude) echo "/usr/bin/$1" ;;
            *) return 1 ;;
        esac
    }
    export -f which

    # テスト実行
    source scripts/claude-review.sh
    run check_prerequisites

    # 検証
    [ "$status" -eq 0 ]
}

@test "parse_args handles custom timeout" {
    source scripts/claude-review.sh

    parse_args --timeout 900

    [ "$CLAUDE_REVIEW_TIMEOUT" -eq 900 ]
}
```

### 統合テストの作成

```bash
# tests/integration/test-claude-review-integration.sh

#!/bin/bash

test_full_review_workflow() {
    # テストリポジトリのセットアップ
    local test_repo="/tmp/test-repo"
    git init "$test_repo"
    cd "$test_repo"

    # テストファイルの作成
    cat > test.sh << 'EOF'
#!/bin/bash
echo $UNSAFE_VAR
EOF

    git add test.sh
    git commit -m "Test commit"

    # レビュー実行
    bash ../scripts/claude-review.sh --commit HEAD

    # レポート生成確認
    [ -f "logs/claude-reviews/latest_claude.json" ]
    [ -f "logs/claude-reviews/latest_claude.md" ]

    # クリーンアップ
    cd ..
    rm -rf "$test_repo"
}

# テスト実行
test_full_review_workflow
```

## ベストプラクティス

### 1. エラーハンドリング

```bash
# 適切なエラーハンドリング

execute_safe_review() {
    local commit="$1"

    # トラップ設定
    trap 'cleanup_on_error' ERR EXIT

    # 前提条件チェック
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        return 1
    fi

    # レビュー実行（タイムアウト付き）
    if ! timeout "$CLAUDE_REVIEW_TIMEOUT" claude_review "$commit"; then
        log_error "Review timed out or failed"
        return 1
    fi

    return 0
}

cleanup_on_error() {
    local exit_code=$?

    if [ $exit_code -ne 0 ]; then
        log_error "Error occurred with exit code: $exit_code"

        # VibeLoggerにエラー記録
        vibe_log "error" "review_failed" \
            "{\"exit_code\": $exit_code}" \
            "Review failed unexpectedly" \
            "Investigate error logs"
    fi
}
```

### 2. パフォーマンス最適化

```bash
# 大規模diffの処理

process_large_diff() {
    local commit="$1"
    local max_diff_size=1048576  # 1MB

    # diffサイズの確認
    local diff_size=$(git show "$commit" | wc -c)

    if [ "$diff_size" -gt "$max_diff_size" ]; then
        log_warning "Large diff detected ($diff_size bytes), using incremental processing"

        # ファイル単位で処理
        git show --name-only "$commit" | while read -r file; do
            git show "$commit" -- "$file" | claude_review_incremental
        done
    else
        # 通常処理
        git show "$commit" | claude_review
    fi
}
```

### 3. セキュリティ考慮事項

```bash
# 安全な一時ファイル処理

create_secure_tempfile() {
    local temp_file=$(mktemp)

    # 権限を所有者のみに制限
    chmod 600 "$temp_file"

    # クリーンアップトラップ
    trap "rm -f '$temp_file'" EXIT

    echo "$temp_file"
}

# 入力サニタイゼーション

sanitize_commit_hash() {
    local commit="$1"

    # 40文字のhex文字列のみ許可
    if ! echo "$commit" | grep -qE '^[0-9a-f]{40}$'; then
        log_error "Invalid commit hash format"
        return 1
    fi

    echo "$commit"
}
```

### 4. ドキュメント生成の自動化

```bash
# スクリプトからドキュメントを自動生成

generate_api_docs() {
    local script_file="$1"
    local output_file="$2"

    cat > "$output_file" << 'EOF'
# API Documentation

## Functions
EOF

    # 関数定義を抽出してドキュメント化
    grep -E '^[a-z_]+\(\)' "$script_file" | while read -r func; do
        func_name=$(echo "$func" | sed 's/()//')

        # 関数コメントを抽出
        func_doc=$(sed -n "/^${func_name}()/,/^}/p" "$script_file" | \
                   grep -E '^[[:space:]]*#' | sed 's/^[[:space:]]*# *//')

        cat >> "$output_file" << EOF

### $func_name()

$func_doc

EOF
    done
}
```

---

**ドキュメントバージョン:** 1.0.0
**最終更新日:** 2025-10-25
**対象スクリプトバージョン:** claude-review.sh v1.0.0, claude-security-review.sh v1.0.0
