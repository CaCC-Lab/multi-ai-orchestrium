# Phase 1 File-Based Prompt System - Test Specification

**作成日**: 2025-10-23
**対象**: Phase 1.1-1.3 実装関数
**目標**: 分岐網羅率 100%

---

## 1. テスト対象関数

| 関数名 | ファイル | 行番号 | 責務 |
|--------|---------|--------|------|
| `supports_file_input()` | multi-ai-ai-interface.sh | 234-259 | AI別ファイル入力サポート判定 |
| `create_secure_prompt_file()` | multi-ai-ai-interface.sh | 279-307 | セキュアなテンポラリファイル作成 |
| `cleanup_prompt_file()` | multi-ai-ai-interface.sh | 320-335 | テンポラリファイル削除 |
| `call_ai_with_context()` | multi-ai-ai-interface.sh | 362-429 | サイズベース自動ルーティング |
| `sanitize_input()` | multi-ai-core.sh | 211-246 | コマンドライン用入力検証 |
| `sanitize_input_for_file()` | multi-ai-core.sh | 248-279 | ファイルベース用入力検証 |
| `call_ai()` | multi-ai-ai-interface.sh | 104-123 | 後方互換性ラッパー |

---

## 2. テスト観点マトリクス

### 2.1 `supports_file_input()` - AI名判定関数

#### 等価分割

| クラス | 入力値 | 期待結果 | 備考 |
|--------|--------|----------|------|
| **有効クラス** |
| サポートAI | `claude` | exit 0 | ファイル入力サポート |
| サポートAI | `codex` | exit 0 | ファイル入力サポート |
| サポートAI | `gemini` | exit 0 | stdin redirect対応 |
| サポートAI | `droid` | exit 0 | stdin redirect対応 |
| 未サポートAI | `qwen` | exit 1 | fallback to stdin |
| 未サポートAI | `cursor` | exit 1 | fallback to stdin |
| 未サポートAI | `amp` | exit 1 | fallback to stdin |
| **無効クラス** |
| 不明AI | `unknown` | exit 1 | デフォルトケース |
| 空文字列 | `""` | exit 1 | 不正入力 |
| NULL | (引数なし) | エラー | 引数不足 |
| 特殊文字 | `claude; rm -rf` | exit 1 | インジェクション試行 |

#### 境界値分析

| 境界 | 入力値 | 期待結果 |
|------|--------|----------|
| 最短AI名 | `amp` (3文字) | exit 1 |
| 最長AI名 | `cursor` (6文字) | exit 1 |
| 大文字 | `CLAUDE` | exit 1 (case sensitive) |
| 混在 | `ClAuDe` | exit 1 (case sensitive) |

#### テストケース設計

| # | Given | When | Then | 種別 |
|---|-------|------|------|------|
| T1.1 | AI名 "claude" | supports_file_input実行 | exit 0 | 正常系 |
| T1.2 | AI名 "gemini" | supports_file_input実行 | exit 0 | 正常系 |
| T1.3 | AI名 "qwen" | supports_file_input実行 | exit 1 | 正常系 |
| T1.4 | AI名 "unknown" | supports_file_input実行 | exit 1 | 異常系 |
| T1.5 | 空文字列 | supports_file_input実行 | exit 1 | 異常系 |
| T1.6 | 引数なし | supports_file_input実行 | エラー終了 | 異常系 |
| T1.7 | AI名 "CLAUDE" | supports_file_input実行 | exit 1 (大文字) | 境界値 |
| T1.8 | インジェクション試行 | supports_file_input実行 | exit 1 | セキュリティ |

---

### 2.2 `create_secure_prompt_file()` - ファイル作成関数

#### 等価分割

