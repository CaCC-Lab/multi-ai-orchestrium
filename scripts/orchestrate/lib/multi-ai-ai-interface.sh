#!/usr/bin/env bash
# Multi-AI AI Interface Library
# Purpose: AI tool invocation and availability checking
# Responsibilities:
#   - AI availability checking with installation hints (check_ai_with_details, check_ai_available)
#   - Unified AI call wrapper with timeout and sanitization (call_ai)
#   - Fallback mechanism for AI failures (call_ai_with_fallback)
#   - Multi-AI tools availability check (check-multi-ai-tools)
#
# Security Notice: When fallback mechanism is enabled, sensitive context data
# may be sent to alternative AI providers. Ensure all configured fallback AIs
# meet your security and data handling requirements before enabling with sensitive data.
#
# Dependencies:
#   - lib/7ai-core.sh (logging functions)
#   - scripts/lib/sanitize.sh (sanitize_prompt function)

set -euo pipefail

# ============================================================================
# Configuration Loading
# Purpose: Load AI profiles and settings from configuration file
# ============================================================================

# Function to load fallback map from YAML configuration
# This approach externalizes configuration from code as recommended
# Uses simple text processing to avoid dependency on external YAML parsers
# SECURITY NOTICE: Fallback mechanism sends context to alternative AI providers.
# Review all fallback mappings to ensure data handling compliance.
load_fallback_map_from_config() {
    local config_file="${PROJECT_ROOT:-.}/config/multi-ai-profiles.yaml"

    if [[ -f "$config_file" ]]; then
        # Parse the YAML file to extract fallback mappings
        # Using sed and grep to extract key-value pairs from YAML
        # This approach works with basic YAML structure and avoids external dependencies
        local fallback_entries
        fallback_entries=$(sed -n '/^ai_fallbacks:/,$p' "$config_file" | \
                         sed '/^ai_settings:/,$d' | \
                         grep -E "^[[:space:]]*[a-z]+:" | \
                         grep -v "ai_fallbacks:" | \
                         sed 's/^[[:space:]]*\([^:]*\): "\([^\"]*\)".*/\1 \2/')

        # Create temporary file to store bash associative array declaration
        local temp_file
        temp_file=$(mktemp)
        echo "declare -gA AI_FALLBACK_MAP=(" > "$temp_file"

        while IFS= read -r line; do
            if [[ -n "$line" && "$line" != *"#"* ]]; then
                local ai_name fallback_ai
                read -r ai_name fallback_ai <<< "$line"
                if [[ -n "$ai_name" && -n "$fallback_ai" ]]; then
                    echo "    [\"$ai_name\"]=\"$fallback_ai\"" >> "$temp_file"
                fi
            fi
        done <<< "$fallback_entries"

        echo ")" >> "$temp_file"

        # Source the temporary file to create the associative array
        source "$temp_file"
        rm -f "$temp_file"

        log_info "Loaded AI fallback mappings from config: $config_file"
    else
        log_warning "Configuration file not found: $config_file, using default fallbacks"

        # Fallback mapping: primary_ai -> fallback_ai
        # Logic: Similar capability, different provider for redundancy
        # SECURITY WARNING: These mappings send sensitive data to alternative providers.
        # Review your data handling policies for each AI before enabling fallbacks.
        declare -gA AI_FALLBACK_MAP=(
            ["codex"]="claude"      # Codex -> Claude (both strong at code review, OpenAI->Anthropic redundancy)
            ["qwen"]="droid"        # Qwen -> Droid (both for implementation, Alibaba->Google redundancy)
            ["droid"]="qwen"        # Droid -> Qwen (reverse fallback, Google->Alibaba redundancy)
            ["cursor"]="claude"     # Cursor -> Claude (IDE integration fallback, Cursor->Anthropic redundancy)
            ["gemini"]="claude"     # Gemini -> Claude (research/security fallback, Google->Anthropic redundancy)
            ["amp"]="gemini"        # Amp -> Gemini (PM/docs fallback, Anthropic->Google redundancy)
            ["claude"]="gemini"     # Claude -> Gemini (strategic fallback, Anthropic->Google redundancy)
        )
    fi
}

