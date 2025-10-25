# Claude Review スラッシュコマンド テスト仕様書

## 目次

1. [テスト観点の概要](#テスト観点の概要)
2. [等価分割・境界値分析](#等価分割境界値分析)
3. [テストケース一覧](#テストケース一覧)
4. [テスト実行方法](#テスト実行方法)
5. [カバレッジ目標](#カバレッジ目標)

## テスト観点の概要

### テストレベル

| テストレベル | 目的 | カバレッジ目標 |
|-------------|------|---------------|
| ユニットテスト | 個別関数の動作確認 | 80%以上 |
| 統合テスト | コンポーネント間の連携確認 | 90%以上 |
| E2Eテスト | エンドツーエンドのワークフロー確認 | 100% |
| セキュリティテスト | 脆弱性の検出と防御確認 | 100% |

### テスト観点

- **正常系**: 期待される動作が正しく行われること
- **異常系**: エラー時の適切なハンドリング
- **境界値**: 入力の境界値での動作確認
- **不正入力**: 意図的な不正入力への対処
- **外部依存**: 外部ツール/サービスの失敗時の挙動
- **例外処理**: 各種例外の適切な処理

## 等価分割・境界値分析

### 1. コマンドライン引数（claude-review.sh）

#### 1.1 タイムアウト値（-t, --timeout）

| 分類 | 値の範囲 | 有効/無効 | 期待される結果 |
|------|---------|----------|--------------|
| 無効クラス1 | 負の値 (-1, -100) | 無効 | エラーメッセージ表示、終了コード1 |
| 無効クラス2 | 0 | 無効 | エラーメッセージ表示、終了コード1 |
| 境界値1 | 1 | 有効 | 1秒でタイムアウト |
| 有効クラス | 2-3599 | 有効 | 指定秒数でタイムアウト |
| 境界値2 | 3600 | 有効 | 3600秒でタイムアウト |
| 境界値3 | 3601 | 有効 | 3601秒でタイムアウト |
| 無効クラス3 | 文字列 ("abc") | 無効 | エラーメッセージ表示、終了コード1 |
| 無効クラス4 | 空文字列 ("") | 無効 | エラーメッセージ表示、終了コード1 |
| デフォルト値 | 未指定 | 有効 | 600秒でタイムアウト |

**境界値テストケース:**
- **下限-1**: -1 → エラー
- **下限**: 0 → エラー
- **下限+1**: 1 → 成功
- **上限-1**: 3599 → 成功
- **上限**: 3600 → 成功
- **上限+1**: 3601 → 成功

#### 1.2 コミットハッシュ（-c, --commit）

| 分類 | 値の範囲 | 有効/無効 | 期待される結果 |
|------|---------|----------|--------------|
| 有効クラス1 | フルハッシュ (40文字) | 有効 | 指定コミットをレビュー |
| 有効クラス2 | 短縮ハッシュ (7-9文字) | 有効 | 指定コミットをレビュー |
| 有効クラス3 | HEAD | 有効 | 最新コミットをレビュー |
| 有効クラス4 | HEAD~1, HEAD~2 | 有効 | 指定された相対位置のコミットをレビュー |
| 有効クラス5 | ブランチ名 | 有効 | ブランチの最新コミットをレビュー |
| 無効クラス1 | 存在しないハッシュ | 無効 | エラーメッセージ表示、終了コード1 |
| 無効クラス2 | 不正な形式 | 無効 | エラーメッセージ表示、終了コード1 |
| 無効クラス3 | 空文字列 | 無効 | エラーメッセージ表示、終了コード1 |
| デフォルト値 | 未指定 | 有効 | HEAD（最新コミット）をレビュー |

#### 1.3 出力ディレクトリ（-o, --output）

| 分類 | 値の範囲 | 有効/無効 | 期待される結果 |
|------|---------|----------|--------------|
| 有効クラス1 | 存在するディレクトリ | 有効 | 指定ディレクトリに出力 |
| 有効クラス2 | 存在しないディレクトリ | 有効 | ディレクトリを作成して出力 |
| 無効クラス1 | 書き込み権限なし | 無効 | エラーメッセージ表示、終了コード1 |
| 無効クラス2 | ファイルパス（ディレクトリではない） | 無効 | エラーメッセージ表示、終了コード1 |
| 無効クラス3 | パストラバーサル (../../etc/passwd) | 無効 | エラーメッセージ表示、終了コード1 |
| デフォルト値 | 未指定 | 有効 | logs/claude-reviews に出力 |

### 2. 入力ファイル/コード

#### 2.1 ファイルサイズ

| 分類 | 値の範囲 | 有効/無効 | 期待される結果 |
|------|---------|----------|--------------|
| 境界値1 | 0 bytes (空ファイル) | 有効 | 空のレビュー結果 |
| 有効クラス1 | 1-1023 bytes | 有効 | 正常にレビュー |
| 境界値2 | 1024 bytes (1KB) | 有効 | 正常にレビュー |
| 有効クラス2 | 1KB-100KB | 有効 | 正常にレビュー |
| 有効クラス3 | 100KB-1MB | 有効 | 正常にレビュー（やや時間がかかる） |
| 境界値3 | 1MB | 有効 | 正常にレビュー（時間がかかる） |
| 有効クラス4 | >1MB | 有効 | 警告表示の上でレビュー |

#### 2.2 ファイル形式

| 分類 | 値の範囲 | 有効/無効 | 期待される結果 |
|------|---------|----------|--------------|
| 有効クラス1 | .sh, .bash | 有効 | Bashスクリプトとしてレビュー |
| 有効クラス2 | .py | 有効 | Pythonコードとしてレビュー |
| 有効クラス3 | .js, .ts | 有効 | JavaScript/TypeScriptとしてレビュー |
| 有効クラス4 | .md, .txt | 有効 | ドキュメントとしてレビュー |
| 有効クラス5 | .json, .yaml | 有効 | 設定ファイルとしてレビュー |
| 無効クラス1 | バイナリファイル | 無効 | 警告表示、レビュースキップ |
| 無効クラス2 | 存在しないファイル | 無効 | エラーメッセージ表示 |

### 3. セキュリティチェック項目（claude-security-review.sh）

#### 3.1 脆弱性の重要度

| 分類 | CVSS v3.1スコア | 重要度 | 期待される結果 |
|------|----------------|--------|--------------|
| クラス1 | 9.0-10.0 | Critical | 即座に修正必須、詳細な修復提案 |
| クラス2 | 7.0-8.9 | High | 早急に修正必要、修復提案 |
| クラス3 | 4.0-6.9 | Medium | 修正推奨、修復提案 |
| クラス4 | 0.1-3.9 | Low | 修正検討、ベストプラクティス提案 |
| クラス5 | 0.0 | None | 問題なし |

#### 3.2 セキュリティルールの種類

| CWE-ID | 脆弱性名 | テストケース数 | 検出パターン |
|--------|---------|---------------|-------------|
| CWE-89 | SQLインジェクション | 5 | SQL文字列連結、動的クエリ |
| CWE-79 | XSS | 5 | HTMLエスケープなし、DOM操作 |
| CWE-77/78 | コマンドインジェクション | 5 | シェルコマンド実行、eval使用 |
| CWE-22 | パストラバーサル | 5 | ファイルパス操作、../ 使用 |
| CWE-798 | ハードコードされた認証情報 | 5 | パスワード、APIキー、トークン |
| CWE-327 | 不安全な暗号化 | 5 | MD5, SHA1, DES使用 |
| CWE-502 | 安全でないデシリアライゼーション | 5 | pickle, eval, unserialize使用 |
| CWE-611 | XXE | 3 | XML外部エンティティ処理 |
| CWE-918 | SSRF | 3 | URL検証なしのリクエスト |
| CWE-287 | 認証バイパス | 3 | 認証チェック不足 |

## テストケース一覧

### claude-review.sh ユニットテスト

#### カテゴリ1: 正常系（主要シナリオ）

| ID | テストケース名 | Given | When | Then | 優先度 |
|----|---------------|-------|------|------|--------|
| TC-R-001 | デフォルト設定でレビュー実行 | gitリポジトリが存在し、HEADコミットがある | 引数なしでスクリプト実行 | 最新コミットがレビューされ、JSON/MDレポート生成、終了コード0 | 高 |
| TC-R-002 | カスタムタイムアウトでレビュー実行 | gitリポジトリが存在 | -t 300 でスクリプト実行 | 300秒でタイムアウト設定され、レビュー完了、終了コード0 | 高 |
| TC-R-003 | 特定コミットのレビュー実行 | gitリポジトリが存在し、特定コミット(abc123)がある | -c abc123 でスクリプト実行 | abc123がレビューされ、レポート生成、終了コード0 | 高 |
| TC-R-004 | カスタム出力ディレクトリ指定 | gitリポジトリが存在 | -o /tmp/reviews でスクリプト実行 | /tmp/reviewsにレポート出力、終了コード0 | 中 |
| TC-R-005 | ヘルプメッセージ表示 | 任意の状態 | -h または --help でスクリプト実行 | ヘルプメッセージ表示、終了コード0 | 低 |
| TC-R-006 | Claude MCP利用可能時のレビュー | Claude MCP設定済み | スクリプト実行 | Claude MCPでレビュー実行、詳細なレポート生成 | 高 |
| TC-R-007 | 複数オプション組み合わせ | gitリポジトリが存在 | -t 900 -c HEAD~1 -o /tmp/reviews でスクリプト実行 | すべてのオプションが適用され、レビュー完了 | 中 |

#### カテゴリ2: 異常系（バリデーションエラー、例外）

| ID | テストケース名 | Given | When | Then | 優先度 |
|----|---------------|-------|------|------|--------|
| TC-R-101 | gitリポジトリ外での実行 | gitリポジトリではないディレクトリ | スクリプト実行 | "Not in a git repository" エラーメッセージ、終了コード1 | 高 |
| TC-R-102 | 存在しないコミット指定 | gitリポジトリが存在 | -c nonexistent でスクリプト実行 | "Commit not found" エラーメッセージ、終了コード1 | 高 |
| TC-R-103 | 負のタイムアウト値 | gitリポジトリが存在 | -t -100 でスクリプト実行 | "Invalid timeout value" エラーメッセージ、終了コード1 | 中 |
| TC-R-104 | 文字列のタイムアウト値 | gitリポジトリが存在 | -t abc でスクリプト実行 | "Invalid timeout value" エラーメッセージ、終了コード1 | 中 |
| TC-R-105 | 書き込み権限のないディレクトリ | 書き込み権限のないディレクトリ存在 | -o /root/reviews でスクリプト実行 | "Permission denied" エラーメッセージ、終了コード1 | 高 |
| TC-R-106 | 不正なオプション指定 | gitリポジトリが存在 | --invalid-option でスクリプト実行 | "Unknown option" エラーメッセージ、ヘルプ表示、終了コード1 | 低 |
| TC-R-107 | 空のコミットハッシュ | gitリポジトリが存在 | -c "" でスクリプト実行 | "Invalid commit hash" エラーメッセージ、終了コード1 | 中 |

#### カテゴリ3: 境界値

| ID | テストケース名 | Given | When | Then | 優先度 |
|----|---------------|-------|------|------|--------|
| TC-R-201 | タイムアウト0秒 | gitリポジトリが存在 | -t 0 でスクリプト実行 | エラーメッセージ表示、終了コード1 | 中 |
| TC-R-202 | タイムアウト1秒（最小値） | gitリポジトリが存在 | -t 1 でスクリプト実行 | 1秒でタイムアウト、途中結果でも完了、終了コード124または0 | 中 |
| TC-R-203 | タイムアウト3600秒（1時間） | gitリポジトリが存在 | -t 3600 でスクリプト実行 | 3600秒でタイムアウト設定、レビュー完了 | 低 |
| TC-R-204 | 空のコミット（変更なし） | 空のコミットが存在 | 空コミットを指定してスクリプト実行 | "No changes to review" メッセージ、空レポート生成、終了コード0 | 中 |
| TC-R-205 | 1行のみの変更 | 1行のみ変更されたコミット | スクリプト実行 | 1行の変更をレビュー、レポート生成、終了コード0 | 低 |
| TC-R-206 | 10000行以上の変更 | 大規模な変更コミット | スクリプト実行 | 警告表示、レビュー実行（時間がかかる）、終了コード0 | 低 |

#### カテゴリ4: 不正な型・形式の入力

| ID | テストケース名 | Given | When | Then | 優先度 |
|----|---------------|-------|------|------|--------|
| TC-R-301 | 特殊文字を含むコミットハッシュ | gitリポジトリが存在 | -c "abc;rm -rf /" でスクリプト実行 | 入力サニタイゼーション、エラーメッセージ、終了コード1 | 高 |
| TC-R-302 | パストラバーサルを含む出力パス | gitリポジトリが存在 | -o "../../etc/passwd" でスクリプト実行 | パストラバーサル検出、エラーメッセージ、終了コード1 | 高 |
| TC-R-303 | NULLバイトを含む入力 | gitリポジトリが存在 | -c "abc\x00def" でスクリプト実行 | NULLバイト削除、エラーメッセージ、終了コード1 | 中 |
| TC-R-304 | 改行コードを含む引数 | gitリポジトリが存在 | -c "abc\ndef" でスクリプト実行 | 改行コード削除、エラーメッセージ、終了コード1 | 中 |
| TC-R-305 | 極端に長い引数 | gitリポジトリが存在 | 10000文字の引数でスクリプト実行 | 引数長さ制限チェック、エラーメッセージ、終了コード1 | 低 |

#### カテゴリ5: 外部依存の失敗

| ID | テストケース名 | Given | When | Then | 優先度 |
|----|---------------|-------|------|------|--------|
| TC-R-401 | gitコマンド未インストール | gitコマンドが利用不可 | スクリプト実行 | "git command not found" エラーメッセージ、終了コード1 | 高 |
| TC-R-402 | Claude MCP未設定 | Claude MCP未設定 | スクリプト実行 | 代替レビュー実行、基本的なレポート生成、終了コード0 | 高 |
| TC-R-403 | Claude MCPタイムアウト | Claude MCP応答なし | スクリプト実行 | タイムアウト発生、代替レビューへフォールバック、終了コード0 | 中 |
| TC-R-404 | ディスク容量不足 | ディスク容量不足 | スクリプト実行 | "No space left on device" エラーメッセージ、終了コード1 | 中 |
| TC-R-405 | ネットワーク切断時 | ネットワーク切断状態 | スクリプト実行 | ローカルレビュー実行、基本的なレポート生成、終了コード0 | 低 |

#### カテゴリ6: 例外種別・エラーメッセージの検証

| ID | テストケース名 | Given | When | Then | 優先度 |
|----|---------------|-------|------|------|--------|
| TC-R-501 | タイムアウト例外 | レビュー処理が長時間かかる | タイムアウト発生 | SIGTERM/SIGKILLシグナル、"Timeout occurred" メッセージ、終了コード124 | 高 |
| TC-R-502 | 割り込みシグナル（Ctrl+C） | レビュー実行中 | Ctrl+C（SIGINT）送信 | グレースフルシャットダウン、一時ファイル削除、"Interrupted by user" メッセージ、終了コード130 | 中 |
| TC-R-503 | git rev-parse失敗 | 不正なgitリポジトリ | スクリプト実行 | "Invalid git repository" エラーメッセージ、終了コード1 | 中 |
| TC-R-504 | ファイル作成失敗 | 出力ディレクトリが読み取り専用 | スクリプト実行 | "Failed to create output file" エラーメッセージ、終了コード1 | 中 |
| TC-R-505 | VibeLogger書き込み失敗 | ログディレクトリが読み取り専用 | スクリプト実行 | ログ失敗を警告表示、レビュー処理は継続、終了コード0 | 低 |

### claude-security-review.sh ユニットテスト

#### カテゴリ1: 正常系（セキュリティチェック）

| ID | テストケース名 | Given | When | Then | 優先度 |
|----|---------------|-------|------|------|--------|
| TC-S-001 | SQLインジェクション検出 | SQL文字列連結を含むコード | スクリプト実行 | SQLインジェクション脆弱性検出、CWE-89報告、修復提案 | 高 |
| TC-S-002 | XSS脆弱性検出 | HTMLエスケープなしのDOM操作コード | スクリプト実行 | XSS脆弱性検出、CWE-79報告、修復提案 | 高 |
| TC-S-003 | コマンドインジェクション検出 | eval/exec使用コード | スクリプト実行 | コマンドインジェクション検出、CWE-77/78報告、修復提案 | 高 |
| TC-S-004 | パストラバーサル検出 | ../を含むファイルパス操作 | スクリプト実行 | パストラバーサル脆弱性検出、CWE-22報告、修復提案 | 高 |
| TC-S-005 | ハードコードされた秘密情報検出 | パスワード/APIキーをハードコード | スクリプト実行 | ハードコードされた秘密情報検出、CWE-798報告、修復提案 | 高 |
| TC-S-006 | 不安全な暗号化検出 | MD5/SHA1使用コード | スクリプト実行 | 不安全な暗号化検出、CWE-327報告、修復提案 | 中 |
| TC-S-007 | 安全でないデシリアライゼーション検出 | pickle/eval使用 | スクリプト実行 | 安全でないデシリアライゼーション検出、CWE-502報告、修復提案 | 中 |
| TC-S-008 | XXE脆弱性検出 | XML外部エンティティ処理 | スクリプト実行 | XXE脆弱性検出、CWE-611報告、修復提案 | 中 |
| TC-S-009 | SSRF脆弱性検出 | URL検証なしのリクエスト | スクリプト実行 | SSRF脆弱性検出、CWE-918報告、修復提案 | 中 |
| TC-S-010 | 複数の脆弱性を同時検出 | 複数の脆弱性を含むコード | スクリプト実行 | すべての脆弱性を検出、優先度順にレポート、修復提案 | 高 |

#### カテゴリ2: 異常系（セキュリティレビュー）

| ID | テストケース名 | Given | When | Then | 優先度 |
|----|---------------|-------|------|------|--------|
| TC-S-101 | セキュリティルールファイル不在 | セキュリティルールファイル削除 | スクリプト実行 | "Security rules file not found" エラーメッセージ、終了コード1 | 高 |
| TC-S-102 | 不正なCVSSスコア計算 | 不正な脆弱性データ | CVSS計算実行 | デフォルトスコア使用、警告メッセージ、処理継続 | 中 |
| TC-S-103 | SARIF形式生成失敗 | SARIF出力ディレクトリが読み取り専用 | スクリプト実行 | "Failed to generate SARIF report" 警告、JSON/MDレポートは生成 | 中 |
| TC-S-104 | タイムアウト発生 | 大規模コードベース | 900秒でタイムアウト | 部分的な結果でレポート生成、タイムアウトメッセージ、終了コード124 | 中 |

#### カテゴリ3: 境界値（セキュリティレビュー）

| ID | テストケース名 | Given | When | Then | 優先度 |
|----|---------------|-------|------|------|--------|
| TC-S-201 | 脆弱性0件のコード | セキュアなコード | スクリプト実行 | "No vulnerabilities found" メッセージ、空レポート生成、終了コード0 | 高 |
| TC-S-202 | 脆弱性1件のコード | 1つのSQLインジェクション | スクリプト実行 | 1件の脆弱性検出、詳細レポート生成、終了コード0 | 中 |
| TC-S-203 | 脆弱性100件以上のコード | 多数の脆弱性を含むコード | スクリプト実行 | すべての脆弱性検出、サマリーレポート生成、終了コード0 | 中 |
| TC-S-204 | Critical重要度の脆弱性 | CVSS 9.0以上の脆弱性 | スクリプト実行 | Critical警告、詳細な修復提案、即座の対応推奨 | 高 |
| TC-S-205 | Low重要度の脆弱性のみ | CVSS 3.9以下の脆弱性 | スクリプト実行 | Low警告、ベストプラクティス提案、終了コード0 | 低 |

#### カテゴリ4: セキュリティテスト（攻撃シミュレーション）

| ID | テストケース名 | Given | When | Then | 優先度 |
|----|---------------|-------|------|------|--------|
| TC-S-301 | パストラバーサル攻撃入力 | スクリプト起動 | -o "../../etc/passwd" 入力 | パストラバーサル検出、入力拒否、エラーメッセージ、終了コード1 | 高 |
| TC-S-302 | コマンドインジェクション攻撃入力 | スクリプト起動 | -c "abc; rm -rf /" 入力 | コマンドインジェクション検出、入力拒否、エラーメッセージ、終了コード1 | 高 |
| TC-S-303 | 環境変数インジェクション | 環境変数に不正な値設定 | スクリプト実行 | 環境変数検証、不正な値拒否、エラーメッセージ、終了コード1 | 中 |
| TC-S-304 | バッファオーバーフロー試行 | 極端に長い引数 | スクリプト実行 | 引数長さ制限、エラーメッセージ、終了コード1 | 中 |
| TC-S-305 | 不正なファイルパス入力 | /dev/null, /proc/self/environ | スクリプト実行 | 特殊ファイルパス検出、エラーメッセージ、終了コード1 | 中 |

### CLIスクリプト統合テスト

#### claude-review.sh

| ID | テストケース名 | Given | When | Then | 優先度 |
|----|---------------|-------|------|------|--------|
| TC-CLI-001 | デフォルト引数で実行 | gitリポジトリが存在 | bash scripts/claude-review.sh 実行 | HEADコミットをレビュー、JSON/MDレポート生成 | 高 |
| TC-CLI-002 | コミット指定で実行 | gitリポジトリが存在、abc123コミット存在 | bash scripts/claude-review.sh --commit abc123 実行 | abc123をレビュー、レポート生成 | 高 |
| TC-CLI-003 | カスタムタイムアウトで実行 | gitリポジトリが存在 | bash scripts/claude-review.sh --timeout 900 実行 | 900秒タイムアウト設定でレビュー実行 | 高 |
| TC-CLI-004 | 存在しないコミット指定 | gitリポジトリが存在 | bash scripts/claude-review.sh --commit nonexistent 実行 | エラーメッセージ表示、終了コード1 | 中 |

#### claude-security-review.sh

| ID | テストケース名 | Given | When | Then | 優先度 |
|----|---------------|-------|------|------|--------|
| TC-CLI-101 | デフォルト引数で実行 | gitリポジトリが存在 | bash scripts/claude-security-review.sh 実行 | HEADコミットをセキュリティレビュー、脆弱性レポート生成 | 高 |
| TC-CLI-102 | コミット指定で実行 | gitリポジトリが存在、abc123コミット存在 | bash scripts/claude-security-review.sh --commit abc123 実行 | abc123をセキュリティレビュー、脆弱性レポート生成 | 高 |
| TC-CLI-103 | 重要度フィルタリング | 脆弱性を含むコード | bash scripts/claude-security-review.sh --severity Critical 実行 | Criticalのみレポート表示 | 高 |
| TC-CLI-104 | SARIF形式出力 | gitリポジトリが存在 | bash scripts/claude-security-review.sh 実行 | SARIF形式レポート生成 | 高 |

### E2Eテスト

| ID | テストケース名 | Given | When | Then | 優先度 |
|----|---------------|-------|------|------|--------|
| TC-E2E-001 | 完全なレビューワークフロー | gitリポジトリが存在 | bash scripts/claude-review.sh → レポート確認 → bash scripts/claude-security-review.sh 実行 | 両レビュー完了、JSON/MDレポート生成、VibeLoggerログ記録 | 高 |
| TC-E2E-002 | 脆弱性検出から修正まで | 脆弱性を含むコード | claude-security-review.sh → 修正 → claude-review.sh で確認 | 脆弱性検出 → 修正提案 → 修正 → 再レビューで問題なし | 高 |
| TC-E2E-003 | 大規模コードベースのレビュー | 1000ファイル以上のリポジトリ | bash scripts/claude-review.sh --timeout 1800 実行 | タイムアウト内に完了、包括的なレポート生成 | 中 |
| TC-E2E-004 | 並列レビュー実行 | gitリポジトリが存在 | claude-review.sh と claude-security-review.sh を並列実行 | リソース競合なし、両方完了、個別レポート生成 | 中 |

## テスト実行方法

### 前提条件

```bash
# 必要なツールのインストール
sudo apt-get install -y bats kcov git

# テストディレクトリのセットアップ
mkdir -p tests/{unit,integration,e2e}
```

### ユニットテスト実行

#### claude-review.sh

```bash
# 全テスト実行
bats tests/unit/test-claude-review.bats

# 特定のテストケース実行
bats tests/unit/test-claude-review.bats -f "TC-R-001"

# カバレッジ付き実行
kcov --exclude-pattern=/usr coverage/unit/claude-review \
  bats tests/unit/test-claude-review.bats
```

#### claude-security-review.sh

```bash
# 全テスト実行
bats tests/unit/test-claude-security-review.bats

# セキュリティテストのみ実行
bats tests/unit/test-claude-security-review.bats -f "TC-S-3"

# カバレッジ付き実行
kcov --exclude-pattern=/usr coverage/unit/claude-security-review \
  bats tests/unit/test-claude-security-review.bats
```

### 統合テスト実行

```bash
# CLIスクリプト統合テスト
bash tests/integration/test-claude-cli-scripts.sh

# カバレッジ付き実行
kcov --exclude-pattern=/usr coverage/integration/cli-scripts \
  bash tests/integration/test-claude-cli-scripts.sh
```

### E2Eテスト実行

```bash
# E2Eワークフローテスト
bash tests/e2e/test-review-workflow.sh

# カバレッジ付き実行
kcov --exclude-pattern=/usr coverage/e2e/workflow \
  bash tests/e2e/test-review-workflow.sh
```

### 全テスト実行（CI用）

```bash
#!/bin/bash
# tests/run-all-tests.sh

set -e

echo "=== Running Unit Tests ==="
bats tests/unit/test-claude-review.bats
bats tests/unit/test-claude-security-review.bats

echo "=== Running Integration Tests ==="
bash tests/integration/test-claude-slash-commands.sh

echo "=== Running E2E Tests ==="
bash tests/e2e/test-review-workflow.sh

echo "=== Generating Coverage Report ==="
kcov --merge coverage/merged coverage/unit/* coverage/integration/* coverage/e2e/*

echo "=== All Tests Passed ==="
```

### カバレッジレポート確認

```bash
# HTMLレポート生成
kcov --merge coverage/merged coverage/unit/* coverage/integration/* coverage/e2e/*

# ブラウザで開く
xdg-open coverage/merged/index.html

# カバレッジ数値確認
grep "percent_covered" coverage/merged/index.json
```

## カバレッジ目標

### 目標値

| メトリクス | 目標値 | 現状 | ステータス |
|-----------|--------|------|-----------|
| 分岐網羅率 | 100% | 0% | 未実装 |
| 行網羅率 | 95%以上 | 0% | 未実装 |
| 関数網羅率 | 100% | 0% | 未実装 |
| テストケース総数 | 90+ | 0 | 未実装 |
| 正常系テスト | 17+ | 0 | 未実装 |
| 異常系テスト | 20+ | 0 | 未実装 |
| 境界値テスト | 15+ | 0 | 未実装 |
| セキュリティテスト | 15+ | 0 | 未実装 |
| E2Eテスト | 4+ | 0 | 未実装 |

### カバレッジ計測コマンド

```bash
# 分岐網羅率
kcov --branch-coverage coverage/branch tests/unit/test-claude-review.bats

# 行網羅率
kcov --line-coverage coverage/line tests/unit/test-claude-review.bats

# 関数網羅率
kcov --function-coverage coverage/function tests/unit/test-claude-review.bats
```

### カバレッジレポート例

```json
{
  "files": {
    "scripts/claude-review.sh": {
      "percent_covered": 98.5,
      "lines_covered": 642,
      "lines_instrumented": 652,
      "branches_covered": 156,
      "branches_instrumented": 156
    }
  },
  "percent_covered": 98.5,
  "lines_covered": 642,
  "lines_instrumented": 652
}
```

## テスト自動化

### GitHub Actions ワークフロー

```yaml
# .github/workflows/test-claude-review.yml
name: Claude Review Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y bats kcov

    - name: Run unit tests
      run: |
        bats tests/unit/test-claude-review.bats
        bats tests/unit/test-claude-security-review.bats

    - name: Run integration tests
      run: bash tests/integration/test-claude-slash-commands.sh

    - name: Run E2E tests
      run: bash tests/e2e/test-review-workflow.sh

    - name: Generate coverage report
      run: |
        kcov --merge coverage/merged coverage/unit/* coverage/integration/* coverage/e2e/*

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        files: coverage/merged/cobertura.xml
        fail_ci_if_error: true

    - name: Check coverage threshold
      run: |
        COVERAGE=$(grep "percent_covered" coverage/merged/index.json | sed 's/[^0-9.]//g')
        if (( $(echo "$COVERAGE < 95.0" | bc -l) )); then
          echo "Coverage $COVERAGE% is below threshold 95%"
          exit 1
        fi
```

## まとめ

このテスト仕様書では、以下を網羅的に定義しました:

1. **等価分割・境界値分析**: 入力値を体系的に分類し、境界値を特定
2. **90+テストケース**: 正常系、異常系、境界値、セキュリティテストを包括
3. **Given/When/Then形式**: 各テストケースを明確に記述
4. **失敗系≥正常系**: 異常系20+件、正常系17件で要件充足
5. **分岐網羅100%**: カバレッジ目標を明確化
6. **実行コマンド**: 各テストレベルでの実行方法を提供

次のステップは、このテスト仕様に基づいてテストコードを実装することです。
