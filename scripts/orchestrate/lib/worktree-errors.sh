#!/usr/bin/env bash
# worktree-errors.sh - Worktreeエラーコード定義と標準化メッセージ
# Phase 1.5: エラーメッセージの改善

set -euo pipefail

# ========================================
# エラーコード体系（WT001-WT999）
# ========================================
#
# WT001-WT099: 検証エラー
# WT100-WT199: 作成エラー
# WT200-WT299: 削除/クリーンアップエラー
# WT300-WT399: 状態管理エラー
# WT400-WT499: 権限/セキュリティエラー
# WT500-WT599: システムリソースエラー
# WT900-WT999: 内部エラー

# ========================================
# エラーメッセージ出力関数（What/Why/How形式）
# ========================================

##
# 構造化エラーメッセージを出力
#
# 引数:
#   $1 - エラーコード（例: WT001）
#   $2 - What（何が起きたか）
#   $3 - Why（なぜ起きたか）
#   $4 - How（どうすればよいか）
#
# 出力:
#   stderrに構造化されたエラーメッセージ
#
# 例:
#   emit_worktree_error "WT001" \
#     "無効なAI名が指定されました" \
#     "許可されているAI名ではありません" \
#     "claude, gemini, amp, qwen, droid, codex, cursor のいずれかを指定してください"
##
emit_worktree_error() {
  local code="$1"
  local what="$2"
  local why="$3"
  local how="$4"

  cat >&2 <<EOF
╔════════════════════════════════════════════════════════════════
║ ❌ Worktreeエラー [$code]
╠════════════════════════════════════════════════════════════════
║ What: $what
║ Why:  $why
║ How:  $how
╚════════════════════════════════════════════════════════════════
EOF

  return 1
}

# ========================================
# 定義済みエラー関数
# ========================================

# WT001: 無効なAI名
error_wt001_invalid_ai_name() {
  local ai_name="$1"
  emit_worktree_error "WT001" \
    "無効なAI名: $ai_name" \
    "許可されているAI名ではありません" \
    "以下のいずれかを指定してください: claude, gemini, amp, qwen, droid, codex, cursor"
}

# WT002: 空のブランチ名
error_wt002_empty_branch_name() {
  emit_worktree_error "WT002" \
    "ブランチ名が空です" \
    "ブランチ名が指定されていないか、空文字列が渡されました" \
    "有効なブランチ名を指定してください（例: feature/my-branch）"
}

# WT003: 不正なブランチ名
error_wt003_invalid_branch_name() {
  local branch_name="$1"
  emit_worktree_error "WT003" \
    "不正なブランチ名: $branch_name" \
    "Git公式のブランチ名制約に違反しています" \
    "以下を確認してください:
  - ASCII制御文字、スペース、特殊文字(~, ^, :, ?, *, [)を使用していない
  - 連続スラッシュ(//)がない
  - .で開始していない
  - .lockで終了していない
詳細: git help check-ref-format"
}

# WT101: Worktree作成失敗
error_wt101_creation_failed() {
  local ai_name="$1"
  local error_msg="${2:-不明}"
  emit_worktree_error "WT101" \
    "$ai_name のWorktree作成に失敗しました" \
    "$error_msg" \
    "以下を確認してください:
  1. git worktree list で既存Worktreeを確認
  2. 同名のWorktreeが存在する場合: git worktree remove worktrees/$ai_name --force
  3. ディスク空き容量を確認: df -h
  4. 再試行してください"
}

# WT102: Worktreeが既に存在
error_wt102_already_exists() {
  local worktree_path="$1"
  emit_worktree_error "WT102" \
    "Worktreeが既に存在します: $worktree_path" \
    "同じパスにWorktreeが既に作成されています" \
    "以下のいずれかを実行してください:
  - 既存を削除: git worktree remove $worktree_path --force
  - 既存を確認: git worktree list
  - 別のAI名を使用"
}

# WT201: Worktree削除失敗
error_wt201_removal_failed() {
  local worktree_path="$1"
  local retries="${2:-0}"
  emit_worktree_error "WT201" \
    "Worktree削除に失敗しました: $worktree_path (試行回数: $retries)" \
    "ファイルがロックされているか、プロセスが使用中の可能性があります" \
    "以下を試してください:
  1. 使用中のプロセスを確認: lsof +D $worktree_path
  2. 強制削除: git worktree remove $worktree_path --force
  3. 手動削除: rm -rf $worktree_path && git worktree prune
  4. ロックファイル削除: rm -f .git/worktrees/$(basename $worktree_path)/lock"
}

# WT301: Worktreeが存在しない
error_wt301_not_exists() {
  local worktree_path="$1"
  emit_worktree_error "WT301" \
    "Worktreeが存在しません: $worktree_path" \
    "指定されたパスにWorktreeが見つかりません" \
    "以下を確認してください:
  - 既存Worktree一覧: git worktree list
  - パスが正しいか確認
  - 先に create_worktree() を実行"
}

# WT302: 無効なGit Worktree
error_wt302_invalid_worktree() {
  local worktree_path="$1"
  emit_worktree_error "WT302" \
    "有効なGit Worktreeではありません: $worktree_path" \
    ".git ファイルが存在しないか、不正な形式です" \
    "以下を確認してください:
  1. ls -la $worktree_path/.git
  2. cat $worktree_path/.git (gitdir:行があるか)
  3. Worktreeを再作成: git worktree remove $worktree_path --force && create_worktree ..."
}

# WT401: ロック取得失敗
error_wt401_lock_failed() {
  emit_worktree_error "WT401" \
    "ロックを取得できませんでした" \
    "別のプロセスがWorktree操作を実行中です" \
    "以下を試してください:
  1. 他のWorktree操作の完了を待つ
  2. ロックファイルを確認: ls -la /tmp/multi-ai-worktree.lock
  3. 古いロックを削除: rm -f /tmp/multi-ai-worktree.lock
  4. 再試行"
}

# WT501: 並列作成で一部失敗
error_wt501_parallel_partial_failure() {
  local ais="$1"
  local exit_code="$2"
  emit_worktree_error "WT501" \
    "並列Worktree作成で一部失敗しました" \
    "一部のAI Worktree作成に失敗しました（exit code: $exit_code）" \
    "以下を確認してください:
  1. 個別ログを確認（上記のエラーメッセージ）
  2. 失敗したWorktreeを特定: git worktree list
  3. 個別に再作成: create_worktree <ai-name>
  4. 並列度を下げて再試行: MAX_PARALLEL_WORKTREES=2"
}

# WT901: AI名が指定されていない
error_wt901_missing_ai_names() {
  emit_worktree_error "WT901" \
    "AI名が指定されていません" \
    "関数にAI名の引数が渡されていません" \
    "AI名を指定してください:
  例: create_worktrees_parallel claude gemini amp qwen"
}

# ========================================
# デバッグモード
# ========================================

# WORKTREE_DEBUG=1 で詳細ログを有効化
if [[ "${WORKTREE_DEBUG:-0}" == "1" ]]; then
  export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
  set -x
fi
