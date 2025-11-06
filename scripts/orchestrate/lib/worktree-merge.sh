#!/usr/bin/env bash
# worktree-merge.sh - マージ戦略と競合処理
# 責務：ブランチマージ、競合解決、履歴維持

set -euo pipefail

# 依存関係をソース
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/worktree-core.sh"

# git-rerereを有効化（Gemini推奨 - 競合の自動解決）
git config rerere.enabled true 2>/dev/null || true
git config rerere.autoupdate true 2>/dev/null || true

# ========================================
# マージ関数
# ========================================

##
# ワークツリーのブランチをターゲットブランチにマージ
#
# 引数:
#   $1 - AI名（claude|gemini|amp|qwen|droid|codex|cursor）
#   $2 - （オプション）ターゲットブランチ（デフォルト: main）
#   $3 - （オプション）マージ戦略（no-ff|ff-only|squash、デフォルト: no-ff）
#
# 戻り値:
#   0 - マージ成功
#   1 - マージ失敗（競合、戦略エラーなど）
#
# マージ戦略:
#   - no-ff: マージコミットを作成（AI貢献を明確に記録）
#   - ff-only: Fast-forwardのみ許可（直線的な履歴）
#   - squash: 複数コミットを1つに統合（クリーンな履歴）
#
# セキュリティ:
#   - git-rerere有効化（自動競合解決）
#   - 状態管理（merging → merged/merge-failed）
#
# 例:
#   merge_worktree_branch "qwen"  # no-ffマージ
#   merge_worktree_branch "droid" "main" "squash"  # squashマージ
##
merge_worktree_branch() {
  local ai_name="$1"
  local target_branch="${2:-main}"
  local merge_strategy="${3:-no-ff}"  # no-ff | ff-only | squash

  local worktree_path="$WORKTREE_BASE_DIR/$ai_name"

  # ワークツリーの存在確認
  if [[ ! -d "$worktree_path" ]]; then
    echo "ERROR: ワークツリーが存在しません: $worktree_path" >&2
    return 1
  fi

  # 状態をマージ中に更新
  save_worktree_state "$ai_name" "merging"

  # ワークツリー内のブランチ名を取得
  local source_branch=$(cd "$worktree_path" && git rev-parse --abbrev-ref HEAD)

  vibe_log "worktree-merge" "start" \
    "{\"ai\":\"$ai_name\",\"source\":\"$source_branch\",\"target\":\"$target_branch\",\"strategy\":\"$merge_strategy\"}" \
    "$ai_nameのブランチをマージ中" \
    "[\"check-conflicts\"]" \
    "worktree-merge"

  # メインリポジトリに戻ってマージ
  local exit_code=0
  local project_root=$(git rev-parse --show-toplevel)

  (
    cd "$project_root"

    # ターゲットブランチが存在することを確認
    if ! git rev-parse --verify "$target_branch" >/dev/null 2>&1; then
      echo "ERROR: ターゲットブランチ '$target_branch' が存在しません" >&2
      return 1
    fi

    # ターゲットブランチをチェックアウト
    if ! git checkout "$target_branch"; then
      echo "ERROR: ブランチ '$target_branch' のチェックアウトに失敗しました" >&2
      return 1
    fi

    # マージ戦略に応じて実行
    case "$merge_strategy" in
      no-ff)
        if git merge --no-ff "$source_branch" -m "merge: Integrate $ai_name changes from $source_branch"; then
          echo "SUCCESS: Merged $source_branch into $target_branch"
        else
          exit_code=$?
          echo "ERROR: Merge conflict detected" >&2
          # マージ失敗時は自動的にabort（リポジトリを元の状態に戻す）
          git merge --abort 2>/dev/null || true
          return $exit_code
        fi
        ;;
      ff-only)
        if git merge --ff-only "$source_branch"; then
          echo "SUCCESS: Fast-forward merged $source_branch"
        else
          exit_code=$?
          echo "ERROR: Cannot fast-forward merge" >&2
          # マージ失敗時は自動的にabort
          git merge --abort 2>/dev/null || true
          return $exit_code
        fi
        ;;
      squash)
        if git merge --squash "$source_branch"; then
          git commit -m "merge: Squash merge $ai_name changes from $source_branch"
          echo "SUCCESS: Squash merged $source_branch"
        else
          exit_code=$?
          echo "ERROR: Squash merge failed" >&2
          # マージ失敗時は自動的にabort
          git merge --abort 2>/dev/null || true
          return $exit_code
        fi
        ;;
      *)
        echo "ERROR: Unknown merge strategy: $merge_strategy" >&2
        return 1
        ;;
    esac
  ) || exit_code=$?

  # 状態を更新
  if [[ $exit_code -eq 0 ]]; then
    save_worktree_state "$ai_name" "merged"
  else
    save_worktree_state "$ai_name" "merge-failed"
  fi

  vibe_log "worktree-merge" "done" \
    "{\"ai\":\"$ai_name\",\"exit_code\":$exit_code}" \
    "$ai_nameのマージが完了" \
    "[]" \
    "worktree-merge"

  return $exit_code
}

