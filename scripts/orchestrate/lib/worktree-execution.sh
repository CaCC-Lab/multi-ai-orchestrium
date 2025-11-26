#!/usr/bin/env bash
# worktree-execution.sh - ワークツリー内のAI実行とエラーリカバリー
# 責務：AIタスク実行、出力管理、タイムアウト処理、エラーリカバリー
# Phase 2.2: エラーリカバリー機能追加

set -euo pipefail

# 依存関係をソース
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/worktree-core.sh"
source "$SCRIPT_DIR/worktree-cleanup.sh"
source "$SCRIPT_DIR/worktree-state.sh"
source "$SCRIPT_DIR/../../../bin/vibe-logger-lib.sh"

# リカバリーログディレクトリ
RECOVERY_LOG_DIR="${RECOVERY_LOG_DIR:-logs/worktree-recovery}"
mkdir -p "$RECOVERY_LOG_DIR"

# ========================================
# ヘルパー関数（フェーズ2統合用）
# ========================================

# Note: create_all_worktrees() is defined in worktree-core.sh
# (Removed duplicate broken implementation that called undefined log_info)

execute_parallel_in_worktrees() {
  local task="$1"
  shift
  local ai_list=("$@")

  # ワークツリーが存在することを確認
  for ai_name in "${ai_list[@]}"; do
    if [[ ! -d "$WORKTREE_BASE_DIR/$ai_name" ]]; then
      echo "ERROR: Worktree for $ai_name does not exist. Run create_all_worktrees first." >&2
      return 1
    fi
  done

  # 並列実行
  execute_all_parallel "$task" 600 "${ai_list[@]}"
}

# ========================================
# AI実行関数
# ========================================