| クラス | AI名 | コンテンツ | 期待結果 | 備考 |
|--------|------|-----------|----------|------|
| **有効クラス** |
| 正常作成 | `claude` | `"test prompt"` | ファイルパス出力, exit 0 | 基本ケース |
| 長文 | `gemini` | 10KB文字列 | ファイルパス出力, exit 0 | 大規模プロンプト |
| Markdown | `qwen` | コードブロック含む | ファイルパス出力, exit 0 | バッククォート |
| 特殊文字 | `codex` | `$;|&!` 含む | ファイルパス出力, exit 0 | シェルメタキャラクタ |
| **無効クラス** |
| 空コンテンツ | `claude` | `""` | ファイルパス出力, exit 0 | 空も許可 |
| mktemp失敗 | `claude` | (正常) | exit 1 | TMPDIR不正 |
| chmod失敗 | `claude` | (正常) | exit 1 | 権限不足 |
| 書き込み失敗 | `claude` | (正常) | exit 1 | ディスク満杯 |

#### 境界値分析

| 境界 | 入力値 | 期待結果 |
|------|--------|----------|
| 最小コンテンツ | 1文字 | ファイル作成成功 |
| 1KB閾値-1 | 1023 bytes | ファイル作成成功 |
| 1KB閾値 | 1024 bytes | ファイル作成成功 |
| 1KB閾値+1 | 1025 bytes | ファイル作成成功 |
| 大規模 | 100KB | ファイル作成成功 |
| 極大 | 10MB | ファイル作成成功 |

#### 検証項目

| 項目 | 検証方法 |
|------|----------|
| ファイル存在 | `[ -f "$file" ]` |
| パーミッション | `[ "$(stat -c %a "$file")" = "600" ]` |
| 内容一致 | `diff <(echo "$content") "$file"` |
| ファイル名形式 | `/tmp/prompt-${ai}-XXXXXX` パターン |
| エラーログ | log_error呼び出し確認 |

#### テストケース設計

| # | Given | When | Then | 種別 |
|---|-------|------|------|------|
| T2.1 | AI="claude", content="test" | create実行 | ファイル作成, exit 0 | 正常系 |
| T2.2 | AI="gemini", content=10KB | create実行 | ファイル作成, exit 0 | 正常系 |
| T2.3 | Markdown with backticks | create実行 | コンテンツ完全保存 | 正常系 |
| T2.4 | content with $;|&! | create実行 | コンテンツ完全保存 | 正常系 |
| T2.5 | AI="claude", content="" | create実行 | 空ファイル作成 | 境界値 |
| T2.6 | 1023 bytes | create実行 | ファイル作成 | 境界値 |
| T2.7 | 1024 bytes | create実行 | ファイル作成 | 境界値 |
| T2.8 | 1025 bytes | create実行 | ファイル作成 | 境界値 |
| T2.9 | TMPDIR="/invalid/path" | create実行 | exit 1, エラーログ | 異常系 |
| T2.10 | chmod失敗シミュレート | create実行 | exit 1, ファイル削除 | 異常系 |
| T2.11 | 書き込み失敗 | create実行 | exit 1, ファイル削除 | 異常系 |
| T2.12 | パーミッション検証 | 作成後確認 | 600 (-rw-------) | セキュリティ |

---

### 2.3 `cleanup_prompt_file()` - ファイル削除関数

#### 等価分割

| クラス | 入力値 | 期待結果 | 備考 |
|--------|--------|----------|------|
| **有効クラス** |
| 存在ファイル | 有効パス | exit 0, ファイル削除 | 正常削除 |
| 空文字列 | `""` | exit 0, 何もしない | 早期リターン |
| NULL | (引数なし) | exit 0, 何もしない | 引数不足 |
| **無効クラス** |
| 不存在ファイル | `/tmp/nonexist` | exit 0, 何もしない | 冪等性 |
| 削除失敗 | 権限なしパス | exit 1, 警告ログ | 権限エラー |
| 読み取り専用FS | `/read-only/file` | exit 1, 警告ログ | ファイルシステムエラー |

#### 境界値分析

| 境界 | 入力値 | 期待結果 |
|------|--------|----------|
| 空文字列 | `""` | exit 0 (早期リターン) |
| 1文字パス | `/` | exit 0 (存在しないため) |
| 長大パス | 4096文字 | 正常動作 |

#### テストケース設計

