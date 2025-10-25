# Multi-AI Orchestrium - Phase 9 実装計画

**作成日**: 2025-10-24
**基準**: 包括的プロジェクト監査レポート (Phase 9)
**総合品質スコア**: 82.5/100 (B+) → 目標: 90+/100 (A)

---

## 📊 実装計画サマリー

| フェーズ | 優先度 | 所要時間 | 期待効果 | 完了率 |
|---------|--------|---------|---------|--------|
| **Phase 9.1** | 🔴 CRITICAL | 1.5時間 | 品質 8.3→8.6/10 | ✅ 100% |
| **Phase 9.2** | 🟡 HIGH | 8-10時間 | 品質 8.6→9.2/10 | 🟡 22% (Task 2.1完了) |
| **Phase 9.3** | 🟢 MEDIUM | 5-8時間 | メンテナンス性向上 | 0% |
| **Phase 9.4** | 🔵 LOW | 15-20時間 | 国際化・可視化 | 0% |

**総所要時間**: 29.5-39.5時間
**総合品質向上**: 82.5/100 → 90+/100

---

## 🔴 Phase 9.1: 緊急対応項目（1.5時間）

**期限**: 即座
**担当**: 優先対応チーム
**期待効果**: ドキュメント品質 8.3 → 8.6/10

### 1.1 重複ドキュメントの削除（15分）

**目的**: 読者の混乱排除、メンテナンス負担軽減

#### タスクリスト

- [ ] **1.1.1** `docs/FILE_BASED_PROMPT_SYSTEM.md`を読み込み、内容を確認
  - [ ] アーキテクチャ図の有無確認
  - [ ] パフォーマンス指標の記載確認
  - [ ] セキュリティ考慮事項の記載確認

- [ ] **1.1.2** `docs/file-based-prompt-guide.md`を読み込み、差分を確認
  - [ ] 固有の内容があるか確認
  - [ ] 重複セクションをリスト化

- [ ] **1.1.3** 統合作業
  - [ ] `file-based-prompt-guide.md`の固有内容を`FILE_BASED_PROMPT_SYSTEM.md`に追加
  - [ ] セクション順序の最適化
  - [ ] 内部リンクの更新

- [ ] **1.1.4** クリーンアップ
  - [ ] `docs/file-based-prompt-guide.md`を削除
  - [ ] README.mdの参照を確認・更新
  - [ ] CLAUDE.mdの参照を確認・更新

- [ ] **1.1.5** 検証
  - [ ] すべてのドキュメントリンクが正常に機能するか確認
  - [ ] `git grep file-based-prompt-guide`で残存参照を検索

**成果物**:
- `docs/FILE_BASED_PROMPT_SYSTEM.md` (統合版)
- `docs/file-based-prompt-guide.md` (削除)

---

### 1.2 テスト実行ガイドの作成（1時間）

**目的**: ユーザーがテストを実行できるようにする

#### タスクリスト

- [ ] **1.2.1** テストファイルの調査
  - [ ] `tests/phase1-file-based-prompt-test.sh` - 実行方法確認
  - [ ] `tests/phase4-e2e-test.sh` - 実行方法確認
  - [ ] `tests/performance-benchmark.sh` - 実行方法確認（存在確認）
  - [ ] `tests/test_suite.sh` - 実行方法確認
  - [ ] その他テストファイルの確認

- [ ] **1.2.2** `tests/README.md`の構造設計
  - [ ] テスト概要セクション
  - [ ] 前提条件セクション（必要なツール、環境変数）
  - [ ] 各テストの説明セクション
  - [ ] トラブルシューティングセクション

- [ ] **1.2.3** `tests/README.md`の作成
  ```markdown
  # Multi-AI Orchestrium テストスイート

  ## 概要
  - Phase 1: ファイルベースプロンプトシステム統合テスト
  - Phase 4: E2Eワークフローテスト
  - Performance: パフォーマンスベンチマーク

  ## 前提条件
  - 必要なAI CLIツール（claude, gemini, qwen等）
  - Bash 4.0以上
  - 環境変数設定（WRAPPER_NON_INTERACTIVE=1等）

  ## テスト実行方法

  ### Phase 1統合テスト
  ```bash
  cd tests
  bash phase1-file-based-prompt-test.sh
  ```

  ### Phase 4 E2Eテスト
  ```bash
  cd tests
  WRAPPER_NON_INTERACTIVE=1 bash phase4-e2e-test.sh
  ```

  ## テスト結果の解釈
  - PASS: テスト成功
  - FAIL: テスト失敗（詳細はログ参照）

  ## トラブルシューティング
  - タイムアウトエラー → タイムアウト値を延長
  - AI CLI not found → check-multi-ai-tools.sh実行
  ```