##
# ワークツリー内でAIタスクを実行
#
# 引数:
#   $1 - AI名（claude|gemini|amp|qwen|droid|codex|cursor）
#   $2 - 実行するタスク（プロンプト）
#   $3 - （オプション）タイムアウト秒数（デフォルト: 600）
#
# 戻り値:
#   0 - 成功（AI実行完了）
#   1 - 失敗（ワークツリー不在、タイムアウト、AI実行エラー）
#
# 副作用:
#   - ワークツリー内の.ai-output.txtに出力を保存
#   - 状態を"executing"→"completed"または"failed"に更新
#   - VibeLoggerログを記録
#
# セキュリティ:
#   - ワークツリー内で実行（ファイル競合を防止）
#   - timeoutコマンドでハング防止
#
# 例:
#   execute_ai_in_worktree "qwen" "Implement user authentication" 900
#   execute_ai_in_worktree "droid" "Review code for security issues"
##
execute_ai_in_worktree() {
  local ai_name="$1"
  local task="$2"
  local timeout="${3:-600}"

  # タイムアウト値の検証
  if [[ ! "$timeout" =~ ^[0-9]+$ ]]; then
    error_with_solution "タイムアウトは正の整数である必要があります: $timeout" \
      "- 推奨値: 300（5分）、600（10分）、900（15分）
- 最小値: 1秒
- 最大値: 86400秒（24時間）
- 例: execute_ai_in_worktree 'qwen' 'task' 600"
    return 1
  fi

  if [[ "$timeout" -le 0 ]]; then
    error_with_solution "タイムアウトは1以上である必要があります: $timeout" \
      "- 推奨値: 300（5分）、600（10分）、900（15分）
- 例: execute_ai_in_worktree 'qwen' 'task' 600"
    return 1
  fi

  # タイムアウト上限チェック（24時間 = 86400秒）
  local MAX_TIMEOUT=86400
  if [[ "$timeout" -gt "$MAX_TIMEOUT" ]]; then
    # 小数点以下の時間を正確に表示（整数除算による切り捨てを回避）
    local total_hours
    local hours
    local minutes
    total_hours=$(awk "BEGIN {printf \"%.1f\", $timeout / 3600}")
    hours=$(( timeout / 3600 ))
    minutes=$(( (timeout % 3600) / 60 ))
    
    echo "WARNING: タイムアウトが24時間（86400秒）を超えています: ${timeout}秒" >&2
    echo "  推奨最大値: 86400秒（24時間）" >&2
    echo "  現在の値: ${timeout}秒（${total_hours}時間 または ${hours}時間${minutes}分）" >&2

    # インタラクティブモードチェック
    if [[ -t 0 ]] && [[ "${CI:-false}" != "true" ]] && [[ "${NON_INTERACTIVE:-false}" != "true" ]]; then
      # インタラクティブモード: ユーザーに確認
      echo -n "本当に続行しますか？ (y/N): " >&2
      read -r response
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "ERROR: ユーザーによりキャンセルされました" >&2
        return 1
      fi
    else
      # 非インタラクティブモード: エラー終了
      error_with_solution "タイムアウトが上限を超えています: ${timeout}秒 > ${MAX_TIMEOUT}秒" \
        "- 推奨最大値: 86400秒（24時間）
- 非インタラクティブモードでは24時間を超えるタイムアウトは許可されません
- インタラクティブモードで実行するか、タイムアウトを削減してください
- 例: execute_ai_in_worktree 'qwen' 'task' 86400"
      return 1
    fi
  fi

  local worktree_path="$WORKTREE_BASE_DIR/$ai_name"

  # ワークツリーの存在確認
  if [[ ! -d "$worktree_path" ]]; then
    echo "ERROR: ワークツリーが存在しません: $worktree_path" >&2
    return 1
  fi

  # 状態を実行中に更新
  save_worktree_state "$ai_name" "executing"

  vibe_log "worktree-execution" "start" \
    "{\"ai\":\"$ai_name\",\"task\":\"$task\",\"timeout\":$timeout}" \
    "$ai_nameでタスクを実行中" \
    "[\"monitor-progress\"]" \
    "worktree-execution"

  # ワークツリー内でAIを実行
  local output_file="$worktree_path/.ai-output.txt"
  local exit_code=0

  (
    cd "$worktree_path"

    # AIラッパーのパス（テスト用にAI_WRAPPER_DIRで上書き可能）
    #
    # 使用例:
    #   AI_WRAPPER_DIR="./test/mocks" execute_ai_in_worktree "qwen" "task" 600
    #   → test/mocks/qwen-wrapper.sh を使用（モックテスト用）
    #
    # セキュリティ対策:
    #   - AI_WRAPPER_DIRはプロジェクトルート配下のみ許可（検証は行167-192で実施）
    #   - 絶対パスに正規化してPath Traversal攻撃を防止（realpath使用）
    #   - See: scripts/orchestrate/lib/worktree-execution.sh:167-192
    local wrapper_dir_unverified="${AI_WRAPPER_DIR:-$SCRIPT_DIR/../../bin}"
    
    # --- セキュリティ検証: パスが安全であることを確認 ---
    # 1. 無効な文字列のチェック
    if [[ ! -d "$wrapper_dir_unverified" ]]; then
      error_with_solution "ラッパー用ディレクトリが存在しません: $wrapper_dir_unverified" \
        "- ディレクトリが存在することを確認してください
- 相対パスの解決が正しいことを確認してください
- ワークツリーのパスが予期しない場所に解決されていないか確認してください"
      return 1
    fi

    # 2. パスの正規化とプロジェクトルート内制限（パストラバーサル対策）
    local real_wrapper_dir
    if ! real_wrapper_dir=$(realpath "$wrapper_dir_unverified" 2>/dev/null); then
      error_with_solution "パスの正規化に失敗しました: $wrapper_dir_unverified" \
        "- 無効なパス文字列が含まれている可能性があります
- パスに不正な文字列が含まれていないか確認してください"
      return 1
    fi

    # プロジェクトのルートディレクトリを取得
    local project_root_normalized
    project_root_normalized=$(git rev-parse --show-toplevel 2>/dev/null) || {
      # gitコマンドが使えない場合、SCRIPT_DIRの親ディレクトリをプロジェクトルートと見なす
      project_root_normalized="$(cd "$SCRIPT_DIR/../.." && pwd)"
    }

    # 実際のラッパーがプロジェクトルート内にあることを確認
    if [[ "$real_wrapper_dir" != "$project_root_normalized"* ]]; then
      error_with_solution "セキュリティエラー: AI_WRAPPER_DIRがプロジェクトルート外を指しています: $real_wrapper_dir" \
        "- AI_WRAPPER_DIRはプロジェクトディレクトリ内に限定してください
- プロジェクトルート: $project_root_normalized
- 許可されるパス: $project_root_normalized/... 以下のパス
- 例: AI_WRAPPER_DIR='./test/mocks' は許可されます
- 例: AI_WRAPPER_DIR='/tmp' または AI_WRAPPER_DIR='../outside' は許可されません"
      return 1
    fi
    
    # 3. 最終的なラッパーの存在と実行可能属性を検証
    local wrapper_path="$real_wrapper_dir/${ai_name}-wrapper.sh"
    if [[ ! -f "$wrapper_path" ]]; then
      error_with_solution "AIラッパーが存在しません: $wrapper_path" \
        "- ラッパーが存在することを確認してください
- ラッパーのファイル名が正しく、AI名と一致することを確認してください
- 例: qwen-wrapper.sh, claude-wrapper.sh など"
      return 1
    fi

    if [[ ! -x "$wrapper_path" ]]; then
      error_with_solution "AIラッパーが実行可能ではありません: $wrapper_path" \
        "- ラッパーの実行許可を設定してください: chmod +x $wrapper_path
- ラッパーが実行可能スクリプトであることを確認してください"
      return 1
    fi

    # AIラッパーを呼び出し
    if timeout "${timeout}s" "$wrapper_path" \
      --prompt "$task" \
      > "$output_file" 2>&1; then
      echo "SUCCESS: $ai_name completed task"
    else
      exit_code=$?
      echo "ERROR: $ai_name failed with exit code $exit_code" >&2
      return $exit_code
    fi
  ) || exit_code=$?

  # 状態を完了に更新
  if [[ $exit_code -eq 0 ]]; then
    save_worktree_state "$ai_name" "completed"
  else
    save_worktree_state "$ai_name" "failed"
  fi

  vibe_log "worktree-execution" "done" \
    "{\"ai\":\"$ai_name\",\"exit_code\":$exit_code}" \
    "$ai_nameのタスクが完了" \
    "[]" \
    "worktree-execution"

  return $exit_code
}

