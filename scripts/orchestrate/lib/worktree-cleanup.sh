#!/usr/bin/env bash
# worktree-cleanup.sh - クリーンアップと状態管理
# 責務：ワークツリー削除、状態復旧、障害処理

set -euo pipefail

# 依存関係をソース
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/worktree-core.sh"

# クリーンアップ用のtrapハンドラ
trap cleanup_all_worktrees EXIT INT TERM

# ========================================
# クリーンアップ関数
# ========================================

##
# 指定されたAIのワークツリーを削除
#
# 引数:
#   $1 - AI名（claude|gemini|amp|qwen|droid|codex|cursor）
#   $2 - （オプション）強制フラグ（true|false、デフォルト: false）
#
# 戻り値:
#   0 - クリーンアップ成功
#   1 - クリーンアップ失敗
#
# 動作:
#   - ワークツリーディレクトリを削除
#   - 関連するブランチを削除
#   - 状態を"none"に更新
#
# 強制フラグ:
#   - true: 未コミット変更があっても削除
#   - false: 未コミット変更がある場合は失敗
#
# セキュリティ:
#   - データ損失を防ぐため、デフォルトは非強制
#   - 障害復旧時のみ強制削除を推奨
#
# 例:
#   cleanup_worktree "qwen"  # 通常のクリーンアップ
#   cleanup_worktree "droid" "true"  # 強制クリーンアップ
##
cleanup_worktree() {
  local ai_name="$1"
  local force="${2:-false}"

  local worktree_path="$WORKTREE_BASE_DIR/$ai_name"

  # ワークツリーが存在しない場合はスキップ
  if [[ ! -d "$worktree_path" ]]; then
    echo "INFO: ワークツリーが存在しません（既に削除済み）: $worktree_path"
    return 0
  fi

  # 状態をクリーニング中に更新
  save_worktree_state "$ai_name" "cleaning"

  vibe_log "worktree-cleanup" "start" \
    "{\"ai\":\"$ai_name\",\"path\":\"$worktree_path\",\"force\":$force}" \
    "$ai_nameのワークツリーをクリーンアップ中" \
    "[\"backup-data\"]" \
    "worktree-cleanup"

  # ブランチ名を取得（削除前）
  local branch_name=$(cd "$worktree_path" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

  # ワークツリーを削除
  local exit_code=0
  if [[ "$force" == "true" ]]; then
    git worktree remove "$worktree_path" --force 2>&1 || exit_code=$?
  else
    git worktree remove "$worktree_path" 2>&1 || exit_code=$?
  fi

  if [[ $exit_code -ne 0 ]]; then
    echo "ERROR: ワークツリー削除に失敗: $worktree_path" >&2
    save_worktree_state "$ai_name" "cleanup-failed"
    return $exit_code
  fi

  # ブランチを削除（オプション）
  if [[ -n "$branch_name" ]] && [[ "$branch_name" != "HEAD" ]]; then
    if git rev-parse --verify "$branch_name" &>/dev/null; then
      git branch -D "$branch_name" 2>&1 || echo "WARNING: ブランチ削除に失敗: $branch_name" >&2
    fi
  fi

  # 状態をnoneに更新
  save_worktree_state "$ai_name" "none"

  vibe_log "worktree-cleanup" "done" \
    "{\"ai\":\"$ai_name\",\"exit_code\":$exit_code}" \
    "$ai_nameのクリーンアップが完了" \
    "[]" \
    "worktree-cleanup"

  echo "✓ Cleaned up: $ai_name"
  return 0
}

##
# すべてのワークツリーを削除
#
# 引数:
#   $1 - （オプション）強制フラグ（true|false、デフォルト: false）
#
# 戻り値:
#   0 - 全クリーンアップ成功
#   1 - 一部または全クリーンアップ失敗
#
# 動作:
#   - 全7AIのワークツリーを順次削除
#   - 空のworktreesディレクトリを削除
#   - 状態ファイル（.state.json）を削除
#
# トリガー:
#   - EXIT/INT/TERMシグナル時に自動実行（trapハンドラ）
#   - 手動呼び出し可能
#
# セキュリティ:
#   - P0要件：データ損失ゼロ
#   - 強制フラグなしでは未コミット変更を保護
#
# 例:
#   cleanup_all_worktrees  # 通常のクリーンアップ
#   cleanup_all_worktrees "true"  # 強制クリーンアップ
##
cleanup_all_worktrees() {
  local force="${1:-false}"
  local ai_list=("claude" "gemini" "amp" "qwen" "droid" "codex" "cursor")

  vibe_pipeline_start "cleanup-all-worktrees" "sequential" ${#ai_list[@]}

  local cleaned=()
  local failed=()
  local overall_exit_code=0

  # 順次クリーンアップ
  for ai_name in "${ai_list[@]}"; do
    if cleanup_worktree "$ai_name" "$force"; then
      cleaned+=("$ai_name")
    else
      failed+=("$ai_name")
      overall_exit_code=1
    fi
  done

  # worktreesディレクトリが空なら削除
  if [[ -d "$WORKTREE_BASE_DIR" ]] && [[ -z "$(ls -A "$WORKTREE_BASE_DIR")" ]]; then
    rmdir "$WORKTREE_BASE_DIR"
    echo "✓ Removed empty worktrees directory"
  fi

  # 状態ファイルを削除
  if [[ -f "$WORKTREE_STATE_FILE" ]]; then
    rm -f "$WORKTREE_STATE_FILE"
    echo "✓ Removed state file"
  fi

  vibe_pipeline_done "cleanup-all-worktrees" \
    "$([[ $overall_exit_code -eq 0 ]] && echo 'success' || echo 'partial')" \
    "$SECONDS" \
    ${#ai_list[@]}

  # 結果を報告
  echo ""
  echo "クリーンアップ成功: ${#cleaned[@]}個"
  if [[ ${#failed[@]} -gt 0 ]]; then
    echo "クリーンアップ失敗: ${#failed[@]}個" >&2
    echo "失敗したAI: ${failed[*]}" >&2
  fi

  return $overall_exit_code
}

# ========================================
# 障害復旧関数
# ========================================

##
# エラー状態のワークツリーから復旧
#
# 引数:
#   なし
#
# 戻り値:
#   0 - 全復旧成功
#   1 - 一部または全復旧失敗
#
# 動作:
#   1. 状態ファイルから各AIの状態を読み込み
#   2. error/merge-failed/cleanup-failedの場合、強制削除で復旧
#   3. none状態は正常と判断
#   4. その他の状態は復旧不要
#
# 用途:
#   - クラッシュ後の復旧
#   - CI/CDパイプライン失敗後のクリーンアップ
#   - 手動介入が必要な状況の検出
#
# セキュリティ:
#   - 強制削除を使用（データ損失の可能性）
#   - エラー状態のみ対象（active状態は保護）
#
# 例:
#   if ! multi-ai-full-orchestrate "task"; then
#     recover_from_failure
#   fi
##
recover_from_failure() {
  echo "障害復旧を開始します..."

  # 状態ファイルを読み込み
  load_worktree_state

  local recovered=()
  local failed=()

  # 各AIの状態をチェック
  for ai_name in claude gemini amp qwen droid codex cursor; do
    local state=$(get_worktree_state "$ai_name")

    case "$state" in
      error|merge-failed|cleanup-failed)
        echo "⚠ Recovering $ai_name from state: $state"

        # エラー状態のワークツリーを強制削除
        if cleanup_worktree "$ai_name" "true"; then
          recovered+=("$ai_name")
          echo "✓ Recovered: $ai_name"
        else
          failed+=("$ai_name")
          echo "✗ Recovery failed: $ai_name" >&2
        fi
        ;;
      none)
        echo "✓ $ai_name is in clean state"
        ;;
      *)
        echo "ℹ $ai_name is in state: $state (no recovery needed)"
        ;;
    esac
  done

  # 結果を報告
  echo ""
  echo "復旧成功: ${#recovered[@]}個"
  if [[ ${#failed[@]} -gt 0 ]]; then
    echo "復旧失敗: ${#failed[@]}個" >&2
    echo "手動での介入が必要なAI: ${failed[*]}" >&2
    return 1
  fi

  return 0
}

# ========================================
# 孤立したワークツリーの検出と削除
# ========================================

##
# 孤立したワークツリーを検出して削除
#
# 引数:
#   なし
#
# 戻り値:
#   0 - prune成功
#   1 - prune失敗
#
# 動作:
#   - git worktree pruneを実行
#   - 削除されたディレクトリへの参照をクリーンアップ
#   - .git/worktrees/内の古いメタデータを削除
#
# 用途:
#   - 手動でrmした後のクリーンアップ
#   - 定期的なメンテナンス
#   - CI/CDパイプラインの事後処理
#
# 実装:
#   - Gitの組み込み機能を使用（安全）
#   - --verboseで削除内容を表示
#
# 例:
#   prune_orphaned_worktrees  # 定期メンテナンス
##
prune_orphaned_worktrees() {
  echo "孤立したワークツリーをチェック中..."

  # Gitの組み込み機能でpruneを実行
  if git worktree prune --verbose 2>&1; then
    echo "✓ 孤立したワークツリーをクリーンアップしました"
    return 0
  else
    echo "✗ pruneに失敗しました" >&2
    return 1
  fi
}

# スクリプトとして直接実行された場合のテスト
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "worktree-cleanup.sh - Cleanup and state management"
  echo "This module should be sourced, not executed directly"
  exit 1
fi