| # | Given | When | Then | 種別 |
|---|-------|------|------|------|
| T3.1 | 存在する一時ファイル | cleanup実行 | ファイル削除, exit 0 | 正常系 |
| T3.2 | 空文字列 | cleanup実行 | 何もせず exit 0 | 正常系 |
| T3.3 | 引数なし | cleanup実行 | 何もせず exit 0 | 境界値 |
| T3.4 | 不存在ファイル | cleanup実行 | exit 0 (冪等性) | 異常系 |
| T3.5 | 削除権限なし | cleanup実行 | exit 1, log_warning | 異常系 |
| T3.6 | 読み取り専用FS | cleanup実行 | exit 1, log_warning | 異常系 |

---

### 2.4 `call_ai_with_context()` - 自動ルーティング関数

#### 等価分割

| クラス | AI名 | プロンプトサイズ | 期待動作 | 備考 |
|--------|------|-----------------|----------|------|
| **有効クラス** |
| 小プロンプト | `claude` | 100 bytes | call_ai()呼び出し | コマンドライン経由 |
| 閾値未満 | `gemini` | 1023 bytes | call_ai()呼び出し | コマンドライン経由 |
| 閾値ジャスト | `qwen` | 1024 bytes | call_ai()呼び出し | 境界値 |
| 閾値超過 | `codex` | 1025 bytes | ファイルベース | ファイル経由 |
| 大プロンプト | `droid` | 10KB | ファイルベース | ファイル経由 |
| 超大 | `cursor` | 100KB | ファイルベース | ファイル経由 |
| **無効クラス** |
| ファイル作成失敗 | `claude` | 2KB | truncate+call_ai() | フォールバック |
| AI不明 | `unknown` | 100 bytes | exit 1 | check_ai_with_details失敗 |

#### 境界値分析

| 境界 | プロンプトサイズ | 期待動作 |
|------|-----------------|----------|
| 0 bytes | 0 | call_ai() (空でも許可) |
| 1 byte | 1 | call_ai() |
| 1023 bytes | 1023 | call_ai() |
| **1024 bytes** | 1024 | call_ai() (閾値) |
| **1025 bytes** | 1025 | ファイルベース |
| 2000 bytes | 2000 | ファイルベース |
| 10MB | 10485760 | ファイルベース |

#### 検証項目

| 項目 | 検証方法 |
|------|----------|
| サイズ判定 | `${#context}` 計算確認 |
| ルーティング先 | ログメッセージ確認 |
| ファイル作成 | 一時ファイル存在確認 |
| クリーンアップ | trap設定とファイル削除確認 |
| フォールバック | 失敗時truncate動作確認 |
| 出力ファイル | 出力内容の検証 |

#### テストケース設計

| # | Given | When | Then | 種別 |
|---|-------|------|------|------|
| T4.1 | AI="claude", 100bytes | call実行 | call_ai()呼び出し | 正常系 |
| T4.2 | AI="gemini", 1023bytes | call実行 | call_ai()呼び出し | 境界値 |
| T4.3 | AI="qwen", 1024bytes | call実行 | call_ai()呼び出し | 境界値 |
| T4.4 | AI="codex", 1025bytes | call実行 | ファイルベース | 境界値 |
| T4.5 | AI="droid", 10KB | call実行 | ファイルベース | 正常系 |
| T4.6 | AI="cursor", 100KB | call実行 | ファイルベース | 正常系 |
| T4.7 | Markdown with backticks | call実行 | コンテンツ保持 | 正常系 |
| T4.8 | ファイル作成失敗Mock | call実行 | truncate+fallback | 異常系 |
| T4.9 | trap動作確認 | INT送信 | クリーンアップ実行 | 異常系 |
| T4.10 | AI="unknown" | call実行 | exit 1 | 異常系 |

---

### 2.5 `sanitize_input()` - コマンドライン用入力検証

#### 等価分割