# Load fallback mappings from configuration
load_fallback_map_from_config

# Get all fallback AIs for a given primary AI as a space-separated list
# Returns empty string if no fallback defined
get_fallback_ais() {
    local primary_ai="$1"
    echo "${AI_FALLBACK_MAP[$primary_ai]:-}"
}

# Get the first fallback AI for a given primary AI
# Returns empty string if no fallback defined
get_fallback_ai() {
    local primary_ai="$1"
    local fallback_ais
    fallback_ais=$(get_fallback_ais "$primary_ai")

    # Extract first fallback AI from the space-separated list
    if [[ -n "$fallback_ais" ]]; then
        echo "$fallback_ais" | awk '{print $1}'
    else
        echo ""
    fi
}

# Load configuration settings from the same config file
load_config_settings() {
    local config_file="${PROJECT_ROOT:-.}/config/multi-ai-profiles.yaml"

    if [[ -f "$config_file" ]]; then
        # Extract the enable_fallback setting from the config
        local fallback_setting
        fallback_setting=$(sed -n '/^ai_settings:/,/^[^[:space:]]/p' "$config_file" | \
                         sed '$d' | \
                         grep -E "^[[:space:]]*enable_fallback:" | \
                         sed 's/^[[:space:]]*enable_fallback:[[:space:]]*\([^#]*\).*/\1/' | \
                         tr -d "\"'" | \
                         sed 's/[[:space:]]*$//')

        if [[ -n "$fallback_setting" ]]; then
            ENABLE_AI_FALLBACK="$fallback_setting"
        else
            ENABLE_AI_FALLBACK="${ENABLE_AI_FALLBACK:-true}"
        fi
    else
        ENABLE_AI_FALLBACK="${ENABLE_AI_FALLBACK:-true}"
    fi
}

# Load configuration settings
load_config_settings

# Enable/disable auto-fallback
export ENABLE_AI_FALLBACK

# Source workflow optimizer modules if feature flags are enabled
if [[ "${ENABLE_FAILURE_RETRY:-false}" == "true" ]] || [[ "${ENABLE_PARALLELISM_ETA:-false}" == "true" ]] || [[ "${ENABLE_CONFIG_OPTIMIZER:-false}" == "true" ]]; then
    # Source failure-retry.sh for failure retry policy
    if [[ -f "$(dirname "${BASH_SOURCE[0]}")/workflow-optimizer/failure-retry.sh" ]]; then
        source "$(dirname "${BASH_SOURCE[0]}")/workflow-optimizer/failure-retry.sh"
    fi
fi

# ============================================================================
# Phase 4: API Rate Limiting (2025-11-08)
# ============================================================================

# API rate limit configuration
# Conservative limit: 80% of typical API rate limits (GitHub: 5000/hour)
API_RATE_LIMIT="${API_RATE_LIMIT:-4000}"
API_CALL_LOG_DIR="${PROJECT_ROOT:-.}/.cache"
API_CALL_LOG="${API_CALL_LOG_DIR}/api-calls-$(date +%Y%m%d).log"

# Initialize API call log directory
# Security: Creates directory with 700 permissions (owner-only access)
init_api_call_log() {
    # Create directory with secure permissions (700 = rwx------)
    mkdir -p -m 700 "$API_CALL_LOG_DIR" 2>/dev/null || {
        log_warning "Failed to create API call log directory: $API_CALL_LOG_DIR"
        return 1
    }

    # Fix permissions on existing directory if it was created without secure permissions
    # This ensures backward compatibility for directories created before this security enhancement
    chmod 700 "$API_CALL_LOG_DIR" 2>/dev/null || {
        log_warning "Failed to set secure permissions (700) on: $API_CALL_LOG_DIR"
    }

    return 0
}