- [ ] **1.2.4** 実行例の追加
  - [ ] Phase 1テストの期待出力サンプル
  - [ ] Phase 4テストの期待出力サンプル
  - [ ] エラー時の対処法

- [ ] **1.2.5** 検証
  - [ ] 実際にREADMEの手順通りにテストを実行
  - [ ] 初心者でも理解できる内容か確認
  - [ ] すべてのテストファイルがカバーされているか確認

**成果物**:
- `tests/README.md` (新規作成、推定200-300行)

---

### 1.3 README.mdのスクリプト数修正（5分）

**目的**: ドキュメントの正確性向上

#### タスクリスト

- [ ] **1.3.1** 現在のスクリプト数を再確認
  ```bash
  find bin -name "*.sh" | wc -l  # 期待: 10
  find scripts -name "*.sh" | wc -l  # 期待: 11
  find src -name "*.sh" | wc -l  # 期待: 14
  # 合計: 35
  ```

- [ ] **1.3.2** `README.md`を開き、該当箇所を検索
  - [ ] "36個"の記載を検索
  - [ ] "全シェルスクリプト"の記載箇所を特定

- [ ] **1.3.3** 修正実施
  ```diff
  - 全シェルスクリプト（36個）に実行権限を一括付与
  + 全シェルスクリプト（35個）に実行権限を一括付与
  ```

- [ ] **1.3.4** 他の箇所も確認
  - [ ] スクリプト数が記載されている他のセクションを検索
  - [ ] 必要に応じて修正

- [ ] **1.3.5** 検証
  - [ ] `git diff README.md`で変更内容確認
  - [ ] 変更が意図通りか確認

**成果物**:
- `README.md` (修正版)

---

### Phase 9.1 完了チェック

- [ ] **1.4.1** すべてのタスクが完了
- [ ] **1.4.2** Git commit作成
  ```bash
  git add docs/FILE_BASED_PROMPT_SYSTEM.md
  git rm docs/file-based-prompt-guide.md
  git add tests/README.md README.md
  git commit -m "docs: Phase 9.1 - Fix critical documentation issues

  - Remove duplicate file-based-prompt-guide.md
  - Add comprehensive tests/README.md
  - Fix script count in README.md (36→35)

  Quality improvement: 8.3/10 → 8.6/10"
  ```

- [ ] **1.4.3** 品質スコア再評価
  - [ ] ドキュメント完全性: 8.5 → 9.0/10
  - [ ] ドキュメント組織化: 8.0 → 9.0/10

---

## 🟡 Phase 9.2: 今月中対応項目（8-10時間）

**期限**: 2025-11-24
**担当**: 開発チーム
**期待効果**: ドキュメント品質 8.6 → 9.2/10、メンテナンス性 7.5 → 8.5/10

### 2.1 ShellCheck警告の解消（2時間）

**目的**: コード品質向上、静的解析エラー削減

#### タスクリスト

- [x] **2.1.1** ShellCheckのインストール確認
  ```bash
  shellcheck --version || sudo apt-get install shellcheck
  ```

- [x] **2.1.2** SC2155警告の全箇所を特定
  ```bash
  shellcheck bin/claude-wrapper.sh 2>&1 | grep SC2155
  shellcheck bin/gemini-wrapper.sh 2>&1 | grep SC2155
  shellcheck bin/amp-wrapper.sh 2>&1 | grep SC2155
  shellcheck bin/qwen-wrapper.sh 2>&1 | grep SC2155
  shellcheck bin/droid-wrapper.sh 2>&1 | grep SC2155
  shellcheck bin/codex-wrapper.sh 2>&1 | grep SC2155
  shellcheck bin/cursor-wrapper.sh 2>&1 | grep SC2155
  ```

- [x] **2.1.3** `bin/claude-wrapper.sh`の修正
  - [x] Line 87の修正
    ```bash
    # 修正前
    local start_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")

    # 修正後
    local start_time
    start_time=$(get_timestamp_ms 2>/dev/null || echo "$(date +%s)000")
    ```
  - [x] Line 142の修正（同様）
  - [x] Line 178の修正（同様）

