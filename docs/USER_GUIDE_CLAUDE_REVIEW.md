# Claude Review CLIスクリプト - ユーザーガイド

## 目次

1. [概要](#概要)
2. [CLIスクリプト使用ガイド](#cliスクリプト使用ガイド)
3. [レビュー結果の読み方](#レビュー結果の読み方)
4. [セキュリティレビューの解釈方法](#セキュリティレビューの解釈方法)
5. [トラブルシューティング](#トラブルシューティング)

## 概要

Multi-AI Orchestriumプロジェクトには、Claude Code MCPを活用した2つのコードレビューCLIスクリプトが含まれています：

- **claude-review.sh**: 包括的なコードレビュー（品質、設計、パフォーマンス）
- **claude-security-review.sh**: セキュリティ脆弱性検出に特化したレビュー

これらのスクリプトは、Multi-AI統合とVibeLogger構造化ロギングを備えた、スタンドアロンで実行可能なCLIツールです。

**注意:** Claude Codeには標準で `/review` と `/security` スラッシュコマンドが既に用意されているため、本プロジェクトではCLIスクリプトのみを提供し、カスタムスラッシュコマンドは作成しません。

## CLIスクリプト使用ガイド

### claude-review.sh - 包括的コードレビュー

#### 基本的な使い方

```bash
# 最新コミットをレビュー（デフォルト）
bash scripts/claude-review.sh

# 特定のコミットをレビュー
bash scripts/claude-review.sh --commit abc123

# カスタムタイムアウトを指定（秒単位）
bash scripts/claude-review.sh --timeout 900

# カスタム出力ディレクトリを指定
bash scripts/claude-review.sh --output /custom/path

# ヘルプメッセージを表示
bash scripts/claude-review.sh --help
```

#### コマンドラインオプション

| オプション | 短縮形 | 説明 | デフォルト |
|----------|--------|------|-----------|
| `--timeout SECONDS` | `-t` | レビュータイムアウト（秒） | 600秒（10分） |
| `--commit HASH` | `-c` | レビュー対象のコミットハッシュ | HEAD |
| `--output DIR` | `-o` | 出力ディレクトリ | logs/claude-reviews |
| `--help` | `-h` | ヘルプメッセージ表示 | - |

#### 環境変数

スクリプトは以下の環境変数をサポートしています：

```bash
# タイムアウトのグローバル設定
export CLAUDE_REVIEW_TIMEOUT=900

# 出力ディレクトリのグローバル設定
export OUTPUT_DIR=/custom/output

# コミットハッシュの設定
export COMMIT_HASH=abc123

# スクリプト実行
bash scripts/claude-review.sh
```

#### レビュー対象

claude-review.shは以下の観点でコードをレビューします：

1. **コード品質**
   - 可読性
   - 保守性
   - コーディング規約の遵守

2. **設計パターン**
   - アーキテクチャの適切性
   - モジュール性
   - 拡張性

3. **パフォーマンス**
   - アルゴリズムの効率
   - リソース使用量
   - ボトルネックの検出

4. **ベストプラクティス**
   - 言語固有の推奨事項
   - フレームワークのベストプラクティス

5. **テストカバレッジ**
   - テストの適切性
   - テスト品質

### claude-security-review.sh - セキュリティ特化レビュー

#### 基本的な使い方

```bash
# 最新コミットをセキュリティレビュー
bash scripts/claude-security-review.sh

# 特定のコミットをレビュー
bash scripts/claude-security-review.sh --commit abc123

# Critical以上の脆弱性のみ表示
bash scripts/claude-security-review.sh --severity Critical

# カスタムタイムアウトを指定
bash scripts/claude-security-review.sh --timeout 1200

# ヘルプメッセージを表示
bash scripts/claude-security-review.sh --help
```

#### コマンドラインオプション

| オプション | 短縮形 | 説明 | デフォルト |
|----------|--------|------|-----------|
| `--timeout SECONDS` | `-t` | レビュータイムアウト（秒） | 900秒（15分） |
| `--commit HASH` | `-c` | レビュー対象のコミットハッシュ | HEAD |
| `--output DIR` | `-o` | 出力ディレクトリ | logs/claude-security-reviews |
| `--severity LEVEL` | `-s` | 最小重要度レベル | Low |
| `--help` | `-h` | ヘルプメッセージ表示 | - |

#### 重要度レベル

| レベル | 説明 | 対応推奨時期 |
|--------|------|-------------|
| **Critical** | 即座に悪用可能な重大な脆弱性 | 即時 |
| **High** | 容易に悪用可能な脆弱性 | 24時間以内 |
| **Medium** | 条件付きで悪用可能な脆弱性 | 1週間以内 |
| **Low** | 悪用困難だが潜在的なリスク | 次回リリース |

#### セキュリティチェック項目（OWASP Top 10 & CWE）

claude-security-review.shは以下の脆弱性をチェックします：

1. **SQLインジェクション** (CWE-89)
2. **クロスサイトスクリプティング (XSS)** (CWE-79)
3. **コマンドインジェクション** (CWE-77, CWE-78)
4. **パストラバーサル** (CWE-22)
5. **ハードコードされた秘密情報** (CWE-798)
6. **不安全な暗号化** (CWE-327)
7. **安全でないデシリアライゼーション** (CWE-502)
8. **XXE (XML External Entity)** (CWE-611)
9. **SSRF (Server-Side Request Forgery)** (CWE-918)
10. **認証バイパス** (CWE-287)

## レビュー結果の読み方

### 出力ファイル形式

各レビュー実行後、以下のファイルが生成されます：

```
logs/claude-reviews/
├── 20251025_123456_abc123_claude.json    # JSON形式レポート
├── 20251025_123456_abc123_claude.md      # Markdown形式レポート
├── latest_claude.json                     # 最新レポートへのシンボリックリンク
└── latest_claude.md                       # 最新レポートへのシンボリックリンク
```

### JSON形式レポート

JSON形式レポートは機械可読で、CI/CDパイプラインやIDEプラグインとの統合に適しています。

**構造例:**

```json
{
  "timestamp": "2025-10-25T12:34:56Z",
  "commit": "abc123",
  "review_type": "comprehensive",
  "summary": {
    "total_issues": 15,
    "by_severity": {
      "critical": 2,
      "high": 5,
      "medium": 6,
      "low": 2
    },
    "by_category": {
      "code_quality": 8,
      "design": 3,
      "performance": 2,
      "best_practices": 2
    }
  },
  "issues": [
    {
      "id": 1,
      "file": "src/example.sh",
      "line": 42,
      "severity": "high",
      "category": "code_quality",
      "message": "Unquoted variable expansion can lead to word splitting",
      "suggestion": "Use \"${variable}\" instead of ${variable}",
      "reference": "https://shellcheck.net/wiki/SC2086"
    }
  ],
  "recommendations": {
    "immediate_actions": ["Fix critical issues in src/example.sh"],
    "follow_up_actions": ["Refactor complex functions", "Improve test coverage"]
  }
}
```

### Markdown形式レポート

Markdown形式レポートは人間が読みやすく、GitHub PRやドキュメントに適しています。

**構造例:**

```markdown
# Claude Code Review Report

**Commit:** abc123
**Date:** 2025-10-25 12:34:56 UTC
**Review Type:** Comprehensive Code Review

## Executive Summary

- **Total Issues:** 15
- **Critical:** 2 | **High:** 5 | **Medium:** 6 | **Low:** 2

## Issues by Category

### Code Quality (8 issues)

#### ❌ Critical: Unquoted variable expansion
- **File:** src/example.sh:42
- **Problem:** `${variable}` is not quoted, can lead to word splitting
- **Suggestion:** Use `"${variable}"` instead
- **Reference:** [ShellCheck SC2086](https://shellcheck.net/wiki/SC2086)

### Design (3 issues)

...

## Recommendations

### Immediate Actions
1. Fix critical issues in src/example.sh
2. Review error handling in main function

### Follow-up Actions
1. Refactor complex functions for better maintainability
2. Improve test coverage to 85%+
```

### レビュー結果の優先順位付け

レビュー結果を効率的に処理するための推奨手順：

1. **Critical/High問題から対処**
   - セキュリティリスク、機能的バグ、パフォーマンスボトルネック

2. **Medium問題を次に対処**
   - コード品質、保守性の問題

3. **Low問題は次回リリースで対処**
   - スタイルガイド違反、軽微な最適化

### VibeLoggerログ

すべてのレビュー実行は、VibeLogger形式で構造化ログとして記録されます：

```
logs/ai-coop/20251025/claude_review_12.jsonl
```

**ログエントリ例:**

```json
{
  "timestamp": "2025-10-25T12:34:56Z",
  "runid": "claude_review_1698234896_12345",
  "event": "tool_execution",
  "action": "claude_review",
  "metadata": {
    "commit": "abc123",
    "timeout_sec": 600,
    "execution_mode": "claude_review"
  },
  "human_note": "Comprehensive code review executed",
  "ai_context": {
    "tool": "Claude",
    "integration": "Multi-AI",
    "ai_team": ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],
    "todo": "Review and apply suggestions"
  }
}
```

## セキュリティレビューの解釈方法

### CVSS v3.1スコアリング

セキュリティレビューでは、各脆弱性にCVSS v3.1スコアが付与されます：

| スコア範囲 | 重要度 | 対応優先度 |
|-----------|--------|----------|
| 9.0 - 10.0 | Critical | P0（即時対応） |
| 7.0 - 8.9 | High | P1（24時間以内） |
| 4.0 - 6.9 | Medium | P2（1週間以内） |
| 0.1 - 3.9 | Low | P3（次回リリース） |

### CWE ID参照

各脆弱性にはCWE IDが付与され、詳細な情報へのリンクが提供されます：

- **CWE-89**: [SQL Injection](https://cwe.mitre.org/data/definitions/89.html)
- **CWE-79**: [Cross-Site Scripting](https://cwe.mitre.org/data/definitions/79.html)
- **CWE-77/78**: [Command Injection](https://cwe.mitre.org/data/definitions/77.html)

### セキュリティレポートの読み方

**JSON形式（セキュリティ特化）:**

```json
{
  "timestamp": "2025-10-25T12:34:56Z",
  "commit": "abc123",
  "review_type": "security",
  "summary": {
    "total_vulnerabilities": 8,
    "by_severity": {
      "critical": 1,
      "high": 3,
      "medium": 3,
      "low": 1
    },
    "owasp_top_10_coverage": ["A03:2021", "A05:2021"]
  },
  "vulnerabilities": [
    {
      "id": 1,
      "cwe_id": "CWE-89",
      "severity": "critical",
      "cvss_score": 9.8,
      "title": "SQL Injection in user query",
      "file": "src/database.sh",
      "line": 75,
      "evidence": "exec \"SELECT * FROM users WHERE id = $user_id\"",
      "impact": "Attacker can execute arbitrary SQL commands",
      "remediation": {
        "description": "Use parameterized queries or prepared statements",
        "code_example": "exec \"SELECT * FROM users WHERE id = ?\" \"$user_id\"",
        "references": [
          "https://owasp.org/www-community/attacks/SQL_Injection",
          "https://cwe.mitre.org/data/definitions/89.html"
        ]
      }
    }
  ]
}
```

### SARIF形式（IDE統合用）

セキュリティレビューは、SARIF (Static Analysis Results Interchange Format) 形式でも出力されます。これにより、VS Code、IntelliJ IDEA、GitHub Code Scanningなどのツールと統合できます：

```
logs/claude-security-reviews/20251025_123456_abc123_security.sarif
```

### セキュリティ脆弱性の修復手順

1. **Critical脆弱性の即時対応**
   ```bash
   # Critical脆弱性のみをフィルタ
   bash scripts/claude-security-review.sh --severity Critical

   # 修復
   # - コード修正
   # - テスト追加
   # - 再レビュー実行

   # 修復確認
   bash scripts/claude-security-review.sh --commit HEAD
   ```

2. **修復提案の適用**
   - レポートの `remediation.code_example` を参考に修正
   - `remediation.references` で詳細なベストプラクティスを確認

3. **修復後の検証**
   ```bash
   # セキュリティレビュー再実行
   bash scripts/claude-security-review.sh

   # 包括的レビューも実行（品質確認）
   bash scripts/claude-review.sh
   ```

## トラブルシューティング

### よくある問題と解決方法

#### 1. Claude MCP接続エラー

**症状:**
```
❌ Claude MCP connection failed
```

**解決方法:**
```bash
# Claude Code MCPの設定確認
which claude

# Claude MCPの再インストール（必要に応じて）
# 公式ドキュメント参照: https://docs.claude.com/

# 環境変数の確認
echo $CLAUDE_API_KEY
```

#### 2. タイムアウト発生

**症状:**
```
❌ Review timed out after 600 seconds
```

**解決方法:**
```bash
# タイムアウトを延長
bash scripts/claude-review.sh --timeout 1200

# または環境変数で設定
export CLAUDE_REVIEW_TIMEOUT=1200
bash scripts/claude-review.sh
```

#### 3. 出力ディレクトリの権限エラー

**症状:**
```
❌ Cannot write to logs/claude-reviews
```

**解決方法:**
```bash
# ディレクトリの権限確認
ls -ld logs/claude-reviews

# 権限修正
chmod 755 logs/claude-reviews

# または別のディレクトリを指定
bash scripts/claude-review.sh --output /tmp/reviews
```

#### 4. 存在しないコミットハッシュ

**症状:**
```
❌ Commit abc123 not found
```

**解決方法:**
```bash
# 有効なコミットハッシュを確認
git log --oneline -10

# 正しいハッシュを指定
bash scripts/claude-review.sh --commit <valid_hash>
```

#### 5. VibeLoggerログが記録されない

**症状:**
ログファイル `logs/ai-coop/YYYYMMDD/claude_review_HH.jsonl` が生成されない

**解決方法:**
```bash
# ログディレクトリの確認
mkdir -p logs/ai-coop/$(date +%Y%m%d)

# 権限確認
chmod 755 logs/ai-coop
chmod 755 logs/ai-coop/$(date +%Y%m%d)

# スクリプト再実行
bash scripts/claude-review.sh
```

### サポートとフィードバック

問題が解決しない場合：

1. **ログの確認**
   ```bash
   # レビューログ
   tail -n 100 logs/ai-coop/$(date +%Y%m%d)/claude_review_*.jsonl

   # エラーログ
   tail -n 100 logs/claude-reviews/latest_claude.json
   ```

2. **GitHub Issueの作成**
   - リポジトリ: `multi-ai-orchestrium`
   - ラベル: `bug`, `claude-review`
   - 添付情報: ログファイル、実行コマンド、エラーメッセージ

3. **詳細ドキュメントの参照**
   - `CLAUDE.md`: プロジェクト全体ガイド
   - `docs/CLAUDE_REVIEW_SLASH_COMMANDS_IMPLEMENTATION_PLAN.md`: 実装計画
   - `README.md`: プロジェクト概要

---

**ドキュメントバージョン:** 1.0.0
**最終更新日:** 2025-10-25
**対象スクリプトバージョン:** claude-review.sh v1.0.0, claude-security-review.sh v1.0.0