| クラス | 入力値 | 期待結果 | 備考 |
|--------|--------|----------|------|
| **有効クラス** |
| 通常文字列 | `"hello world"` | そのまま出力 | 正常 |
| Markdown | `` `code` `` | そのまま出力 | Phase 1.2でバッククォート許可 |
| 改行含む | `"line1\nline2"` | スペース変換後出力 | 制御文字除去 |
| タブ含む | `"a\tb"` | スペース変換後出力 | 制御文字除去 |
| 1999文字 | 1999文字列 | そのまま出力 | 長さ制限-1 |
| 2000文字 | 2000文字列 | そのまま出力 | 長さ制限ジャスト |
| **無効クラス** |
| 2001文字 | 2001文字列 | exit 1, エラーログ | 長さ超過 |
| セミコロン | `"cmd;cmd"` | exit 1, エラーログ | コマンド区切り |
| パイプ | `"cmd|cmd"` | exit 1, エラーログ | パイプライン |
| ドル記号 | `"$VAR"` | exit 1, エラーログ | 変数展開 |
| リダイレクト | `"cmd<file"` | exit 1, エラーログ | 入力リダイレクト |
| リダイレクト | `"cmd>file"` | exit 1, エラーログ | 出力リダイレクト |
| アンパサンド | `"cmd&"` | exit 1, エラーログ | バックグラウンド実行 |
| エクスクラメーション | `"cmd!"` | exit 1, エラーログ | 履歴展開 |
| 空文字列 | `""` | exit 1, エラーログ | 空入力 |
| 空白のみ | `"   "` | exit 1, エラーログ | 空入力 |

#### 境界値分析

| 境界 | 入力値 | 期待結果 |
|------|--------|----------|
| 0文字 | `""` | exit 1 |
| 1文字 | `"a"` | 出力 |
| 1999文字 | 1999文字列 | 出力 |
| **2000文字** | 2000文字列 | 出力 |
| **2001文字** | 2001文字列 | exit 1 |
| 4000文字 | 4000文字列 | exit 1 |

#### テストケース設計

| # | Given | When | Then | 種別 |
|---|-------|------|------|------|
| T5.1 | "hello world" | sanitize実行 | 正常出力 | 正常系 |
| T5.2 | `` `code block` `` | sanitize実行 | 正常出力 | 正常系 |
| T5.3 | "line1\nline2" | sanitize実行 | スペース変換 | 正常系 |
| T5.4 | 2000文字 | sanitize実行 | 正常出力 | 境界値 |
| T5.5 | 2001文字 | sanitize実行 | exit 1 | 境界値 |
| T5.6 | "cmd;rm -rf" | sanitize実行 | exit 1 | 異常系 |
| T5.7 | "cmd\|grep" | sanitize実行 | exit 1 | 異常系 |
| T5.8 | "$VAR" | sanitize実行 | exit 1 | 異常系 |
| T5.9 | "cmd<file" | sanitize実行 | exit 1 | 異常系 |
| T5.10 | "cmd>file" | sanitize実行 | exit 1 | 異常系 |
| T5.11 | "cmd&" | sanitize実行 | exit 1 | 異常系 |
| T5.12 | "cmd!" | sanitize実行 | exit 1 | 異常系 |
| T5.13 | "" | sanitize実行 | exit 1 | 異常系 |
| T5.14 | "   " | sanitize実行 | exit 1 | 異常系 |

---

### 2.6 `sanitize_input_for_file()` - ファイルベース用入力検証

#### 等価分割

| クラス | 入力値 | 期待結果 | 備考 |
|--------|--------|----------|------|
| **有効クラス** |
| 通常文字列 | `"hello world"` | そのまま出力 | 正常 |
| Markdown | `` `code` `` | そのまま出力 | バッククォート許可 |
| シェルメタ | `$;|&!<>` | そのまま出力 | ファイル内は安全 |
| 巨大文字列 | 10MB | そのまま出力 | 長さ制限なし |
| **無効クラス** |
| Null byte | `"\x00"` | exit 1, エラーログ | ファイルシステム攻撃 |
| パストラバーサル | `"../../"` | exit 1, エラーログ | ディレクトリ攻撃 |
| /etc/passwd | `"/etc/passwd"` | exit 1, エラーログ | システムファイル |
| /bin/sh | `"/bin/sh"` | exit 1, エラーログ | シェル実行 |
| 空文字列 | `""` | exit 1, エラーログ | 空入力 |
| 空白のみ | `"   "` | exit 1, エラーログ | 空入力 |