# Check if API rate limit is approaching or exceeded
# Returns:
#   0 - Rate limit OK (under threshold)
#   1 - Rate limit approaching/exceeded (trigger backoff)
check_api_rate_limit() {
    local current_hour
    current_hour=$(date +%Y%m%d-%H)

    # Ensure log file exists
    touch "$API_CALL_LOG" 2>/dev/null || return 0

    # Count API calls in current hour
    local calls_this_hour
    calls_this_hour=$(grep -c "^$current_hour" "$API_CALL_LOG" 2>/dev/null || echo 0)
    # Remove any newlines or whitespace
    calls_this_hour=$(echo "$calls_this_hour" | tr -d '\n\r ')

    # Check if approaching limit (>= 80% of limit)
    if [ "${calls_this_hour:-0}" -ge "$API_RATE_LIMIT" ]; then
        log_warning "API rate limit approaching ($calls_this_hour/$API_RATE_LIMIT calls this hour)"
        return 1  # Trigger backoff
    fi

    log_debug "API rate limit OK: $calls_this_hour/$API_RATE_LIMIT calls this hour"
    return 0
}

# Log API call with timestamp
# Arguments:
#   $1 - AI name
#   $2 - Operation description (optional)
log_api_call() {
    local ai="$1"
    local operation="${2:-API call}"
    local timestamp
    timestamp=$(date +%Y%m%d-%H:%M:%S)

    # Initialize log directory if needed
    init_api_call_log

    # Log call
    echo "$timestamp $ai $operation" >> "$API_CALL_LOG" 2>/dev/null || {
        log_warning "Failed to log API call to: $API_CALL_LOG"
    }
}

# ============================================================================
# AI Availability Functions (2 functions)
# ============================================================================

# Check AI availability (simple check)
check_ai_available() {
    local ai=$1
    case $ai in
        gemini)
            command -v gemini >/dev/null 2>&1
            ;;
        qwen)
            command -v qwen >/dev/null 2>&1
            ;;
        codex)
            command -v codex >/dev/null 2>&1
            ;;
        cursor)
            command -v cursor-agent >/dev/null 2>&1
            ;;
        amp)
            command -v amp >/dev/null 2>&1
            ;;
        droid)
            command -v droid >/dev/null 2>&1
            ;;
        claude)
            # Claude is integrated in this CLI
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Check AI availability with installation details
check_ai_with_details() {
    local ai=$1

    if ! check_ai_available "$ai"; then
        log_error "AI tool '$ai' not found"
        log_info "Installation: "
        case $ai in
            gemini) echo "  pip install google-generativeai-cli" ;;
            qwen) echo "  pip install qwen-cli" ;;
            codex) echo "  npm install -g @openai/codex-cli" ;;
            cursor) echo "  npm install -g cursor-agent" ;;
            amp) echo "  npm install -g @anthropic/amp-cli" ;;
            droid) echo "  pip install droid-cli" ;;
            claude) echo "  # Claude is integrated in this CLI" ;;
        esac
        return 1
    fi
    return 0
}

# Check all Multi-AI tools
check-multi-ai-tools() {
    log_info "Checking Multi-AI Tool Availability..."
    echo ""

    local all_available=true

    for ai in $ALL_AIS; do
        echo -n "  $ai: "
        if check_ai_available "$ai"; then
            echo -e "${GREEN}✓ Available${NC}"
        else
            echo -e "${RED}✗ Not found${NC}"
            all_available=false
        fi
    done

    echo ""
    if $all_available; then
        log_success "All 7 AI tools are available!"
        return 0
    else
        log_warning "Some AI tools are missing. Install them for full Multi-AI functionality."
        return 1
    fi
}

# ============================================================================
# AI Invocation Functions (2 functions)
# ============================================================================