##
# 複数のAIでタスクを並列実行
#
# 引数:
#   $1 - 実行するタスク（プロンプト）
#   $2 - （オプション）タイムアウト秒数（デフォルト: 600）
#   $@ - （オプション、3番目以降）AI名のリスト（デフォルト: 全7AI）
#
# 戻り値:
#   0 - 全AI成功
#   1 - 一部または全AI失敗
#
# 特徴:
#   - 真の並列実行（バックグラウンドジョブ）
#   - 各AIの終了コードを個別に記録
#   - VibeLoggerパイプラインメトリクス
#
# パフォーマンス:
#   - 7AI並列実行でも約30秒未満（P0要件）
#
# 例:
#   execute_all_parallel "Implement feature X" 900
#   execute_all_parallel "Code review" 600 qwen droid codex  # 3AIのみ
##
execute_all_parallel() {
  local task="$1"
  local timeout="${2:-600}"
  local ai_list=("${@:3}")  # 3番目以降の引数をAIリストとして取得

  # デフォルトのAIリスト
  if [[ ${#ai_list[@]} -eq 0 ]]; then
    ai_list=("claude" "gemini" "amp" "qwen" "droid" "codex" "cursor")
  fi

  vibe_pipeline_start "execute-all-parallel" "parallel" ${#ai_list[@]}

  local pids=()
  local exit_codes=()

  # 並列実行
  for ai_name in "${ai_list[@]}"; do
    execute_ai_in_worktree "$ai_name" "$task" "$timeout" &
    pids+=($!)
  done

  # すべてのジョブを待機
  local overall_exit_code=0
  for pid in "${pids[@]}"; do
    if wait "$pid"; then
      exit_codes+=(0)
    else
      local code=$?
      exit_codes+=($code)
      overall_exit_code=1
    fi
  done

  vibe_pipeline_done "execute-all-parallel" \
    "$([[ $overall_exit_code -eq 0 ]] && echo 'success' || echo 'partial')" \
    "$SECONDS" \
    ${#ai_list[@]}

  return $overall_exit_code
}

# ========================================
# 出力収集関数
# ========================================

##
# 複数のAIの出力を収集して結合
#
# 引数:
#   $@ - AI名のリスト
#
# 戻り値:
#   0 - 常に成功
#
# 出力:
#   各AIの.ai-output.txtの内容を改行区切りで出力
#   ファイルが存在しないAIはスキップ
#
# 用途:
#   - Codexによる複数実装の統合
#   - 統合レポート生成
#   - マージコミットメッセージの作成
#
# 例:
#   collect_outputs qwen droid > combined-output.txt
#   outputs=$(collect_outputs "${AI_LIST[@]}")
##
collect_outputs() {
  local ai_list=("${@}")
  local outputs=()

  for ai_name in "${ai_list[@]}"; do
    local output_file="$WORKTREE_BASE_DIR/$ai_name/.ai-output.txt"
    if [[ -f "$output_file" ]]; then
      outputs+=("$(cat "$output_file")")
    fi
  done

  # 出力を結合して返す
  printf "%s\n" "${outputs[@]}"
}

# ========================================
# Phase 2.2.1: 中断されたWorktreeの検出
# ========================================

##
# 孤立したWorktreeを検出
#
# 引数:
#   なし
#
# 戻り値:
#   0 - 孤立Worktreeが見つかった
#   1 - 孤立Worktreeなし
#
# 動作:
#   - git worktree listで全Worktreeをリスト
#   - WORKTREE_BASE_DIR配下のディレクトリと比較
#   - 存在しないディレクトリを孤立と判定
#
# 出力:
#   - 孤立したWorktreeのパスを標準出力
#
# 例:
#   orphaned=$(detect_orphaned_worktrees)
#   if [[ -n "$orphaned" ]]; then
#     echo "Found orphaned worktrees: $orphaned"
#   fi
##
detect_orphaned_worktrees() {
    vibe_log "worktree-detection" "orphaned-check" \
        "{}" \
        "孤立したWorktreeをチェック中" \
        "[]" \
        "worktree-detection"

    local orphaned_list=()

    # git worktree listから全Worktreeを取得
    while IFS= read -r line; do
        # Format: /path/to/worktree  commit-hash [branch-name]
        local worktree_path=$(echo "$line" | awk '{print $1}')

        # WORKTREE_BASE_DIR配下のWorktreeのみ対象
        if [[ "$worktree_path" != *"$WORKTREE_BASE_DIR"* ]]; then
            continue
        fi

        # ディレクトリが存在しないか確認
        if [[ ! -d "$worktree_path" ]]; then
            orphaned_list+=("$worktree_path")
            echo "⚠ Orphaned worktree detected: $worktree_path" >&2
        fi
    done < <(git worktree list --porcelain 2>/dev/null | grep "^worktree " | sed 's/^worktree //')

    # 結果を出力
    if [[ ${#orphaned_list[@]} -gt 0 ]]; then
        printf "%s\n" "${orphaned_list[@]}"
        return 0
    fi

    echo "✓ No orphaned worktrees found"
    return 1
}

##
# 孤立したブランチを検出
#
# 引数:
#   なし
#
# 戻り値:
#   0 - 孤立ブランチが見つかった
#   1 - 孤立ブランチなし
#
# 動作:
#   - ai/*/でマッチするブランチをリスト
#   - 対応するWorktreeが存在しないブランチを孤立と判定
#
# 出力:
#   - 孤立したブランチ名を標準出力
#
# 例:
#   orphaned=$(detect_orphaned_branches)
#   if [[ -n "$orphaned" ]]; then
#     echo "Found orphaned branches: $orphaned"
#   fi
##
detect_orphaned_branches() {
    vibe_log "worktree-detection" "orphaned-branches" \
        "{}" \
        "孤立したブランチをチェック中" \
        "[]" \
        "worktree-detection"

    local orphaned_list=()

    # ai/*パターンのブランチを検索
    while IFS= read -r branch; do
        # ブランチ名からAI名を抽出 (ai/<ai-name>/*)
        if [[ "$branch" =~ ^ai/([^/]+)/ ]]; then
            local ai_name="${BASH_REMATCH[1]}"
            local worktree_path="$WORKTREE_BASE_DIR/$ai_name"

            # 対応するWorktreeが存在しない場合
            if [[ ! -d "$worktree_path" ]]; then
                # さらに、git worktree listにも存在しないことを確認
                if ! git worktree list | grep -q "$worktree_path"; then
                    orphaned_list+=("$branch")
                    echo "⚠ Orphaned branch detected: $branch (no worktree at $worktree_path)" >&2
                fi
            fi
        fi
    done < <(git branch --list "ai/*" | sed 's/^[* ] //')

    # 結果を出力
    if [[ ${#orphaned_list[@]} -gt 0 ]]; then
        printf "%s\n" "${orphaned_list[@]}"
        return 0
    fi

    echo "✓ No orphaned branches found"
    return 1
}

##
# Worktreeシステムのヘルスチェック
#
# 引数:
#   なし
#
# 戻り値:
#   0 - システムは健全
#   1 - 問題が検出された
#
# 動作:
#   1. 孤立したWorktreeの検出
#   2. 孤立したブランチの検出
#   3. 状態ファイルの整合性チェック
#   4. 中断された実行の検出
#
# 出力:
#   - 検出された問題のサマリー
#
# 用途:
#   - 起動時の自動チェック
#   - 定期メンテナンス
#
# 例:
#   if ! check_worktree_health; then
#     echo "Worktree system has issues, running recovery..."
#   fi
##
check_worktree_health() {
    echo "=== Worktreeシステム ヘルスチェック ==="
    echo ""

    local issues_found=0

    # 1. 孤立したWorktreeの検出
    echo "[1/4] 孤立したWorktreeをチェック..."
    local orphaned_worktrees
    if orphaned_worktrees=$(detect_orphaned_worktrees 2>&1); then
        issues_found=$((issues_found + 1))
        echo "  ⚠ 孤立したWorktreeが見つかりました:"
        echo "$orphaned_worktrees" | sed 's/^/    /'
    else
        echo "  ✓ 孤立したWorktreeなし"
    fi
    echo ""

    # 2. 孤立したブランチの検出
    echo "[2/4] 孤立したブランチをチェック..."
    local orphaned_branches
    if orphaned_branches=$(detect_orphaned_branches 2>&1); then
        issues_found=$((issues_found + 1))
        echo "  ⚠ 孤立したブランチが見つかりました:"
        echo "$orphaned_branches" | sed 's/^/    /'
    else
        echo "  ✓ 孤立したブランチなし"
    fi
    echo ""

    # 3. 状態ファイルの整合性チェック
    echo "[3/4] 状態ファイルの整合性をチェック..."
    if [[ -f "$WORKTREE_STATE_FILE" ]]; then
        # 状態ファイルから"creating"や"cleaning"状態のAIを検出
        local stale_states=()
        for ai_name in claude gemini amp qwen droid codex cursor; do
            local state=$(get_worktree_state "$ai_name" 2>/dev/null || echo "none")
            if [[ "$state" == "creating" || "$state" == "cleaning" ]]; then
                stale_states+=("$ai_name ($state)")
            fi
        done

        if [[ ${#stale_states[@]} -gt 0 ]]; then
            issues_found=$((issues_found + 1))
            echo "  ⚠ 中断された可能性のある操作:"
            printf "    %s\n" "${stale_states[@]}"
        else
            echo "  ✓ 状態ファイルは正常"
        fi
    else
        echo "  ✓ 状態ファイルなし（クリーンな状態）"
    fi
    echo ""

    # 4. ロックファイルの確認
    echo "[4/4] ロックファイルをチェック..."
    if [[ -f "$WORKTREE_LOCK_FILE" ]]; then
        # ロックファイルのプロセスIDを確認
        local lock_pid
        if lock_pid=$(cat "$WORKTREE_LOCK_FILE" 2>/dev/null); then
            if ! ps -p "$lock_pid" > /dev/null 2>&1; then
                issues_found=$((issues_found + 1))
                echo "  ⚠ 古いロックファイルが残っています (PID: $lock_pid, プロセスは存在しません)"
            else
                echo "  ℹ ロックファイルが存在します (PID: $lock_pid, プロセスは実行中)"
            fi
        else
            echo "  ⚠ ロックファイルの形式が不正です"
            issues_found=$((issues_found + 1))
        fi
    else
        echo "  ✓ ロックファイルなし"
    fi
    echo ""

    # サマリー
    echo "=== ヘルスチェック完了 ==="
    if [[ $issues_found -eq 0 ]]; then
        echo "✓ システムは健全です"
        vibe_log "worktree-health" "check-passed" \
            "{\"issues\":0}" \
            "Worktreeシステムは健全" \
            "[]" \
            "worktree-health"
        return 0
    else
        echo "⚠ $issues_found 件の問題が検出されました"
        vibe_log "worktree-health" "check-failed" \
            "{\"issues\":$issues_found}" \
            "Worktreeシステムに問題が検出されました" \
            "[\"run-recovery\"]" \
            "worktree-health"
        return 1
    fi
}

# ========================================
# Phase 2.2.2: 自動リカバリー機能
# ========================================

##
# 孤立したWorktreeを復旧（prune実行）
#
# 引数:
#   なし
#
# 戻り値:
#   0 - 復旧成功
#   1 - 復旧失敗
#
# 動作:
#   - git worktree pruneで孤立Worktreeをクリーンアップ
#
# 例:
#   recover_orphaned_worktrees
##
recover_orphaned_worktrees() {
    echo "孤立したWorktreeを復旧中..."
    if prune_orphaned_worktrees; then
        echo "✓ 孤立Worktreeの復旧が完了しました"
        return 0
    else
        echo "✗ 孤立Worktreeの復旧に失敗しました" >&2
        return 1
    fi
}

##
# 孤立したブランチを削除
#
# 引数:
#   なし
#
# 戻り値:
#   0 - 削除成功
#   1 - 削除失敗
#
# 動作:
#   - detect_orphaned_branches()で検出されたブランチを削除
#
# 例:
#   recover_orphaned_branches
##
recover_orphaned_branches() {
    echo "孤立したブランチを復旧中..."

    local orphaned_branches
    if ! orphaned_branches=$(detect_orphaned_branches 2>&1); then
        echo "✓ 孤立したブランチはありません"
        return 0
    fi

    local deleted_count=0
    local failed_count=0

    while IFS= read -r branch; do
        # "⚠ Orphaned branch detected:" 行はスキップ
        if [[ "$branch" =~ ^⚠ ]]; then
            continue
        fi

        # 空行スキップ
        if [[ -z "$branch" ]]; then
            continue
        fi

        # "✓ No orphaned branches found" 行はスキップ
        if [[ "$branch" =~ ^✓ ]]; then
            continue
        fi

        echo "  削除中: $branch"
        if git branch -D "$branch" 2>/dev/null; then
            deleted_count=$((deleted_count + 1))
            echo "    ✓ 削除成功"
        else
            failed_count=$((failed_count + 1))
            echo "    ✗ 削除失敗" >&2
        fi
    done <<< "$orphaned_branches"

    echo ""
    echo "削除成功: $deleted_count 個"
    if [[ $failed_count -gt 0 ]]; then
        echo "削除失敗: $failed_count 個" >&2
        return 1
    fi

    return 0
}

##
# 古いロックファイルを削除
#
# 引数:
#   なし
#
# 戻り値:
#   0 - 削除成功またはロックファイルなし
#   1 - 削除失敗
#
# 動作:
#   - ロックファイルのPIDが存在しない場合、削除
#
# 例:
#   recover_stale_locks
##
recover_stale_locks() {
    echo "古いロックファイルをチェック中..."

    if [[ ! -f "$WORKTREE_LOCK_FILE" ]]; then
        echo "✓ ロックファイルはありません"
        return 0
    fi

    local lock_pid
    if lock_pid=$(cat "$WORKTREE_LOCK_FILE" 2>/dev/null); then
        if ! ps -p "$lock_pid" > /dev/null 2>&1; then
            echo "  ⚠ 古いロックファイルを削除します (PID: $lock_pid)"
            if rm -f "$WORKTREE_LOCK_FILE"; then
                echo "  ✓ ロックファイルを削除しました"
                return 0
            else
                echo "  ✗ ロックファイルの削除に失敗しました" >&2
                return 1
            fi
        else
            echo "  ℹ ロックファイルは有効です (PID: $lock_pid)"
            return 0
        fi
    else
        echo "  ⚠ ロックファイルの形式が不正です、削除します"
        rm -f "$WORKTREE_LOCK_FILE"
        return 0
    fi
}

##
# 中断された状態を復旧
#
# 引数:
#   なし
#
# 戻り値:
#   0 - 復旧成功
#   1 - 復旧失敗
#
# 動作:
#   - "creating"や"cleaning"状態のAIを検出
#   - 対応するWorktreeを強制削除
#   - 状態を"none"に更新
#
# 例:
#   recover_stale_states
##
recover_stale_states() {
    echo "中断された状態を復旧中..."

    if [[ ! -f "$WORKTREE_STATE_FILE" ]]; then
        echo "✓ 状態ファイルはありません"
        return 0
    fi

    local recovered_count=0
    local failed_count=0

    for ai_name in claude gemini amp qwen droid codex cursor; do
        local state=$(get_worktree_state "$ai_name" 2>/dev/null || echo "none")

        if [[ "$state" == "creating" || "$state" == "cleaning" ]]; then
            echo "  復旧中: $ai_name (state: $state)"

            # Worktreeが存在する場合は削除
            if [[ -d "$WORKTREE_BASE_DIR/$ai_name" ]]; then
                if cleanup_worktree "$ai_name" "true"; then
                    recovered_count=$((recovered_count + 1))
                    echo "    ✓ 復旧成功"
                else
                    failed_count=$((failed_count + 1))
                    echo "    ✗ 復旧失敗" >&2
                fi
            else
                # Worktreeが存在しない場合は状態のみリセット
                save_worktree_state "$ai_name" "none"
                recovered_count=$((recovered_count + 1))
                echo "    ✓ 状態をリセットしました"
            fi
        fi
    done

    echo ""
    echo "復旧成功: $recovered_count 個"
    if [[ $failed_count -gt 0 ]]; then
        echo "復旧失敗: $failed_count 個" >&2
        return 1
    fi

    return 0
}

##
# 自動リカバリーを実行（ユーザー確認なし）
#
# 引数:
#   なし
#
# 戻り値:
#   0 - 全復旧成功
#   1 - 一部または全復旧失敗
#
# 動作:
#   1. 孤立したWorktreeを復旧
#   2. 孤立したブランチを削除
#   3. 古いロックファイルを削除
#   4. 中断された状態を復旧
#
# 例:
#   auto_recover_worktrees
##
auto_recover_worktrees() {
    echo "=== 自動リカバリー開始 ==="
    echo ""

    # リカバリー開始をログ
    log_recovery_event "recovery-start" '{"trigger":"auto"}'

    vibe_log "worktree-recovery" "auto-start" \
        "{}" \
        "自動リカバリーを開始" \
        "[]" \
        "worktree-recovery"

    local overall_exit_code=0

    # 1. 孤立したWorktreeを復旧
    echo "[1/4] 孤立したWorktreeを復旧..."
    if ! recover_orphaned_worktrees; then
        overall_exit_code=1
    fi
    echo ""

    # 2. 孤立したブランチを削除
    echo "[2/4] 孤立したブランチを削除..."
    if ! recover_orphaned_branches; then
        overall_exit_code=1
    fi
    echo ""

    # 3. 古いロックファイルを削除
    echo "[3/4] 古いロックファイルを削除..."
    if ! recover_stale_locks; then
        overall_exit_code=1
    fi
    echo ""

    # 4. 中断された状態を復旧
    echo "[4/4] 中断された状態を復旧..."
    if ! recover_stale_states; then
        overall_exit_code=1
    fi
    echo ""

    # サマリー
    echo "=== 自動リカバリー完了 ==="
    if [[ $overall_exit_code -eq 0 ]]; then
        echo "✓ すべてのリカバリーが成功しました"

        # 成功をログ
        log_recovery_event "recovery-success" '{"result":"all_successful"}'

        vibe_log "worktree-recovery" "auto-success" \
            "{}" \
            "自動リカバリーが成功" \
            "[]" \
            "worktree-recovery"
    else
        echo "⚠ 一部のリカバリーが失敗しました" >&2

        # 部分的成功をログ
        log_recovery_event "recovery-partial" '{"result":"partial_success"}'

        vibe_log "worktree-recovery" "auto-partial" \
            "{}" \
            "自動リカバリーが部分的に成功" \
            "[\"check-logs\"]" \
            "worktree-recovery"
    fi

    return $overall_exit_code
}

##
# ユーザー確認付きリカバリーを実行
#
# 引数:
#   なし
#
# 戻り値:
#   0 - リカバリー成功またはユーザーがスキップ
#   1 - リカバリー失敗
#
# 動作:
#   1. ヘルスチェックを実行
#   2. 問題が検出された場合、ユーザーに確認
#   3. ユーザーが承認したらauto_recover_worktrees()を実行
#
# 例:
#   prompt_user_recovery
##
prompt_user_recovery() {
    # ヘルスチェックを実行
    if check_worktree_health; then
        echo ""
        echo "リカバリーは不要です"
        return 0
    fi

    echo ""
    echo "問題が検出されました。リカバリーを実行しますか？"
    echo "  - 孤立したWorktree/ブランチを削除"
    echo "  - 古いロックファイルを削除"
    echo "  - 中断された状態を復旧"
    echo ""

    # インタラクティブモードチェック
    if [[ -t 0 ]] && [[ "${CI:-false}" != "true" ]] && [[ "${NON_INTERACTIVE:-false}" != "true" ]]; then
        # インタラクティブモード: ユーザーに確認
        echo -n "リカバリーを実行しますか？ (Y/n): "
        read -r response

        # デフォルトはY（空入力またはY/y）
        if [[ -z "$response" ]] || [[ "$response" =~ ^[Yy]$ ]]; then
            echo ""
            auto_recover_worktrees
            return $?
        else
            echo "リカバリーをスキップしました"
            return 0
        fi
    else
        # 非インタラクティブモード: 自動実行
        echo "非インタラクティブモード: 自動リカバリーを実行します"
        echo ""
        auto_recover_worktrees
        return $?
    fi
}

# ========================================
# Phase 2.2.3: リカバリーログ機能
# ========================================

##
# リカバリーイベントを記録
#
# 引数:
#   $1 - イベントタイプ（recovery-start|recovery-end|issue-detected|issue-resolved）
#   $2 - JSON形式のメタデータ
#
# 戻り値:
#   0 - 常に成功
#
# 動作:
#   - NDJSON形式でリカバリーログを記録
#   - ファイル: $RECOVERY_LOG_DIR/YYYYMMDD/recovery.ndjson
#
# 例:
#   log_recovery_event "recovery-start" '{"trigger":"manual"}'
#   log_recovery_event "issue-detected" '{"type":"orphaned_worktree","count":2}'
##
log_recovery_event() {
    local event_type="$1"
    local metadata="$2"

    local date_string=$(date +%Y%m%d)
    local log_dir="$RECOVERY_LOG_DIR/$date_string"
    local log_file="$log_dir/recovery.ndjson"

    mkdir -p "$log_dir"

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # NDJSON形式で記録
    local log_entry
    log_entry=$(jq -n \
        --arg timestamp "$timestamp" \
        --arg event "$event_type" \
        --argjson meta "$metadata" \
        '{timestamp: $timestamp, event: $event, metadata: $meta}')

    echo "$log_entry" >> "$log_file"

    # VibeLoggerにも記録
    vibe_log "worktree-recovery" "$event_type" \
        "$metadata" \
        "リカバリーイベント: $event_type" \
        "[]" \
        "worktree-recovery"
}

##
# リカバリー統計情報を取得
#
# 引数:
#   $1 - （オプション）日数（デフォルト: 7日間）
#
# 戻り値:
#   0 - 常に成功
#
# 出力:
#   JSON形式の統計情報
#
# 例:
#   get_recovery_statistics 7
#   get_recovery_statistics  # デフォルト7日間
##
get_recovery_statistics() {
    local days="${1:-7}"

    echo "=== リカバリー統計（過去${days}日間） ==="
    echo ""

    local total_recoveries=0
    local successful_recoveries=0
    local failed_recoveries=0
    local orphaned_worktrees=0
    local orphaned_branches=0
    local stale_locks=0
    local stale_states=0

    # 過去N日分のログを集計
    for ((i=0; i<days; i++)); do
        local date_string=$(date -d "$i days ago" +%Y%m%d 2>/dev/null || date -v -"${i}"d +%Y%m%d)
        local log_file="$RECOVERY_LOG_DIR/$date_string/recovery.ndjson"

        if [[ ! -f "$log_file" ]]; then
            continue
        fi

        while IFS= read -r line; do
            local event=$(echo "$line" | jq -r '.event')

            case "$event" in
                recovery-start)
                    total_recoveries=$((total_recoveries + 1))
                    ;;
                recovery-success)
                    successful_recoveries=$((successful_recoveries + 1))
                    ;;
                recovery-partial|recovery-failed)
                    failed_recoveries=$((failed_recoveries + 1))
                    ;;
                issue-detected)
                    local issue_type=$(echo "$line" | jq -r '.metadata.type')
                    case "$issue_type" in
                        orphaned_worktree)
                            local count=$(echo "$line" | jq -r '.metadata.count // 1')
                            orphaned_worktrees=$((orphaned_worktrees + count))
                            ;;
                        orphaned_branch)
                            local count=$(echo "$line" | jq -r '.metadata.count // 1')
                            orphaned_branches=$((orphaned_branches + count))
                            ;;
                        stale_lock)
                            stale_locks=$((stale_locks + 1))
                            ;;
                        stale_state)
                            local count=$(echo "$line" | jq -r '.metadata.count // 1')
                            stale_states=$((stale_states + count))
                            ;;
                    esac
                    ;;
            esac
        done < "$log_file"
    done

    # 成功率を計算
    local success_rate=0
    if [[ $total_recoveries -gt 0 ]]; then
        success_rate=$(awk "BEGIN {printf \"%.1f\", ($successful_recoveries / $total_recoveries) * 100}")
    fi

    # JSON形式で出力
    jq -n \
        --arg days "$days" \
        --arg total "$total_recoveries" \
        --arg success "$successful_recoveries" \
        --arg failed "$failed_recoveries" \
        --arg rate "$success_rate" \
        --arg worktrees "$orphaned_worktrees" \
        --arg branches "$orphaned_branches" \
        --arg locks "$stale_locks" \
        --arg states "$stale_states" \
        '{
            period_days: $days,
            total_recoveries: $total,
            successful: $success,
            failed: $failed,
            success_rate: $rate,
            issues: {
                orphaned_worktrees: $worktrees,
                orphaned_branches: $branches,
                stale_locks: $locks,
                stale_states: $states
            }
        }'

    echo ""
    echo "総リカバリー実行数: $total_recoveries"
    echo "成功: $successful_recoveries"
    echo "失敗: $failed_recoveries"
    echo "成功率: ${success_rate}%"
    echo ""
    echo "検出された問題:"
    echo "  - 孤立Worktree: $orphaned_worktrees 件"
    echo "  - 孤立ブランチ: $orphaned_branches 件"
    echo "  - 古いロックファイル: $stale_locks 件"
    echo "  - 中断された状態: $stale_states 件"
}

##
# リカバリー履歴を分析
#
# 引数:
#   $1 - （オプション）日数（デフォルト: 30日間）
#
# 戻り値:
#   0 - 常に成功
#
# 出力:
#   人間が読める形式のレポート
#
# 例:
#   analyze_recovery_history 30
##
analyze_recovery_history() {
    local days="${1:-30}"

    echo "=== リカバリー履歴分析（過去${days}日間） ==="
    echo ""

    # 統計情報を取得
    local stats=$(get_recovery_statistics "$days")

    echo "$stats" | jq .

    echo ""
    echo "=== 推奨事項 ==="

    local total=$(echo "$stats" | jq -r '.total_recoveries')
    local failed=$(echo "$stats" | jq -r '.failed')
    local orphaned_worktrees=$(echo "$stats" | jq -r '.issues.orphaned_worktrees')

    if [[ "$total" -eq 0 ]]; then
        echo "✓ リカバリー実行履歴がありません"
        echo "  システムは安定しています"
    elif [[ "$failed" -gt 3 ]]; then
        echo "⚠ リカバリー失敗が多発しています"
        echo "  以下を確認してください:"
        echo "  - ディスク容量"
        echo "  - ファイル権限"
        echo "  - Git設定"
    elif [[ "$orphaned_worktrees" -gt 10 ]]; then
        echo "⚠ 孤立Worktreeが多発しています"
        echo "  以下を確認してください:"
        echo "  - 異常終了の原因（ログを確認）"
        echo "  - trapハンドラの動作"
        echo "  - タイムアウト設定"
    else
        echo "✓ システムは正常に動作しています"
        echo "  定期的なヘルスチェックを継続してください"
    fi
}

# スクリプトとして直接実行された場合のテスト
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "worktree-execution.sh - AI execution and error recovery in worktrees"
  echo ""
  echo "Usage: source this file, then call functions"
  echo ""
  echo "Available functions (Phase 2.2.1):"
  echo "  - detect_orphaned_worktrees"
  echo "  - detect_orphaned_branches"
  echo "  - check_worktree_health"
  echo ""
  echo "Running health check..."
  check_worktree_health
  exit $?
fi