- [x] **2.1.4** 他の6つのラッパーにも同様の修正を適用
  - [x] `bin/gemini-wrapper.sh`
  - [x] `bin/amp-wrapper.sh`
  - [x] `bin/qwen-wrapper.sh`
  - [x] `bin/droid-wrapper.sh`
  - [x] `bin/codex-wrapper.sh`
  - [x] `bin/cursor-wrapper.sh`

- [x] **2.1.5** 修正の検証
  ```bash
  for wrapper in bin/*-wrapper.sh; do
    echo "Checking $wrapper..."
    shellcheck "$wrapper" 2>&1 | grep SC2155 || echo "  ✓ No SC2155 warnings"
  done
  ```

- [x] **2.1.6** 動作確認
  - [x] 各ラッパーが正常に動作するか確認
  - [x] タイムスタンプが正しく取得されるか確認

- [x] **2.1.7** テスト実行 ✅
  ```bash
  bash tests/phase1-file-based-prompt-test.sh
  # Results: 66/66 tests passed (100% pass rate)
  ```

**成果物**:
- 7つのラッパースクリプト（SC2155警告解消版）

---

### 2.2 AIラッパースクリプトのリファクタリング（3-4時間）

**目的**: コード重複60%削減、メンテナンス性向上

#### 2.2.1 共通ライブラリの設計（1時間）

- [ ] **2.2.1.1** 共通パターンの抽出
  ```bash
  # 7つのラッパーの共通ロジックを特定
  diff -u bin/claude-wrapper.sh bin/qwen-wrapper.sh | grep -A 5 "^-"
  ```

- [ ] **2.2.1.2** `bin/common-wrapper-lib.sh`の構造設計
  ```markdown
  共通機能:
  1. AGENTS.md統合（classify_task, get_task_timeout）
  2. VibeLogger統合（vibe_wrapper_start, vibe_wrapper_done）
  3. タイムアウト管理（WRAPPER_SKIP_TIMEOUT処理）
  4. 承認プロンプト（requires_approval処理）
  5. エラーハンドリング（標準化されたエラー処理）
  ```

- [ ] **2.2.1.3** 関数シグネチャの設計
  ```bash
  # run_ai_wrapper()のシグネチャ
  # Args:
  #   $1: AI名 (e.g., "Claude", "Gemini")
  #   $2: CLIバイナリパス (e.g., "claude", "/usr/local/bin/gemini")
  #   $3: ベースタイムアウト（秒）
  #   $4: プロンプト
  #   $5: オプション引数（-y, --stream-json等）
  ```

#### 2.2.2 共通ライブラリの実装（1.5時間）

- [ ] **2.2.2.1** `bin/common-wrapper-lib.sh`の作成
  - [ ] ヘッダーコメント
  - [ ] 依存関係のsource（agents-utils.sh, vibe-logger-lib.sh）
  - [ ] `run_ai_wrapper()`関数の実装
  - [ ] エラーハンドリング関数の実装
  - [ ] ログ出力関数の実装

- [ ] **2.2.2.2** テスト用スクリプトの作成
  ```bash
  # tests/test-common-wrapper.sh
  source bin/common-wrapper-lib.sh
  run_ai_wrapper "TestAI" "echo" 60 "test prompt"
  ```

- [ ] **2.2.2.3** 動作確認
  - [ ] シンプルなケースでの動作確認
  - [ ] エラーケースのハンドリング確認
  - [ ] VibeLoggerの出力確認

#### 2.2.3 ラッパースクリプトの移行（1-1.5時間）

- [ ] **2.2.3.1** `bin/claude-wrapper.sh`の簡略化
  ```bash
  #!/usr/bin/env bash
  set -euo pipefail

  # Load common library
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "${SCRIPT_DIR}/common-wrapper-lib.sh"

  # AI-specific configuration
  CLAUDE_BIN="${CLAUDE_BIN:-claude}"
  BASE_TIMEOUT=120

  # Execute wrapper
  run_ai_wrapper "Claude" "$CLAUDE_BIN" "$BASE_TIMEOUT" "$@"
  ```

- [ ] **2.2.3.2** 他の6つのラッパーも同様に簡略化
  - [ ] `bin/gemini-wrapper.sh`
  - [ ] `bin/amp-wrapper.sh`
  - [ ] `bin/qwen-wrapper.sh`
  - [ ] `bin/droid-wrapper.sh`
  - [ ] `bin/codex-wrapper.sh`
  - [ ] `bin/cursor-wrapper.sh`

