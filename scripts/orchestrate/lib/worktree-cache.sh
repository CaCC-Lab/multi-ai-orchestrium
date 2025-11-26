#!/usr/bin/env bash
# Worktree Cache Library
# Version: 1.0.0
# Phase 5 Issue #3: Worktree Cache implementation

set -euo pipefail

# デフォルト設定
WORKTREE_CACHE_DIR="${WORKTREE_CACHE_DIR:-.cache/worktrees}"
WORKTREE_CACHE_TTL="${WORKTREE_CACHE_TTL:-3600}"  # 1時間
WORKTREE_CACHE_MAX_SIZE="${WORKTREE_CACHE_MAX_SIZE:-524288000}"  # 500MB

# AI別キャッシュディレクトリの取得
get_cache_dir() {
    local ai_name="$1"
    echo "$WORKTREE_CACHE_DIR/$ai_name"
}

# VibeLoggerライブラリをロード
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
if [[ -f "$PROJECT_ROOT/bin/vibe-logger-lib.sh" ]]; then
    source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"
fi

# キャッシュディレクトリ初期化
init_worktree_cache() {
    local cache_dir="$WORKTREE_CACHE_DIR"

    # メインキャッシュディレクトリ作成
    mkdir -p "$cache_dir"

    # AI別ディレクトリ作成
    for ai in claude gemini amp qwen droid codex cursor; do
        mkdir -p "$cache_dir/$ai"
        touch "$cache_dir/$ai/.gitkeep"
    done

    # cache-index.json初期化
    local cache_index="$cache_dir/cache-index.json"
    if [[ ! -f "$cache_index" ]]; then
        cat > "$cache_index" <<EOF
{
  "max_entries": 7,
  "current_size_bytes": 0,
  "max_size_bytes": $WORKTREE_CACHE_MAX_SIZE,
  "entries": []
}
EOF
        vibe_log "worktree-lifecycle" "cache_init" \
            "{\"cache_dir\":\"$cache_dir\",\"max_size\":$WORKTREE_CACHE_MAX_SIZE}" \
            "Cache initialized" "[]" "worktree-cache"
    fi
}

