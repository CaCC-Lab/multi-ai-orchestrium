#!/bin/bash
set -euo pipefail

#
# cache-manager.sh
#
# Cache Management System for Spec-Driven Development
# Provides SHA-256 based caching with TTL management.
#

# Configuration
CACHE_DIR="${CACHE_DIR:-/tmp/spec-driven-cache}"
CACHE_TTL="${CACHE_TTL:-86400}"  # Default: 24 hours in seconds
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Source VibeLogger if available
if [[ -f "$PROJECT_ROOT/bin/vibe-logger-lib.sh" ]]; then
    # shellcheck source=../../bin/vibe-logger-lib.sh
    source "$PROJECT_ROOT/bin/vibe-logger-lib.sh"
else
    # Fallback logging
    vibe_log() { echo "[$(date +%FT%T)] $*" >&2; }
fi

# Cache statistics
declare -g CACHE_HITS=0
declare -g CACHE_MISSES=0

#
# init_cache
#
# Initializes the cache directory.
#
# Usage: init_cache
# Returns: 0 on success, 1 on failure
#
init_cache() {
    if [[ ! -d "$CACHE_DIR" ]]; then
        mkdir -p "$CACHE_DIR" || {
            vibe_log "cache.init" "failed" \
                "{\"cache_dir\": \"$CACHE_DIR\"}" \
                "Failed to create cache directory"
            return 1
        }
    fi

    vibe_log "cache.init" "initialized" \
        "{\"cache_dir\": \"$CACHE_DIR\", \"ttl\": $CACHE_TTL}" \
        "Cache initialized at $CACHE_DIR with TTL ${CACHE_TTL}s"

    return 0
}

#
# generate_cache_key
#
# Generates SHA-256 hash for a file or string.
#
# Usage: generate_cache_key <file_path|string> [--string]
# Args:
#   file_path|string - File path or string to hash
#   --string - Treat input as string instead of file path
# Returns: SHA-256 hash (lowercase hex)
#
generate_cache_key() {
    local input="$1"
    local is_string="${2:-}"

    if [[ "$is_string" == "--string" ]]; then
        # Hash string directly
        echo -n "$input" | sha256sum | awk '{print $1}'
    else
        # Hash file content
        if [[ -f "$input" ]]; then
            sha256sum "$input" | awk '{print $1}'
        else
            vibe_log "cache.key" "file_not_found" \
                "{\"file\": \"$input\"}" \
                "File not found for cache key generation"
            return 1
        fi
    fi
}

#
# get_cache_path
#
# Converts cache key to file path.
#
# Usage: get_cache_path <cache_key>
# Args:
#   cache_key - SHA-256 cache key
# Returns: Full path to cache file
#
get_cache_path() {
    local cache_key="$1"
    echo "$CACHE_DIR/${cache_key}.json"
}

#
# is_cache_valid
#
# Checks if cached file is still valid (within TTL).
#
# Usage: is_cache_valid <cache_path>
# Args:
#   cache_path - Path to cached file
# Returns: 0 if valid, 1 if expired or missing
#
is_cache_valid() {
    local cache_path="$1"

    if [[ ! -f "$cache_path" ]]; then
        return 1
    fi

    local current_time file_mtime age
    current_time=$(date +%s)
    file_mtime=$(stat -c %Y "$cache_path" 2>/dev/null || stat -f %m "$cache_path" 2>/dev/null || echo 0)
    age=$((current_time - file_mtime))

    if (( age > CACHE_TTL )); then
        vibe_log "cache.validity" "expired" \
            "{\"cache_path\": \"$cache_path\", \"age\": $age, \"ttl\": $CACHE_TTL}" \
            "Cache expired (age: ${age}s, TTL: ${CACHE_TTL}s)"
        return 1
    fi

    return 0
}

#
# cache_get
#
# Retrieves value from cache.
#
# Usage: cache_get <cache_key>
# Args:
#   cache_key - SHA-256 cache key
# Returns: Cached JSON content (stdout) and 0 on success, 1 on cache miss
#
cache_get() {
    local cache_key="$1"
    local cache_path
    cache_path=$(get_cache_path "$cache_key")

    if is_cache_valid "$cache_path"; then
        cat "$cache_path"

        CACHE_HITS=$((CACHE_HITS + 1))

        vibe_log "cache.get" "hit" \
            "{\"cache_key\": \"$cache_key\", \"hits\": $CACHE_HITS}" \
            "Cache hit for key $cache_key"

        return 0
    fi

    CACHE_MISSES=$((CACHE_MISSES + 1))

    vibe_log "cache.get" "miss" \
        "{\"cache_key\": \"$cache_key\", \"misses\": $CACHE_MISSES}" \
        "Cache miss for key $cache_key"

    return 1
}

#
# cache_set
#
# Stores value in cache.
#
# Usage: cache_set <cache_key> <json_content>
# Args:
#   cache_key - SHA-256 cache key
#   json_content - JSON content to cache
# Returns: 0 on success, 1 on failure
#
cache_set() {
    local cache_key="$1"
    local json_content="$2"
    local cache_path
    cache_path=$(get_cache_path "$cache_key")

    # Ensure cache directory exists
    init_cache || return 1

    # Write content to cache file
    echo "$json_content" > "$cache_path" || {
        vibe_log "cache.set" "failed" \
            "{\"cache_key\": \"$cache_key\"}" \
            "Failed to write cache file"
        return 1
    }

    vibe_log "cache.set" "stored" \
        "{\"cache_key\": \"$cache_key\", \"size\": $(wc -c < "$cache_path")}" \
        "Cached data for key $cache_key"

    return 0
}

