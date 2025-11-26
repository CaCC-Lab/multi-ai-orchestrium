#!/bin/bash
# Git Worktree Manager - AI別ワークスペース管理
# Team A: Qwen + Droid
# 設計書: docs/asyncthink/GIT_WORKTREES_INTEGRATION_DESIGN.md

set -euo pipefail

# ===================================================================
# 設定と定数
# ===================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# VibeLogger統合
source "$SCRIPT_DIR/../../bin/vibe-logger-lib.sh" 2>/dev/null || true

# Sanitize統合
source "$SCRIPT_DIR/../lib/sanitize.sh" 2>/dev/null || true

# Worktree設定
WORKTREE_BASE="${WORKTREE_BASE:-$PROJECT_ROOT/worktrees}"
WORKTREE_LOCK_DIR="${WORKTREE_LOCK_DIR:-/tmp/multi-ai-worktree-locks}"
WORKTREE_LOCK_TIMEOUT="${WORKTREE_LOCK_TIMEOUT:-60}"  # 秒
WORKTREE_SHADOW_MODE="${WORKTREE_SHADOW_MODE:-false}"

# サポートAI一覧
SUPPORTED_AIS=("claude" "gemini" "amp" "qwen" "droid" "codex" "cursor")

# ログディレクトリ
WORKTREE_LOG_DIR="${WORKTREE_LOG_DIR:-$PROJECT_ROOT/logs/worktrees}"
mkdir -p "$WORKTREE_LOG_DIR" "$WORKTREE_LOCK_DIR"

# ===================================================================
# ユーティリティ関数
# ===================================================================

# AI名のバリデーション（ホワイトリスト）
validate_ai_name() {
    local ai_name="$1"

    # ホワイトリスト検証
    for supported_ai in "${SUPPORTED_AIS[@]}"; do
        if [[ "$ai_name" == "$supported_ai" ]]; then
            return 0
        fi
    done

    echo "ERROR: Invalid AI name: $ai_name" >&2
    echo "Supported AIs: ${SUPPORTED_AIS[*]}" >&2
    return 1
}

# パストラバーサル防止
sanitize_worktree_input() {
    local input="$1"

    # パストラバーサル検出
    if [[ "$input" =~ \.\. ]]; then
        echo "ERROR: Path traversal detected in: $input" >&2
        return 1
    fi

    # 特殊文字除去
    if type sanitize_input >/dev/null 2>&1; then
        sanitize_input "$input"
    else
        echo "$input" | tr -cd '[:alnum:]_-'
    fi
}

# Worktreeパス生成
get_worktree_path() {
    local ai_name="$1"
    local task_id="${2:-default}"

    echo "$WORKTREE_BASE/${ai_name}/${task_id}"
}

# Lock取得（flock排他制御）
acquire_worktree_lock() {
    local ai_name="$1"
    local lock_file="$WORKTREE_LOCK_DIR/${ai_name}.lock"
    local timeout="$WORKTREE_LOCK_TIMEOUT"

    # Lock file作成
    touch "$lock_file"

    # タイムアウト付き排他制御
    if ! flock --timeout "$timeout" "$lock_file" true; then
        echo "ERROR: Failed to acquire lock for $ai_name (timeout: ${timeout}s)" >&2
        return 1
    fi

    echo "$lock_file"
}

# VibeLogger監査ログ
log_worktree_event() {
    local event="$1"
    local ai_name="$2"
    local metadata="$3"
    local human_note="$4"

    if type vibe_log >/dev/null 2>&1; then
        vibe_log "worktree" "$event" "$metadata" "$human_note" "" "worktree-manager"
    fi

    # JSONログ保存
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="$WORKTREE_LOG_DIR/${ai_name}_${timestamp}.json"

    cat > "$log_file" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "event": "$event",
  "ai": "$ai_name",
  "metadata": $metadata
}
EOF
}

# ===================================================================
# 主要API: create_worktree
# ===================================================================

