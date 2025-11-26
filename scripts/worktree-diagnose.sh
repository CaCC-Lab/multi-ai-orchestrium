#!/usr/bin/env bash
# worktree-diagnose.sh - Worktree自動診断ツール
# Phase 5 Issue #5: Automatic Diagnostic Tool
# 責務：Worktree関連の問題を自動検出・修復

set -euo pipefail

# 設定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# Worktree設定の読み込み
WORKTREE_BASE_DIR="${WORKTREE_BASE_DIR:-worktrees}"
WORKTREE_LOCK_FILE="${WORKTREE_LOCK_FILE:-/tmp/multi-ai-worktree.lock}"
DIAGNOSTIC_REPORT_FILE="${DIAGNOSTIC_REPORT_FILE:-/tmp/worktree-diagnostic-report.json}"

# 診断結果
declare -a DIAGNOSTIC_ISSUES=()
declare -a DIAGNOSTIC_WARNINGS=()
declare -a DIAGNOSTIC_ERRORS=()

# ログ関数（VibeLoggerが利用可能な場合は使用）
if command -v vibe_log &>/dev/null; then
    source "$PROJECT_ROOT/bin/vibe-logger-lib.sh" 2>/dev/null || true
else
    vibe_log() { echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*" >&2; }
fi

# 診断項目の実行
run_diagnostics() {
    echo "Running worktree diagnostics..."
    
    check_orphaned_worktrees || true
    check_deadlocks || true
    check_disk_usage || true
    check_conflicting_branches || true
    
    echo "Diagnostics completed."
}

# 孤立Worktree検出（Step 2）
check_orphaned_worktrees() {
    echo "Checking for orphaned worktrees..."
    
    local orphaned_count=0
    local orphaned_list=()
    
    # Git Worktreeリストを取得（登録されているWorktree）
    local registered_worktrees=()
    if command -v git &>/dev/null; then
        while IFS= read -r line; do
            if [[ "$line" =~ ^worktree[[:space:]]+(.+)$ ]]; then
                registered_worktrees+=("${BASH_REMATCH[1]}")
            fi
        done < <(git worktree list --porcelain 2>/dev/null || true)
    fi
    
    # 実際のWorktreeディレクトリをスキャン
    # FIXED: Only scan directories that contain a .git file (actual worktree roots)
    # This prevents false positives for grouping folders and subdirectories
    if [[ -d "$WORKTREE_BASE_DIR" ]]; then
        while IFS= read -r worktree_path; do
            [[ -z "$worktree_path" ]] && continue
            
            # Only check directories that contain a .git file (worktree root indicator)
            # Skip if this is not a worktree root (no .git file)
            if [[ ! -f "$worktree_path/.git" ]]; then
                continue
            fi
            
            # 正規化されたパス（絶対パスに変換）
            local normalized_path
            if [[ "$worktree_path" == /* ]]; then
                normalized_path="$worktree_path"
            else
                normalized_path="$(cd "$PROJECT_ROOT" && cd "$worktree_path" && pwd 2>/dev/null || echo "$worktree_path")"
            fi
            
            local is_registered=false
            
            # Git Worktreeリストに存在するかチェック
            for registered_path in "${registered_worktrees[@]}"; do
                local normalized_registered
                if [[ "$registered_path" == /* ]]; then
                    normalized_registered="$registered_path"
                else
                    normalized_registered="$(cd "$PROJECT_ROOT" && cd "$registered_path" && pwd 2>/dev/null || echo "$registered_path")"
                fi
                
                if [[ "$normalized_path" == "$normalized_registered" ]]; then
                    is_registered=true
                    break
                fi
            done
            
            if [[ "$is_registered" == "false" ]]; then
                orphaned_list+=("$worktree_path")
                ((orphaned_count++))
            fi
        done < <(find "$WORKTREE_BASE_DIR" -mindepth 1 -maxdepth 3 -type d -print 2>/dev/null || true)
    fi
    
    if (( orphaned_count > 0 )); then
        local orphaned_str=$(IFS=','; echo "${orphaned_list[*]}")
        DIAGNOSTIC_WARNINGS+=("orphaned_worktrees:$orphaned_count:$orphaned_str")
        echo "WARNING: $orphaned_count orphaned worktrees detected"
        for wt in "${orphaned_list[@]}"; do
            echo "  - $wt"
        done
        return 1
    fi
    
    echo "OK: No orphaned worktrees detected"
    return 0
}

# 孤立Worktree修復
fix_orphaned_worktrees() {
    local fixed_count=0
    
    # 孤立Worktreeを検出
    check_orphaned_worktrees || true
    
    # 警告から孤立Worktreeリストを取得
    for warning in "${DIAGNOSTIC_WARNINGS[@]}"; do
        if [[ "$warning" =~ ^orphaned_worktrees: ]]; then
            local warning_parts=(${warning//:/ })
            local count="${warning_parts[1]}"
            local orphaned_str="${warning#orphaned_worktrees:$count:}"
            
            # カンマ区切りのリストを配列に変換
            IFS=',' read -ra orphaned_array <<< "$orphaned_str"
            
            # 各孤立Worktreeを削除
            for worktree_path in "${orphaned_array[@]}"; do
                [[ -z "$worktree_path" ]] && continue
                
                if [[ -d "$worktree_path" ]]; then
                    echo "Removing orphaned worktree: $worktree_path"
                    rm -rf "$worktree_path" 2>/dev/null || {
                        echo "ERROR: Failed to remove $worktree_path" >&2
                        continue
                    }
                    ((fixed_count++))
                fi
            done
        fi
    done
    
    if (( fixed_count > 0 )); then
        echo "Fixed $fixed_count orphaned worktrees"
        # 警告を削除（修復済み）
        DIAGNOSTIC_WARNINGS=("${DIAGNOSTIC_WARNINGS[@]//orphaned_worktrees:*/}")
    fi
    
    return 0
}

# デッドロック検出（Step 3）
check_deadlocks() {
    echo "Checking for deadlocks..."
    
    local deadlock_count=0
    local max_lock_age=300  # 5分以上古いロックはデッドロックとみなす
    
    if [[ -f "$WORKTREE_LOCK_FILE" ]]; then
        # ロックファイルのタイムスタンプを取得
        local lock_timestamp=0
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            lock_timestamp=$(stat -f %Y "$WORKTREE_LOCK_FILE" 2>/dev/null || echo "0")
        else
            # Linux
            lock_timestamp=$(stat -c %Y "$WORKTREE_LOCK_FILE" 2>/dev/null || echo "0")
        fi
        
        if (( lock_timestamp > 0 )); then
            local current_timestamp=$(date +%s)
            local lock_age=$((current_timestamp - lock_timestamp))
            
            if (( lock_age > max_lock_age )); then
                # FIXED: Use flock -n to check if lock is actually held
                # The lock file created by flock doesn't contain a PID, so we need to
                # test if we can acquire the lock non-blocking. If we can acquire it,
                # the lock is stale (deadlock). If we can't, it's still active.
                local lock_stale=false
                if command -v flock &>/dev/null; then
                    # Try to acquire lock non-blocking (flock -n)
                    # If successful, the lock was stale (not held by any process)
                    # If failed, the lock is still active (held by another process)
                    (
                        flock -n 9 || exit 1
                        # If we get here, we acquired the lock, meaning it was stale
                        exit 0
                    ) 9>"$WORKTREE_LOCK_FILE" 2>/dev/null
                    
                    if [[ $? -eq 0 ]]; then
                        # We successfully acquired the lock, meaning it was stale
                        lock_stale=true
                        # Release the lock immediately
                        flock -u 9 9>"$WORKTREE_LOCK_FILE" 2>/dev/null || true
                    else
                        # Could not acquire lock, it's still active
                        lock_stale=false
                    fi
                else
                    # Fallback: If flock is not available, assume stale if old enough
                    # This is less safe but better than always removing active locks
                    lock_stale=true
                fi
                
                if [[ "$lock_stale" == "true" ]]; then
                    DIAGNOSTIC_WARNINGS+=("deadlock:$WORKTREE_LOCK_FILE:$lock_age")
                    echo "WARNING: Deadlock detected in $WORKTREE_LOCK_FILE (age: ${lock_age}s)"
                    ((deadlock_count++))
                    return 1
                fi
            fi
        fi
    fi
    
    echo "OK: No deadlocks detected"
    return 0
}

# デッドロック修復
fix_deadlocks() {
    local fixed_count=0
    
    check_deadlocks || {
        # デッドロックを強制解除
        if [[ -f "$WORKTREE_LOCK_FILE" ]]; then
            echo "Removing deadlock: $WORKTREE_LOCK_FILE"
            rm -f "$WORKTREE_LOCK_FILE" 2>/dev/null || {
                echo "ERROR: Failed to remove lock file: $WORKTREE_LOCK_FILE" >&2
                return 1
            }
            ((fixed_count++))
            
            # 警告を削除（修復済み）
            DIAGNOSTIC_WARNINGS=("${DIAGNOSTIC_WARNINGS[@]//deadlock:*/}")
        fi
    }
    
    if (( fixed_count > 0 )); then
        echo "Fixed $fixed_count deadlock(s)"
    fi
    
    return 0
}

# ディスク使用量チェック（Step 4）
check_disk_usage() {
    echo "Checking disk usage..."
    
    local max_size_bytes=1073741824  # 1GB
    local used_bytes=0
    
    if [[ -d "$WORKTREE_BASE_DIR" ]]; then
        # duコマンドでサイズを取得
        if command -v du &>/dev/null; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                used_bytes=$(du -sk "$WORKTREE_BASE_DIR" 2>/dev/null | awk '{print $1 * 1024}' || echo "0")
            else
                # Linux
                used_bytes=$(du -sb "$WORKTREE_BASE_DIR" 2>/dev/null | cut -f1 || echo "0")
            fi
        else
            # duがない場合はfindで概算
            used_bytes=$(find "$WORKTREE_BASE_DIR" -type f -exec stat -c %s {} \; 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "0")
        fi
    fi
    
    # 使用率を計算（整数演算）
    local usage_percent=0
    if (( max_size_bytes > 0 )); then
        usage_percent=$((used_bytes * 100 / max_size_bytes))
    fi
    
    # 人間が読みやすい形式に変換
    local used_mb=$((used_bytes / 1048576))
    local max_mb=$((max_size_bytes / 1048576))
    
    if (( used_bytes > max_size_bytes )); then
        DIAGNOSTIC_WARNINGS+=("disk_usage:$used_bytes:$max_size_bytes:$usage_percent")
        echo "WARNING: Disk usage is ${usage_percent}% (${used_mb}MB / ${max_mb}MB)"
        return 1
    else
        echo "OK: Disk usage is ${usage_percent}% (${used_mb}MB / ${max_mb}MB)"
        return 0
    fi
}

# 競合ブランチ検出（Step 5）
check_conflicting_branches() {
    echo "Checking for conflicting branches..."
    
    local conflict_count=0
    declare -A branch_worktrees
    
    if ! command -v git &>/dev/null; then
        echo "OK: Git not available, skipping branch conflict check"
        return 0
    fi
    
    # Git Worktreeリストからブランチとパスのマッピングを作成
    local current_worktree_path=""
    local current_branch=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^worktree[[:space:]]+(.+)$ ]]; then
            current_worktree_path="${BASH_REMATCH[1]}"
            current_branch=""
        elif [[ "$line" =~ ^branch[[:space:]]+(.+)$ ]]; then
            current_branch="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^HEAD[[:space:]]+([0-9a-f]+)$ ]] && [[ -z "$current_branch" ]]; then
            # HEADのみの場合はブランチ名を取得
            if [[ -n "$current_worktree_path" ]] && [[ -d "$current_worktree_path" ]]; then
                current_branch=$(git -C "$current_worktree_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
            fi
        fi
        
        # ブランチ名が取得できた場合
        if [[ -n "$current_branch" ]] && [[ -n "$current_worktree_path" ]]; then
            # detached HEADの場合はスキップ
            if [[ "$current_branch" == "HEAD" ]]; then
                continue
            fi
            
            if [[ -n "${branch_worktrees[$current_branch]:-}" ]]; then
                local existing_path="${branch_worktrees[$current_branch]}"
                DIAGNOSTIC_WARNINGS+=("conflicting_branch:$current_branch:$current_worktree_path:$existing_path")
                echo "WARNING: Conflicting branch '$current_branch' found in multiple worktrees:"
                echo "  - $current_worktree_path"
                echo "  - $existing_path"
                ((conflict_count++))
            else
                branch_worktrees["$current_branch"]="$current_worktree_path"
            fi
            
            # リセット
            current_worktree_path=""
            current_branch=""
        fi
    done < <(git worktree list --porcelain 2>/dev/null || true)
    
    if (( conflict_count > 0 )); then
        return 1
    fi
    
    echo "OK: No conflicting branches detected"
    return 0
}

# 自動修復機能（Step 6）
apply_fixes() {
    echo "Applying automatic fixes..."
    
    local fixes_applied=0
    
    # 孤立Worktreeの修復
    if echo "${DIAGNOSTIC_WARNINGS[@]}" | grep -q "orphaned_worktrees"; then
        fix_orphaned_worktrees
        ((fixes_applied++))
    fi
    
    # デッドロックの修復（Step 3で実装）
    if echo "${DIAGNOSTIC_WARNINGS[@]}" | grep -q "deadlock"; then
        fix_deadlocks
        ((fixes_applied++))
    fi
    
    if (( fixes_applied == 0 )); then
        echo "No fixes needed"
    else
        echo "Applied $fixes_applied fix(es)"
    fi
    
    return 0
}

# レポート生成（Step 6で実装）
generate_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local status="OK"
    
    # ステータス判定
    if (( ${#DIAGNOSTIC_ERRORS[@]} > 0 )); then
        status="🔴 ERROR"
    elif (( ${#DIAGNOSTIC_WARNINGS[@]} > 0 )); then
        status="⚠️ WARNING"
    else
        status="✅ OK"
    fi
    
    cat <<EOF
===== Worktree Diagnostic Report =====
Date: $timestamp
Status: $status

Issues Found:
EOF
    
    # 警告の表示
    for warning in "${DIAGNOSTIC_WARNINGS[@]}"; do
        echo "  - [WARNING] $warning"
    done
    
    # エラーの表示
    for error in "${DIAGNOSTIC_ERRORS[@]}"; do
        echo "  - [ERROR] $error"
    done
    
    echo ""
    echo "Summary:"
    echo "  Total Issues: $((${#DIAGNOSTIC_WARNINGS[@]} + ${#DIAGNOSTIC_ERRORS[@]}))"
    echo "  Warnings: ${#DIAGNOSTIC_WARNINGS[@]}"
    echo "  Errors: ${#DIAGNOSTIC_ERRORS[@]}"
}

# JSON形式レポート生成（Step 6で実装）
generate_json_report() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")
    local status="ok"
    
    # ステータス判定
    if (( ${#DIAGNOSTIC_ERRORS[@]} > 0 )); then
        status="error"
    elif (( ${#DIAGNOSTIC_WARNINGS[@]} > 0 )); then
        status="warning"
    fi
    
    # jqが利用可能な場合は使用、そうでなければ簡易JSON生成
    if command -v jq &>/dev/null; then
        jq -n \
            --arg timestamp "$timestamp" \
            --arg status "$status" \
            --argjson warnings "${#DIAGNOSTIC_WARNINGS[@]}" \
            --argjson errors "${#DIAGNOSTIC_ERRORS[@]}" \
            '{
                timestamp: $timestamp,
                status: $status,
                summary: {
                    total_issues: ($warnings + $errors),
                    warnings: $warnings,
                    errors: $errors,
                    ok: (4 - $warnings - $errors)
                },
                issues: []
            }' > "$DIAGNOSTIC_REPORT_FILE"
    else
        # 簡易JSON生成
        cat > "$DIAGNOSTIC_REPORT_FILE" <<EOF
{
  "timestamp": "$timestamp",
  "status": "$status",
  "summary": {
    "total_issues": $((${#DIAGNOSTIC_WARNINGS[@]} + ${#DIAGNOSTIC_ERRORS[@]})),
    "warnings": ${#DIAGNOSTIC_WARNINGS[@]},
    "errors": ${#DIAGNOSTIC_ERRORS[@]},
    "ok": $((4 - ${#DIAGNOSTIC_WARNINGS[@]} - ${#DIAGNOSTIC_ERRORS[@]}))
  },
  "issues": []
}
EOF
    fi
    
    echo "JSON report saved to $DIAGNOSTIC_REPORT_FILE"
}

# メイン関数
main() {
    local action="${1:-report}"
    
    case "$action" in
        --report|report|"")
            run_diagnostics
            generate_report
            ;;
        --fix|fix)
            run_diagnostics
            apply_fixes
            generate_report
            ;;
        --json|json)
            run_diagnostics
            generate_json_report
            ;;
        --help|-h|help)
            cat <<EOF
Usage: $0 [OPTION]

Options:
  --report, report    Generate diagnostic report (default)
  --fix, fix          Run diagnostics and apply automatic fixes
  --json, json        Generate JSON format report
  --help, -h, help    Show this help message

Examples:
  $0                  # Generate text report
  $0 --report         # Generate text report
  $0 --fix            # Run diagnostics and fix issues
  $0 --json           # Generate JSON report
EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $action" >&2
            echo "Run '$0 --help' for usage information." >&2
            exit 1
            ;;
    esac
}

# スクリプトが直接実行された場合のみmainを呼び出す
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
