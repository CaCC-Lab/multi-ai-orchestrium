#!/usr/bin/env bash
# Multi-AI AI Interface Library
# Purpose: AI tool invocation and availability checking
# Responsibilities:
#   - AI availability checking with installation hints (check_ai_with_details, check_ai_available)
#   - Unified AI call wrapper with timeout and sanitization (call_ai)
#   - Fallback mechanism for AI failures (call_ai_with_fallback)
#   - Multi-AI tools availability check (check-multi-ai-tools)
#
# Dependencies:
#   - lib/7ai-core.sh (logging functions)
#   - scripts/lib/sanitize.sh (sanitize_prompt function)

set -euo pipefail

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
# This function maintains backward compatibility with existing code
call_ai() {
    local ai=$1
    local prompt=$2
    local timeout=${3:-300}
    local output_file=${4:-}

    # Availability check
    check_ai_with_details "$ai" || return 1

    # Delegate to new context-aware function
    # This automatically handles:
    # - Size-based routing (command-line vs file-based)
    # - Secure temporary file creation
    # - Automatic cleanup
    # - Fallback mechanisms
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
#
# Usage:
#   call_ai_with_context "claude" "$large_prompt" 600 "/tmp/output.txt"
#
call_ai_with_context() {
    local ai_name="$1"
    local context="$2"
    local timeout="${3:-300}"
    local output_file="${4:-}"
    local context_size=${#context}
    local exit_code=0

    # Size threshold: 1KB (1024 bytes)
    local size_threshold=1024

    # Decision: Use file-based input for large prompts
    if [ "$context_size" -gt "$size_threshold" ]; then
        log_info "[$ai_name] Large prompt detected (${context_size}B > ${size_threshold}B), using file-based input"

        # Create secure temporary file
        local prompt_file
        if ! prompt_file=$(create_secure_prompt_file "$ai_name" "$context"); then
            log_error "[$ai_name] File creation failed, falling back to truncated command-line"
            # Fallback: Truncate and use command-line
            local truncated="${context:0:$size_threshold}"
            call_ai "$ai_name" "$truncated" "$timeout" "$output_file"
            return $?
        fi

        # Set up automatic cleanup
        # shellcheck disable=SC2064
        trap "cleanup_prompt_file '$prompt_file'" EXIT INT TERM

        # Determine input method based on AI support
        local wrapper_script="$PROJECT_ROOT/bin/${ai_name}-wrapper.sh"

        if [ -f "$wrapper_script" ]; then
            log_info "[$ai_name] Using wrapper with file input"

            if supports_file_input "$ai_name"; then
                # Use --prompt-file if supported
                timeout "$timeout" "$wrapper_script" --prompt-file "$prompt_file" ${output_file:+> "$output_file"} 2>&1
                exit_code=$?
            else
                # Fallback to stdin redirect with --stdin flag for explicit handling
                timeout "$timeout" "$wrapper_script" --stdin ${output_file:+> "$output_file"} < "$prompt_file" 2>&1
                exit_code=$?
            fi
        else
            log_warning "[$ai_name] Wrapper not found, using direct CLI with stdin"
            timeout "$timeout" "$ai_name" ${output_file:+> "$output_file"} < "$prompt_file" 2>&1
            exit_code=$?
        fi

        # Clean up temporary file
        cleanup_prompt_file "$prompt_file"
        trap - EXIT INT TERM

        # Log routing decision for metrics
        if [ -n "${VIBE_LOGGER_ENABLED:-}" ]; then
            # VibeLogger integration (if available)
            log_info "[$ai_name] File-based routing: size=${context_size}B, exit_code=$exit_code"
        fi

        return $exit_code
    else
        # Small prompt: Use command-line arguments (direct wrapper call)
        log_info "[$ai_name] Small prompt (${context_size}B), using command-line arguments"

        # Check AI availability first
        check_ai_with_details "$ai_name" || return 1

        # Call wrapper directly to avoid circular dependency
        local wrapper_script="$PROJECT_ROOT/bin/${ai_name}-wrapper.sh"

        if [ -f "$wrapper_script" ]; then
            timeout "$timeout" "$wrapper_script" --prompt "$context" ${output_file:+> "$output_file"} 2>&1
            return $?
        else
            # Fallback to direct CLI
            log_warning "[$ai_name] Wrapper not found, using direct CLI"
            timeout "$timeout" "$ai_name" --prompt "$context" ${output_file:+> "$output_file"} 2>&1
            return $?
        fi
    fi
}