# Worktree作成
# @param $1 ai_name     AI名（qwen, droid, codex等）
# @param $2 branch_name ブランチ名（feature/auth-impl等、存在しない場合は自動作成）
# @param $3 task_id     タスクID（オプション、デフォルト: default）
# @param $4 base_ref    ブランチ作成元（オプション、デフォルト: HEAD）
# @return   Worktreeパス
create_worktree() {
    local ai_name="$1"
    local branch_name="$2"
    local task_id="${3:-default}"
    local base_ref="${4:-HEAD}"

    # === Step 1: Input Validation ===
    if ! validate_ai_name "$ai_name"; then
        return 1
    fi

    ai_name=$(sanitize_worktree_input "$ai_name")
    task_id=$(sanitize_worktree_input "$task_id")

    # ブランチ名サニタイズ（/, -, _許可）
    branch_name=$(echo "$branch_name" | tr -cd '[:alnum:]/_-')

    if [[ -z "$branch_name" ]]; then
        echo "ERROR: Invalid branch name" >&2
        return 1
    fi

    # === Step 2: Worktreeパス決定 ===
    local worktree_path=$(get_worktree_path "$ai_name" "$task_id")

    # === Shadow Mode チェック ===
    if [[ "$WORKTREE_SHADOW_MODE" == "true" ]]; then
        echo "SHADOW MODE: Would create worktree at $worktree_path" >&2
        log_worktree_event "shadow_create" "$ai_name" \
            "{\"path\": \"$worktree_path\", \"branch\": \"$branch_name\", \"task_id\": \"$task_id\"}" \
            "Shadow mode: Worktree creation logged only"
        echo "$worktree_path"
        return 0
    fi

    # === Step 3: Lock Acquisition ===
    local lock_file
    lock_file=$(acquire_worktree_lock "$ai_name") || return 1

    (
        # Lock内での処理
        flock -x 200 || exit 1

        # === Step 4: 既存Worktree確認 ===
        if [[ -d "$worktree_path" ]]; then
            echo "WARNING: Worktree already exists at $worktree_path, removing..." >&2
            git worktree remove --force "$worktree_path" 2>/dev/null || true
            rm -rf "$worktree_path"
        fi

        # === Step 5: Worktree作成 ===
        mkdir -p "$(dirname "$worktree_path")"

        # ブランチを事前作成/リセット（Day 4 fix）
        if git show-ref --verify --quiet "refs/heads/$branch_name"; then
            git branch -f "$branch_name" "$base_ref" >/dev/null 2>&1 || true
        else
            git branch "$branch_name" "$base_ref" >/dev/null 2>&1 || true
        fi

        if ! git worktree add "$worktree_path" "$branch_name" 2>&1; then
            echo "ERROR: Failed to create worktree for $ai_name" >&2
            exit 1
        fi

        # === Step 6: Sparse-Checkout設定 ===
        # ディスク使用量90%削減
        if [[ -n "${WORKTREE_SPARSE_CHECKOUT:-}" ]] && [[ "$WORKTREE_SPARSE_CHECKOUT" == "true" ]]; then
            (
                cd "$worktree_path"
                git sparse-checkout init --cone
                git sparse-checkout set src tests scripts
            ) 2>/dev/null || echo "WARNING: Sparse checkout failed, continuing..." >&2
        fi

        # === Step 7: 監査ログ ===
        log_worktree_event "create" "$ai_name" \
            "{\"path\": \"$worktree_path\", \"branch\": \"$branch_name\", \"task_id\": \"$task_id\"}" \
            "Worktree created for $ai_name at $worktree_path"

        echo "$worktree_path"

    ) 200>"$lock_file"

    return $?
}

# ===================================================================
# 主要API: merge_worktree
# ===================================================================

# Worktreeマージとクリーンアップ
# @param $1 ai_name       AI名
# @param $2 task_id       タスクID
# @param $3 target_branch ターゲットブランチ（オプション、デフォルト: main）
# @return   merge commit hash
merge_worktree() {
    local ai_name="$1"
    local task_id="${2:-default}"
    local target_branch="${3:-main}"

    # === Step 1: Validation ===
    if ! validate_ai_name "$ai_name"; then
        return 1
    fi

    ai_name=$(sanitize_worktree_input "$ai_name")
    task_id=$(sanitize_worktree_input "$task_id")

    # === Step 2: Worktreeパス解決 ===
    local worktree_path=$(get_worktree_path "$ai_name" "$task_id")

    if [[ ! -d "$worktree_path" ]]; then
        echo "ERROR: Worktree not found at $worktree_path" >&2
        return 1
    fi

    # === Shadow Mode チェック ===
    if [[ "$WORKTREE_SHADOW_MODE" == "true" ]]; then
        echo "SHADOW MODE: Would merge worktree from $worktree_path" >&2
        log_worktree_event "shadow_merge" "$ai_name" \
            "{\"path\": \"$worktree_path\", \"target\": \"$target_branch\", \"task_id\": \"$task_id\"}" \
            "Shadow mode: Worktree merge logged only"
        return 0
    fi

    # === Step 3: Change Detection ===
    local changes
    changes=$(cd "$worktree_path" && git diff --stat HEAD 2>/dev/null || true)

    if [[ -z "$changes" ]]; then
        echo "INFO: No changes to merge from $worktree_path, skipping..." >&2
        cleanup_worktree "$ai_name" "$task_id" "true"
        return 0
    fi

    # === Step 4: Lock Acquisition ===
    local lock_file
    lock_file=$(acquire_worktree_lock "$ai_name") || return 1

    local merge_commit
    (
        # Lock内での処理
        flock -x 200 || exit 1

        # === Step 5: Conflict Check ===
        # メインリポジトリに切り替え
        cd "$PROJECT_ROOT"
        git checkout "$target_branch" || exit 1

        # Worktreeブランチ名取得
        local branch_name
        branch_name=$(cd "$worktree_path" && git branch --show-current)

        # Conflict チェック（--no-commit で試行）
        if ! git merge --no-commit --no-ff "$branch_name" 2>&1; then
            echo "ERROR: Merge conflict detected, aborting merge" >&2
            git merge --abort 2>/dev/null || true
            exit 1
        fi

        # === Step 6: Merge Execution ===
        git merge --abort 2>/dev/null || true  # --no-commit を破棄

        if ! git merge --no-ff -m "Merge $ai_name worktree ($task_id)" "$branch_name"; then
            echo "ERROR: Merge failed" >&2
            exit 1
        fi

        merge_commit=$(git rev-parse HEAD)

        # === Step 7: Worktree Removal ===
        git worktree remove "$worktree_path" 2>&1 || true
        git worktree prune 2>&1 || true

        # === Step 8: 監査ログ ===
        log_worktree_event "merge" "$ai_name" \
            "{\"path\": \"$worktree_path\", \"target\": \"$target_branch\", \"commit\": \"$merge_commit\", \"task_id\": \"$task_id\"}" \
            "Worktree merged from $ai_name, commit: $merge_commit"

        echo "$merge_commit"

    ) 200>"$lock_file"

    return $?
}

