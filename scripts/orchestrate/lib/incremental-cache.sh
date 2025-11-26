#!/usr/bin/env bash
#
# Incremental Cache Library
# Phase 4 Tier 2 Task 4: 増分合成
#
# Purpose: Phase-level dependency tracking and content-based caching
# Goal: 15-30% speedup through change detection and selective re-execution
#
# Architecture:
#   - Content hashing (SHA256) for change detection
#   - Phase metadata with dependency hashes
#   - TTL-based cache invalidation
#   - Graceful fallback on cache miss
#

set -euo pipefail

# ===== Configuration =====

INCREMENTAL_CACHE_DIR="${INCREMENTAL_CACHE_DIR:-${AI_CACHE_DIR:-$PROJECT_ROOT/.cache/workflows}}"
INCREMENTAL_CACHE_TTL="${INCREMENTAL_CACHE_TTL:-3600}"  # 1 hour
CACHE_VERBOSE="${CACHE_VERBOSE:-false}"

# ===== Logging =====

log_cache_event() {
    local event="$1"
    local message="$2"

    if [[ "$CACHE_VERBOSE" == "true" ]]; then
        echo "[INCREMENTAL_CACHE] $event: $message" >&2
    fi
}

# ===== Core Functions =====

#
# Calculate SHA256 hash of file content
#
# Arguments:
#   $1 - file_path: Path to file for hashing
#
# Returns:
#   SHA256 hash string (64 chars) on stdout
#   Exit code 0 on success, 1 on failure
#
# Example:
#   hash=$(calculate_content_hash "logs/output.md")
#
calculate_content_hash() {
    local file_path="$1"

    if [[ ! -f "$file_path" ]]; then
        log_cache_event "HASH_ERROR" "File not found: $file_path"
        return 1
    fi

    local hash=""

    # Try Linux sha256sum
    if command -v sha256sum >/dev/null 2>&1; then
        hash=$(sha256sum "$file_path" 2>/dev/null | cut -d' ' -f1)
    # Try macOS shasum
    elif command -v shasum >/dev/null 2>&1; then
        hash=$(shasum -a 256 "$file_path" 2>/dev/null | cut -d' ' -f1)
    else
        log_cache_event "HASH_ERROR" "No SHA256 utility available (sha256sum or shasum)"
        return 1
    fi

    if [[ -z "$hash" ]]; then
        log_cache_event "HASH_ERROR" "Failed to calculate hash for $file_path"
        return 1
    fi

    log_cache_event "HASH_CALC" "file=${file_path##*/} | hash=${hash:0:16}..."

    echo "$hash"
    return 0
}

#
# Save phase metadata with content hash and dependencies
#
# Arguments:
#   $1 - workflow_id: Unique workflow identifier
#   $2 - phase_idx: Phase index (0-based)
#   $3 - ai_name: AI name (claude, gemini, etc.)
#   $4 - role: AI role description
#   $5 - output_file: Path to phase output file
#   $6 - dependency_hashes: JSON string of dependency hashes (optional, default: {})
#
# Returns:
#   Exit code 0 on success, 1 on failure
#
# Example:
#   save_phase_metadata "workflow-123" 0 "claude" "architecture" \
#       "logs/claude_output.md" '{}'
#
save_phase_metadata() {
    local workflow_id="$1"
    local phase_idx="$2"
    local ai_name="$3"
    local role="$4"
    local output_file="$5"
    local dependency_hashes="${6:-{}}"

    # Validate inputs
    if [[ -z "$workflow_id" ]] || [[ -z "$phase_idx" ]] || [[ -z "$ai_name" ]]; then
        log_cache_event "SAVE_ERROR" "Missing required arguments"
        return 1
    fi

    if [[ ! -f "$output_file" ]]; then
        log_cache_event "SAVE_ERROR" "Output file not found: $output_file"
        return 1
    fi

    # Create cache directory
    local meta_dir="$INCREMENTAL_CACHE_DIR/${workflow_id}"
    mkdir -p "$meta_dir" 2>/dev/null || {
        log_cache_event "SAVE_ERROR" "Failed to create directory: $meta_dir"
        return 1
    }

    # Calculate output hash
    local output_hash
    output_hash=$(calculate_content_hash "$output_file") || {
        log_cache_event "SAVE_ERROR" "Failed to calculate hash for $output_file"
        return 1
    }

    # Prepare metadata
    local meta_file="$meta_dir/phase_${phase_idx}.meta"
    local timestamp=$(date +%s)

    # Validate dependency_hashes is valid JSON
    # Note: Currently defaulting to empty object for complex JSON to avoid parsing issues
    # TODO: Fix dependency hash preservation in Phase 4 Tier 2 Task 4 completion
    if echo "$dependency_hashes" | jq empty 2>/dev/null; then
        : # Valid JSON, continue
    else
        log_cache_event "SAVE_WARN" "Invalid dependency_hashes JSON, using empty object"
        dependency_hashes="{}"
    fi

    # Generate JSON metadata using jq
    if command -v jq >/dev/null 2>&1; then
        jq -n \
            --arg phase_idx "$phase_idx" \
            --arg ai "$ai_name" \
            --arg role "$role" \
            --arg output_hash "$output_hash" \
            --arg output_file "$output_file" \
            --argjson dependency_hashes "$dependency_hashes" \
            --arg timestamp "$timestamp" \
            --arg ttl "$INCREMENTAL_CACHE_TTL" \
            '{
                phase_idx: ($phase_idx | tonumber),
                ai: $ai,
                role: $role,
                output_hash: $output_hash,
                output_file: $output_file,
                dependency_hashes: $dependency_hashes,
                timestamp: ($timestamp | tonumber),
                ttl: ($ttl | tonumber)
            }' > "$meta_file" 2>/dev/null || {
            log_cache_event "SAVE_ERROR" "Failed to write metadata with jq"
            return 1
        }
    else
        # Fallback: manual JSON generation (less safe)
        cat > "$meta_file" <<EOF
{
  "phase_idx": $phase_idx,
  "ai": "$ai_name",
  "role": "$role",
  "output_hash": "$output_hash",
  "output_file": "$output_file",
  "dependency_hashes": $dependency_hashes,
  "timestamp": $timestamp,
  "ttl": $INCREMENTAL_CACHE_TTL
}
EOF
    fi

    log_cache_event "SAVE_OK" "phase=$phase_idx | ai=$ai_name | hash=${output_hash:0:16}..."

    return 0
}