#### 境界値分析

| 境界 | 入力値 | 期待結果 |
|------|--------|----------|
| 0文字 | `""` | exit 1 |
| 1文字 | `"a"` | 出力 |
| 1KB | 1024 bytes | 出力 |
| 1MB | 1048576 bytes | 出力 |
| 10MB | 10485760 bytes | 出力 |

#### テストケース設計

| # | Given | When | Then | 種別 |
|---|-------|------|------|------|
| T6.1 | "hello world" | sanitize実行 | 正常出力 | 正常系 |
| T6.2 | `` `code` `` | sanitize実行 | 正常出力 | 正常系 |
| T6.3 | "$;&#124;&!<>" | sanitize実行 | 正常出力 | 正常系 |
| T6.4 | 10MB文字列 | sanitize実行 | 正常出力 | 正常系 |
| T6.5 | "\x00" | sanitize実行 | exit 1 | 異常系 |
| T6.6 | "../../" | sanitize実行 | exit 1 | 異常系 |
| T6.7 | "/etc/passwd" | sanitize実行 | exit 1 | 異常系 |
| T6.8 | "/bin/sh" | sanitize実行 | exit 1 | 異常系 |
| T6.9 | "" | sanitize実行 | exit 1 | 異常系 |
| T6.10 | "   " | sanitize実行 | exit 1 | 異常系 |

---

### 2.7 `call_ai()` - 後方互換性ラッパー

#### 等価分割

| クラス | 入力値 | 期待結果 | 備考 |
|--------|--------|----------|------|
| **有効クラス** |
| 全引数指定 | ai, prompt, timeout, file | call_ai_with_context呼び出し | 正常 |
| timeout省略 | ai, prompt, "", file | timeout=300でcall | デフォルト値 |
| output_file省略 | ai, prompt, 600, "" | 標準出力 | デフォルト値 |
| **無効クラス** |
| AI不明 | "unknown", prompt, 300, file | exit 1 | check_ai_with_details失敗 |
| AI引数なし | (引数不足) | エラー | 引数不足 |

#### テストケース設計

| # | Given | When | Then | 種別 |
|---|-------|------|------|------|
| T7.1 | 全引数指定 | call_ai実行 | call_ai_with_context呼び出し | 正常系 |
| T7.2 | timeout省略 | call_ai実行 | timeout=300でcall | 正常系 |
| T7.3 | output_file省略 | call_ai実行 | 標準出力 | 正常系 |
| T7.4 | AI="unknown" | call_ai実行 | exit 1 | 異常系 |
| T7.5 | 引数不足 | call_ai実行 | エラー | 異常系 |

---

## 3. テストケース総数

| 関数 | 正常系 | 異常系 | 境界値 | 合計 |
|------|--------|--------|--------|------|
| `supports_file_input()` | 3 | 3 | 2 | 8 |
| `create_secure_prompt_file()` | 4 | 3 | 5 | 12 |
| `cleanup_prompt_file()` | 2 | 3 | 1 | 6 |
| `call_ai_with_context()` | 7 | 3 | 0 | 10 |
| `sanitize_input()` | 4 | 10 | 0 | 14 |
| `sanitize_input_for_file()` | 4 | 6 | 0 | 10 |
| `call_ai()` | 3 | 2 | 0 | 5 |
| **合計** | **27** | **30** | **8** | **65** |

**失敗系比率**: 30/27 = 111% ✅ (正常系以上の異常系テスト)

---

## 4. カバレッジ目標

| 指標 | 目標 | 測定方法 |
|------|------|----------|
| ステートメント網羅 | 100% | `kcov` or 手動トレース |
| 分岐網羅 | 100% | 全if/case文の両方向 |
| 条件網羅 | 100% | 複合条件の全組み合わせ |
| 関数網羅 | 100% | 全関数の呼び出し |

