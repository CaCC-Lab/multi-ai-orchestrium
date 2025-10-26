#!/bin/bash
# adapter-claude-security.sh - Claude Security Review Adapter
# Version: 1.0
# Inherits from adapter-base.sh for security-focused code review

# Source the base adapter
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/adapter-base.sh"

# AI-specific prompt extension for security review
extend_prompt_for_claude-security() {
    local base_prompt="$1"
    local file_context="$2"

    # Add security-specific prompt enhancements
    cat <<EOF
$base_prompt

**SECURITY REVIEW FOCUS**:
- OWASP Top 10 vulnerabilities (SQL Injection, XSS, Command Injection, etc.)
- CWE-based security patterns
- Authentication and authorization issues
- Cryptographic weaknesses (CWE-327)
- Hardcoded secrets (CWE-798)
- Path traversal (CWE-22)
- CVSS v3.1 scoring for identified vulnerabilities

**Output Requirements**:
- SARIF format support for IDE integration
- Severity classification: Critical, High, Medium, Low
- CWE mappings for all findings
- Remediation guidance

Context: $file_context
EOF
}

# Override call_ai_wrapper to use claude-security-review.sh
call_ai_wrapper_claude-security() {
    local ai_name="$1"
    local prompt="$2"
    local timeout="$3"

    # Path to the existing Claude security review script
    local security_script="./scripts/claude-security-review.sh"

    if [[ ! -f "$security_script" ]]; then
        echo "Error: Claude security review script not found: $security_script" >&2
        return 1
    fi

    # Create temporary file for the prompt
    local temp_prompt_file=$(mktemp)
    echo "$prompt" > "$temp_prompt_file"

    # Execute Claude security review script with timeout
    # The script expects --commit option, so we'll pass the diff as stdin
    timeout "${timeout}s" bash "$security_script" < "$temp_prompt_file" 2>&1
    local exit_code=$?

    # Cleanup
    rm -f "$temp_prompt_file"

    return $exit_code
}

# Specialized validation for security review output
validate_security_review_output() {
    local output="$1"

    # First, call base validation
    if ! validate_review_output "$output"; then
        return 1
    fi

    # Additional security-specific validation
    if ! echo "$output" | grep -q "SARIF\|severity\|CWE"; then
        echo "Warning: Security review output missing expected security metadata" >&2
        # Don't fail - output might still be useful
    fi

    # Check for CVSS scoring
    if ! echo "$output" | grep -q "cvss_score\|severity"; then
        echo "Warning: Security review output missing CVSS scoring" >&2
    fi

    echo "$output"
    return 0
}

# Override the main execution to use security-specific functions
execute_claude_security_review() {
    local prompt="$1"
    local timeout="${2:-900}"  # Default: 900s (15 minutes) for security reviews
    local file_context="$3"

    # Validation
    if [[ -z "$prompt" ]]; then
        echo "Error: Missing required parameter: prompt" >&2
        return 1
    fi

    # Step 1: Extend prompt for security review
    local extended_prompt
    extended_prompt=$(extend_prompt_for_claude-security "$prompt" "$file_context")

    # Step 2: Execute security review
    local output
    output=$(call_ai_wrapper_claude-security "claude-security" "$extended_prompt" "$timeout")
    local exit_code=$?

    # Step 3: Validate security review output
    if [[ $exit_code -eq 0 ]]; then
        validate_security_review_output "$output"
        return $?
    else
        echo "Error: Claude security review failed with code $exit_code" >&2
        return $exit_code
    fi
}

# Export functions for use in review scripts
export -f extend_prompt_for_claude-security
export -f call_ai_wrapper_claude-security
export -f validate_security_review_output
export -f execute_claude_security_review

# Default timeout for security reviews
export CLAUDE_SECURITY_TIMEOUT=900