# キャッシュ保存（base_ref対応）
save_to_cache() {
    local ai_name="$1"
    local worktree_path="$2"
    local base_ref="${3:-main}"
    local cache_dir=$(get_cache_dir "$ai_name")

    # キャッシュディレクトリが存在しない場合は初期化
    if [[ ! -d "$WORKTREE_CACHE_DIR" ]]; then
        init_worktree_cache
    fi

    # テンプレートディレクトリ作成
    local template_dir="$cache_dir/template"
    mkdir -p "$template_dir"

    # Worktreeの内容をコピー（.gitを除く）
    if command -v rsync &>/dev/null; then
        rsync -a --exclude='.git' "$worktree_path/" "$template_dir/" 2>/dev/null || true
    else
        # rsyncがない場合はcpを使用
        cp -R "$worktree_path"/* "$template_dir/" 2>/dev/null || true
        rm -rf "$template_dir/.git" 2>/dev/null || true
    fi

    # メタデータ保存（base_ref対応）
    local commit_hash=$(git rev-parse "$base_ref" 2>/dev/null || git rev-parse HEAD 2>/dev/null || echo "unknown")
    local size_bytes=$(du -sb "$template_dir" 2>/dev/null | awk '{print $1}' || echo 0)
    local metadata="$cache_dir/metadata.json"

    # jqが利用可能な場合は構造化JSONで保存
    if command -v jq &>/dev/null; then
        jq -n \
            --arg ai_name "$ai_name" \
            --arg created_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
            --arg base_ref "$base_ref" \
            --arg commit_hash "$commit_hash" \
            --argjson size_bytes "$size_bytes" \
            --argjson ttl "$WORKTREE_CACHE_TTL" \
            '{
                ai_name: $ai_name,
                created_at: $created_at,
                last_used: $created_at,
                base_ref: $base_ref,
                commit_hash: $commit_hash,
                size_bytes: $size_bytes,
                hit_count: 0,
                ttl_seconds: $ttl
            }' > "$metadata"
    else
        # jqがない場合は簡易形式
        cat > "$metadata" <<EOF
{
  "ai": "$ai_name",
  "created_at": "$(date -Iseconds)",
  "last_accessed": "$(date -Iseconds)",
  "access_count": 1,
  "base_ref": "$base_ref",
  "commit_hash": "$commit_hash",
  "size_bytes": $size_bytes,
  "ttl_seconds": $WORKTREE_CACHE_TTL
}
EOF
    fi

    # LRUインデックス更新
    update_lru_index "$ai_name" "$size_bytes"

    vibe_log "worktree-lifecycle" "cache_save" \
        "{\"ai\":\"$ai_name\",\"path\":\"$worktree_path\",\"size\":$size_bytes}" \
        "Saved to cache" "[]" "worktree-cache"
}

# キャッシュからロード（base_ref対応）
load_from_cache() {
    local ai_name="$1"
    local worktree_path="$2"
    local base_ref="${3:-main}"
    local cache_dir=$(get_cache_dir "$ai_name")
    local template_dir="$cache_dir/template"

    # キャッシュヒットチェック（base_refを含む）
    if ! cache_lookup "$ai_name" "$base_ref"; then
        return 1  # MISS
    fi

    # worktreeパスのディレクトリを作成
    mkdir -p "$worktree_path"

    # テンプレートからWorktreeを復元
    if command -v rsync &>/dev/null; then
        rsync -a "$template_dir/" "$worktree_path/" 2>/dev/null || return 1
    else
        cp -R "$template_dir"/* "$worktree_path/" 2>/dev/null || return 1
    fi

    # メタデータ更新（last_accessed, access_count）
    update_cache_metadata "$ai_name"

    vibe_log "worktree-lifecycle" "cache_load" \
        "{\"ai\":\"$ai_name\",\"path\":\"$worktree_path\"}" \
        "Loaded from cache" "[]" "worktree-cache"

    return 0  # HIT
}

# キャッシュルックアップ（base_ref対応）
cache_lookup() {
    local ai_name="$1"
    local base_ref="${2:-main}"
    local cache_dir=$(get_cache_dir "$ai_name")
    local metadata="$cache_dir/metadata.json"
    local template_dir="$cache_dir/template"

    # キャッシュディレクトリ存在チェック
    if [[ ! -d "$template_dir" ]]; then
        return 1  # MISS
    fi

    # メタデータ読み込み
    if [[ ! -f "$metadata" ]]; then
        return 1  # MISS
    fi

    # jqがない場合はキャッシュを使用しない
    if ! command -v jq &>/dev/null; then
        return 1  # MISS
    fi

    # base_refチェック（実装計画に基づく）
    local cached_base_ref=$(jq -r '.base_ref // .commit_hash' "$metadata" 2>/dev/null || echo "")
    if [[ -n "$cached_base_ref" ]]; then
        # base_refが指定されている場合は、コミットハッシュまたはbase_refでチェック
        local current_ref=$(git rev-parse "$base_ref" 2>/dev/null || git rev-parse HEAD 2>/dev/null || echo "")
        if [[ -z "$current_ref" ]] || [[ "$cached_base_ref" != "$current_ref" ]] && [[ "$cached_base_ref" != "$base_ref" ]]; then
            return 1  # MISS (base_ref不一致)
        fi
    else
        # 後方互換性: commit_hashチェック
        local cached_commit=$(jq -r '.commit_hash' "$metadata" 2>/dev/null || echo "")
        local current_commit=$(git rev-parse HEAD 2>/dev/null || echo "")
        if [[ -z "$cached_commit" || "$cached_commit" != "$current_commit" ]]; then
            return 1  # MISS (stale)
        fi
    fi

    # TTLチェック
    local cached_ttl=$(jq -r '.ttl_seconds' "$metadata" 2>/dev/null || echo "3600")
    local cached_time=$(jq -r '.created_at' "$metadata" 2>/dev/null || echo "")
    local current_time=$(date +%s)
    local cached_time_epoch=$(date -d "$cached_time" +%s 2>/dev/null || echo 0)
    local age=$((current_time - cached_time_epoch))

    if [[ $age -gt $cached_ttl ]]; then
        return 1  # MISS (expired)
    fi

    return 0  # HIT
}

# キャッシュメタデータ更新
update_cache_metadata() {
    local ai_name="$1"
    local cache_dir="$WORKTREE_CACHE_DIR/$ai_name"
    local metadata="$cache_dir/metadata.json"

    if [[ ! -f "$metadata" ]]; then
        return
    fi

    if ! command -v jq &>/dev/null; then
        return
    fi

    # last_accessed更新、access_count++
    jq --arg now "$(date -Iseconds)" \
        '.last_accessed = $now | .access_count += 1' \
        "$metadata" > "$metadata.tmp" && mv "$metadata.tmp" "$metadata"

    # LRUインデックス更新
    local size_bytes=$(jq -r '.size_bytes' "$metadata")
    update_lru_index "$ai_name" "$size_bytes"
}

# LRUインデックス更新
update_lru_index() {
    local ai_name="$1"
    local size_bytes="$2"
    local cache_index="$WORKTREE_CACHE_DIR/cache-index.json"

    if [[ ! -f "$cache_index" ]]; then
        return
    fi

    if ! command -v jq &>/dev/null; then
        return
    fi

    # 既存エントリ削除
    jq --arg ai "$ai_name" 'del(.entries[] | select(.ai == $ai))' \
        "$cache_index" > "$cache_index.tmp"

    # 新規エントリ追加（先頭に）
    jq --arg ai "$ai_name" --arg size "$size_bytes" \
        '.entries = [{ai: $ai, last_accessed: (now | todate), size_bytes: ($size | tonumber)}] + .entries' \
        "$cache_index.tmp" > "$cache_index"

    rm -f "$cache_index.tmp"

    # サイズ制限チェック
    check_cache_size_limit
}

# キャッシュサイズ制限チェック
check_cache_size_limit() {
    local cache_index="$WORKTREE_CACHE_DIR/cache-index.json"

    if [[ ! -f "$cache_index" ]]; then
        return
    fi

    if ! command -v jq &>/dev/null; then
        return
    fi

    local max_size=$(jq -r '.max_size_bytes' "$cache_index")
    local current_size=$(jq -r '[.entries[].size_bytes] | add // 0' "$cache_index")

    # 制限超過チェック
    if [[ $current_size -gt $max_size ]]; then
        evict_lru_entries
    fi
}

# LRU削除
evict_lru_entries() {
    local cache_index="$WORKTREE_CACHE_DIR/cache-index.json"

    if [[ ! -f "$cache_index" ]]; then
        return
    fi

    if ! command -v jq &>/dev/null; then
        return
    fi

    local max_size=$(jq -r '.max_size_bytes' "$cache_index")

    # 最後のエントリから削除
    while true; do
        local current_size=$(jq -r '[.entries[].size_bytes] | add // 0' "$cache_index")

        if [[ $current_size -le $max_size ]]; then
            break
        fi

        # 最古のエントリ取得
        local oldest_ai=$(jq -r '.entries[-1].ai // ""' "$cache_index")

        if [[ -z "$oldest_ai" ]]; then
            break
        fi

        # キャッシュディレクトリ削除
        rm -rf "$WORKTREE_CACHE_DIR/$oldest_ai/template" 2>/dev/null
        rm -f "$WORKTREE_CACHE_DIR/$oldest_ai/metadata.json" 2>/dev/null

        # インデックスから削除
        jq --arg ai "$oldest_ai" 'del(.entries[] | select(.ai == $ai))' \
            "$cache_index" > "$cache_index.tmp"
        mv "$cache_index.tmp" "$cache_index"

        vibe_log "worktree-lifecycle" "cache_evict" \
            "{\"ai\":\"$oldest_ai\"}" \
            "LRU cache eviction" "[]" "worktree-cache"
    done
}

# キャッシュ統計
get_cache_stats() {
    local cache_index="$WORKTREE_CACHE_DIR/cache-index.json"

    if [[ ! -f "$cache_index" ]]; then
        echo "{\"hit_count\": 0, \"miss_count\": 0, \"hit_rate\": 0.0}"
        return
    fi

    if ! command -v jq &>/dev/null; then
        echo "{\"hit_count\": 0, \"miss_count\": 0, \"hit_rate\": 0.0}"
        return
    fi

    # VibeLoggerログから統計を計算
    local hit_count=$(grep -r "cache_load" logs/vibe/ 2>/dev/null | wc -l || echo 0)
    local miss_count=$(grep -r "cache_miss" logs/vibe/ 2>/dev/null | wc -l || echo 0)
    local total=$((hit_count + miss_count))

    if [[ $total -eq 0 ]]; then
        echo "{\"hit_count\": 0, \"miss_count\": 0, \"hit_rate\": 0.0}"
        return
    fi

    local hit_rate=$(awk "BEGIN {printf \"%.2f\", ($hit_count / $total) * 100}")

    echo "{\"hit_count\": $hit_count, \"miss_count\": $miss_count, \"hit_rate\": $hit_rate}"
}

# キャッシュメトリクスレポート
report_cache_metrics() {
    echo "===== Worktree Cache Metrics ====="

    # 統計情報
    local stats=$(get_cache_stats)
    local hit_count=$(echo "$stats" | jq -r '.hit_count')
    local miss_count=$(echo "$stats" | jq -r '.miss_count')
    local hit_rate=$(echo "$stats" | jq -r '.hit_rate')

    echo "Cache Hit Count: $hit_count"
    echo "Cache Miss Count: $miss_count"
    echo "Cache Hit Rate: ${hit_rate}%"

    # AI別統計
    echo ""
    echo "Per-AI Statistics:"
    for ai in claude gemini amp qwen droid codex cursor; do
        local ai_hits=$(grep -r "cache_load.*\"ai\":\"$ai\"" logs/vibe/ 2>/dev/null | wc -l || echo 0)
        local ai_misses=$(grep -r "cache_miss.*\"ai\":\"$ai\"" logs/vibe/ 2>/dev/null | wc -l || echo 0)
        local ai_total=$((ai_hits + ai_misses))

        if [[ $ai_total -gt 0 ]]; then
            local ai_hit_rate=$(awk "BEGIN {printf \"%.1f\", ($ai_hits / $ai_total) * 100}")
            echo "  $ai: $ai_hits hits, $ai_misses misses (${ai_hit_rate}%)"
        fi
    done

    # ディスク使用量
    echo ""
    echo "Disk Usage:"
    local cache_size=$(du -sh "$WORKTREE_CACHE_DIR" 2>/dev/null | awk '{print $1}' || echo "0")
    echo "  Total: $cache_size"

    # LRUインデックス情報
    if [[ -f "$WORKTREE_CACHE_DIR/cache-index.json" ]] && command -v jq &>/dev/null; then
        echo ""
        echo "LRU Index:"
        local entries=$(jq -r '.entries | length' "$WORKTREE_CACHE_DIR/cache-index.json")
        local current_size=$(jq -r '.current_size_bytes' "$WORKTREE_CACHE_DIR/cache-index.json")
        local max_size=$(jq -r '.max_size_bytes' "$WORKTREE_CACHE_DIR/cache-index.json")
        echo "  Entries: $entries"
        echo "  Current Size: $(numfmt --to=iec $current_size 2>/dev/null || echo $current_size)"
        echo "  Max Size: $(numfmt --to=iec $max_size 2>/dev/null || echo $max_size)"
    fi
}

# 古いキャッシュのクリーンアップ（TTLベース）
cleanup_old_cache() {
    local max_age="${WORKTREE_CACHE_MAX_AGE:-86400}"  # デフォルト: 24時間
    local cache_root="$WORKTREE_CACHE_DIR"
    local current_time=$(date +%s)
    local cleaned_count=0

    if [[ ! -d "$cache_root" ]]; then
        return 0
    fi

    if ! command -v jq &>/dev/null; then
        return 0
    fi

    # AI別キャッシュをチェック
    for ai_cache_dir in "$cache_root"/*/; do
        [[ -d "$ai_cache_dir" ]] || continue

        local metadata_file="$ai_cache_dir/metadata.json"
        if [[ ! -f "$metadata_file" ]]; then
            continue
        fi

        # メタデータから作成時刻を取得
        local created_at=$(jq -r '.created_at' "$metadata_file" 2>/dev/null || echo "")
        if [[ -z "$created_at" ]]; then
            continue
        fi

        # 作成時刻をエポック秒に変換
        local created_time_epoch=$(date -d "$created_at" +%s 2>/dev/null || echo "0")
        if [[ $created_time_epoch -eq 0 ]]; then
            continue
        fi

        local age=$((current_time - created_time_epoch))

        # 最大年齢を超えている場合は削除
        if (( age > max_age )); then
            local ai_name=$(basename "$ai_cache_dir")
            echo "Removing old cache for $ai_name (age: ${age}s, max: ${max_age}s)"

            # キャッシュディレクトリ削除
            rm -rf "$ai_cache_dir/template" 2>/dev/null || true
            rm -f "$metadata_file" 2>/dev/null || true

            # LRUインデックスから削除
            local cache_index="$cache_root/cache-index.json"
            if [[ -f "$cache_index" ]] && command -v jq &>/dev/null; then
                jq --arg ai "$ai_name" 'del(.entries[] | select(.ai == $ai))' \
                    "$cache_index" > "${cache_index}.tmp" 2>/dev/null && \
                mv "${cache_index}.tmp" "$cache_index" 2>/dev/null || true
            fi

            vibe_log "worktree-lifecycle" "cache_cleanup_old" \
                "{\"ai\":\"$ai_name\",\"age_seconds\":$age}" \
                "Removed old cache for $ai_name" "[]" "worktree-cache"

            ((cleaned_count++))
        fi
    done

    if [[ $cleaned_count -gt 0 ]]; then
        echo "Cleaned up $cleaned_count old cache entries"
    fi

    return 0
}

# キャッシュクリーンアップ（全削除）
clean_worktree_cache() {
    local cache_dir="$WORKTREE_CACHE_DIR"

    if [[ ! -d "$cache_dir" ]]; then
        echo "Cache directory does not exist: $cache_dir"
        return
    fi

    echo "Cleaning worktree cache: $cache_dir"

    # キャッシュディレクトリ削除
    rm -rf "$cache_dir"

    # 再初期化
    init_worktree_cache

    echo "Cache cleaned successfully"

    vibe_log "worktree-lifecycle" "cache_clean" \
        "{\"cache_dir\":\"$cache_dir\"}" \
        "Cache cleaned" "[]" "worktree-cache"
}

# エクスポート
export -f get_cache_dir
export -f init_worktree_cache
export -f save_to_cache
export -f load_from_cache
export -f cache_lookup
export -f update_cache_metadata
export -f update_lru_index
export -f check_cache_size_limit
export -f evict_lru_entries
export -f cleanup_old_cache
export -f get_cache_stats
export -f report_cache_metrics
export -f clean_worktree_cache