---

## 5. テスト実行環境

| 項目 | 仕様 |
|------|------|
| Shell | bash 4.0+ |
| OS | Linux (WSL2) |
| 必要ツール | `mktemp`, `chmod`, `stat`, `diff`, `timeout` |
| Mockツール | カスタムMock関数（テストコード内定義） |

---

## 6. テスト実装方針

### 6.1 テストフレームワーク

- シンプルなBash関数ベース
- Assert関数: `assert_equals`, `assert_exit_code`, `assert_file_exists`, `assert_contains`
- テスト分離: 各テストケースは独立実行
- クリーンアップ: trap使用で一時ファイル自動削除

### 6.2 Mock戦略

| Mock対象 | Mock方法 |
|----------|----------|
| `log_*` 関数 | 空関数で置き換え |
| `check_ai_with_details` | 条件付きreturn |
| `mktemp` | 失敗シミュレーション用にラップ |
| `chmod` | 失敗シミュレーション用にラップ |
| ファイルシステム | tmpfs使用 |

### 6.3 テスト順序

1. 単体テスト（関数単位）
2. 統合テスト（関数間連携）
3. シナリオテスト（エンドツーエンド）

---

## 7. 追加テスト観点

### 7.1 非機能要件

| 観点 | テスト内容 |
|------|-----------|
| パフォーマンス | 1KB未満プロンプトは<10ms |
| パフォーマンス | 100KBプロンプトは<100ms |
| メモリ | 10MBプロンプトでもメモリリークなし |
| 並列性 | 同時10プロセスでファイル名衝突なし |
| セキュリティ | パーミッション600厳守 |
| セキュリティ | 一時ファイルの情報漏洩なし |

### 7.2 エラーメッセージ検証

| エラーケース | 期待メッセージ |
|-------------|--------------|
| 長さ超過 | "Input too long" |
| 不正文字 | "Invalid characters detected" |
| 空入力 | "Input cannot be empty" |
| ファイル作成失敗 | "Failed to create temporary file" |
| パーミッション失敗 | "Failed to set permissions" |
| 書き込み失敗 | "Failed to write content" |

### 7.3 競合状態テスト

| シナリオ | テスト方法 |
|---------|-----------|
| 同時ファイル作成 | 並列プロセス起動 |
| 削除中の読み取り | trap + kill -INT |
| ディスク満杯 | `dd` でtmpfs埋める |

---

## 8. 不足観点の自己追加

以下の観点を追加で実装します：

### 8.1 ロギング検証
- 各エラーケースで適切なlog_error/log_warning呼び出し
- VibeLogger統合時の構造化ログ検証

### 8.2 trap動作検証
- INT/TERM/EXITシグナルでのクリーンアップ
- trap中のエラーハンドリング

### 8.3 環境変数依存
- TMPDIR上書き時の動作
- PROJECT_ROOT不正時の動作

### 8.4 文字エンコーディング
- UTF-8マルチバイト文字
- 絵文字含むプロンプト
- Latin-1等の非UTF-8

---

## 9. 実行コマンド

```bash
# テスト実行
bash tests/phase1-file-based-prompt-test.sh

# カバレッジ付き実行（kcov使用）
kcov --exclude-pattern=/usr coverage tests/phase1-file-based-prompt-test.sh

# カバレッジレポート表示
xdg-open coverage/index.html

# 並列実行（高速化）
bash tests/phase1-file-based-prompt-test.sh --parallel

# 特定テストのみ実行
bash tests/phase1-file-based-prompt-test.sh T2.*

# 詳細モード
bash tests/phase1-file-based-prompt-test.sh --verbose
```

---

## 10. 成功基準

| 項目 | 基準 |
|------|------|
| テスト成功率 | 100% (65/65) |
| 分岐網羅率 | 100% |
| 実行時間 | <60秒 (全テスト) |
| メモリリーク | 0件 |
| セキュリティ違反 | 0件 |

---

**次のステップ**: この仕様書に基づき、`tests/phase1-file-based-prompt-test.sh` を実装
