#!/usr/bin/env bash
# すべてのワークツリーの視覚的ステータス表示

show_worktree_status() {
  local ai_list=(claude gemini amp qwen droid codex cursor)

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Multi-AI Worktreesステータス"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "%-10s %-10s %-30s %-15s\n" "AI" "ステータス" "ブランチ" "未コミット"
  echo "────────────────────────────────────────────────"

  for ai_name in "${ai_list[@]}"; do
    local worktree_path="$WORKTREE_BASE_DIR/$ai_name"

    if [[ -d "$worktree_path" ]]; then
      local state=$(get_worktree_state "$ai_name")
      local branch=$(cd "$worktree_path" && git rev-parse --abbrev-ref HEAD)
      local uncommitted=$(cd "$worktree_path" && git status --porcelain | wc -l)

      # カラーコーディング
      case "$state" in
        active) state="🟢 アクティブ" ;;
        creating) state="🟡 作成中" ;;
        executing) state="🔵 実行中" ;;
        merging) state="🟣 マージ中" ;;
        error) state="🔴 エラー" ;;
        *) state="⚪ 不明" ;;
      esac

      printf "%-10s %-15s %-30s %-15s\n" \
        "$ai_name" "$state" "$branch" "$uncommitted ファイル"
    else
      printf "%-10s %-15s %-30s %-15s\n" \
        "$ai_name" "⚫ 未作成" "-" "-"
    fi
  done

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # ディスク使用量
  if [[ -d "$WORKTREE_BASE_DIR" ]]; then
    local total_size=$(du -sh "$WORKTREE_BASE_DIR" | cut -f1)
    echo "総ディスク使用量: $total_size"
  fi
}

# メイン実行
source "$(dirname "${BASH_SOURCE[0]}")/worktree-core.sh"
load_worktree_state
show_worktree_status