- [ ] **2.2.3.3** 各ラッパーの動作確認
  ```bash
  for wrapper in bin/*-wrapper.sh; do
    echo "Testing $wrapper..."
    bash "$wrapper" --prompt "test" || echo "  ✗ Failed"
  done
  ```

- [ ] **2.2.3.4** Phase 1テストの実行
  ```bash
  bash tests/phase1-file-based-prompt-test.sh
  ```

**成果物**:
- `bin/common-wrapper-lib.sh` (新規、推定300-400行)
- 7つの簡略化されたラッパースクリプト（各50-80行）
- コード削減: 1400行 → 600行（60%削減達成）

---

### 2.3 関数APIリファレンスの作成（3-4時間）

**目的**: 開発者向けドキュメント充実、コード理解の容易化

#### 2.3.1 関数の棚卸し（1時間）

- [ ] **2.3.1.1** 主要ライブラリの関数リスト作成
  ```bash
  # scripts/orchestrate/lib/multi-ai-core.sh (15関数)
  grep "^[a-zA-Z_][a-zA-Z0-9_]*() {" scripts/orchestrate/lib/multi-ai-core.sh

  # scripts/orchestrate/lib/multi-ai-ai-interface.sh (8関数)
  grep "^[a-zA-Z_][a-zA-Z0-9_]*() {" scripts/orchestrate/lib/multi-ai-ai-interface.sh

  # scripts/orchestrate/lib/multi-ai-config.sh (16関数)
  grep "^[a-zA-Z_][a-zA-Z0-9_]*() {" scripts/orchestrate/lib/multi-ai-config.sh

  # scripts/orchestrate/lib/multi-ai-workflows.sh (13関数)
  grep "^[a-zA-Z_][a-zA-Z0-9_]*() {" scripts/orchestrate/lib/multi-ai-workflows.sh

  # scripts/lib/sanitize.sh
  # bin/vibe-logger-lib.sh
  # bin/agents-utils.sh
  ```

- [ ] **2.3.1.2** 関数を機能別にグループ化
  ```markdown
  1. コアユーティリティ (multi-ai-core.sh)
  2. AI インターフェース (multi-ai-ai-interface.sh)
  3. 設定管理 (multi-ai-config.sh)
  4. ワークフロー (multi-ai-workflows.sh)
  5. セキュリティ (sanitize.sh)
  6. ロギング (vibe-logger-lib.sh)
  7. タスク分類 (agents-utils.sh)
  ```

- [ ] **2.3.1.3** 優先度付け
  - [ ] 高優先度: 公開API（ユーザーが直接呼び出す）
  - [ ] 中優先度: 内部API（スクリプト間で呼び出す）
  - [ ] 低優先度: ヘルパー関数

#### 2.3.2 APIリファレンスの構造設計（30分）

- [ ] **2.3.2.1** `docs/API_REFERENCE.md`の構造
  ```markdown
  # Multi-AI Orchestrium API リファレンス

  ## 目次
  1. [ワークフロー関数](#ワークフロー関数)
  2. [AI インターフェース](#ai-インターフェース)
  3. [設定管理](#設定管理)
  4. [セキュリティ](#セキュリティ)
  5. [ロギング](#ロギング)
  6. [ユーティリティ](#ユーティリティ)

  ## ワークフロー関数

  ### multi-ai-full-orchestrate
  **説明**: フルオーケストレーションワークフロー実行
  **引数**:
    - `$1` (string): タスク説明
    - `$2` (string, optional): プロファイル名（デフォルト: balanced-multi-ai）
  **戻り値**:
    - `0`: 成功
    - `1`: 失敗
  **使用例**:
    ```bash
    source scripts/orchestrate/orchestrate-multi-ai.sh
    multi-ai-full-orchestrate "新機能開発"
    ```
  **依存関数**: execute_yaml_workflow, log_phase_start
  **ファイル**: scripts/orchestrate/lib/multi-ai-workflows.sh:123-156
  ```

- [ ] **2.3.2.2** 標準化されたフォーマット定義
  ```markdown
  各関数の記載項目:
  - 説明（1-2行）
  - 引数（型、必須/オプション、デフォルト値）
  - 戻り値（終了コード、標準出力）
  - 使用例（実行可能なコード）
  - 依存関数（呼び出す他の関数）
  - ファイル（ファイル名と行番号）
  - 備考（注意事項、制限事項）
  ```

#### 2.3.3 APIリファレンスの執筆（1.5-2時間）

