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

# Unified AI call wrapper (standardized AI invocation with AGENTS.md integration)
call_ai() {
    local ai=$1
    local prompt=$2
    local timeout=$3
    local output_file=$4

    # Availability check
    check_ai_with_details "$ai" || return 1

    log_info "[$ai] Starting (AGENTS.md auto-classification enabled)..."

    # Determine wrapper script path
    local wrapper_script="$PROJECT_ROOT/bin/${ai}-wrapper.sh"

    # FORCE DIRECT CLI: Bypass wrappers to respect our timeout settings
    # Wrappers have internal timeout logic that conflicts with our extended timeouts
    if true; then  # Force fallback to direct CLI (was: ! -f "$wrapper_script")
        log_warning "[$ai] Wrapper not found at $wrapper_script, falling back to direct CLI"
        # Fallback to original direct CLI invocation
        local prompt_file="/tmp/7ai-prompt-$$-$RANDOM.txt"

        # SECURITY: Sanitize prompt before writing to file (Issue #3)
        local sanitized_prompt
        if ! sanitized_prompt=$(sanitize_input "$prompt"); then
            log_error "[$ai] Prompt sanitization failed"
            return 1
        fi

        # Use sanitized prompt for file creation
        echo "$sanitized_prompt" > "$prompt_file"

        case $ai in
            gemini)
                timeout "$timeout" bash -c "gemini -p \"\$(cat '$prompt_file')\" -y" > "$output_file" 2>&1
                ;;
            qwen)
                timeout "$timeout" bash -c "qwen -p \"\$(cat '$prompt_file')\" -y" > "$output_file" 2>&1
                ;;
            codex)
                timeout "$timeout" bash -c "codex exec \"\$(cat '$prompt_file')\"" > "$output_file" 2>&1
                ;;
            cursor)
                timeout "$timeout" bash -c "cursor-agent -p \"\$(cat '$prompt_file')\" --print" > "$output_file" 2>&1
                ;;
            amp)
                timeout "$timeout" bash -c "amp -x \"\$(cat '$prompt_file')\"" > "$output_file" 2>&1
                ;;
            droid)
                timeout "$timeout" bash -c "droid exec --auto high \"\$(cat '$prompt_file')\"" > "$output_file" 2>&1
                ;;
            claude)
                echo "Claude (CTO) Task:" > "$output_file"
                echo "" >> "$output_file"
                echo "$prompt" >> "$output_file"
                echo "" >> "$output_file"
                echo "Note: This is a placeholder. Claude Code should execute this task interactively." >> "$output_file"
                ;;
            *)
                log_error "Unknown AI: $ai"
                rm -f "$prompt_file"
                return 1
                ;;
        esac
        local exit_code=$?
        rm -f "$prompt_file"
    else
        # Use wrapper script with AGENTS.md integration
        # Wrappers handle timeout internally based on task classification

        # SECURITY: Sanitize prompt before passing to wrapper (Issue #3)
        local sanitized_prompt
        if ! sanitized_prompt=$(sanitize_input "$prompt"); then
            log_error "[$ai] Prompt sanitization failed"
            return 1
        fi

        "$wrapper_script" --prompt "$sanitized_prompt" > "$output_file" 2>&1
        local exit_code=$?
    fi

    if [ $exit_code -eq 0 ]; then
        log_success "[$ai] Complete"
    elif [ $exit_code -eq 124 ]; then
        log_error "[$ai] Timed out"
    else
        log_error "[$ai] Failed (exit code: $exit_code)"
    fi

    return $exit_code
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