##
# 複数のワークツリーブランチを順次マージ
#
# 引数:
#   $1 - （オプション）ターゲットブランチ（デフォルト: main）
#   $2 - （オプション）マージ戦略（no-ff|ff-only|squash、デフォルト: no-ff）
#   $@ - （オプション、3番目以降）AI名のリスト（デフォルト: 全7AI）
#
# 戻り値:
#   0 - 全マージ成功
#   1 - 一部または全マージ失敗
#
# 特徴:
#   - 順次マージ（後のAIは前のAIの変更の上に構築）
#   - 競合時にユーザーに手動解決を促す
#   - 部分的失敗でも続行
#
# 推奨順序:
#   1. Qwen（高速プロトタイプ）
#   2. Droid（品質改善）
#   3. Codex（最適化）
#
# 例:
#   merge_all_sequential  # 全7AIを順次マージ
#   merge_all_sequential "main" "squash" qwen droid  # 2AIのみsquashマージ
##
merge_all_sequential() {
  local target_branch="${1:-main}"
  local merge_strategy="${2:-no-ff}"
  local ai_list=("${@:3}")

  # デフォルトのAIリスト
  if [[ ${#ai_list[@]} -eq 0 ]]; then
    ai_list=("claude" "gemini" "amp" "qwen" "droid" "codex" "cursor")
  fi

  vibe_pipeline_start "merge-all-sequential" "sequential" ${#ai_list[@]}

  local merged=()
  local failed=()
  local overall_exit_code=0

  # 順次マージ
  for ai_name in "${ai_list[@]}"; do
    if merge_worktree_branch "$ai_name" "$target_branch" "$merge_strategy"; then
      merged+=("$ai_name")
      echo "✓ Merged: $ai_name"
    else
      failed+=("$ai_name")
      overall_exit_code=1
      echo "✗ Failed: $ai_name" >&2

      # 競合が発生した場合、ユーザーに通知
      echo "⚠ Merge conflict in $ai_name. Please resolve manually:" >&2
      echo "   cd $WORKTREE_BASE_DIR/$ai_name" >&2
      echo "   # Resolve conflicts, then:" >&2
      echo "   git add ." >&2
      echo "   git commit" >&2
    fi
  done

  vibe_pipeline_done "merge-all-sequential" \
    "$([[ $overall_exit_code -eq 0 ]] && echo 'success' || echo 'partial')" \
    "$SECONDS" \
    ${#ai_list[@]}

  # 結果を報告
  echo ""
  echo "マージ成功: ${merged[*]}"
  if [[ ${#failed[@]} -gt 0 ]]; then
    echo "マージ失敗: ${failed[*]}" >&2
  fi

  return $overall_exit_code
}

# ========================================
# 競合検出関数
# ========================================

##
# マージ前に競合を検出（ドライラン）
#
# 引数:
#   $1 - AI名（claude|gemini|amp|qwen|droid|codex|cursor）
#
# 戻り値:
#   0 - 競合なし（マージ可能）
#   1 - 競合あり
#
# 出力:
#   "OK: No conflicts detected for <ai>"
#   "CONFLICT: Merge conflicts detected for <ai>"
#
# 用途:
#   - マージ前の検証
#   - 並列実行時の競合リスク評価
#   - CI/CDパイプラインの自動チェック
#
# 実装:
#   - git merge-treeでドライラン実行
#   - 実際のリポジトリに影響なし
#
# 例:
#   if check_merge_conflicts "qwen"; then
#     merge_worktree_branch "qwen"
#   else
#     echo "競合があります。手動解決が必要です。"
#   fi
##
check_merge_conflicts() {
  local ai_name="$1"

  local worktree_path="$WORKTREE_BASE_DIR/$ai_name"
  local source_branch=$(cd "$worktree_path" && git rev-parse --abbrev-ref HEAD)

  # ドライランでマージをテスト
  local project_root=$(git rev-parse --show-toplevel)
  (
    cd "$project_root"
    if git merge-tree $(git merge-base HEAD "$source_branch") HEAD "$source_branch" | grep -q "<<<<<"; then
      echo "CONFLICT: Merge conflicts detected for $ai_name"
      return 1
    else
      echo "OK: No conflicts detected for $ai_name"
      return 0
    fi
  )
}

# スクリプトとして直接実行された場合のテスト
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "worktree-merge.sh - Merge strategies and conflict handling"
  echo "This module should be sourced, not executed directly"
  exit 1
fi