- [ ] **2.3.3.1** ワークフローセクション（10関数）
  - [ ] `multi-ai-full-orchestrate`
  - [ ] `multi-ai-speed-prototype`
  - [ ] `multi-ai-enterprise-quality`
  - [ ] `multi-ai-hybrid-development`
  - [ ] `multi-ai-chatdev-develop`
  - [ ] `multi-ai-discuss-before`
  - [ ] `multi-ai-review-after`
  - [ ] `multi-ai-coa-analyze`
  - [ ] `multi-ai-consensus-review`
  - [ ] `multi-ai-code-review`

- [ ] **2.3.3.2** AI インターフェースセクション（8関数）
  - [ ] `call_ai`
  - [ ] `call_ai_with_context`
  - [ ] `execute_with_fallback`
  - [ ] `supports_file_input`
  - [ ] `create_secure_prompt_file`
  - [ ] `cleanup_prompt_file`
  - [ ] その他

- [ ] **2.3.3.3** セキュリティセクション（10関数）
  - [ ] `sanitize_input`
  - [ ] `sanitize_input_for_file`
  - [ ] `sanitize_workflow_prompt`
  - [ ] `sanitize_with_fallback`
  - [ ] `sanitize_log_output`
  - [ ] その他

- [ ] **2.3.3.4** ロギングセクション（15関数）
  - [ ] `vibe_log`
  - [ ] `vibe_wrapper_start`
  - [ ] `vibe_wrapper_done`
  - [ ] `vibe_tdd_cycle_start`
  - [ ] その他

- [ ] **2.3.3.5** その他のセクション（残り関数）
  - [ ] 設定管理関数
  - [ ] ユーティリティ関数
  - [ ] タスク分類関数

#### 2.3.4 検証とレビュー（30分）

- [ ] **2.3.4.1** 使用例の動作確認
  - [ ] すべてのコード例が実行可能か確認
  - [ ] 引数と戻り値が正確か確認

- [ ] **2.3.4.2** 内部リンクの確認
  - [ ] 目次からのリンクが正常か確認
  - [ ] 関数間の相互参照が正確か確認

- [ ] **2.3.4.3** 完全性の確認
  - [ ] すべての公開関数が記載されているか確認
  - [ ] 漏れがないか再チェック

**成果物**:
- `docs/API_REFERENCE.md` (新規、推定800-1200行)

---

### Phase 9.2 完了チェック

- [ ] **2.4.1** すべてのタスクが完了
- [ ] **2.4.2** Git commit作成
  ```bash
  git add bin/*.sh docs/API_REFERENCE.md
  git commit -m "refactor: Phase 9.2 - Code quality and documentation improvements

  - Fix ShellCheck SC2155 warnings (7 wrappers)
  - Refactor AI wrappers with common library (60% code reduction)
  - Add comprehensive API reference (55+ functions)

  Code quality improvement:
  - Lines of code: 1400 → 600 (60% reduction)
  - Maintainability: 7.5/10 → 8.5/10
  - Documentation: 8.6/10 → 9.2/10"
  ```

- [ ] **2.4.3** 品質スコア再評価
  - [ ] メンテナンス性: 7.5 → 8.5/10
  - [ ] ドキュメント品質: 8.6 → 9.2/10
  - [ ] コード品質: 8.0 → 8.5/10

---

## 🟢 Phase 9.3: 中期改善項目（5-8時間）

**期限**: 2025-12-15
**担当**: リファクタリングチーム
**期待効果**: メンテナンス性 8.5 → 9.0/10

### 3.1 multi-ai-workflows.shの分割（3-4時間）

**目的**: 大規模ファイルの分割、モジュール性向上

#### タスクリスト

- [ ] **3.1.1** 現状分析
  - [ ] `multi-ai-workflows.sh`の関数リスト作成（13関数）
  - [ ] 関数の依存関係マッピング
  - [ ] 機能別グループ化

- [ ] **3.1.2** 分割戦略の決定
  ```markdown
  提案:
  - workflows-chatdev.sh (4関数、~500行)
  - workflows-coa.sh (3関数、~400行)
  - workflows-hybrid.sh (3関数、~500行)
  - workflows-review.sh (3関数、~400行)
  ```

- [ ] **3.1.3** `workflows-chatdev.sh`の作成
  - [ ] `multi-ai-chatdev-develop`
  - [ ] `multi-ai-discuss-before`
  - [ ] `chatdev_phase_*`ヘルパー関数
  - [ ] テスト実行