#
# Check if phase can use cached result
#
# Arguments:
#   $1 - workflow_id: Unique workflow identifier
#   $2 - phase_idx: Phase index (0-based)
#   $3 - current_dependency_hashes: JSON string of current dependency hashes (optional, default: {})
#
# Returns:
#   Exit code 0 if cache valid, 1 if must re-execute
#
# Example:
#   if check_phase_cache_valid "workflow-123" 1 '{"phase_0": "abc123"}'; then
#       echo "Cache hit"
#   else
#       echo "Cache miss"
#   fi
#
check_phase_cache_valid() {
    local workflow_id="$1"
    local phase_idx="$2"
    local current_dependency_hashes="${3:-{}}"

    local meta_file="$INCREMENTAL_CACHE_DIR/${workflow_id}/phase_${phase_idx}.meta"

    # No metadata → cache miss
    if [[ ! -f "$meta_file" ]]; then
        log_cache_event "CACHE_MISS" "phase=$phase_idx | reason=no_metadata"
        return 1
    fi

    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        log_cache_event "CACHE_MISS" "phase=$phase_idx | reason=no_jq"
        return 1
    fi

    # Validate metadata JSON
    if ! jq empty "$meta_file" 2>/dev/null; then
        log_cache_event "CACHE_MISS" "phase=$phase_idx | reason=invalid_json"
        return 1
    fi

    # Check TTL
    local cached_timestamp
    cached_timestamp=$(jq -r '.timestamp' "$meta_file" 2>/dev/null)

    if [[ -z "$cached_timestamp" ]] || [[ "$cached_timestamp" == "null" ]]; then
        log_cache_event "CACHE_MISS" "phase=$phase_idx | reason=no_timestamp"
        return 1
    fi

    local current_timestamp=$(date +%s)
    local age=$((current_timestamp - cached_timestamp))

    local cached_ttl
    cached_ttl=$(jq -r '.ttl' "$meta_file" 2>/dev/null)

    if [[ -z "$cached_ttl" ]] || [[ "$cached_ttl" == "null" ]]; then
        cached_ttl="$INCREMENTAL_CACHE_TTL"
    fi

    # TTL expired
    if [[ $age -gt $cached_ttl ]]; then
        log_cache_event "CACHE_MISS" "phase=$phase_idx | reason=ttl_expired | age=${age}s > ttl=${cached_ttl}s"
        return 1
    fi

    # Check output file exists
    local output_file
    output_file=$(jq -r '.output_file' "$meta_file" 2>/dev/null)

    if [[ -z "$output_file" ]] || [[ ! -f "$output_file" ]]; then
        log_cache_event "CACHE_MISS" "phase=$phase_idx | reason=output_missing"
        return 1
    fi

    # Check dependency hashes
    local cached_dependency_hashes
    cached_dependency_hashes=$(jq -c '.dependency_hashes' "$meta_file" 2>/dev/null)

    if [[ -z "$cached_dependency_hashes" ]]; then
        cached_dependency_hashes="{}"
    fi

    # Normalize JSON for comparison (sort keys)
    local cached_deps_normalized
    local current_deps_normalized

    cached_deps_normalized=$(echo "$cached_dependency_hashes" | jq -S '.' 2>/dev/null) || cached_deps_normalized="{}"
    current_deps_normalized=$(echo "$current_dependency_hashes" | jq -S '.' 2>/dev/null) || current_deps_normalized="{}"

    # Compare dependency hashes
    if [[ "$cached_deps_normalized" != "$current_deps_normalized" ]]; then
        log_cache_event "CACHE_MISS" "phase=$phase_idx | reason=dependency_changed"
        log_cache_event "CACHE_MISS_DETAIL" "cached=$cached_deps_normalized | current=$current_deps_normalized"
        return 1
    fi

    # Cache valid
    log_cache_event "CACHE_HIT" "phase=$phase_idx | age=${age}s/${cached_ttl}s"

    return 0
}

