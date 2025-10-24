#!/usr/bin/env bash
# agents-utils.sh - Task classification utilities based on AGENTS.md
# Provides dynamic timeout and approval logic for AI wrapper scripts

# Task classification based on AGENTS.md specification
# Returns: "lightweight", "standard", or "critical"
classify_task() {
    local prompt="$1"

    # Critical task patterns (🔴) - require approval
    if echo "$prompt" | grep -qiE "(database.*schema|production|deploy|delete.*database|drop.*table|migration.*prod|security.*change|api.*key|credential|password|secret|architecture.*change|breaking.*change)"; then
        echo "critical"
        return
    fi

    # Lightweight task patterns (🟢) - fast execution
    # Using word boundaries to avoid false matches like "thread" containing "read"
    if echo "$prompt" | grep -qiE "\b(read|check|status|list|show|explain|view|get|fetch|display|info|help|describe|search|find)\b"; then
        echo "lightweight"
        return
    fi

    # Additional lightweight patterns: simple fixes and single file operations
    if echo "$prompt" | grep -qiE "(simple[ _]fix|1[ _]file|single[ _]file|one[ _]file)"; then
        echo "lightweight"
        return
    fi

    # Standard task patterns (🟡) - normal execution (default)
    echo "standard"
}

# Convert timeout string to integer seconds
# Args: timeout value (e.g., "120", "120s", "2m", "1h")
# Returns: integer seconds
to_seconds() {
    local v="${1:-}"
    # Trim spaces
    v="${v//[[:space:]]/}"
    # Empty -> default 0
    [[ -z "$v" ]] && { echo 0; return 0; }
    # Pure number
    if [[ "$v" =~ ^[0-9]+$ ]]; then echo "$v"; return 0; fi
    # Ns, Nm, Nh
    if [[ "$v" =~ ^([0-9]+)([smh])$ ]]; then
        local n="${BASH_REMATCH[1]}"; local u="${BASH_REMATCH[2]}"
        case "$u" in
            s) echo "$n" ;;
            m) echo $((n * 60)) ;;
            h) echo $((n * 3600)) ;;
        esac
        return 0
    fi
    # Fallback: strip trailing 's' if present
    if [[ "$v" =~ ^([0-9]+)s$ ]]; then echo "${BASH_REMATCH[1]}"; return 0; fi
    # Last resort: return as-is (may fail fast and be obvious)
    echo "$v"
}

# Get timeout multiplier based on task classification
# Args: classification, base_timeout (in seconds)
# Returns: timeout string (e.g., "90s", "180s", "540s")
get_task_timeout() {
    local classification="$1"
    local base_timeout="${2:-180}"  # Default 180s if not specified

    case "$classification" in
        lightweight)
            # Lightweight: 0.5x base timeout
            echo "$((base_timeout / 2))s"
            ;;
        standard)
            # Standard: 1.0x base timeout
            echo "${base_timeout}s"
            ;;
        critical)
            # Critical: 3.0x base timeout
            echo "$((base_timeout * 3))s"
            ;;
        *)
            # Unknown: use base timeout
            echo "${base_timeout}s"
            ;;
    esac
}

# Get process label for task classification
# Args: classification
# Returns: process label string
get_process_label() {
    local classification="$1"

    case "$classification" in
        lightweight)
            echo "🟢 Light Process"
            ;;
        standard)
            echo "🟡 Standard Process"
            ;;
        critical)
            echo "🔴 Critical Process"
            ;;
        *)
            echo "❓ Unknown Process"
            ;;
    esac
}

# Check if task requires manual approval
# Args: classification
# Returns: 0 (true) if approval required, 1 (false) otherwise
requires_approval() {
    local classification="$1"

    if [[ "$classification" == "critical" ]]; then
        return 0  # Requires approval
    else
        return 1  # No approval needed
    fi
}

# Get AGENTS.md path using PROJECT_ROOT or current directory
# Returns: path to AGENTS.md or error
get_agents_path() {
    local agents_path="${PROJECT_ROOT:-$(pwd)}/AGENTS.md"
    if [[ ! -f "$agents_path" ]]; then
        echo "ERROR: AGENTS.md not found at $agents_path" >&2
        return 1
    fi
    echo "$agents_path"
}

# Validate AGENTS.md is readable
# Returns: 0 if readable, 1 if not
validate_agents_md() {
    local agents_path="${PROJECT_ROOT:-$(pwd)}/AGENTS.md"
    if [[ ! -r "$agents_path" ]]; then
        echo "ERROR: AGENTS.md not readable at $agents_path" >&2
        return 1
    fi
    return 0
}

# Get quality level based on task classification
# Args: classification
# Returns: quality level string
get_quality_level() {
    local classification="$1"

    case "$classification" in
        light|lightweight)
            echo "medium"
            ;;
        standard)
            echo "high"
            ;;
        critical)
            echo "high"
            ;;
        *)
            echo "high"
            ;;
    esac
}

# Find AGENTS.md by searching up the directory tree
# Returns: path to AGENTS.md or empty if not found
find_agents_md() {
    local current_dir="${1:-$(pwd)}"
    local max_depth=10
    local depth=0

    # Check environment variable first
    if [[ -n "${AGENTS_MD:-}" ]] && [[ -f "${AGENTS_MD}" ]]; then
        echo "${AGENTS_MD}"
        return 0
    fi

    # Search up the directory tree
    while [[ "$depth" -lt "$max_depth" ]]; do
        if [[ -f "$current_dir/AGENTS.md" ]]; then
            echo "$current_dir/AGENTS.md"
            return 0
        fi

        # Stop at root
        if [[ "$current_dir" == "/" ]]; then
            break
        fi

        current_dir="$(dirname "$current_dir")"
        ((depth++))
    done

    # Not found
    return 1
}

# Export functions for sourcing
export -f classify_task
export -f to_seconds
export -f get_task_timeout
export -f get_process_label
export -f requires_approval
export -f get_agents_path
export -f validate_agents_md
export -f get_quality_level
export -f find_agents_md

# Self-test when run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== agents-utils.sh Self-Test ==="
    echo

    # Test path resolution
    echo "1. Path Resolution Test:"
    if agents_path=$(get_agents_path); then
        echo "   ✅ Found AGENTS.md at: $agents_path"
    else
        echo "   ❌ AGENTS.md not found"
    fi
    echo

    # Test task classification
    echo "2. Task Classification Test:"
    test_prompts=(
        "read the file"
        "check status"
        "delete database schema"
        "implement new feature"
        "production deployment"
        "simple fix for bug"
    )

    for prompt in "${test_prompts[@]}"; do
        classification=$(classify_task "$prompt")
        label=$(get_process_label "$classification")
        echo "   \"$prompt\" → $classification ($label)"
    done
    echo

    # Test timeout calculation
    echo "3. Timeout Calculation Test (base: 60s):"
    for class in lightweight standard critical; do
        timeout=$(get_task_timeout "$class" 60)
        echo "   $class → $timeout"
    done
    echo

    # Test quality level
    echo "4. Quality Level Test:"
    for class in lightweight standard critical; do
        quality=$(get_quality_level "$class")
        echo "   $class → $quality"
    done
    echo

    # Test approval requirement
    echo "5. Approval Requirement Test:"
    for class in lightweight standard critical; do
        if requires_approval "$class"; then
            echo "   $class → Approval Required"
        else
            echo "   $class → No Approval"
        fi
    done
    echo

    echo "=== Self-Test Complete ==="
fi