- [ ] **3.1.4** `workflows-coa.sh`の作成
  - [ ] `multi-ai-coa-analyze`
  - [ ] CoA関連ヘルパー関数
  - [ ] テスト実行

- [ ] **3.1.5** `workflows-hybrid.sh`の作成
  - [ ] `multi-ai-hybrid-development`
  - [ ] `multi-ai-full-orchestrate`
  - [ ] ハイブリッド関連ヘルパー
  - [ ] テスト実行

- [ ] **3.1.6** `workflows-review.sh`の作成
  - [ ] `multi-ai-review-after`
  - [ ] `multi-ai-consensus-review`
  - [ ] `multi-ai-code-review`
  - [ ] テスト実行

- [ ] **3.1.7** `orchestrate-multi-ai.sh`の更新
  ```bash
  # 分割されたワークフローをsource
  source "${_ORCHESTRATE_LIB_DIR}/workflows-chatdev.sh"
  source "${_ORCHESTRATE_LIB_DIR}/workflows-coa.sh"
  source "${_ORCHESTRATE_LIB_DIR}/workflows-hybrid.sh"
  source "${_ORCHESTRATE_LIB_DIR}/workflows-review.sh"
  ```

- [ ] **3.1.8** 統合テスト
  - [ ] すべてのワークフローが正常に動作するか確認
  - [ ] Phase 4 E2Eテストの実行

- [ ] **3.1.9** `multi-ai-workflows.sh`の削除
  ```bash
  git rm scripts/orchestrate/lib/multi-ai-workflows.sh
  ```

**成果物**:
- `scripts/orchestrate/lib/workflows-chatdev.sh` (~500行)
- `scripts/orchestrate/lib/workflows-coa.sh` (~400行)
- `scripts/orchestrate/lib/workflows-hybrid.sh` (~500行)
- `scripts/orchestrate/lib/workflows-review.sh` (~400行)

---

### 3.2 コードドキュメントの標準化（2-3時間）

**目的**: 関数ドキュメントの統一、可読性向上

#### タスクリスト

- [ ] **3.2.1** ドキュメント標準の定義
  ```bash
  # 標準フォーマット
  # function_name()
  # 説明: 関数の目的（1-2行）
  #
  # Args:
  #   $1 (type): 引数の説明
  #   $2 (type, optional): オプション引数の説明（デフォルト: 値）
  #
  # Returns:
  #   0: 成功
  #   1: 失敗
  #
  # Side effects:
  #   - グローバル変数への影響
  #   - ファイルシステムへの影響
  #
  # Example:
  #   function_name "arg1" "arg2"
  ```

- [ ] **3.2.2** 主要関数へのドキュメント追加
  - [ ] `multi-ai-core.sh`の15関数
  - [ ] `multi-ai-ai-interface.sh`の8関数
  - [ ] `multi-ai-config.sh`の16関数
  - [ ] 新規ワークフローファイル（4ファイル）

- [ ] **3.2.3** 既存コメントの更新
  - [ ] 古い形式のコメントを標準形式に変換
  - [ ] 不正確な情報の修正

- [ ] **3.2.4** 検証
  - [ ] すべての公開関数にドキュメントがあるか確認
  - [ ] フォーマットが統一されているか確認

**成果物**:
- 標準化されたコードドキュメント（55+関数）

---

### 3.3 インデックスドキュメントの作成（1時間）

**目的**: ドキュメントナビゲーション改善

#### タスクリスト

- [ ] **3.3.1** `docs/INDEX.md`の作成
  ```markdown
  # Multi-AI Orchestrium ドキュメント索引

  ## 🚀 はじめに
  - [README.md](../README.md) - プロジェクト概要
  - [CLAUDE.md](../CLAUDE.md) - アーキテクチャガイド

  ## 📖 ユーザーガイド
  - [インストールガイド](../README.md#導入手順)
  - [クイックスタート](../README.md#使用例)
  - [ワークフロー実行](../CLAUDE.md#ワークフローの実行)

  ## 🔧 開発者向け
  - [API リファレンス](API_REFERENCE.md)
  - [設定ガイド](../CLAUDE.md#設定システム)
  - [テストガイド](../tests/README.md)

  ## 📚 技術ドキュメント
  - [ファイルベースプロンプトシステム](FILE_BASED_PROMPT_SYSTEM.md)
  - [マイグレーションガイド](MIGRATION_GUIDE_v3.2.md)

  ## 🔍 監査レポート
  - [品質監査レポート](DOCUMENTATION_QUALITY_AUDIT_20251024.md)
  - [監査サマリー](DOCUMENTATION_AUDIT_SUMMARY.txt)

  ## 📋 実装計画
  - [Phase 9実装計画](IMPLEMENTATION_PLAN_PHASE9.md)
  ```