# ===================================================================
# 主要API: cleanup_worktree
# ===================================================================

# Worktreeクリーンアップ（ロールバック）
# @param $1 ai_name AI名
# @param $2 task_id タスクID
# @param $3 force   強制削除フラグ（true: 未保存変更破棄）
# @return   0=成功, 1=失敗
cleanup_worktree() {
    local ai_name="$1"
    local task_id="${2:-default}"
    local force="${3:-false}"

    # === Step 1: Validation ===
    if ! validate_ai_name "$ai_name"; then
        return 1
    fi

    ai_name=$(sanitize_worktree_input "$ai_name")
    task_id=$(sanitize_worktree_input "$task_id")

    # === Step 2: Worktreeパス解決 ===
    local worktree_path=$(get_worktree_path "$ai_name" "$task_id")

    # === Step 3: Existence Check ===
    if [[ ! -d "$worktree_path" ]]; then
        echo "WARNING: Worktree not found at $worktree_path, nothing to clean" >&2
        return 0
    fi

    # === Shadow Mode チェック ===
    if [[ "$WORKTREE_SHADOW_MODE" == "true" ]]; then
        echo "SHADOW MODE: Would cleanup worktree at $worktree_path" >&2
        log_worktree_event "shadow_cleanup" "$ai_name" \
            "{\"path\": \"$worktree_path\", \"task_id\": \"$task_id\", \"force\": \"$force\"}" \
            "Shadow mode: Worktree cleanup logged only"
        return 0
    fi

    # === Step 4: Uncommitted Changes Check ===
    if [[ "$force" != "true" ]]; then
        local uncommitted
        uncommitted=$(cd "$worktree_path" && git status --porcelain 2>/dev/null || true)

        if [[ -n "$uncommitted" ]]; then
            echo "ERROR: Uncommitted changes detected in $worktree_path" >&2
            echo "Use force=true to discard changes" >&2
            return 1
        fi
    fi

    # === Step 5: Worktree Remove ===
    local lock_file
    lock_file=$(acquire_worktree_lock "$ai_name") || return 1

    (
        # Lock内での処理
        flock -x 200 || exit 1

        if [[ "$force" == "true" ]]; then
            git worktree remove --force "$worktree_path" 2>&1 || true
        else
            git worktree remove "$worktree_path" 2>&1 || true
        fi

        # === Step 6: Prune ===
        git worktree prune 2>&1 || true

        # === Step 7: 監査ログ ===
        log_worktree_event "cleanup" "$ai_name" \
            "{\"path\": \"$worktree_path\", \"task_id\": \"$task_id\", \"force\": \"$force\"}" \
            "Worktree cleaned up for $ai_name (force: $force)"

    ) 200>"$lock_file"

    return 0
}

# ===================================================================
# 補助API: list_active_worktrees
# ===================================================================

# アクティブなWorktree一覧取得
list_active_worktrees() {
    git worktree list --porcelain | grep -E "^worktree " | sed 's/^worktree //'
}

# ===================================================================
# エクスポート
# ===================================================================

# Bashスクリプトからsourceして使用する場合
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f create_worktree
    export -f merge_worktree
    export -f cleanup_worktree
    export -f list_active_worktrees
fi
