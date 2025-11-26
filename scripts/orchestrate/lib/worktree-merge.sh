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
#   $3 - （オプション）マージ戦略（デフォルト: no-ff）
#
# 戻り値:
#   0 - マージ成功
#   1 - マージ失敗（競合、戦略エラーなど）
#
# マージ戦略:
#   - no-ff: マージコミットを作成（AI貢献を明確に記録）
#   - ff-only: Fast-forwardのみ許可（直線的な履歴）
#   - squash: 複数コミットを1つに統合（クリーンな履歴）
#   - ours: 競合時にOURS（ターゲットブランチ）を優先
#   - theirs: 競合時にTHEIRS（AIブランチ）を優先
#   - manual: インタラクティブに競合を解決
#   - best: 品質スコアベースで最適な戦略を自動選択
#
# セキュリティ:
#   - git-rerere有効化（自動競合解決）
#   - 状態管理（merging → merged/merge-failed）
#
# 例:
#   merge_worktree_branch "qwen"  # no-ffマージ
#   merge_worktree_branch "droid" "main" "squash"  # squashマージ
#   merge_worktree_branch "qwen" "main" "theirs"  # Qwenの変更を優先
#   merge_worktree_branch "droid" "main" "manual"  # 対話的に解決
##
merge_worktree_branch() {
  local ai_name="$1"
  local target_branch="${2:-main}"
  local merge_strategy="${3:-no-ff}"  # no-ff | ff-only | squash | ours | theirs | manual | best

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
      ours)
        if git merge -X ours --no-ff "$source_branch" -m "merge: Integrate $ai_name (ours strategy)"; then
          echo "SUCCESS: Merged $source_branch (ours strategy - target branch priority)"
        else
          exit_code=$?
          echo "ERROR: Merge with ours strategy failed" >&2
          git merge --abort 2>/dev/null || true
          return $exit_code
        fi
        ;;
      theirs)
        if git merge -X theirs --no-ff "$source_branch" -m "merge: Integrate $ai_name (theirs strategy)"; then
          echo "SUCCESS: Merged $source_branch (theirs strategy - AI branch priority)"
        else
          exit_code=$?
          echo "ERROR: Merge with theirs strategy failed" >&2
          git merge --abort 2>/dev/null || true
          return $exit_code
        fi
        ;;
      manual)
        # インタラクティブ競合解決を呼び出す
        # 非対話モードの場合は theirs 戦略にフォールバック
        if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
          echo "INFO: Non-interactive mode - falling back to 'theirs' strategy"
          if git merge -X theirs --no-ff "$source_branch" -m "merge: Integrate $ai_name (auto: theirs)"; then
            echo "SUCCESS: Merged $source_branch (non-interactive fallback: theirs)"
          else
            exit_code=$?
            echo "ERROR: Non-interactive merge failed" >&2
            git merge --abort 2>/dev/null || true
            return $exit_code
          fi
        else
          # この関数はファイルの後半で定義されているため、source済みであることを前提とする
          if interactive_conflict_resolution "$ai_name" "$target_branch"; then
            echo "SUCCESS: Manual conflict resolution completed"
          else
            exit_code=$?
            echo "ERROR: Manual conflict resolution failed or was cancelled" >&2
            return $exit_code
          fi
        fi
        ;;
      best)
        # 品質スコアベースの戦略選択（簡易版）
        # 1. 競合チェック
        # 2. 競合なし → fast-forward試行、失敗 → no-ff
        # 3. 競合あり → theirs戦略（AI優先）
        echo "INFO: Using best strategy (automatic selection)..."

        # 競合チェック
        local merge_base=$(git merge-base HEAD "$source_branch")
        if git merge-tree "$merge_base" HEAD "$source_branch" | grep -q "<<<<<"; then
          echo "INFO: Conflicts detected, using 'theirs' strategy (AI priority)"
          if git merge -X theirs --no-ff "$source_branch" -m "merge: Integrate $ai_name (auto: theirs)"; then
            echo "SUCCESS: Merged $source_branch (best strategy: theirs)"
          else
            exit_code=$?
            echo "ERROR: Best strategy merge failed" >&2
            git merge --abort 2>/dev/null || true
            return $exit_code
          fi
        else
          # 競合なし - fast-forward試行
          if git merge --ff-only "$source_branch" 2>/dev/null; then
            echo "SUCCESS: Fast-forward merged $source_branch (best strategy: ff-only)"
          else
            # fast-forward失敗 → no-ff
            if git merge --no-ff "$source_branch" -m "merge: Integrate $ai_name (auto: no-ff)"; then
              echo "SUCCESS: Merged $source_branch (best strategy: no-ff)"
            else
              exit_code=$?
              echo "ERROR: Best strategy merge failed" >&2
              git merge --abort 2>/dev/null || true
              return $exit_code
            fi
          fi
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
# マージ競合をカラー表示で可視化
#
# 引数:
#   $1 - AI名（claude|gemini|amp|qwen|droid|codex|cursor）
#   $2 - （オプション）ターゲットブランチ（デフォルト: main）
#
# 戻り値:
#   0 - 可視化成功
#   1 - エラー（Worktreeなし、競合なし）
#
# 出力:
#   カラー表示された競合箇所
#   ファイル名、行番号、競合内容を整形して表示
#
# 例:
#   visualize_merge_conflicts "qwen"
#   visualize_merge_conflicts "droid" "develop"
##
visualize_merge_conflicts() {
  local ai_name="$1"
  local target_branch="${2:-main}"

  local worktree_path="$WORKTREE_BASE_DIR/$ai_name"

  # Worktreeの存在確認
  if [[ ! -d "$worktree_path" ]]; then
    echo "ERROR: Worktreeが存在しません: $worktree_path" >&2
    return 1
  fi

  # ブランチ名を取得
  local source_branch=$(cd "$worktree_path" && git rev-parse --abbrev-ref HEAD)
  local project_root=$(git rev-parse --show-toplevel)

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔍 Merge Conflict Visualization: $ai_name"
  echo "   Source: $source_branch"
  echo "   Target: $target_branch"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # ドライランで競合をチェック
  (
    cd "$project_root"
    local merge_base=$(git merge-base "$target_branch" "$source_branch")
    local merge_tree_output=$(git merge-tree "$merge_base" "$target_branch" "$source_branch")

    # 競合マーカーを検索
    if ! echo "$merge_tree_output" | grep -q "<<<<<"; then
      echo "✓ 競合は検出されませんでした"
      return 0
    fi

    # 競合ファイルを抽出
    local conflict_files=$(echo "$merge_tree_output" | grep -A 20 "<<<<<" | grep -B 5 "=====" | grep -B 10 ">>>>>" || true)

    # ファイル別に競合を表示
    echo "$merge_tree_output" | awk '
      /^<<<<<<< / { in_conflict=1; conflict_start=NR; ours=$0; next }
      /^=======/ { if (in_conflict) { separator=NR } }
      /^>>>>>>> / {
        if (in_conflict) {
          theirs=$0
          print "┌─ CONFLICT at lines " conflict_start "-" NR " ─────────────────"
          print "│ \033[0;31m" ours "\033[0m"
          for (i=conflict_start+1; i<separator; i++) { print "│ \033[0;31m  " lines[i] "\033[0m" }
          print "│ \033[0;33m=======\033[0m"
          for (i=separator+1; i<NR; i++) { print "│ \033[0;32m  " lines[i] "\033[0m" }
          print "│ \033[0;32m" theirs "\033[0m"
          print "└────────────────────────────────────────────────"
          print ""
          in_conflict=0
        }
      }
      { if (in_conflict) lines[NR]=$0 }
    '
  )
}