#
# Load phase output from cache
#
# Arguments:
#   $1 - workflow_id: Unique workflow identifier
#   $2 - phase_idx: Phase index (0-based)
#   $3 - output_destination: File path to write cached output
#
# Returns:
#   Exit code 0 on success, 1 on failure
#
# Example:
#   if load_phase_from_cache "workflow-123" 1 "logs/output.md"; then
#       echo "Loaded from cache"
#   fi
#
load_phase_from_cache() {
    local workflow_id="$1"
    local phase_idx="$2"
    local output_destination="$3"

    local meta_file="$INCREMENTAL_CACHE_DIR/${workflow_id}/phase_${phase_idx}.meta"

    if [[ ! -f "$meta_file" ]]; then
        log_cache_event "LOAD_ERROR" "phase=$phase_idx | reason=no_metadata"
        return 1
    fi

    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        log_cache_event "LOAD_ERROR" "phase=$phase_idx | reason=no_jq"
        return 1
    fi

    # Get cached output file path
    local cached_output_file
    cached_output_file=$(jq -r '.output_file' "$meta_file" 2>/dev/null)

    if [[ -z "$cached_output_file" ]] || [[ "$cached_output_file" == "null" ]]; then
        log_cache_event "LOAD_ERROR" "phase=$phase_idx | reason=no_output_path"
        return 1
    fi

    if [[ ! -f "$cached_output_file" ]]; then
        log_cache_event "LOAD_ERROR" "phase=$phase_idx | reason=output_missing | path=$cached_output_file"
        return 1
    fi

    # Create destination directory if needed
    local dest_dir
    dest_dir=$(dirname "$output_destination")
    mkdir -p "$dest_dir" 2>/dev/null || {
        log_cache_event "LOAD_ERROR" "phase=$phase_idx | reason=mkdir_failed | dir=$dest_dir"
        return 1
    }

    # Copy cached output to destination
    if ! cp "$cached_output_file" "$output_destination" 2>/dev/null; then
        log_cache_event "LOAD_ERROR" "phase=$phase_idx | reason=copy_failed"
        return 1
    fi

    log_cache_event "LOAD_OK" "phase=$phase_idx | from=${cached_output_file##*/} | to=${output_destination##*/}"

    return 0
}

#
# Get phase output hash from metadata
#
# Arguments:
#   $1 - workflow_id: Unique workflow identifier
#   $2 - phase_idx: Phase index (0-based)
#
# Returns:
#   Output hash string on stdout, empty string on failure
#   Exit code 0 on success, 1 on failure
#
# Example:
#   hash=$(get_phase_output_hash "workflow-123" 0)
#
get_phase_output_hash() {
    local workflow_id="$1"
    local phase_idx="$2"

    local meta_file="$INCREMENTAL_CACHE_DIR/${workflow_id}/phase_${phase_idx}.meta"

    if [[ ! -f "$meta_file" ]]; then
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    local output_hash
    output_hash=$(jq -r '.output_hash' "$meta_file" 2>/dev/null)

    if [[ -z "$output_hash" ]] || [[ "$output_hash" == "null" ]]; then
        return 1
    fi

    echo "$output_hash"
    return 0
}

#
# Build dependency hashes JSON from previous phases
#
# Arguments:
#   $1 - workflow_id: Unique workflow identifier
#   $2... - phase_indices: Space-separated list of dependency phase indices
#
# Returns:
#   JSON string of dependency hashes on stdout
#   Exit code 0 on success, 1 on failure
#
# Example:
#   deps=$(build_dependency_hashes "workflow-123" "0" "1")
#   # Returns: {"phase_0": "abc123...", "phase_1": "def456..."}
#
build_dependency_hashes() {
    local workflow_id="$1"
    shift
    local dependency_indices=("$@")

    local dependency_hashes="{}"

    for dep_idx in "${dependency_indices[@]}"; do
        local dep_hash
        dep_hash=$(get_phase_output_hash "$workflow_id" "$dep_idx")

        if [[ -n "$dep_hash" ]]; then
            if command -v jq >/dev/null 2>&1; then
                dependency_hashes=$(echo "$dependency_hashes" | \
                    jq --arg idx "$dep_idx" --arg hash "$dep_hash" \
                    '. + {("phase_" + $idx): $hash}' 2>/dev/null)
            fi
        fi
    done

    echo "$dependency_hashes"
    return 0
}

# ===== Export Functions =====

export -f calculate_content_hash
export -f save_phase_metadata
export -f check_phase_cache_valid
export -f load_phase_from_cache
export -f get_phase_output_hash
export -f build_dependency_hashes
export -f log_cache_event
