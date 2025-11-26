#!/usr/bin/env bash
# リソース衝突回避（API rate limit）
# Purpose: AsyncThink Phase 2, Week 15-16
# Responsibilities:
#   - API同時実行数制限
#   - グローバルカウンタベースのシンプルな実装
#   - セマフォライクな動作
#
# Dependencies:
#   - lib/multi-ai-core.sh (logging)
#
# Usage:
#   source scripts/orchestrate/lib/resource-limiter.sh
#   acquire_ai_slot "qwen"
#   # AI実行...
#   release_ai_slot "qwen"

set -euo pipefail

# ============================================================================
# グローバル変数
# ============================================================================

# 現在の同時実行AI数
CURRENT_CONCURRENT_AI="${CURRENT_CONCURRENT_AI:-0}"

# 最大同時実行AI数（デフォルト: 2）
MAX_CONCURRENT_AI="${MAX_CONCURRENT_AI:-2}"

# AI実行状態ファイル（ロックファイルベース実装）
AI_SLOTS_DIR="${AI_SLOTS_DIR:-/tmp/multi-ai-slots}"
mkdir -p "$AI_SLOTS_DIR" 2>/dev/null || true

# クリーンアップトラップ
trap 'cleanup_ai_slots' EXIT INT TERM

# ============================================================================
# コア関数
# ============================================================================

# AI実行スロット取得
# Args:
#   $1 - ai_name: AI名（qwen, droid, claude等）
# Returns:
#   0: スロット取得成功
#   1: スロット取得失敗（タイムアウト）
acquire_ai_slot() {
    local ai_name=${1:-"unknown"}
    local max_wait_seconds=${2:-60}  # デフォルト60秒タイムアウト
    local waited=0

    # ロックファイル作成
    local slot_file="$AI_SLOTS_DIR/${ai_name}-$$-$(date +%s%N)"

    log_info "🔒 [$ai_name] Acquiring AI slot (max: $MAX_CONCURRENT_AI)..."

    while true; do
        # 現在のスロット数をカウント
        local current_slots=$(ls -1 "$AI_SLOTS_DIR" 2>/dev/null | wc -l)

        if (( current_slots < MAX_CONCURRENT_AI )); then
            # スロット取得
            touch "$slot_file" 2>/dev/null || {
                log_error "[$ai_name] Failed to create slot file: $slot_file"
                return 1
            }

            # 再カウント（競合状態チェック）
            current_slots=$(ls -1 "$AI_SLOTS_DIR" 2>/dev/null | wc -l)

            if (( current_slots <= MAX_CONCURRENT_AI )); then
                # 成功
                CURRENT_CONCURRENT_AI=$current_slots
                log_info "✅ [$ai_name] AI slot acquired ($current_slots/$MAX_CONCURRENT_AI)"
                echo "$slot_file"  # スロットファイルパスを返す
                return 0
            else
                # 競合状態で超過 → ロールバック
                rm -f "$slot_file" 2>/dev/null || true
                log_warning "⚠️ [$ai_name] Slot race condition, retrying..."
            fi
        fi

        # タイムアウトチェック
        if (( waited >= max_wait_seconds )); then
            log_error "❌ [$ai_name] AI slot acquisition timed out after ${max_wait_seconds}s"
            return 1
        fi

        # 待機
        log_info "⏳ [$ai_name] Waiting for AI slot (current: $current_slots/$MAX_CONCURRENT_AI)..."
        sleep 1
        ((waited++))
    done
}

# AI実行スロット解放
# Args:
#   $1 - slot_file: acquire_ai_slotで返されたスロットファイルパス
# Returns:
#   0: スロット解放成功
#   1: スロット解放失敗
release_ai_slot() {
    local slot_file=$1
    local ai_name=$(basename "$slot_file" | cut -d'-' -f1)

    if [[ -f "$slot_file" ]]; then
        rm -f "$slot_file" 2>/dev/null || {
            log_error "[$ai_name] Failed to remove slot file: $slot_file"
            return 1
        }

        local current_slots=$(ls -1 "$AI_SLOTS_DIR" 2>/dev/null | wc -l)
        CURRENT_CONCURRENT_AI=$current_slots

        log_info "🔓 [$ai_name] AI slot released ($current_slots/$MAX_CONCURRENT_AI)"
        return 0
    else
        log_warning "⚠️ [$ai_name] Slot file not found: $slot_file"
        return 1
    fi
}

# すべてのAIスロットをクリーンアップ
cleanup_ai_slots() {
    log_info "🧹 Cleaning up AI slots..."
    rm -rf "$AI_SLOTS_DIR" 2>/dev/null || true
    CURRENT_CONCURRENT_AI=0
    log_info "✓ AI slots cleaned up"
}

# 現在のスロット使用状況を表示
show_ai_slot_status() {
    local current_slots=$(ls -1 "$AI_SLOTS_DIR" 2>/dev/null | wc -l)
    log_info "📊 AI Slot Status: $current_slots/$MAX_CONCURRENT_AI in use"

    if (( current_slots > 0 )); then
        log_info "Active AI slots:"
        ls -1 "$AI_SLOTS_DIR" 2>/dev/null | while read -r slot; do
            local ai_name=$(echo "$slot" | cut -d'-' -f1)
            local slot_age=$(($(date +%s) - $(stat -c %Y "$AI_SLOTS_DIR/$slot" 2>/dev/null || echo 0)))
            log_info "  - $ai_name (age: ${slot_age}s)"
        done
    fi
}

# ============================================================================
# ラッパー関数（AI実行と統合）
# ============================================================================

# AIをスロット管理付きで実行
# Args:
#   $1 - ai_name: AI名
#   $2 - prompt: プロンプト
#   $3 - timeout: タイムアウト秒
#   $4 - output_file: 出力ファイルパス（オプション）
# Returns:
#   AI実行の終了コード
call_ai_with_slot() {
    local ai_name=$1
    local prompt=$2
    local timeout=$3
    local output_file=${4:-""}

    # スロット取得
    local slot_file
    slot_file=$(acquire_ai_slot "$ai_name") || {
        log_error "[$ai_name] Failed to acquire AI slot, aborting..."
        return 1
    }

    # AI実行（スロット解放をtrapで保証）
    trap "release_ai_slot '$slot_file'" RETURN

    if [[ -n "$output_file" ]]; then
        call_ai "$ai_name" "$prompt" "$timeout" > "$output_file" 2>&1
        local exit_code=$?
    else
        call_ai "$ai_name" "$prompt" "$timeout"
        local exit_code=$?
    fi

    # スロット解放（trapで自動実行されるが、明示的にも呼ぶ）
    release_ai_slot "$slot_file"

    return $exit_code
}

# ============================================================================
# エクスポート
# ============================================================================

export -f acquire_ai_slot
export -f release_ai_slot
export -f cleanup_ai_slots
export -f show_ai_slot_status
export -f call_ai_with_slot

# グローバル変数エクスポート
export CURRENT_CONCURRENT_AI
export MAX_CONCURRENT_AI
export AI_SLOTS_DIR

log_info "✓ Resource Limiter library loaded (max concurrent: $MAX_CONCURRENT_AI)"