- [ ] **3.3.2** README.mdへのリンク追加
  - [ ] "ドキュメント"セクションに`docs/INDEX.md`へのリンク追加

- [ ] **3.3.3** CLAUDE.mdへのリンク追加
  - [ ] "ドキュメント"参照セクションに索引リンク追加

**成果物**:
- `docs/INDEX.md` (新規、~100行)

---

### Phase 9.3 完了チェック

- [ ] **3.4.1** すべてのタスクが完了
- [ ] **3.4.2** Git commit作成
  ```bash
  git add scripts/orchestrate/lib/workflows-*.sh docs/INDEX.md
  git rm scripts/orchestrate/lib/multi-ai-workflows.sh
  git commit -m "refactor: Phase 9.3 - Modularize workflows and improve navigation

  - Split multi-ai-workflows.sh into 4 modules
  - Standardize function documentation (ARGS/RETURNS format)
  - Add docs/INDEX.md for navigation

  Maintainability improvement: 8.5/10 → 9.0/10"
  ```

- [ ] **3.4.3** 品質スコア再評価
  - [ ] メンテナンス性: 8.5 → 9.0/10
  - [ ] ドキュメント組織化: 9.0 → 9.5/10

---

## 🔵 Phase 9.4: 長期改善項目（15-20時間）

**期限**: 2026-03-31
**担当**: 拡張機能チーム
**期待効果**: 国際化、可視化、総合品質 90+/100達成

### 4.1 アーキテクチャ図の作成（4-5時間）

**目的**: ビジュアル理解の促進

#### タスクリスト

- [ ] **4.1.1** ツールの選定
  - [ ] Mermaid.js（Markdown埋め込み可能）
  - [ ] PlantUML
  - [ ] Draw.io

- [ ] **4.1.2** 7AI協調フロー図の作成
  ```mermaid
  graph TB
    A[Claude - CTO] --> B[戦略設計]
    C[Gemini - CIO] --> D[調査・分析]
    E[Amp - PM] --> F[プロジェクト管理]
    G[Qwen] --> H[高速プロトタイプ]
    I[Droid] --> J[エンタープライズ実装]
    K[Codex] --> L[コードレビュー]
    M[Cursor] --> N[IDE統合]

    B --> O[統合]
    D --> O
    F --> O
    H --> O
    J --> O
    L --> O
    N --> O
  ```

- [ ] **4.1.3** YAML駆動ワークフロー図
  - [ ] プロファイル読み込み
  - [ ] フェーズ実行
  - [ ] 並列/順次処理
  - [ ] 出力統合

- [ ] **4.1.4** ファイルベースプロンプトシステム図
  - [ ] サイズ判定フロー
  - [ ] ルーティング決定
  - [ ] セキュリティ処理

- [ ] **4.1.5** 図の統合
  - [ ] `docs/ARCHITECTURE.md`に埋め込み
  - [ ] README.mdに概要図追加

**成果物**:
- `docs/ARCHITECTURE.md` (新規、図5-7個、500-700行)

---

### 4.2 英語版ドキュメントの作成（8-10時間）

**目的**: 国際化、海外開発者へのアプローチ

#### タスクリスト

- [ ] **4.2.1** README.mdの英訳
  - [ ] 概要セクション
  - [ ] インストール手順
  - [ ] 使用例
  - [ ] ライセンス

- [ ] **4.2.2** CLAUDE.mdの英訳
  - [ ] アーキテクチャ概要
  - [ ] プロジェクト構造
  - [ ] ワークフロー実行
  - [ ] 設定システム

- [ ] **4.2.3** API_REFERENCE.mdの英訳
  - [ ] すべての関数ドキュメント
  - [ ] 使用例

- [ ] **4.2.4** その他ドキュメントの英訳
  - [ ] FILE_BASED_PROMPT_SYSTEM.md
  - [ ] MIGRATION_GUIDE_v3.2.md
  - [ ] tests/README.md

- [ ] **4.2.5** 多言語対応の構造化
  ```
  docs/
  ├── en/
  │   ├── README.md
  │   ├── CLAUDE.md
  │   ├── API_REFERENCE.md
  │   └── ...
  └── ja/
      ├── README.md (existing)
      ├── CLAUDE.md (existing)
      └── ...
  ```

