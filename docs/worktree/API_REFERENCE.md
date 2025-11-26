# Git Worktrees API リファレンス

**バージョン:** v1.0
**最終更新:** 2025-11-08
**対象:** Multi-AI Orchestrium Worktree統合システム

---

## 📚 目次

1. [概要](#概要)
2. [ライブラリ構成](#ライブラリ構成)
3. [worktree-core.sh](#worktree-coresh) - コアWorktree操作
4. [worktree-state.sh](#worktree-statesh) - 状態管理
5. [worktree-history.sh](#worktree-historysh) - 実行履歴追跡
6. [worktree-metrics.sh](#worktree-metricssh) - メトリクス収集
7. [worktree-merge.sh](#worktree-mergesh) - マージ戦略
8. [worktree-execution.sh](#worktree-executionsh) - 実行管理
9. [worktree-cleanup.sh](#worktree-cleanupsh) - クリーンアップ
10. [worktree-errors.sh](#worktree-errorssh) - エラー処理
11. [使用例](#使用例)

---

## 概要

Git Worktrees統合システムは、7つのAI（Claude、Gemini、Amp、Qwen、Droid、Codex、Cursor）を独立したGit Worktreeで並列実行するためのBashライブラリ集です。

**主な特徴:**
- ✅ ファイル競合なしの完全並列実行
- ✅ 並列度制御（最大7 worktrees、デフォルト4）
- ✅ NDJSON形式の状態管理
- ✅ 自動エラーリカバリー
- ✅ 包括的なメトリクス収集

**依存関係:**
- Bash 4.0以上
- Git 2.5以上（git worktree サポート）
- jq 1.5以上（JSON処理）

---

## ライブラリ構成

| ライブラリ | 関数数 | 責務 |
|-----------|--------|------|
| worktree-core.sh | 10 | Worktree作成・削除・検証 |
| worktree-state.sh | 8 | NDJSON状態ファイル管理 |
| worktree-history.sh | 7 | 実行履歴追跡・統計分析 |
| worktree-metrics.sh | 7 | パフォーマンスメトリクス収集 |
| worktree-merge.sh | 6 | マージ戦略・競合解決 |
| worktree-execution.sh | 16 | AI実行管理・リカバリー |
| worktree-cleanup.sh | 6 | trap管理・クリーンアップ |
| worktree-errors.sh | 12 | エラーコード定義・出力 |
| **合計** | **72** | - |

---

## worktree-core.sh

**責務:** Worktreeの作成、削除、検証、並列実行制御

**依存関係:**
```bash
source "$SCRIPT_DIR/../../../bin/vibe-logger-lib.sh"
source "$SCRIPT_DIR/worktree-errors.sh"
source "$SCRIPT_DIR/worktree-state.sh"
```

**グローバル変数:**
```bash
WORKTREE_BASE_DIR="${WORKTREE_BASE_DIR:-worktrees}"  # Worktreeベースディレクトリ
MAX_PARALLEL_WORKTREES="${MAX_PARALLEL_WORKTREES:-4}"  # 並列度（1-7）
WORKTREE_LOCK_FILE="/tmp/multi-ai-worktree.lock"     # ロックファイル
```

### create_worktree()

Worktreeを作成してブランチをチェックアウトします。

**シグネチャ:**
```bash
create_worktree <ai-name> <worktree-path> [branch-name]
```

**引数:**
- `$1` - AI名（claude|gemini|amp|qwen|droid|codex|cursor）
- `$2` - Worktree作成先パス
- `$3` - ブランチ名（省略時: `ai/<ai-name>/<timestamp>`）

**戻り値:**
- `0` - 成功
- `1` - 失敗（エラーメッセージをstderrに出力）

**使用例:**
```bash
# 基本使用方法
create_worktree "qwen" "worktrees/qwen"

# カスタムブランチ名
create_worktree "claude" "worktrees/claude" "feature/new-analysis"

# タイムスタンプ付きブランチ（自動生成）
create_worktree "gemini" "worktrees/gemini"
# → ブランチ名: ai/gemini/20251108-120000
```

**内部動作:**
1. AI名の検証
2. 既存Worktreeのチェック
3. 状態を`creating`に設定
4. `git worktree add -b <branch> <path>`実行
5. 状態を`active`に設定
6. VibeLoggerでログ記録

---

### create_worktrees_parallel()

複数のWorktreeを並列作成します（Phase 1.3実装）。

**シグネチャ:**
```bash
create_worktrees_parallel <ai1> <ai2> [ai3] ...
```

**引数:**
- `$@` - AI名のリスト（スペース区切り）

**戻り値:**
- `0` - 全て成功
- `1` - 一部または全て失敗

**並列度:**
- 環境変数`MAX_PARALLEL_WORKTREES`で制御（デフォルト: 4）
- 最大7（AI数の上限）

**使用例:**
```bash
# 4並列でWorktree作成（デフォルト）
create_worktrees_parallel claude gemini amp qwen droid codex cursor

# 2並列に制限（CI環境）
export MAX_PARALLEL_WORKTREES=2
create_worktrees_parallel claude gemini

# 7並列（最大並列度）
export MAX_PARALLEL_WORKTREES=7
create_worktrees_parallel claude gemini amp qwen droid codex cursor
```

**パフォーマンス:**
- 7 Worktree順次作成: 約3.5秒
- 7 Worktree並列作成（4並列）: 約0.7秒（**5倍高速化**）

---

### verify_worktree()

Worktreeの存在と正常性を検証します。

**シグネチャ:**
```bash
verify_worktree <ai-name>
```

**引数:**
- `$1` - AI名

**戻り値:**
- `0` - Worktreeは存在し正常
- `1` - Worktreeが存在しないか異常

**検証項目:**
1. ディレクトリの存在確認
2. Gitリポジトリの確認（`.git`ファイル）
3. `git worktree list`での登録確認
4. ブランチのチェックアウト確認

**使用例:**
```bash
if verify_worktree "qwen"; then
  echo "Qwen worktree is ready"
else
  echo "Qwen worktree is missing or invalid"
  create_worktree "qwen" "worktrees/qwen"
fi
```

---

### list_active_worktrees()

現在アクティブなWorktreeの一覧を取得します。

**シグネチャ:**
```bash
list_active_worktrees
```

**引数:** なし

**戻り値:**
- `0` - 成功（一覧をstdoutに出力）
- `1` - 失敗

**出力形式:**
```
worktrees/claude  ai/claude/20251108-120000
worktrees/gemini  ai/gemini/20251108-120001
worktrees/qwen    ai/qwen/20251108-120002
```

**使用例:**
```bash
# 一覧表示
list_active_worktrees

# アクティブ数をカウント
count=$(list_active_worktrees | wc -l)
echo "Active worktrees: $count"

# 各Worktreeに対して処理
list_active_worktrees | while read -r path branch; do
  echo "Processing $path ($branch)"
done
```

---

### その他の関数

| 関数名 | 説明 |
|--------|------|
| `acquire_worktree_lock()` | グローバルロックを取得 |
| `release_worktree_lock()` | グローバルロックを解放 |
| `cleanup_stale_locks()` | 古いロックファイルを削除 |
| `get_worktree_path()` | AI名からWorktreeパスを取得 |
| `get_worktree_branch()` | AI名からブランチ名を取得 |
| `is_worktree_active()` | Worktreeがアクティブか確認 |

---

## worktree-state.sh

**責務:** NDJSON形式の状態ファイル管理、状態遷移検証

**状態定義:**
```
none → creating → active → cleaning → none
           ↓         ↓
        error    error
```

**状態ファイル形式:**
```json
{"timestamp":"2025-11-08T12:00:00Z","ai":"qwen","state":"creating","branch":"ai/qwen/20251108-120000","worktree":"worktrees/qwen"}
{"timestamp":"2025-11-08T12:00:01Z","ai":"qwen","state":"active","branch":"ai/qwen/20251108-120000","worktree":"worktrees/qwen"}
```

### update_worktree_state()

Worktreeの状態を更新します（NDJSON形式で追記）。

**シグネチャ:**
```bash
update_worktree_state <ai-name> <state> [branch] [worktree-path]
```

**引数:**
- `$1` - AI名
- `$2` - 状態（none|creating|active|cleaning|error）
- `$3` - ブランチ名（省略可）
- `$4` - Worktreeパス（省略可）

**戻り値:**
- `0` - 成功
- `1` - 無効な状態遷移

**使用例:**
```bash
# Worktree作成開始
update_worktree_state "qwen" "creating" "ai/qwen/20251108-120000" "worktrees/qwen"

# アクティブ状態に遷移
update_worktree_state "qwen" "active"

# クリーンアップ開始
update_worktree_state "qwen" "cleaning"

# クリーンアップ完了
update_worktree_state "qwen" "none"
```

---

### get_worktree_state()

現在の状態を取得します。

**シグネチャ:**
```bash
get_worktree_state <ai-name>
```

**引数:**
- `$1` - AI名

**戻り値:**
- `0` - 成功（状態をstdoutに出力）
- `1` - 失敗

**出力:** `none`|`creating`|`active`|`cleaning`|`error`

**使用例:**
```bash
state=$(get_worktree_state "qwen")
if [[ "$state" == "active" ]]; then
  echo "Qwen worktree is active"
fi
```

---

### validate_worktree_state_transition()

状態遷移の妥当性を検証します。

**シグネチャ:**
```bash
validate_worktree_state_transition <current-state> <new-state>
```

**引数:**
- `$1` - 現在の状態
- `$2` - 新しい状態

**戻り値:**
- `0` - 有効な遷移
- `1` - 無効な遷移

**許可される遷移:**
```
none      → creating
creating  → active, error
active    → cleaning, error
cleaning  → none, error
error     → none
```

**使用例:**
```bash
if validate_worktree_state_transition "$current" "$new"; then
  echo "Valid transition: $current → $new"
else
  echo "ERROR: Invalid transition: $current → $new" >&2
  exit 1
fi
```

---

### その他の関数

| 関数名 | 説明 |
|--------|------|
| `get_all_worktree_states()` | 全AI状態を取得 |
| `is_valid_state()` | 状態値の妥当性確認 |
| `get_worktree_state_value()` | JSONから状態値を抽出 |
| `get_previous_worktree_state()` | 前回の状態を取得 |
| `reset_all_worktree_states()` | 全状態をnoneにリセット |

---

## worktree-history.sh

**責務:** 実行履歴の記録、統計分析、レポート生成

**履歴ファイル形式:**
```bash
logs/worktree-history/YYYYMMDD/history.ndjson
```

**NDJSON例:**
```json
{"timestamp":"2025-11-08T12:00:00Z","workflow":"multi-ai-full-orchestrate","ai":"qwen","event":"start","branch":"ai/qwen/20251108-120000"}
{"timestamp":"2025-11-08T12:05:30Z","workflow":"multi-ai-full-orchestrate","ai":"qwen","event":"end","status":"success","duration":330}
```

### record_worktree_execution_start()

Worktree実行開始を記録します。

**シグネチャ:**
```bash
record_worktree_execution_start <workflow-name> <ai-name> [branch-name]
```

**引数:**
- `$1` - ワークフロー名
- `$2` - AI名
- `$3` - ブランチ名（省略可）

**戻り値:**
- `0` - 成功

**使用例:**
```bash
record_worktree_execution_start "multi-ai-full-orchestrate" "qwen" "ai/qwen/20251108-120000"
```

---

### record_worktree_execution_end()

Worktree実行終了を記録します。

**シグネチャ:**
```bash
record_worktree_execution_end <workflow-name> <ai-name> <status> <duration-sec>
```

**引数:**
- `$1` - ワークフロー名
- `$2` - AI名
- `$3` - 実行ステータス（success|failure|timeout）
- `$4` - 実行時間（秒）

**戻り値:**
- `0` - 成功

**使用例:**
```bash
start_time=$(date +%s)
# ... AI実行 ...
end_time=$(date +%s)
duration=$((end_time - start_time))

record_worktree_execution_end "multi-ai-full-orchestrate" "qwen" "success" "$duration"
```

---

### get_execution_statistics()

実行統計を取得します。

**シグネチャ:**
```bash
get_execution_statistics [workflow-name] [days]
```

**引数:**
- `$1` - ワークフロー名（省略時: 全ワークフロー）
- `$2` - 過去何日分（デフォルト: 7日）

**戻り値:**
- `0` - 成功（統計をstdoutに出力）

**出力形式:**
```
Total Executions: 150
Successful: 142 (94.7%)
Failed: 8 (5.3%)
Average Duration: 245 seconds
```

**使用例:**
```bash
# 過去7日の全統計
get_execution_statistics

# 特定ワークフローの統計（過去30日）
get_execution_statistics "multi-ai-full-orchestrate" 30
```

---

### その他の関数

| 関数名 | 説明 |
|--------|------|
| `query_execution_history()` | 履歴をクエリ |
| `get_success_rate_trend()` | 成功率の推移を取得 |
| `generate_history_report()` | HTMLレポート生成 |
| `get_workflow_avg_duration()` | ワークフローの平均実行時間 |

---

## worktree-metrics.sh

**責務:** リソース使用量、パフォーマンスメトリクス収集

**メトリクスファイル:**
```bash
logs/worktree-metrics/metrics.ndjson
```

### record_resource_usage()

現在のリソース使用量を記録します。

**シグネチャ:**
```bash
record_resource_usage <workflow-name>
```

**引数:**
- `$1` - ワークフロー名

**戻り値:**
- `0` - 成功

**記録される情報:**
- CPU使用率
- メモリ使用量
- ディスク使用量
- Worktree数
- タイムスタンプ

**使用例:**
```bash
# ワークフロー開始時
record_resource_usage "multi-ai-full-orchestrate"

# 定期的に記録
while worktree_is_running; do
  record_resource_usage "multi-ai-full-orchestrate"
  sleep 30
done
```

---

### get_workflow_success_rate()

ワークフローの成功率を取得します。

**シグネチャ:**
```bash
get_workflow_success_rate <workflow-name> [days]
```

**引数:**
- `$1` - ワークフロー名
- `$2` - 過去何日分（デフォルト: 7日）

**戻り値:**
- `0` - 成功（成功率をstdoutに出力）

**出力形式:** `94.7` （パーセント値）

**使用例:**
```bash
success_rate=$(get_workflow_success_rate "multi-ai-full-orchestrate" 7)
echo "Success rate (last 7 days): ${success_rate}%"

if (( $(echo "$success_rate < 90" | bc -l) )); then
  echo "WARNING: Success rate is below 90%"
fi
```

---

### その他の関数

| 関数名 | 説明 |
|--------|------|
| `get_current_resource_usage()` | 現在のリソース使用量取得 |
| `get_ai_avg_duration()` | AI別平均実行時間 |
| `get_daily_success_trend()` | 日別成功率推移 |
| `generate_metrics_dashboard()` | HTMLダッシュボード生成 |

---

## worktree-merge.sh

**責務:** Worktreeブランチのマージ、競合解決支援

**サポートされるマージ戦略:**
- `no-ff` - Non-fast-forward merge（デフォルト）
- `squash` - Squash merge
- `ff-only` - Fast-forward only
- `ours` - Ours strategy（競合時にbaseを優先）
- `theirs` - Theirs strategy（競合時にAIブランチを優先）
- `manual` - 手動競合解決（非対話モードでは`theirs`にフォールバック）
- `best` - 品質スコアベース自動選択

### merge_worktree_branch()

Worktreeブランチをターゲットブランチにマージします。

**シグネチャ:**
```bash
merge_worktree_branch <ai-name> <target-branch> [strategy]
```

**引数:**
- `$1` - AI名
- `$2` - ターゲットブランチ（通常は`main`）
- `$3` - マージ戦略（デフォルト: `no-ff`）

**戻り値:**
- `0` - 成功
- `1` - 失敗

**使用例:**
```bash
# デフォルト戦略（no-ff）
merge_worktree_branch "qwen" "main"

# Squash merge
merge_worktree_branch "qwen" "main" "squash"

# 競合時にAIブランチを優先
merge_worktree_branch "qwen" "main" "theirs"

# 品質スコアベース自動選択
merge_worktree_branch "qwen" "main" "best"
```

---

### check_merge_conflicts()

マージ競合を事前チェックします。

**シグネチャ:**
```bash
check_merge_conflicts <ai-name> [target-branch]
```

**引数:**
- `$1` - AI名
- `$2` - ターゲットブランチ（デフォルト: `main`）

**戻り値:**
- `0` - 競合なし
- `1` - 競合あり

**使用例:**
```bash
if check_merge_conflicts "qwen" "main"; then
  echo "No conflicts detected, safe to merge"
  merge_worktree_branch "qwen" "main"
else
  echo "Conflicts detected, manual resolution required"
  visualize_merge_conflicts "qwen"
fi
```

---

### visualize_merge_conflicts()

競合箇所を可視化します（Phase 2.3.2）。

**シグネチャ:**
```bash
visualize_merge_conflicts <ai-name> [target-branch]
```

**引数:**
- `$1` - AI名
- `$2` - ターゲットブランチ（デフォルト: `main`）

**戻り値:**
- `0` - 成功

**出力例:**
```
=== Merge Conflicts for qwen ===

File: src/main.sh
Conflict sections: 2

<<<<<<< HEAD (main)
echo "Version 1.0"
=======
echo "Version 2.0"
>>>>>>> ai/qwen/20251108-120000

Conflict Summary:
- Total files: 1
- Total conflicts: 2
```

**使用例:**
```bash
visualize_merge_conflicts "qwen" "main" | tee conflicts-report.txt
```

---

### その他の関数

| 関数名 | 説明 |
|--------|------|
| `compare_ai_changes()` | 複数AI間の変更比較 |
| `interactive_conflict_resolution()` | 対話式競合解決（非対話モード対応） |
| `merge_all_sequential()` | 複数Worktreeの順次マージ |

---

## worktree-execution.sh

**責務:** AI実行管理、エラーリカバリー、孤立Worktree検出

**主要な機能:**
- AI実行のラッピング
- タイムアウト管理
- 孤立Worktreeの検出と自動リカバリー
- ロックファイルの管理

### execute_in_worktree()

Worktree内でAIコマンドを実行します。

**シグネチャ:**
```bash
execute_in_worktree <ai-name> <command> [timeout-sec]
```

**引数:**
- `$1` - AI名
- `$2` - 実行するコマンド
- `$3` - タイムアウト（秒、デフォルト: 600）

**戻り値:**
- `0` - 成功
- `1` - 失敗
- `124` - タイムアウト

**使用例:**
```bash
# 基本使用方法
execute_in_worktree "qwen" "bash scripts/analyze.sh"

# タイムアウト指定
execute_in_worktree "droid" "bash scripts/implement.sh" 900

# エラーハンドリング
if execute_in_worktree "claude" "bash scripts/review.sh"; then
  echo "Claude review completed successfully"
else
  exit_code=$?
  if [[ $exit_code -eq 124 ]]; then
    echo "ERROR: Claude review timed out"
  else
    echo "ERROR: Claude review failed with exit code $exit_code"
  fi
fi
```

---

### detect_orphaned_worktrees()

孤立Worktreeを検出します（Phase 2.2.1）。

**シグネチャ:**
```bash
detect_orphaned_worktrees
```

**引数:** なし

**戻り値:**
- `0` - 成功（孤立Worktreeのリストをstdoutに出力）
- `1` - 失敗

**検出条件:**
- Worktreeディレクトリは存在するが、`git worktree list`に登録されていない
- 状態ファイルは`active`だが、Worktreeが存在しない

**出力形式:**
```
worktrees/qwen
worktrees/droid
```

**使用例:**
```bash
orphaned=$(detect_orphaned_worktrees)
if [[ -n "$orphaned" ]]; then
  echo "Found orphaned worktrees:"
  echo "$orphaned"
  recover_orphaned_worktrees
fi
```

---

### recover_orphaned_worktrees()

孤立Worktreeを自動リカバリーします（Phase 2.2.2）。

**シグネチャ:**
```bash
recover_orphaned_worktrees [--auto]
```

**引数:**
- `--auto` - 確認プロンプトなしで自動実行

**戻り値:**
- `0` - 成功
- `1` - 失敗

**リカバリー処理:**
1. 孤立Worktreeの検出
2. ユーザー確認（`--auto`なしの場合）
3. Worktreeの削除
4. ブランチの削除
5. 状態ファイルの同期
6. リカバリーログの記録

**使用例:**
```bash
# 対話式リカバリー
recover_orphaned_worktrees

# 自動リカバリー（CI環境）
recover_orphaned_worktrees --auto
```

---

### その他の関数

| 関数名 | 説明 |
|--------|------|
| `detect_orphaned_branches()` | 孤立ブランチ検出 |
| `recover_orphaned_branches()` | 孤立ブランチリカバリー |
| `recover_stale_states()` | 古い状態ファイルのリカバリー |
| `recover_stale_locks()` | 古いロックファイルのリカバリー |
| `auto_recover_worktrees()` | 全リカバリー処理の自動実行 |
| `prompt_user_recovery()` | ユーザー確認プロンプト |
| `log_recovery_event()` | リカバリーイベントの記録 |
| `analyze_recovery_history()` | リカバリー履歴の分析 |
| `get_recovery_statistics()` | リカバリー統計の取得 |
| `check_worktree_health()` | Worktree健全性チェック |

---

## worktree-cleanup.sh

**責務:** trap管理、自動クリーンアップ、Worktree削除

### setup_worktree_cleanup_trap()

クリーンアップtrapを設定します（Phase 0修正）。

**シグネチャ:**
```bash
setup_worktree_cleanup_trap
```

**引数:** なし

**戻り値:**
- `0` - 成功

**動作:**
- `EXIT`, `INT`, `TERM`シグナルに対してクリーンアップ関数を登録
- ワークフロー開始時に**明示的に**呼び出す必要がある

**使用例:**
```bash
# ワークフロー開始時
setup_worktree_cleanup_trap

# Worktree作成と実行
create_worktrees_parallel claude gemini qwen
# ... AI実行 ...

# ワークフロー終了時
teardown_worktree_cleanup_trap
```

---

### teardown_worktree_cleanup_trap()

クリーンアップtrapを解除します（Phase 0修正）。

**シグネチャ:**
```bash
teardown_worktree_cleanup_trap
```

**引数:** なし

**戻り値:**
- `0` - 成功

**動作:**
- 設定したtrapを解除
- ワークフロー終了時に**明示的に**呼び出す必要がある

---

### cleanup_worktree()

個別Worktreeをクリーンアップします。

**シグネチャ:**
```bash
cleanup_worktree <ai-name>
```

**引数:**
- `$1` - AI名

**戻り値:**
- `0` - 成功
- `1` - 失敗

**処理内容:**
1. 通常削除を試行（`git worktree remove`）
2. 失敗時は`--force`で再試行
3. リトライ機構（最大3回、1秒間隔）
4. ブランチの削除
5. 状態ファイルの更新

**使用例:**
```bash
# 基本使用方法
cleanup_worktree "qwen"

# エラーハンドリング
if ! cleanup_worktree "qwen"; then
  echo "WARNING: Failed to cleanup qwen worktree"
fi
```

---

### cleanup_all_worktrees()

全Worktreeを一括クリーンアップします。

**シグネチャ:**
```bash
cleanup_all_worktrees
```

**引数:** なし

**戻り値:**
- `0` - 全て成功
- `1` - 一部失敗

**使用例:**
```bash
# ワークフロー終了時
cleanup_all_worktrees

# trapハンドラー内
trap cleanup_all_worktrees EXIT INT TERM
```

---

### その他の関数

| 関数名 | 説明 |
|--------|------|
| `force_cleanup_worktree()` | 強制削除（--force固定） |
| `cleanup_worktree_branch()` | ブランチのみ削除 |

---

## worktree-errors.sh

**責務:** エラーコード定義、標準化されたエラーメッセージ出力

**エラーコード範囲:** WT001 - WT999

### エラーコード一覧

| コード | 説明 | カテゴリ |
|-------|------|---------|
| WT001 | 無効なAI名 | 検証エラー |
| WT101 | Worktree作成失敗 | 作成エラー |
| WT102 | Worktree既存 | 作成エラー |
| WT201 | Worktree削除失敗 | 削除エラー |
| WT202 | Worktree未存在 | 削除エラー |
| WT301 | マージ失敗 | マージエラー |
| WT302 | マージ競合 | マージエラー |
| WT401 | ロック取得失敗 | 並列制御エラー |
| WT402 | ロック解放失敗 | 並列制御エラー |
| WT501 | 状態遷移エラー | 状態管理エラー |
| WT502 | 無効な状態 | 状態管理エラー |
| WT901 | 内部エラー | システムエラー |
| WT902 | 依存関係エラー | システムエラー |

### error_invalid_ai_name()

無効なAI名エラーを出力します（WT001）。

**シグネチャ:**
```bash
error_invalid_ai_name <ai-name>
```

**引数:**
- `$1` - 無効なAI名

**戻り値:**
- `1` - 常に失敗

**出力例:**
```
ERROR [WT001]: Invalid AI name: 'foo'

What: The AI name 'foo' is not recognized.
Why: Only claude, gemini, amp, qwen, droid, codex, cursor are supported.
How: Check the AI name and try again.

Valid AI names:
  - claude
  - gemini
  - amp
  - qwen
  - droid
  - codex
  - cursor
```

---

### error_worktree_create_failed()

Worktree作成失敗エラーを出力します（WT101）。

**シグネチャ:**
```bash
error_worktree_create_failed <ai-name> <error-message>
```

**引数:**
- `$1` - AI名
- `$2` - エラーメッセージ

**戻り値:**
- `1` - 常に失敗

---

### その他のエラー関数

| 関数名 | コード | 説明 |
|--------|--------|------|
| `error_worktree_already_exists()` | WT102 | Worktree既存エラー |
| `error_worktree_delete_failed()` | WT201 | 削除失敗 |
| `error_worktree_not_found()` | WT202 | Worktree未存在 |
| `error_merge_failed()` | WT301 | マージ失敗 |
| `error_merge_conflict()` | WT302 | マージ競合 |
| `error_lock_acquire_failed()` | WT401 | ロック取得失敗 |
| `error_lock_release_failed()` | WT402 | ロック解放失敗 |
| `error_state_transition()` | WT501 | 状態遷移エラー |
| `error_invalid_state()` | WT502 | 無効な状態 |

---

## 使用例

### 例1: 基本的なWorktreeワークフロー

```bash
#!/usr/bin/env bash
set -euo pipefail

# ライブラリをソース
source scripts/orchestrate/lib/worktree-core.sh
source scripts/orchestrate/lib/worktree-cleanup.sh

# Trapセットアップ
setup_worktree_cleanup_trap

# Worktree作成
create_worktree "qwen" "worktrees/qwen"

# Worktree内で実行
(
  cd worktrees/qwen
  echo "Running analysis in qwen worktree..."
  bash scripts/analyze.sh
  git add .
  git commit -m "Analysis results"
)

# メインブランチにマージ
merge_worktree_branch "qwen" "main" "no-ff"

# クリーンアップ
cleanup_worktree "qwen"

# Trap解除
teardown_worktree_cleanup_trap
```

---

### 例2: 並列実行ワークフロー

```bash
#!/usr/bin/env bash
set -euo pipefail

source scripts/orchestrate/lib/worktree-core.sh
source scripts/orchestrate/lib/worktree-execution.sh

# 並列度設定
export MAX_PARALLEL_WORKTREES=4

# Worktreeを並列作成
create_worktrees_parallel claude gemini qwen droid

# 各AIで並列実行
for ai in claude gemini qwen droid; do
  (
    execute_in_worktree "$ai" "bash scripts/process-$ai.sh" 900
  ) &
done

# 全プロセス完了を待機
wait

# 結果をマージ
for ai in claude gemini qwen droid; do
  merge_worktree_branch "$ai" "main" "no-ff"
done

# 一括クリーンアップ
cleanup_all_worktrees
```

---

### 例3: エラーリカバリー付きワークフロー

```bash
#!/usr/bin/env bash
set -euo pipefail

source scripts/orchestrate/lib/worktree-core.sh
source scripts/orchestrate/lib/worktree-execution.sh

# 起動時に健全性チェック
check_worktree_health

# 孤立Worktreeを自動リカバリー
if [[ -n "$(detect_orphaned_worktrees)" ]]; then
  echo "Recovering orphaned worktrees..."
  recover_orphaned_worktrees --auto
fi

# Worktree作成
create_worktree "qwen" "worktrees/qwen"

# タイムアウト付き実行
if ! execute_in_worktree "qwen" "bash scripts/heavy-task.sh" 1200; then
  exit_code=$?
  if [[ $exit_code -eq 124 ]]; then
    echo "ERROR: Task timed out after 1200 seconds"
  else
    echo "ERROR: Task failed with exit code $exit_code"
  fi

  # 失敗時もクリーンアップ
  cleanup_worktree "qwen"
  exit 1
fi

# 正常終了
merge_worktree_branch "qwen" "main"
cleanup_worktree "qwen"
```

---

### 例4: メトリクス収集付きワークフロー

```bash
#!/usr/bin/env bash
set -euo pipefail

source scripts/orchestrate/lib/worktree-core.sh
source scripts/orchestrate/lib/worktree-history.sh
source scripts/orchestrate/lib/worktree-metrics.sh

workflow="my-workflow"
ai="qwen"

# 実行開始を記録
record_worktree_execution_start "$workflow" "$ai"
start_time=$(date +%s)

# Worktree作成と実行
create_worktree "$ai" "worktrees/$ai"

# リソース使用量を定期的に記録
(
  while pgrep -f "worktrees/$ai" > /dev/null; do
    record_resource_usage "$workflow"
    sleep 30
  done
) &
monitor_pid=$!

# AI実行
execute_in_worktree "$ai" "bash scripts/task.sh"
status=$?

# モニタリング停止
kill $monitor_pid 2>/dev/null || true

# 実行終了を記録
end_time=$(date +%s)
duration=$((end_time - start_time))

if [[ $status -eq 0 ]]; then
  record_worktree_execution_end "$workflow" "$ai" "success" "$duration"
else
  record_worktree_execution_end "$workflow" "$ai" "failure" "$duration"
fi

# クリーンアップ
cleanup_worktree "$ai"

# 統計表示
echo ""
echo "=== Execution Statistics ==="
get_execution_statistics "$workflow" 7
echo ""
echo "Success Rate: $(get_workflow_success_rate "$workflow" 7)%"
```

---

### 例5: 複数AI比較ワークフロー

```bash
#!/usr/bin/env bash
set -euo pipefail

source scripts/orchestrate/lib/worktree-core.sh
source scripts/orchestrate/lib/worktree-merge.sh

# 2つのAIで同じタスクを実行
for ai in qwen droid; do
  create_worktree "$ai" "worktrees/$ai"
  execute_in_worktree "$ai" "bash scripts/implement-feature.sh"
done

# 変更を比較
echo "=== Comparing AI Changes ==="
compare_ai_changes "" qwen droid

# マージ前に競合チェック
for ai in qwen droid; do
  if ! check_merge_conflicts "$ai" "main"; then
    echo "Conflicts detected for $ai"
    visualize_merge_conflicts "$ai"
  fi
done

# ユーザーに選択を促す
echo ""
echo "Which implementation do you want to merge?"
echo "1) qwen"
echo "2) droid"
echo "3) both (manual conflict resolution)"
read -p "Choice: " choice

case "$choice" in
  1)
    merge_worktree_branch "qwen" "main" "theirs"
    ;;
  2)
    merge_worktree_branch "droid" "main" "theirs"
    ;;
  3)
    merge_worktree_branch "qwen" "main" "no-ff"
    merge_worktree_branch "droid" "main" "manual"
    ;;
esac

# クリーンアップ
cleanup_all_worktrees
```

---

## 関連ドキュメント

- [トラブルシューティングガイド](TROUBLESHOOTING.md) - よくある問題と解決策
- [アーキテクチャドキュメント](ARCHITECTURE.md) - システム構成図とデータフロー
- [貢献ガイド](CONTRIBUTING.md) - 開発環境セットアップとコーディング規約
- [WORKTREE_TEST_PROCEDURE.md](../../WORKTREE_TEST_PROCEDURE.md) - テスト手順書
- [WORKTREE_CI_CD_GUIDE.md](../WORKTREE_CI_CD_GUIDE.md) - CI/CD統合ガイド

---

**最終更新:** 2025-11-08
**バージョン:** v1.0
**メンテナー:** Multi-AI Orchestrium Contributors