##
# 複数AIの変更を並列比較
#
# 引数:
#   $1 - 比較対象ファイルパス（オプション、省略時は全ファイル）
#   $@ - AI名のリスト（2つ以上、例: qwen droid）
#
# 戻り値:
#   0 - 比較成功
#   1 - エラー（AI数不足、Worktreeなし）
#
# 出力:
#   並列表示された各AIの変更内容
#   カラー表示で差分をハイライト
#
# 例:
#   compare_ai_changes "" qwen droid
#   compare_ai_changes "src/app.js" qwen droid codex
##
compare_ai_changes() {
  local file_filter="$1"
  shift
  local ai_list=("$@")

  # AI数のチェック
  if [[ ${#ai_list[@]} -lt 2 ]]; then
    echo "ERROR: 少なくとも2つのAIが必要です（指定: ${#ai_list[@]}個）" >&2
    return 1
  fi

  # 全Worktreeの存在確認
  for ai_name in "${ai_list[@]}"; do
    if [[ ! -d "$WORKTREE_BASE_DIR/$ai_name" ]]; then
      echo "ERROR: Worktreeが存在しません: $ai_name" >&2
      return 1
    fi
  done

  local project_root=$(git rev-parse --show-toplevel)

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 AI Changes Comparison: ${ai_list[*]}"
  if [[ -n "$file_filter" ]]; then
    echo "   File: $file_filter"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # 各AIの変更を取得
  local -A ai_changes
  local -A ai_branches

  for ai_name in "${ai_list[@]}"; do
    local worktree_path="$WORKTREE_BASE_DIR/$ai_name"
    ai_branches[$ai_name]=$(cd "$worktree_path" && git rev-parse --abbrev-ref HEAD)

    # mainからの差分を取得
    (
      cd "$project_root"
      local branch="${ai_branches[$ai_name]}"
      if [[ -n "$file_filter" ]]; then
        ai_changes[$ai_name]=$(git diff main.."$branch" -- "$file_filter" 2>/dev/null || echo "No changes")
      else
        ai_changes[$ai_name]=$(git diff main.."$branch" --stat 2>/dev/null || echo "No changes")
      fi
    )
  done

  # 並列表示（簡易版 - 統計情報）
  echo "┌─ Changes Summary ──────────────────────────────"
  for ai_name in "${ai_list[@]}"; do
    echo "│"
    echo "│ 🤖 $ai_name (${ai_branches[$ai_name]})"
    echo "│ ────────────────────────────────────────────"
    # 統計を整形して表示
    echo "${ai_changes[$ai_name]}" | sed 's/^/│   /'
  done
  echo "└────────────────────────────────────────────────"
  echo ""

  # 詳細比較（ファイル指定時のみ）
  if [[ -n "$file_filter" ]]; then
    echo "┌─ Detailed Diff ────────────────────────────────"
    for ai_name in "${ai_list[@]}"; do
      echo "│"
      echo "│ 🤖 $ai_name"
      echo "│ ────────────────────────────────────────────"
      (
        cd "$project_root"
        git diff main.."${ai_branches[$ai_name]}" --color=always -- "$file_filter" | sed 's/^/│   /'
      )
    done
    echo "└────────────────────────────────────────────────"
  fi

  return 0
}

##
# TUIでインタラクティブに競合を解決
#
# 引数:
#   $1 - AI名（claude|gemini|amp|qwen|droid|codex|cursor）
#   $2 - （オプション）ターゲットブランチ（デフォルト: main）
#
# 戻り値:
#   0 - 全競合解決成功
#   1 - エラーまたはユーザーキャンセル
#
# 動作:
#   1. マージを試行し、競合ファイルをリストアップ
#   2. 各ファイルで選択肢提示（whiptail/dialog使用）
#      - Accept OURS (main)
#      - Accept THEIRS (AI branch)
#      - Edit manually (EDITOR起動)
#      - Skip (後で手動解決)
#   3. 選択に応じて自動適用
#   4. 全競合解決後、git add & commit
#
# 例:
#   interactive_conflict_resolution "qwen"
#   interactive_conflict_resolution "droid" "develop"
##
interactive_conflict_resolution() {
  local ai_name="$1"
  local target_branch="${2:-main}"

  local worktree_path="$WORKTREE_BASE_DIR/$ai_name"

  # Worktreeの存在確認
  if [[ ! -d "$worktree_path" ]]; then
    echo "ERROR: Worktreeが存在しません: $worktree_path" >&2
    return 1
  fi

  # 非対話モードのチェック
  if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
    echo "INFO: Non-interactive mode - automatically accepting THEIRS (AI branch)"
    local source_branch=$(cd "$worktree_path" && git rev-parse --abbrev-ref HEAD)
    local project_root=$(git rev-parse --show-toplevel)

    (
      cd "$project_root"

      # ターゲットブランチをチェックアウト
      git checkout "$target_branch" 2>/dev/null || {
        echo "ERROR: ブランチ '$target_branch' のチェックアウトに失敗しました" >&2
        return 1
      }

      # theirs戦略でマージ
      if git merge -X theirs --no-ff "$source_branch" -m "merge: Integrate $ai_name (non-interactive: theirs)"; then
        echo "SUCCESS: Auto-merged using theirs strategy"
        return 0
      else
        echo "ERROR: Non-interactive merge failed" >&2
        git merge --abort 2>/dev/null || true
        return 1
      fi
    )
    return $?
  fi

  # whiptail/dialogの利用可能性をチェック
  local dialog_cmd=""
  if command -v whiptail >/dev/null 2>&1; then
    dialog_cmd="whiptail"
  elif command -v dialog >/dev/null 2>&1; then
    dialog_cmd="dialog"
  else
    echo "WARNING: whiptailもdialogも見つかりません。テキストベースのインターフェースを使用します。" >&2
  fi

  local source_branch=$(cd "$worktree_path" && git rev-parse --abbrev-ref HEAD)
  local project_root=$(git rev-parse --show-toplevel)

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔧 Interactive Conflict Resolution: $ai_name"
  echo "   Source: $source_branch"
  echo "   Target: $target_branch"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # マージを試行
  (
    cd "$project_root"

    # ターゲットブランチをチェックアウト
    git checkout "$target_branch" 2>/dev/null || {
      echo "ERROR: ブランチ '$target_branch' のチェックアウトに失敗しました" >&2
      return 1
    }

    # マージを試行（競合があれば停止）
    if git merge --no-commit --no-ff "$source_branch" 2>/dev/null; then
      echo "✓ 競合なしでマージできます"
      git merge --abort 2>/dev/null || true
      return 0
    fi

    # 競合ファイルをリストアップ
    local conflict_files=($(git diff --name-only --diff-filter=U))

    if [[ ${#conflict_files[@]} -eq 0 ]]; then
      echo "✓ 競合ファイルが見つかりません"
      git merge --abort 2>/dev/null || true
      return 0
    fi

    echo "⚠ ${#conflict_files[@]}個の競合ファイルが見つかりました:"
    for file in "${conflict_files[@]}"; do
      echo "   - $file"
    done
    echo ""

    # 各ファイルの競合を解決
    local resolved=0
    local skipped=0

    for conflict_file in "${conflict_files[@]}"; do
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "📄 File: $conflict_file"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      if [[ -n "$dialog_cmd" ]]; then
        # TUIメニュー
        local choice
        choice=$($dialog_cmd --title "Conflict Resolution" \
          --menu "Choose resolution for $conflict_file:" 15 60 4 \
          "1" "Accept OURS (main)" \
          "2" "Accept THEIRS ($ai_name)" \
          "3" "Edit manually" \
          "4" "Skip" \
          3>&1 1>&2 2>&3)

        case "$choice" in
          1)
            git checkout --ours "$conflict_file"
            git add "$conflict_file"
            echo "✓ Accepted OURS (main)"
            ((resolved++))
            ;;
          2)
            git checkout --theirs "$conflict_file"
            git add "$conflict_file"
            echo "✓ Accepted THEIRS ($ai_name)"
            ((resolved++))
            ;;
          3)
            ${EDITOR:-vi} "$conflict_file"
            git add "$conflict_file"
            echo "✓ Manual edit completed"
            ((resolved++))
            ;;
          4)
            echo "⊙ Skipped (resolve manually later)"
            ((skipped++))
            ;;
          *)
            echo "⊙ No selection, skipped"
            ((skipped++))
            ;;
        esac
      else
        # テキストベースのインターフェース
        echo "Choose resolution:"
        echo "  1) Accept OURS (main)"
        echo "  2) Accept THEIRS ($ai_name)"
        echo "  3) Edit manually"
        echo "  4) Skip"
        read -p "Enter choice (1-4): " choice

        case "$choice" in
          1)
            git checkout --ours "$conflict_file"
            git add "$conflict_file"
            echo "✓ Accepted OURS (main)"
            ((resolved++))
            ;;
          2)
            git checkout --theirs "$conflict_file"
            git add "$conflict_file"
            echo "✓ Accepted THEIRS ($ai_name)"
            ((resolved++))
            ;;
          3)
            ${EDITOR:-vi} "$conflict_file"
            git add "$conflict_file"
            echo "✓ Manual edit completed"
            ((resolved++))
            ;;
          4|*)
            echo "⊙ Skipped"
            ((skipped++))
            ;;
        esac
      fi

      echo ""
    done

    # 結果サマリー
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Resolution Summary:"
    echo "   Resolved: $resolved"
    echo "   Skipped: $skipped"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # 全て解決されたかチェック
    if [[ $skipped -eq 0 ]]; then
      echo "✓ 全ての競合が解決されました。コミットします..."
      git commit -m "merge: Resolve conflicts for $ai_name integration"
      echo "✓ マージコミット完了"
      return 0
    else
      echo "⚠ $skipped 個の競合が未解決です。手動で解決してください。"
      echo "   1. 競合を解決"
      echo "   2. git add <files>"
      echo "   3. git commit"
      git merge --abort 2>/dev/null || true
      return 1
    fi
  )
}

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
