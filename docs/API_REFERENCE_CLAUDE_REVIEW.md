# Claude Review CLI Scripts - API Reference

**Version**: 1.0.0
**Last Updated**: 2025-10-25
**Status**: Complete

## 目次

1. [概要](#概要)
2. [スクリプト入出力仕様](#スクリプト入出力仕様)
3. [環境変数リファレンス](#環境変数リファレンス)
4. [エラーコード一覧](#エラーコード一覧)
5. [出力フォーマット仕様](#出力フォーマット仕様)
6. [VibeLogger統合仕様](#vibelogger統合仕様)
7. [セキュリティルールマッピング](#セキュリティルールマッピング)

---

## 概要

Claude Review CLI Scriptsは、Gitコミットに対してコードレビューとセキュリティレビューを実行する2つの独立したスクリプトから構成されます。

### スクリプト一覧

| スクリプト | 目的 | デフォルトタイムアウト | 出力形式 |
|-----------|------|---------------------|---------|
| `claude-review.sh` | 包括的コードレビュー | 600秒 (10分) | JSON, Markdown |
| `claude-security-review.sh` | セキュリティ脆弱性検出 | 900秒 (15分) | JSON, Markdown, SARIF |

---

## スクリプト入出力仕様

### claude-review.sh

#### コマンドライン引数

```bash
bash scripts/claude-review.sh [OPTIONS]
```

| オプション | 短縮形 | 引数 | 必須 | デフォルト | 説明 |
|----------|-------|------|------|----------|------|
| `--timeout` | `-t` | SECONDS | No | 600 | レビュータイムアウト（秒） |
| `--commit` | `-c` | HASH | No | HEAD | レビュー対象のコミットハッシュ |
| `--output` | `-o` | DIR | No | `logs/claude-reviews` | 出力ディレクトリパス |
| `--help` | `-h` | - | No | - | ヘルプメッセージを表示 |

#### 入力仕様

**必須条件**:
- Gitリポジトリ内で実行すること
- 指定されたコミットハッシュが存在すること
- Claude wrapperが利用可能であること（フォールバックあり）

**入力データ**:
```bash
# Gitから自動取得される情報
- git show --no-color <COMMIT_HASH>  # コミットのdiff
- git show --format="%s" -s          # コミットメッセージ
- git show --format="%an <%ae>" -s   # 作成者情報
- git show --format="%ad" -s         # 日付情報
```

#### 出力仕様

**出力ファイル**:
```
logs/claude-reviews/
├── YYYYMMDD_HHMMSS_<commit>_claude.log      # 完全なレビューログ
├── YYYYMMDD_HHMMSS_<commit>_claude.json     # JSON形式レポート
├── YYYYMMDD_HHMMSS_<commit>_claude.md       # Markdown形式レポート
├── latest_claude.json -> (上記JSONへのシンボリックリンク)
└── latest_claude.md   -> (上記Markdownへのシンボリックリンク)
```

**JSON出力フォーマット**:
```json
{
  "timestamp": "2025-10-25T12:00:00Z",
  "commit": "abc123...",
  "commit_short": "abc123",
  "review_duration_sec": 0,
  "status": "completed",
  "analysis": {
    "critical_issues": 2,
    "warnings": 5
  },
  "log_file": "/path/to/log/file"
}
```

**Markdown出力フォーマット**:
```markdown
# Claude Code Review Report

**Commit**: `abc123` (`abc123...`)
**Date**: 2025-10-25 12:00:00
**Timeout**: 600s

## Summary

- **Critical Issues**: 2
- **Warnings**: 5

## Analysis

### 🔴 Critical Issues
[検出されたクリティカルな問題のリスト]

### ⚠️ Warnings
[検出された警告のリスト]

## Full Log
See: `/path/to/log/file`
```

#### 実行フロー

```
1. 前提条件チェック
   ├─ Gitリポジトリ確認
   ├─ コミット存在確認
   └─ Claude wrapper利用可否確認

2. レビュー実行
   ├─ Claude利用可能 → execute_claude_review()
   │   ├─ diff取得
   │   ├─ プロンプト生成
   │   ├─ Claude wrapper実行 (timeout: CLAUDE_REVIEW_TIMEOUT)
   │   └─ 結果パース
   └─ Claude利用不可 → execute_alternative_review()
       ├─ パターンベース解析
       ├─ 他のAI (gemini/qwen/codex/cursor) で補完
       └─ 結果生成

3. 出力生成
   ├─ JSON形式レポート
   ├─ Markdown形式レポート
   └─ シンボリックリンク作成

4. VibeLogger記録
   ├─ tool.start (レビュー開始)
   ├─ tool.done (レビュー完了)
   └─ summary.done (サマリー生成)
```

---

### claude-security-review.sh

#### コマンドライン引数

```bash
bash scripts/claude-security-review.sh [OPTIONS]
```

| オプション | 短縮形 | 引数 | 必須 | デフォルト | 説明 |
|----------|-------|------|------|----------|------|
| `--timeout` | `-t` | SECONDS | No | 900 | レビュータイムアウト（秒） |
| `--commit` | `-c` | HASH | No | HEAD | レビュー対象のコミットハッシュ |
| `--output` | `-o` | DIR | No | `logs/claude-security-reviews` | 出力ディレクトリパス |
| `--severity` | `-s` | LEVEL | No | Low | 最小重要度レベル (Critical/High/Medium/Low) |
| `--help` | `-h` | - | No | - | ヘルプメッセージを表示 |

#### 入力仕様

**必須条件**:
- Gitリポジトリ内で実行すること
- 指定されたコミットハッシュが存在すること
- セキュリティルール定義が有効であること

**セキュリティチェック対象**:
1. SQL Injection (CWE-89)
2. Cross-Site Scripting (CWE-79)
3. Command Injection (CWE-77, CWE-78)
4. Path Traversal (CWE-22)
5. Hardcoded Secrets (CWE-798)
6. Insecure Cryptography (CWE-327)
7. Unsafe Deserialization (CWE-502)

#### 出力仕様

**出力ファイル**:
```
logs/claude-security-reviews/
├── YYYYMMDD_HHMMSS_<commit>_security.log         # 完全なレビューログ
├── YYYYMMDD_HHMMSS_<commit>_security.json        # JSON形式レポート
├── YYYYMMDD_HHMMSS_<commit>_security.md          # Markdown形式レポート
├── YYYYMMDD_HHMMSS_<commit>_security.sarif       # SARIF形式レポート
├── latest_security.json  -> (上記JSONへのシンボリックリンク)
├── latest_security.md    -> (上記Markdownへのシンボリックリンク)
└── latest_security.sarif -> (上記SARIFへのシンボリックリンク)
```

**JSON出力フォーマット**:
```json
{
  "timestamp": "2025-10-25T12:00:00Z",
  "commit": "abc123...",
  "commit_short": "abc123",
  "scan_type": "security",
  "min_severity": "Low",
  "total_vulnerabilities": 3,
  "log_file": "/path/to/log/file"
}
```

**SARIF出力フォーマット**:
```json
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "Claude Security Review",
          "version": "1.0.0",
          "informationUri": "https://claude.com"
        }
      },
      "results": []
    }
  ]
}
```

#### 実行フロー

```
1. 前提条件チェック
   ├─ Gitリポジトリ確認
   ├─ コミット存在確認
   └─ Claude wrapper利用可否確認

2. セキュリティレビュー実行
   ├─ Claude利用可能 → execute_claude_security_review()
   │   ├─ diff取得
   │   ├─ セキュリティプロンプト生成 (OWASP Top 10焦点)
   │   ├─ Claude wrapper実行 (timeout: SECURITY_REVIEW_TIMEOUT)
   │   └─ 脆弱性カウント
   └─ Claude利用不可 → execute_pattern_security_review()
       ├─ パターンベースセキュリティチェック
       ├─ check_security_patterns() 実行
       └─ 脆弱性カウント

3. 出力生成
   ├─ JSON形式レポート
   ├─ Markdown形式レポート
   ├─ SARIF形式レポート (IDE統合用)
   └─ シンボリックリンク作成

4. VibeLogger記録
   ├─ security.start (スキャン開始)
   ├─ security.vulnerability (脆弱性検出時)
   └─ security.done (スキャン完了)
```

---

## 環境変数リファレンス

### 共通環境変数

| 変数名 | デフォルト値 | 説明 | 使用スクリプト |
|-------|------------|------|--------------|
| `OUTPUT_DIR` | `logs/claude-reviews` または `logs/claude-security-reviews` | 出力ディレクトリのベースパス | 両方 |
| `COMMIT_HASH` | `HEAD` | レビュー対象のコミットハッシュ | 両方 |

### claude-review.sh 固有

| 変数名 | デフォルト値 | 説明 | 範囲 |
|-------|------------|------|------|
| `CLAUDE_REVIEW_TIMEOUT` | `600` | レビュータイムアウト（秒） | 60-3600 |

### claude-security-review.sh 固有

| 変数名 | デフォルト値 | 説明 | 範囲 |
|-------|------------|------|------|
| `SECURITY_REVIEW_TIMEOUT` | `900` | セキュリティレビュータイムアウト（秒） | 60-3600 |
| `MIN_SEVERITY` | `Low` | 最小重要度レベル | Critical, High, Medium, Low |

### VibeLogger 環境変数

| 変数名 | デフォルト値 | 説明 |
|-------|------------|------|
| `VIBE_LOG_DIR` | `logs/ai-coop/YYYYMMDD` | VibeLoggerログの出力ディレクトリ |

### 内部変数（上書き非推奨）

| 変数名 | デフォルト値 | 説明 |
|-------|------------|------|
| `SCRIPT_DIR` | `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)` | スクリプトディレクトリパス |
| `PROJECT_ROOT` | `$(dirname "$SCRIPT_DIR")` | プロジェクトルートディレクトリ |
| `USE_CLAUDE` | auto-detected | Claude wrapper利用可否フラグ |

### 環境変数の優先順位

```
1. コマンドライン引数（最優先）
   例: --timeout 1200

2. 環境変数
   例: export CLAUDE_REVIEW_TIMEOUT=1200

3. デフォルト値（最低優先）
   例: CLAUDE_REVIEW_TIMEOUT=${CLAUDE_REVIEW_TIMEOUT:-600}
```

### 使用例

```bash
# 環境変数で設定
export CLAUDE_REVIEW_TIMEOUT=900
export OUTPUT_DIR=/tmp/my-reviews
bash scripts/claude-review.sh

# コマンドライン引数で一時的に上書き
bash scripts/claude-review.sh --timeout 1200 --output /custom/path

# 環境変数とコマンドライン引数の組み合わせ
export COMMIT_HASH=abc123
bash scripts/claude-review.sh --timeout 900  # COMMIT_HASH=abc123, timeout=900
```

---

## エラーコード一覧

### 終了コード (Exit Codes)

| コード | 意味 | 発生条件 | 対処方法 |
|-------|------|---------|---------|
| `0` | 正常終了 | レビュー成功 | - |
| `1` | 一般エラー | - Gitリポジトリではない<br>- コミットが見つからない<br>- 不明なオプション | エラーメッセージを確認し、前提条件を満たす |
| `124` | タイムアウト | `timeout` コマンドによる強制終了 | タイムアウト値を増やす (`--timeout`) |
| `>0` | AI実行エラー | - Claude wrapper実行失敗<br>- AI応答エラー | ログファイルを確認し、AI接続を確認 |

### エラーメッセージ分類

#### クリティカルエラー（実行中断）

```bash
log_error "Not in a git repository"
# 原因: Gitリポジトリ外で実行
# 対処: cd でGitリポジトリに移動

log_error "Commit not found: $COMMIT_HASH"
# 原因: 指定されたコミットハッシュが存在しない
# 対処: git log で有効なコミットハッシュを確認

log_error "Unknown option: $1"
# 原因: 無効なコマンドライン引数
# 対処: --help でオプションを確認
```

#### 警告（実行継続）

```bash
log_warning "Claude wrapper not found, using alternative implementation"
# 原因: bin/claude-wrapper.sh が実行可能ではない
# 影響: パターンベース解析または他のAIにフォールバック

log_warning "Claude review failed or returned empty results, falling back to alternative implementation"
# 原因: Claude実行タイムアウトまたは空の結果
# 影響: execute_alternative_review() にフォールバック
```

#### 情報メッセージ

```bash
log_info "Checking prerequisites..."
log_success "Prerequisites check passed"
log_success "Output directory: $OUTPUT_DIR"
log_info "Claude review completed successfully"
```

### エラーハンドリングフロー

```bash
# claude-review.sh のエラーハンドリング例
main() {
    parse_args "$@" || exit 1           # 引数パースエラー → exit 1
    check_prerequisites || exit 1        # 前提条件エラー → exit 1

    if [[ "$USE_CLAUDE" == "true" ]]; then
        result=$(execute_claude_review 2>/dev/null || echo "")
        if [ -f "$log_file" ] && [ -s "$log_file" ]; then
            # 成功 → 通常処理
        else
            # 失敗 → フォールバック
            log_warning "Claude review failed, falling back..."
            result=$(execute_alternative_review)
        fi
    fi

    exit $status  # AI実行の終了コードを返す
}
```

### トラブルシューティング

| エラー | 原因 | 解決方法 |
|-------|------|---------|
| `bash: scripts/claude-review.sh: Permission denied` | 実行権限なし | `chmod +x scripts/claude-review.sh` |
| `timeout: killed` | タイムアウト超過 | `--timeout 1200` で延長 |
| `No diff available for commit` | コミットが空またはマージコミット | 別のコミットを指定 |
| Empty output files | AI応答なし | Claude wrapper接続確認、ログ確認 |

---

## 出力フォーマット仕様

### JSON形式レポート

#### claude-review.sh JSON

**ファイル名**: `YYYYMMDD_HHMMSS_<commit>_claude.json`

**スキーマ**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "timestamp": {
      "type": "string",
      "format": "date-time",
      "description": "ISO 8601形式のタイムスタンプ"
    },
    "commit": {
      "type": "string",
      "description": "完全なコミットハッシュ"
    },
    "commit_short": {
      "type": "string",
      "description": "短縮コミットハッシュ (7文字)"
    },
    "review_duration_sec": {
      "type": "number",
      "description": "レビュー実行時間（秒）"
    },
    "status": {
      "type": "string",
      "enum": ["completed", "failed", "timeout"],
      "description": "レビューステータス"
    },
    "analysis": {
      "type": "object",
      "properties": {
        "critical_issues": {
          "type": "number",
          "description": "クリティカルな問題の数"
        },
        "warnings": {
          "type": "number",
          "description": "警告の数"
        }
      }
    },
    "log_file": {
      "type": "string",
      "description": "完全なログファイルパス"
    }
  },
  "required": ["timestamp", "commit", "status"]
}
```

#### claude-security-review.sh JSON

**ファイル名**: `YYYYMMDD_HHMMSS_<commit>_security.json`

**スキーマ**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "timestamp": {
      "type": "string",
      "format": "date-time"
    },
    "commit": {
      "type": "string"
    },
    "commit_short": {
      "type": "string"
    },
    "scan_type": {
      "type": "string",
      "const": "security"
    },
    "min_severity": {
      "type": "string",
      "enum": ["Critical", "High", "Medium", "Low"]
    },
    "total_vulnerabilities": {
      "type": "number",
      "description": "検出された脆弱性の総数"
    },
    "log_file": {
      "type": "string"
    }
  },
  "required": ["timestamp", "commit", "scan_type", "total_vulnerabilities"]
}
```

### Markdown形式レポート

#### claude-review.sh Markdown

**構造**:
```markdown
# Claude Code Review Report

## メタデータセクション
- Commit ハッシュ
- Date
- Timeout設定

## Summary セクション
- Critical Issues カウント
- Warnings カウント

## Analysis セクション
### 🔴 Critical Issues
(最大20行のクリティカル問題リスト)

### ⚠️ Warnings
(最大20行の警告リスト)

## Full Log セクション
(完全なログファイルへのリンク)
```

#### claude-security-review.sh Markdown

**構造**:
```markdown
# Pattern-Based Security Review Report (または Claude Security Review)

## Commit Information
- Commit ハッシュ
- Date
- Author

## Pattern-Based Security Analysis (パターンベースの場合)
### 🔴 [Vulnerability Type] (CWE-XXX)
- **Matches found**: N
- コード抜粋（最大10行）

## Summary
- Total Vulnerabilities Found
- Scan Type
- Minimum Severity

## Recommendations
1. Review all detected vulnerabilities
2. Apply security best practices
3. ...
```

### SARIF形式レポート (セキュリティレビューのみ)

**ファイル名**: `YYYYMMDD_HHMMSS_<commit>_security.sarif`

**目的**: IDE統合、CI/CD統合

**スキーマ**: [SARIF v2.1.0](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)

**基本構造**:
```json
{
  "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
  "version": "2.1.0",
  "runs": [
    {
      "tool": {
        "driver": {
          "name": "Claude Security Review",
          "version": "1.0.0",
          "informationUri": "https://claude.com"
        }
      },
      "results": []
    }
  ]
}
```

**IDE統合例**:
- Visual Studio Code: [SARIF Viewer Extension](https://marketplace.visualstudio.com/items?itemName=MS-SarifVSCode.sarif-viewer)
- IntelliJ IDEA: SARIF形式のインポート機能
- GitHub: Code Scanning API経由でアップロード

---

## VibeLogger統合仕様

### ログファイル構造

**出力先**: `logs/ai-coop/YYYYMMDD/*.jsonl`

**ファイル命名規則**:
- `claude_review_HH.jsonl` (claude-review.sh)
- `claude_security_HH.jsonl` (claude-security-review.sh)

### ログエントリフォーマット

**基本構造**:
```json
{
  "timestamp": "2025-10-25T12:00:00Z",
  "runid": "claude_review_1729857600_12345",
  "event": "tool.start",
  "action": "claude_review",
  "metadata": {
    "commit": "abc123...",
    "timeout_sec": 600,
    "execution_mode": "claude_review"
  },
  "human_note": "Claudeレビュー実行開始: コミット abc123",
  "ai_context": {
    "tool": "Claude",
    "integration": "Multi-AI",
    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],
    "todo": "analyze_code,detect_issues,suggest_improvements"
  }
}
```

### イベントタイプ一覧

#### claude-review.sh イベント

| イベント | アクション | タイミング | メタデータ |
|---------|----------|----------|----------|
| `tool.start` | `claude_review` | レビュー開始時 | commit, timeout_sec, execution_mode |
| `tool.done` | `claude_review` | レビュー完了時 | status, issues_found, execution_time_ms |
| `summary.done` | `review_summary` | サマリー生成時 | priority, output_files, summary_length |

#### claude-security-review.sh イベント

| イベント | アクション | タイミング | メタデータ |
|---------|----------|----------|----------|
| `security.start` | `security_scan` | スキャン開始時 | commit, timeout_sec, min_severity, security_rules |
| `security.vulnerability` | `found` | 脆弱性検出時 | type, severity, cwe_id, count |
| `security.done` | `security_scan` | スキャン完了時 | status, total_vulnerabilities, execution_time_ms |

### VibeLogger関数リファレンス

#### vibe_log()

**シグネチャ**:
```bash
vibe_log <event_type> <action> <metadata_json> <human_note> [ai_todo]
```

**引数**:
- `event_type`: イベントタイプ (tool.start, tool.done, etc.)
- `action`: アクション名 (claude_review, security_scan, etc.)
- `metadata_json`: JSON形式のメタデータ
- `human_note`: 人間が読めるメモ
- `ai_todo`: (オプション) AI向けのTODOリスト (カンマ区切り)

**例**:
```bash
vibe_log "tool.start" "claude_review" '{"commit":"abc123"}' \
    "Claudeレビュー実行開始" \
    "analyze_code,detect_issues"
```

#### vibe_tool_start()

**シグネチャ**:
```bash
vibe_tool_start <action> <commit_hash> <timeout>
```

**用途**: レビュー開始をログ記録

#### vibe_tool_done()

**シグネチャ**:
```bash
vibe_tool_done <action> <status> <issues_found> <execution_time_ms>
```

**用途**: レビュー完了をログ記録

#### vibe_security_start()

**シグネチャ**:
```bash
vibe_security_start <commit_hash> <timeout>
```

**用途**: セキュリティスキャン開始をログ記録

#### vibe_vulnerability_found()

**シグネチャ**:
```bash
vibe_vulnerability_found <vulnerability_type> <severity> <cwe_id> <count>
```

**用途**: 脆弱性検出をログ記録

#### vibe_security_done()

**シグネチャ**:
```bash
vibe_security_done <status> <total_vulnerabilities> <execution_time_ms>
```

**用途**: セキュリティスキャン完了をログ記録

### ログクエリ例

```bash
# 特定のrunidのログを抽出
cat logs/ai-coop/20251025/claude_review_12.jsonl | jq 'select(.runid == "claude_review_1729857600_12345")'

# エラーが発生したレビューを検索
cat logs/ai-coop/20251025/*.jsonl | jq 'select(.metadata.status == "failed")'

# 脆弱性検出イベントのみ抽出
cat logs/ai-coop/20251025/claude_security_*.jsonl | jq 'select(.event == "security.vulnerability")'

# 実行時間が長いレビューを検索 (> 300秒)
cat logs/ai-coop/20251025/*.jsonl | jq 'select(.metadata.execution_time_ms > 300000)'
```

---

## セキュリティルールマッピング

### OWASP Top 10 マッピング

| OWASP 2021 | CWE ID | セキュリティルールキー | 検出パターン | 重要度 |
|-----------|--------|---------------------|------------|--------|
| A03:2021-Injection | CWE-89 | `sql_injection` | `exec.*sql\|query.*\$\|SELECT.*FROM` | Critical |
| A03:2021-Injection | CWE-77, CWE-78 | `command_injection` | `exec\(\|system\(\|popen\(` | Critical |
| A03:2021-Injection | CWE-79 | `xss` | `innerHTML\|document\.write\|eval\(` | High |
| A01:2021-Broken Access Control | CWE-22 | `path_traversal` | `\.\./\|\.\.\\\\` | High |
| A02:2021-Cryptographic Failures | CWE-798 | `hardcoded_secrets` | `password\s*=\s*['"]\|api_key\s*=\s*['"]` | Critical |
| A02:2021-Cryptographic Failures | CWE-327 | `insecure_crypto` | `MD5\|SHA1(?!256)\|DES\|RC4` | High |
| A08:2021-Software and Data Integrity Failures | CWE-502 | `unsafe_deserialization` | `unserialize\|pickle\.loads\|yaml\.load(?!_safe)` | High |

### CWE IDリファレンス

#### CWE-89: SQL Injection

**説明**: SQLクエリに外部入力を直接埋め込むことによる脆弱性

**検出パターン**:
```regex
exec.*sql|query.*\$|SELECT.*FROM|INSERT.*INTO|UPDATE.*SET|DELETE.*FROM
```

**検出例**:
```python
# 脆弱なコード
query = f"SELECT * FROM users WHERE id = {user_id}"  # ❌

# 安全なコード
query = "SELECT * FROM users WHERE id = ?"
cursor.execute(query, (user_id,))  # ✅
```

**CVSS v3.1 ベーススコア**: 9.8 (Critical)

#### CWE-79: Cross-Site Scripting (XSS)

**説明**: Webページに悪意あるスクリプトを注入する脆弱性

**検出パターン**:
```regex
innerHTML|document\.write|eval\(|dangerouslySetInnerHTML
```

**検出例**:
```javascript
// 脆弱なコード
element.innerHTML = userInput;  // ❌

// 安全なコード
element.textContent = userInput;  // ✅
```

**CVSS v3.1 ベーススコア**: 6.1 (Medium)

#### CWE-77/78: Command Injection

**説明**: OSコマンドに外部入力を直接埋め込むことによる脆弱性

**検出パターン**:
```regex
exec\(|system\(|popen\(|shell_exec|passthru
```

**検出例**:
```bash
# 脆弱なコード
system("cat $filename");  # ❌

# 安全なコード
cat "$filename"  # 変数をクォートで囲む ✅
```

**CVSS v3.1 ベーススコア**: 9.8 (Critical)

#### CWE-22: Path Traversal

**説明**: ファイルパスに `../` を含めることでディレクトリ外にアクセスする脆弱性

**検出パターン**:
```regex
\.\./|\.\.\\\\|readFile.*\$|open.*\$
```

**検出例**:
```python
# 脆弱なコード
file_path = f"/var/www/{user_input}"  # ❌
open(file_path)

# 安全なコード
import os
base_dir = "/var/www/"
file_path = os.path.join(base_dir, os.path.basename(user_input))  # ✅
```

**CVSS v3.1 ベーススコア**: 7.5 (High)

#### CWE-798: Hardcoded Credentials

**説明**: パスワードやAPIキーをソースコードに直接埋め込む脆弱性

**検出パターン**:
```regex
password\s*=\s*['"]|api_key\s*=\s*['"]|secret\s*=\s*['"]|token\s*=\s*['"]
```

**検出例**:
```python
# 脆弱なコード
password = "admin123"  # ❌

# 安全なコード
import os
password = os.environ.get("PASSWORD")  # ✅
```

**CVSS v3.1 ベーススコア**: 9.8 (Critical)

#### CWE-327: Insecure Cryptography

**説明**: 脆弱な暗号化アルゴリズムの使用

**検出パターン**:
```regex
MD5|SHA1(?!256)|DES|RC4
```

**検出例**:
```python
# 脆弱なコード
import hashlib
hashlib.md5(data)  # ❌

# 安全なコード
hashlib.sha256(data)  # ✅
```

**CVSS v3.1 ベーススコア**: 7.5 (High)

#### CWE-502: Unsafe Deserialization

**説明**: 信頼できないデータのデシリアライゼーション

**検出パターン**:
```regex
unserialize|pickle\.loads|yaml\.load(?!_safe)|eval
```

**検出例**:
```python
# 脆弱なコード
import pickle
data = pickle.loads(user_input)  # ❌

# 安全なコード
import yaml
data = yaml.safe_load(user_input)  # ✅
```

**CVSS v3.1 ベーススコア**: 9.8 (Critical)

### カスタムルール定義方法

セキュリティルールは `SECURITY_RULES` 連想配列で定義されています。

**フォーマット**:
```bash
SECURITY_RULES[rule_key]="CWE-ID|Description|regex_pattern"
```

**新しいルールの追加例**:
```bash
# LDAP Injection検出ルールの追加
SECURITY_RULES[ldap_injection]="CWE-90|LDAP Injection|ldapsearch.*\$|ldap_bind.*\$|ldap_search.*\$"

# XXE (XML External Entity) 検出ルールの追加
SECURITY_RULES[xxe]="CWE-611|XML External Entity|<!ENTITY|SYSTEM|PUBLIC"

# Server-Side Request Forgery検出ルールの追加
SECURITY_RULES[ssrf]="CWE-918|Server-Side Request Forgery|requests\.get.*\$|urllib\.request.*\$|file_get_contents.*\$"
```

### 重要度レベル定義

| レベル | CVSS v3.1スコア | 対応優先度 | 例 |
|-------|----------------|-----------|-----|
| **Critical** | 9.0 - 10.0 | 即座に対応 | SQL Injection, Command Injection, Hardcoded Secrets |
| **High** | 7.0 - 8.9 | 24時間以内 | XSS, Path Traversal, Insecure Crypto |
| **Medium** | 4.0 - 6.9 | 1週間以内 | Information Disclosure, Weak Password Policy |
| **Low** | 0.1 - 3.9 | 次回リリース時 | Minor Configuration Issues |

### セキュリティレビュー戦略

```
1. Critical/High脆弱性の即座の修正
   ├─ SQL Injection → パラメータ化クエリへ移行
   ├─ Command Injection → 入力検証 + エスケープ
   └─ Hardcoded Secrets → 環境変数へ移行

2. Medium脆弱性の計画的修正
   ├─ 次回スプリントで優先対応
   └─ セキュリティベストプラクティスへの準拠

3. Low脆弱性の長期的改善
   ├─ 技術的負債として管理
   └─ 次期メジャーバージョンで対応
```

---

## 付録

### A. プロンプトテンプレート

#### claude-review.sh プロンプト

```
Please perform a comprehensive code review of the following commit:

Commit: {COMMIT_HASH} ({COMMIT_MESSAGE})
Author: {AUTHOR_NAME} <{AUTHOR_EMAIL}>
Date: {COMMIT_DATE}

Changes:
{DIFF_CONTENT}

Please analyze:
1. Code quality and best practices
2. Potential bugs or issues
3. Security vulnerabilities
4. Performance implications
5. Maintainability concerns
6. Testing suggestions

Provide specific, actionable feedback with line numbers where applicable.
```

#### claude-security-review.sh プロンプト

```
Please perform a comprehensive security review of the following commit focusing on OWASP Top 10 and CWE vulnerabilities:

Commit: {COMMIT_HASH} ({COMMIT_MESSAGE})
Author: {AUTHOR_NAME} <{AUTHOR_EMAIL}>
Date: {COMMIT_DATE}

Security Focus Areas:
1. SQL Injection (CWE-89)
2. Cross-Site Scripting (CWE-79)
3. Command Injection (CWE-77, CWE-78)
4. Path Traversal (CWE-22)
5. Hardcoded Secrets (CWE-798)
6. Insecure Cryptography (CWE-327)
7. Unsafe Deserialization (CWE-502)
8. Authentication & Authorization issues
9. Insecure Direct Object References
10. Security Misconfiguration

Changes:
{DIFF_CONTENT}

For each vulnerability found, provide:
- Vulnerability type and CWE ID
- Severity level (Critical/High/Medium/Low)
- Specific code location
- Detailed explanation
- Remediation suggestions with code examples
- CVSS v3.1 score if applicable
```

### B. IDE統合例

#### Visual Studio Code

**設定**: `.vscode/tasks.json`
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Claude Code Review",
      "type": "shell",
      "command": "bash scripts/claude-review.sh --commit HEAD",
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    },
    {
      "label": "Claude Security Review",
      "type": "shell",
      "command": "bash scripts/claude-security-review.sh --commit HEAD --severity High",
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    }
  ]
}
```

**使用方法**: `Ctrl+Shift+P` → "Tasks: Run Task" → "Claude Code Review"

#### Git Hooks統合

**設定**: `.git/hooks/pre-commit`
```bash
#!/bin/bash
# Claudeセキュリティレビューを自動実行

echo "Running security review..."
if ! bash scripts/claude-security-review.sh --severity Critical; then
    echo "❌ Critical security issues found. Commit aborted."
    exit 1
fi

echo "✅ Security review passed."
exit 0
```

**有効化**:
```bash
chmod +x .git/hooks/pre-commit
```

### C. CI/CD統合例

#### GitHub Actions

**設定**: `.github/workflows/code-review.yml`
```yaml
name: Claude Code Review

on:
  pull_request:
    branches: [ main ]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Run Claude Review
        run: |
          bash scripts/claude-review.sh --commit ${{ github.event.pull_request.head.sha }}

      - name: Run Security Review
        run: |
          bash scripts/claude-security-review.sh --commit ${{ github.event.pull_request.head.sha }} --severity High

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: logs/claude-security-reviews/latest_security.sarif
```

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-25
**Maintained By**: Multi-AI Orchestrium Team