- [ ] **4.2.6** ルートREADME.mdの更新
  - [ ] 言語切り替えリンクの追加
  - [ ] Badge追加（英語/日本語）

**成果物**:
- 英語版ドキュメント（5-7ファイル、3000-4000行）

---

### 4.3 Contributing Guidelinesの作成（2-3時間）

**目的**: オープンソース貢献の促進

#### タスクリスト

- [ ] **4.3.1** `CONTRIBUTING.md`の作成
  ```markdown
  # Contributing to Multi-AI Orchestrium

  ## Code of Conduct

  ## How to Contribute

  ### Reporting Bugs

  ### Suggesting Enhancements

  ### Pull Request Process

  ### Coding Standards
  - Bash best practices
  - ShellCheck compliance
  - Function documentation (ARGS/RETURNS)

  ### Commit Message Guidelines
  - Conventional Commits
  - Co-Authored-By: Claude

  ### Testing Requirements
  - Phase 1 tests must pass
  - Add tests for new features
  ```

- [ ] **4.3.2** Issue/PR テンプレートの作成
  - [ ] `.github/ISSUE_TEMPLATE/bug_report.md`
  - [ ] `.github/ISSUE_TEMPLATE/feature_request.md`
  - [ ] `.github/PULL_REQUEST_TEMPLATE.md`

**成果物**:
- `CONTRIBUTING.md` (新規、300-500行)
- GitHubテンプレート（3ファイル）

---

### Phase 9.4 完了チェック

- [ ] **4.4.1** すべてのタスクが完了
- [ ] **4.4.2** Git commit作成
  ```bash
  git add docs/ARCHITECTURE.md docs/en/ CONTRIBUTING.md .github/
  git commit -m "feat: Phase 9.4 - Internationalization and visualization

  - Add architecture diagrams (Mermaid.js)
  - Add English documentation (5 files)
  - Add CONTRIBUTING.md and GitHub templates

  International reach: Enabled
  Quality score: 82.5/100 → 90+/100"
  ```

- [ ] **4.4.3** 最終品質スコア評価
  - [ ] 総合品質: 82.5 → 90+/100
  - [ ] ドキュメント品質: 9.2 → 9.5/10
  - [ ] アクセシビリティ: 8.0 → 9.5/10

---

## 📊 進捗トラッキング

### 全体進捗

- [ ] Phase 9.1: 緊急対応（1.5時間） - **0% 完了**
- [ ] Phase 9.2: 今月中対応（8-10時間） - **0% 完了**
- [ ] Phase 9.3: 中期改善（5-8時間） - **0% 完了**
- [ ] Phase 9.4: 長期改善（15-20時間） - **0% 完了**

**総合進捗**: 0/4 フェーズ完了 (**0%**)

### マイルストーン

- [ ] **M1**: ドキュメント品質 8.6/10達成（Phase 9.1完了）
- [ ] **M2**: ドキュメント品質 9.2/10達成（Phase 9.2完了）
- [ ] **M3**: メンテナンス性 9.0/10達成（Phase 9.3完了）
- [ ] **M4**: 総合品質 90+/100達成（Phase 9.4完了）

---

## 🎯 成功基準

### Phase 9.1成功基準
- [x] 重複ドキュメント削除完了
- [ ] tests/README.md作成完了
- [ ] README.md修正完了
- [ ] ドキュメント品質 8.6/10以上

### Phase 9.2成功基準
- [ ] ShellCheck警告ゼロ
- [ ] コード削減60%達成
- [ ] API_REFERENCE.md作成完了
- [ ] ドキュメント品質 9.2/10以上
- [ ] メンテナンス性 8.5/10以上

### Phase 9.3成功基準
- [ ] multi-ai-workflows.sh分割完了
- [ ] 標準化ドキュメント完了
- [ ] docs/INDEX.md作成完了
- [ ] メンテナンス性 9.0/10以上

### Phase 9.4成功基準
- [ ] アーキテクチャ図完成
- [ ] 英語版ドキュメント完成
- [ ] CONTRIBUTING.md完成
- [ ] 総合品質 90+/100達成

---

## 📝 メモ

- このドキュメントは進捗に応じて更新すること
- 各タスク完了時にチェックマークを付けること
- 課題や変更事項はこのセクションに記録すること

---

**最終更新**: 2025-10-24
**作成者**: Claude Code (Multi-AI Orchestrium Quality-Checker Agent)
**ステータス**: 実装計画承認待ち
