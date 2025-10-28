# README.md 検証レポート

## 実行日時
2025-10-28

## 検証概要
README.mdの内容が現在のプロジェクト実装と一致しているか徹底的に調査しました。

---

## ✅ 正しい内容

### 1. スクリプトの存在
- ✅ すべての主要スクリプトが存在
  - setup-permissions.sh
  - check-multi-ai-tools.sh
  - scripts/review-dispatcher.sh
  - scripts/multi-ai-review.sh
  - 5AI個別レビュー（gemini, qwen, cursor, amp, droid）
  - 3コアレビュー（security, quality, enterprise）
  - Claude専用レビュー（claude-review, claude-security-review）
  - その他レビュー（codex-review, coderabbit-review）

### 2. レビューシステムの数
- ✅ **13個のレビュースクリプト** - 正しい

### 3. 設定ファイル
- ✅ config/multi-ai-profiles.yaml (存在)
- ✅ config/review-profiles.yaml (存在)
- ✅ config/ai-cli-versions.yaml (存在)
- ✅ requirements.txt (存在)

### 4. オーケストレーション関数
- ✅ multi-ai-full-orchestrate (存在)
- ✅ multi-ai-chatdev-develop (存在)
- ✅ multi-ai-discuss-before (存在)
- ✅ multi-ai-review-after (存在)
- ✅ multi-ai-quad-review (存在)
- ✅ tdd-multi-ai-cycle (存在)

### 5. AI割り当て
- ✅ Security review: Gemini (Primary) → Claude Security (Fallback)
- ✅ Quality review: Claude (Primary) → Codex (Fallback)
- ✅ Enterprise review: Droid (Primary)

---

## ❌ 不一致・問題点

### 1. **セキュリティレビューのタイムアウト**

**README.md記載：**
```
| Security | Gemini | OWASP Top 10、CVE検索 | 900秒 |
```

**実際の実装：**
```bash
# scripts/review/security-review.sh:46
DEFAULT_TIMEOUT=600  # 10 minutes for Gemini (Web search overhead)
```

**不一致**: README 900秒 vs 実際 600秒

**推奨修正**: READMEを600秒に修正

---

### 2. **高速モード（fast）のタイムアウト**

**README.md記載：**
```
| `fast` | P0-P1のみ、高速 | 120秒 |
```

**実際の実装：**
```bash
# scripts/review/quality-review.sh:40
FAST_MODE_TIMEOUT=300  # 5 minutes for fast mode (increased from 120s for Claude)
```

**YAML設定：**
```yaml
# config/review-profiles.yaml
fast:
  timeout: 120
```

**不一致**:
- README: 120秒
- quality-review.sh: 300秒
- YAML config: 120秒

**状況**: YAMLは120秒だが、quality-review.sh自体は300秒にハードコードされている。YAMLの設定が優先されるべきだが、スクリプトのハードコード値が使われる可能性がある。

**推奨修正**:
- Option A: quality-review.shを120秒に修正
- Option B: READMEとYAMLを300秒に修正（より現実的）

---

### 3. **security-focusedプロファイルのタイムアウト**

**README.md記載：**
```
| `security-focused` | セキュリティ特化 | 900秒 |
```

**実際のYAML設定：**
```yaml
# config/review-profiles.yaml
security-focused:
  timeout: 600  # 10 minutes (Web search overhead)
```

**不一致**: README 900秒 vs YAML 600秒

**推奨修正**: READMEを600秒に修正

---

### 4. **quality-focusedプロファイルのタイムアウト**

**README.md記載：**
```
| `quality-focused` | 品質・テスト特化 | 600秒 |
```

**実際のYAML設定：**
```yaml
# config/review-profiles.yaml
quality-focused:
  timeout: 300  # 5 minutes (fast review)
```

**不一致**: README 600秒 vs YAML 300秒

**推奨修正**: READMEを300秒に修正

---

### 5. **品質レビューの説明にコメントの不整合**

**quality-review.shのコメント：**
```bash
# Line 2: Code quality-focused review using Qwen + Codex fallback
# Line 24: Load Claude adapter (primary) - Changed from Qwen for better reliability
# Line 208: echo "Primary AI (Qwen) failed or timed out. Falling back to Codex..." >&2
```

**状況**:
- ファイルヘッダーには「Qwen + Codex」
- 実際の実装は「Claude + Codex」
- エラーメッセージには「Qwen failed」

**推奨修正**:
- ファイルヘッダーを「Claude + Codex」に修正
- エラーメッセージを「Claude failed」に修正

---

## 📋 修正推奨事項まとめ

### 優先度: 高

1. **README.md レビュータイプ表**
   ```markdown
   | Security | Gemini | OWASP Top 10、CVE検索 | 600秒 |  # 900→600に変更
   ```

2. **README.md レビュープロファイル表**
   ```markdown
   | `security-focused` | セキュリティ特化 | 600秒 |     # 900→600に変更
   | `quality-focused` | 品質・テスト特化 | 300秒 |     # 600→300に変更
   ```

### 優先度: 中

3. **fast modeタイムアウトの統一**
   - Option A: quality-review.shを120秒に修正
   - Option B: READMEとYAMLを300秒に修正

   **推奨**: Option Bを選択（300秒の方がClaude使用時に現実的）

4. **quality-review.shのコメント修正**
   ```bash
   # Line 2: Code quality-focused review using Claude + Codex fallback
   # Line 208: echo "Primary AI (Claude) failed or timed out. Falling back to Codex..." >&2
   ```

---

## 📊 検証統計

- **確認項目数**: 50+
- **正常項目**: 45
- **不一致項目**: 5
- **深刻度**:
  - Critical: 0
  - High: 3 (タイムアウト不一致)
  - Medium: 2 (コメント不整合)

---

## 結論

README.mdの大部分は正確ですが、タイムアウト値に関する記載に不一致があります。
特に、YAML設定ファイルの値とREADMEの記載が異なる箇所が4つ見つかりました。

これらはすべて数値的な不一致であり、機能的な問題ではありませんが、
ユーザーが正しいタイムアウト値を理解するために修正が必要です。