# Unified AI call wrapper (backward compatibility layer)
# Phase 1.3 Update: Now uses call_ai_with_context() internally
# Phase 4 Update: Added API rate limiting with exponential backoff
# This function maintains backward compatibility with existing code
call_ai() {
    local ai=$1
    local prompt=$2
    local timeout=${3:-300}
    local output_file=${4:-}

    # Availability check
    check_ai_with_details "$ai" || return 1

    # Phase 4: API rate limit check with exponential backoff
    local retry_count=0
    local max_retries=3
    while ! check_api_rate_limit; do
        retry_count=$((retry_count + 1))

        if [ $retry_count -gt $max_retries ]; then
            log_error "API rate limit exceeded, maximum retries ($max_retries) reached"
            return 1
        fi

        # Exponential backoff: 5min, 10min, 15min
        local wait_time=$((300 * retry_count))
        log_info "API rate limit approaching. Waiting ${wait_time}s for cooldown (retry $retry_count/$max_retries)"
        sleep "$wait_time"
    done

    # Log API call
    log_api_call "$ai" "call_ai"

    # Delegate to new context-aware function
    # This automatically handles:
    # - Size-based routing (command-line vs file-based)
    # - Secure temporary file creation
    # - Automatic cleanup
    # - Fallback mechanisms
    # Note: The 5th parameter (is_fallback_call) defaults to false for primary calls
    call_ai_with_context "$ai" "$prompt" "$timeout" "$output_file"
}

# AI failure fallback mechanism
call_ai_with_fallback() {
    local primary_ai=$1
    local fallback_ai=$2
    local prompt=$3
    local timeout=$4
    local output_file=$5

    if call_ai "$primary_ai" "$prompt" "$timeout" "$output_file"; then
        return 0
    fi

    log_warning "[$primary_ai] failed, falling back to [$fallback_ai]"
    call_ai "$fallback_ai" "$prompt" "$timeout" "$output_file"
}

# ============================================================================
# File-Based Prompt System (Phase 1.1 - Core Functions)
# Purpose: Handle large prompts (>1KB) via secure temporary files
# Added: 2025-10-23 - File-Based Prompt System Implementation
# ============================================================================

# Check if AI tool supports file-based input
#
# Arguments:
#   $1 - AI name (claude, gemini, qwen, codex, cursor, amp, droid)
#
# Returns:
#   0 - Supports file input (--file or --input flag)
#   1 - Does not support, fallback to stdin redirect
#
# Usage:
#   if supports_file_input "claude"; then
#       claude-mcp --file "$prompt_file"
#   else
#       claude-mcp < "$prompt_file"
#   fi
#
supports_file_input() {
    local ai_name="$1"

    case "$ai_name" in
        claude|codex|gemini|droid|qwen|cursor|amp)
            # Phase 1.3: All wrappers use stdin redirect (<file) for now
            # Future: Add --prompt-file flag support in Phase 3
            # Returning 1 means "use stdin redirect" (the fallback path)
            return 1
            ;;
        *)
            log_warning "Unknown AI: $ai_name, assuming stdin support"
            return 1
            ;;
    esac
}

# Create secure temporary file for prompt
#
# Arguments:
#   $1 - AI name (for debugging/logging)
#   $2 - Prompt content
#
# Returns:
#   stdout - Path to created file
#   exit 0 on success, 1 on failure
#
# Security:
#   - chmod 600 (owner read/write only)
#   - mktemp for unique filename
#   - AI name in filename for debugging
#
# Usage:
#   prompt_file=$(create_secure_prompt_file "claude" "$large_prompt")
#
create_secure_prompt_file() {
    local ai_name="$1"
    local content="$2"

    # Create temporary file with AI name for debugging
    local prompt_file
    prompt_file=$(mktemp "${TMPDIR:-/tmp}/prompt-${ai_name}-XXXXXX") || {
        log_error "Failed to create temporary file for $ai_name"
        return 1
    }

    # Set secure permissions (owner read/write only)
    chmod 600 "$prompt_file" || {
        log_error "Failed to set permissions on $prompt_file"
        rm -f "$prompt_file"
        return 1
    }

    # Write content to file
    echo "$content" > "$prompt_file" || {
        log_error "Failed to write content to $prompt_file"
        rm -f "$prompt_file"
        return 1
    }

    # Output file path for caller
    echo "$prompt_file"
    return 0
}

