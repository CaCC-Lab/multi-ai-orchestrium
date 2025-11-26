#!/usr/bin/env bash
# worktree-execution.sh - ワークツリー内のAI実行
# 責務：AIタスク実行、出力管理、タイムアウト処理

set -euo pipefail

# 依存関係をソース
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/worktree-core.sh"

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

# スクリプトとして直接実行された場合のテスト
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "worktree-execution.sh - AI execution in worktrees"
  echo "This module should be sourced, not executed directly"
  exit 1
fi