#
# cache_delete
#
# Deletes a cached entry.
#
# Usage: cache_delete <cache_key>
# Args:
#   cache_key - SHA-256 cache key
# Returns: 0 on success, 1 on failure
#
cache_delete() {
    local cache_key="$1"
    local cache_path
    cache_path=$(get_cache_path "$cache_key")

    if [[ -f "$cache_path" ]]; then
        rm -f "$cache_path" || {
            vibe_log "cache.delete" "failed" \
                "{\"cache_key\": \"$cache_key\"}" \
                "Failed to delete cache file"
            return 1
        }

        vibe_log "cache.delete" "deleted" \
            "{\"cache_key\": \"$cache_key\"}" \
            "Deleted cache entry for key $cache_key"
    fi

    return 0
}

#
# cache_clear
#
# Clears all cache entries.
#
# Usage: cache_clear [--expired-only]
# Args:
#   --expired-only - Only delete expired entries (optional)
# Returns: 0 on success, 1 on failure
#
cache_clear() {
    local expired_only="${1:-}"
    local deleted_count=0

    init_cache || return 1

    if [[ "$expired_only" == "--expired-only" ]]; then
        # Delete only expired entries
        while IFS= read -r -d '' cache_file; do
            if ! is_cache_valid "$cache_file"; then
                rm -f "$cache_file"
                deleted_count=$((deleted_count + 1))
            fi
        done < <(find "$CACHE_DIR" -name "*.json" -print0 2>/dev/null)

        vibe_log "cache.clear" "expired_cleared" \
            "{\"deleted_count\": $deleted_count}" \
            "Cleared $deleted_count expired cache entries"
    else
        # Delete all entries
        rm -f "$CACHE_DIR"/*.json 2>/dev/null || true
        deleted_count=$(find "$CACHE_DIR" -name "*.json" 2>/dev/null | wc -l)

        vibe_log "cache.clear" "all_cleared" \
            "{\"deleted_count\": $deleted_count}" \
            "Cleared all cache entries"
    fi

    return 0
}

#
# cache_stats
#
# Returns cache statistics.
#
# Usage: cache_stats
# Returns: JSON string with cache statistics
#
cache_stats() {
    local total_entries=0
    local total_size=0
    local hit_rate="0.00"

    if [[ -d "$CACHE_DIR" ]]; then
        total_entries=$(find "$CACHE_DIR" -name "*.json" 2>/dev/null | wc -l)
        total_size=$(du -sb "$CACHE_DIR" 2>/dev/null | awk '{print $1}' || echo 0)
    fi

    local total_requests=$((CACHE_HITS + CACHE_MISSES))
    if (( total_requests > 0 )) && command -v bc &> /dev/null; then
        hit_rate=$(echo "scale=2; $CACHE_HITS / $total_requests" | bc)
    fi

    cat <<EOF
{
  "cache_dir": "$CACHE_DIR",
  "total_entries": $total_entries,
  "total_size_bytes": $total_size,
  "cache_hits": $CACHE_HITS,
  "cache_misses": $CACHE_MISSES,
  "hit_rate": $hit_rate,
  "ttl_seconds": $CACHE_TTL
}
EOF
}

#
# cache_spec_file
#
# Caches task extraction results for a specification file.
#
# Usage: cache_spec_file <spec_file> <tasks_json>
# Args:
#   spec_file - Path to specification file
#   tasks_json - JSON array of extracted tasks
# Returns: 0 on success, 1 on failure
#
cache_spec_file() {
    local spec_file="$1"
    local tasks_json="$2"

    local cache_key
    cache_key=$(generate_cache_key "$spec_file") || return 1

    cache_set "$cache_key" "$tasks_json"
}

#
# get_cached_spec
#
# Retrieves cached task extraction results for a specification file.
#
# Usage: get_cached_spec <spec_file>
# Args:
#   spec_file - Path to specification file
# Returns: Cached tasks JSON (stdout) and 0 on success, 1 on cache miss
#
get_cached_spec() {
    local spec_file="$1"

    local cache_key
    cache_key=$(generate_cache_key "$spec_file") || return 1

    cache_get "$cache_key"
}

#
# invalidate_spec_cache
#
# Invalidates cache for a specification file.
#
# Usage: invalidate_spec_cache <spec_file>
# Args:
#   spec_file - Path to specification file
# Returns: 0 on success, 1 on failure
#
invalidate_spec_cache() {
    local spec_file="$1"

    local cache_key
    cache_key=$(generate_cache_key "$spec_file") || return 1

    cache_delete "$cache_key"
}

# Export functions for use in other scripts
export -f init_cache
export -f generate_cache_key
export -f get_cache_path
export -f is_cache_valid
export -f cache_get
export -f cache_set
export -f cache_delete
export -f cache_clear
export -f cache_stats
export -f cache_spec_file
export -f get_cached_spec
export -f invalidate_spec_cache