# Clean up temporary prompt file
#
# Arguments:
#   $1 - Path to file to delete
#
# Returns:
#   0 on success, 1 on failure (non-critical)
#
# Usage:
#   cleanup_prompt_file "$prompt_file"
#
cleanup_prompt_file() {
    local prompt_file="$1"

    if [ -z "$prompt_file" ]; then
        return 0
    fi

    if [ -f "$prompt_file" ]; then
        rm -f "$prompt_file" 2>/dev/null || {
            log_warning "Failed to delete temporary file: $prompt_file"
            return 1
        }
    fi

    return 0
}

# Helper function to handle AI caching
handle_cache() {
    local ai_name="$1"
    local context="$2"
    local output_file="$3"
    local cache_key=""

    # Phase 3: AI Result Caching
    # Only use cache if output_file is specified
    if [ -n "$output_file" ] && [ "${AI_CACHE_ENABLED:-1}" = "1" ]; then
        cache_key=$(get_cache_key "$ai_name" "$context" 2>/dev/null)

        if [ -n "$cache_key" ] && check_cache "$cache_key"; then
            # Cache hit - load from cache
            if load_from_cache "$cache_key" "$output_file"; then
                log_info "[$ai_name] Using cached result (key: ${cache_key:0:16}...)"
                return 0
            fi
        fi
    fi

    echo "$cache_key"
    return 1
}

# Helper function to process large prompts
process_large_prompt() {
    local ai_name="$1"
    local context="$2"
    local timeout_seconds="$3"
    local output_file="$4"
    local cache_key="$5"

    local size_threshold=1024
    local context_size=${#context}

    log_info "[$ai_name] Large prompt detected (${context_size}B > ${size_threshold}B), using file-based input"

    # Create secure temporary file
    local prompt_file
    if ! prompt_file=$(create_secure_prompt_file "$ai_name" "$context"); then
        log_structured_error \
            "[$ai_name] Failed to create temporary file for large prompt" \
            "Disk space, permissions, or /tmp not writable" \
            "Check: df -h /tmp && ls -ld /tmp. Falling back to truncated (${size_threshold}B) prompt"
        # Fallback: Truncate and use command-line
        local truncated="${context:0:$size_threshold}"
        call_ai "$ai_name" "$truncated" "$timeout_seconds" "$output_file"
        return $?
    fi

    # Set up automatic cleanup
    # shellcheck disable=SC2064
    trap "cleanup_prompt_file '$prompt_file'" EXIT INT TERM

    # Determine input method based on AI support
    local wrapper_script="$PROJECT_ROOT/bin/${ai_name}-wrapper.sh"
    local exit_code=0

    if [ -f "$wrapper_script" ]; then
        log_info "[$ai_name] Using wrapper with file input"

        ( # Start a subshell to scope the environment variable
            export WRAPPER_NON_INTERACTIVE="${WRAPPER_NON_INTERACTIVE:-1}"

            if supports_file_input "$ai_name"; then
                # Use --prompt-file if supported
                if [ -n "$output_file" ]; then
                    timeout "$timeout_seconds" "$wrapper_script" --prompt-file "$prompt_file" > "$output_file" 2>&1
                else
                    timeout "$timeout_seconds" "$wrapper_script" --prompt-file "$prompt_file" 2>&1
                fi
            else
                # Fallback to stdin redirect with --stdin flag for explicit handling
                # Set WRAPPER_SKIP_TIMEOUT=1 to let outer timeout manage execution
                if [ -n "$output_file" ]; then
                    WRAPPER_SKIP_TIMEOUT=1 timeout "$timeout_seconds" "$wrapper_script" --stdin < "$prompt_file" > "$output_file" 2>&1
                else
                    WRAPPER_SKIP_TIMEOUT=1 timeout "$timeout_seconds" "$wrapper_script" --stdin < "$prompt_file" 2>&1
                fi
            fi
        )
        exit_code=$? # Capture the exit code from the subshell
    else
        log_warning "[$ai_name] Wrapper not found, using direct CLI with stdin"
        if [ -n "$output_file" ]; then
            timeout "$timeout_seconds" "$ai_name" < "$prompt_file" > "$output_file" 2>&1
            exit_code=$?
        else
            timeout "$timeout_seconds" "$ai_name" < "$prompt_file" 2>&1
            exit_code=$?
        fi
    fi

    # Clean up temporary file
    cleanup_prompt_file "$prompt_file"
    trap - EXIT INT TERM

    # Log routing decision for metrics
    if [ -n "${VIBE_LOGGER_ENABLED:-}" ]; then
            # VibeLogger integration (if available)
            log_info "[$ai_name] File-based routing: size=${context_size}B, exit_code=$exit_code"
    fi

    # Phase 3: Save to cache on success
    if [ $exit_code -eq 0 ] && [ -n "$output_file" ] && [ -n "$cache_key" ] && [ "${AI_CACHE_ENABLED:-1}" = "1" ]; then
        save_to_cache "$cache_key" "$output_file" 2>/dev/null || log_warning "[$ai_name] Failed to save cache"
    fi

    return $exit_code
}

# Helper function to process small prompts
process_small_prompt() {
    local ai_name="$1"
    local context="$2"
    local timeout_seconds="$3"
    local output_file="$4"
    local cache_key="$5"

    local context_size=${#context}

    # Small prompt: Use command-line arguments (direct wrapper call)
    log_info "[$ai_name] Small prompt (${context_size}B), using command-line arguments"

    # Check AI availability first
    check_ai_with_details "$ai_name" || return 1

    # Call wrapper directly to avoid circular dependency
    local wrapper_script="$PROJECT_ROOT/bin/${ai_name}-wrapper.sh"
    local exit_code=0

    if [ -f "$wrapper_script" ]; then
        # Set WRAPPER_SKIP_TIMEOUT=1 to let outer timeout manage execution
        # IMPORTANT: Export context to ensure it's available in subshell
        ( # Start a subshell to scope the environment variable
            export WRAPPER_NON_INTERACTIVE="${WRAPPER_NON_INTERACTIVE:-1}"
            export CONTEXT_VALUE="$context"

            # Debug: Verify context is available
            if [ -z "$CONTEXT_VALUE" ]; then
                echo "ERROR: Context is empty in subshell for $ai_name" >&2
                exit 1
            fi

            if [ -n "$output_file" ]; then
                WRAPPER_SKIP_TIMEOUT=1 timeout "$timeout_seconds" "$wrapper_script" --prompt "$context" > "$output_file" 2>&1
            else
                WRAPPER_SKIP_TIMEOUT=1 timeout "$timeout_seconds" "$wrapper_script" --prompt "$context" 2>&1
            fi
        )
        exit_code=$?
    else
        # Fallback to direct CLI
        log_warning "[$ai_name] Wrapper not found, using direct CLI"
        if [ -n "$output_file" ]; then
            timeout "$timeout_seconds" "$ai_name" --prompt "$context" > "$output_file" 2>&1
        else
            timeout "$timeout_seconds" "$ai_name" --prompt "$context" 2>&1
        fi
        exit_code=$?
    fi

    # Phase 3: Save to cache on success
    if [ $exit_code -eq 0 ] && [ -n "$output_file" ] && [ -n "$cache_key" ] && [ "${AI_CACHE_ENABLED:-1}" = "1" ]; then
        save_to_cache "$cache_key" "$output_file" 2>/dev/null || log_warning "[$ai_name] Failed to save cache"
    fi

    return $exit_code
}

# Validate timeout argument to prevent "invalid time interval" errors
# Ensure timeout is a positive integer
# FIXED: Return 0 (success) even on validation failure to allow graceful fallback
# This prevents "set -euo pipefail" from stopping the entire pipeline
validate_timeout() {
    local timeout_val="$1"
    local ai_name_val="$2"
    local default_timeout="${3:-300}"

    # Extract numeric value if input contains numbers (e.g., "60s" -> "60")
    local numeric_val=""
    if [[ "$timeout_val" =~ ^([0-9]+) ]]; then
        numeric_val="${BASH_REMATCH[1]}"
    fi

    # Validate: must be numeric and within valid range (1-3600 seconds)
    if [[ -n "$numeric_val" ]] && ((numeric_val >= 1 && numeric_val <= 3600)); then
        echo "$numeric_val"
        return 0
    fi

    # Validation failed: log warning and return default value (but return 0 to allow continuation)
    # This is NOT an error - it's a graceful fallback to a safe default
    if command -v log_error >/dev/null 2>&1; then
        log_error "[$ai_name_val] Invalid timeout value: '$timeout_val'. Using default: ${default_timeout}s"
    else
        echo "WARNING: [$ai_name_val] Invalid timeout value: '$timeout_val'. Using default: ${default_timeout}s" >&2
    fi
    echo "$default_timeout"
    return 0  # ✅ Return success to allow pipeline continuation
}

# Internal function for original implementation (extracted for retry policy)
call_ai_with_context_internal() {
    local ai_name="$1"
    local context="$2"
    local timeout_seconds="${3:-300}"
    local output_file="${4:-}"
    # Note: The 5th parameter (fallback_chain) is ignored in this function to prevent fallback recursion

    # FIXED: Validate timeout argument to prevent "invalid time interval" errors
    timeout_seconds=$(validate_timeout "$timeout_seconds" "$ai_name" 300)

    # Handle caching
    local cache_key
    if handle_cache "$ai_name" "$context" "$output_file"; then
        return 0
    else
        cache_key=$(handle_cache "$ai_name" "$context" "$output_file" 2>&1)
    fi

    # Size threshold: 1KB (1024 bytes)
    local size_threshold=1024
    local context_size=${#context}

    # Decision: Use file-based input for large prompts
    if [ "$context_size" -gt "$size_threshold" ]; then
        process_large_prompt "$ai_name" "$context" "$timeout_seconds" "$output_file" "$cache_key"
    else
        process_small_prompt "$ai_name" "$context" "$timeout_seconds" "$output_file" "$cache_key"
    fi
}

# Original call_ai_with_context implementation (extracted for backward compatibility when retry is disabled)
call_ai_with_context_original() {
    local ai_name="$1"
    local context="$2"
    local timeout_seconds="${3:-300}"
    local output_file="${4:-}"
    # Note: The 5th parameter (fallback_chain) is ignored in this function to prevent fallback recursion

    # FIXED: Validate timeout argument to prevent "invalid time interval" errors
    timeout_seconds=$(validate_timeout "$timeout_seconds" "$ai_name" 300)

    # Handle caching
    local cache_key
    if handle_cache "$ai_name" "$context" "$output_file"; then
        return 0
    else
        cache_key=$(handle_cache "$ai_name" "$context" "$output_file" 2>&1)
    fi

    # Size threshold: 1KB (1024 bytes)
    local size_threshold=1024
    local context_size=${#context}

    # Decision: Use file-based input for large prompts
    if [ "$context_size" -gt "$size_threshold" ]; then
        process_large_prompt "$ai_name" "$context" "$timeout_seconds" "$output_file" "$cache_key"
    else
        process_small_prompt "$ai_name" "$context" "$timeout_seconds" "$output_file" "$cache_key"
    fi
}

# Call AI with automatic context-aware routing
#
# This is the main function that automatically chooses between:
#   - Command-line arguments (for prompts < 1KB)
#   - File-based input (for prompts >= 1KB)
#
# Arguments:
#   $1 - AI name
#   $2 - Prompt/context
#   $3 - Timeout (optional, default: 300)
#   $4 - Output file (optional)
#   $5 - Fallback chain (optional, default: "", prevents circular fallbacks)
#
# Returns:
#   Exit code from AI execution
#
# Features:
#   - Automatic size detection (1KB threshold)
#   - Secure temporary file handling
#   - Automatic cleanup via trap
#   - Fallback to command-line on file creation failure
#   - VibeLogger integration for routing decisions
#   - Auto-fallback mechanism to improve reliability
#   - Enhanced recursion prevention with fallback chain tracking
#
# Usage:
#   call_ai_with_context "claude" "$large_prompt" 600 "/tmp/output.txt"
#
call_ai_with_context() {
    local ai_name="$1"
    local context="$2"
    local timeout="${3:-300}"
    local output_file="${4:-}"
    local fallback_chain="${5:-}"  # Track the chain of fallbacks to prevent circular loops
    local exit_code=0

    # Feature Flag check for failure retry
    if [[ "${ENABLE_FAILURE_RETRY:-false}" == "true" ]]; then
        # Use retry policy
        execute_with_retry_policy "$ai_name" call_ai_with_context_internal "$ai_name" "$context" "$timeout" "$output_file"
        exit_code=$?
    else
        # Original implementation without retry
        call_ai_with_context_original "$ai_name" "$context" "$timeout" "$output_file"
        exit_code=$?
    fi

    # Auto-fallback mechanism (2025-11-27)
    # If primary AI fails and fallback is enabled, try fallback AI(s)
    # Only attempt fallback if this AI hasn't been in the fallback chain already to prevent circular loops
    if [[ $exit_code -ne 0 ]] && [[ "${ENABLE_AI_FALLBACK:-true}" == "true" ]]; then
        local primary_exit_code="$exit_code"  # Store original exit code for logging
        local fallback_ais
        fallback_ais=$(get_fallback_ais "$ai_name")

        if [[ -n "$fallback_ais" ]]; then
            # Convert space-separated list to array
            local fallback_array=($fallback_ais)

            # Check if current AI is already in the fallback chain to prevent circular fallbacks
            if [[ " $fallback_chain " =~ " $ai_name " ]]; then
                log_warning "[$ai_name] Circular fallback detected (chain: $fallback_chain), skipping fallback"
                return $exit_code  # Don't try fallbacks if we've already tried this AI
            fi

            # Add current AI to the fallback chain for subsequent calls
            local updated_fallback_chain="$fallback_chain $ai_name"

            for fallback_ai in "${fallback_array[@]}"; do
                # Defensive check: prevent AI from falling back to itself
                if [[ "$fallback_ai" == "$ai_name" ]]; then
                    log_debug "[$ai_name] Skipping fallback to self, continuing to next fallback option"
                    continue
                fi

                # Defensive check: prevent AI from falling back to a previous AI in the chain
                if [[ " $fallback_chain " =~ " $fallback_ai " ]]; then
                    log_debug "[$ai_name] Skipping fallback to [$fallback_ai] (already in chain: $fallback_chain), continuing to next fallback option"
                    continue
                fi

                log_warning "[$ai_name] Failed (exit_code=$primary_exit_code), falling back to [$fallback_ai] (chain: $updated_fallback_chain)"

                # Call with fallback AI, passing the updated fallback chain to prevent circular fallbacks
                call_ai_with_context "$fallback_ai" "$context" "$timeout" "$output_file" "$updated_fallback_chain"
                exit_code=$?

                if [[ $exit_code -eq 0 ]]; then
                    log_info "[$fallback_ai] Fallback for [$ai_name] succeeded (original failure: $primary_exit_code, chain: $updated_fallback_chain)"
                    break  # Success, exit the fallback loop
                else
                    log_error "[$fallback_ai] Fallback for [$ai_name] failed (exit_code=$exit_code, original failure: $primary_exit_code, chain: $updated_fallback_chain)"
                    # Continue to next fallback in the chain
                fi
            done

            if [[ $exit_code -ne 0 ]]; then
                log_error "All fallback options exhausted for [$ai_name] (chain: $fallback_chain), all fallback AIs failed. Original failure: exit_code=$primary_exit_code"
            else
                log_info "Fallback mechanism successful: [$fallback_ai] completed work for [$ai_name] (original failure: $primary_exit_code, chain: $updated_fallback_chain)"
            fi
        fi
    fi

    return $exit_code
}

# Export functions for use in subshells (required for parallel execution)
export -f call_ai_with_context
export -f call_ai_with_context_original
export -f call_ai_with_context_internal
export -f call_ai
export -f create_secure_prompt_file
export -f cleanup_prompt_file
export -f supports_file_input
export -f validate_timeout
export -f handle_cache
export -f process_large_prompt
export -f process_small_prompt
