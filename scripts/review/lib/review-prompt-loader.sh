#!/usr/bin/env bash
# review-prompt-loader.sh - REVIEW-PROMPT.md loader and AI-specific prompt extension
# Version: 1.0.0
# Purpose: Load review prompt template and extend it based on AI characteristics
# Reference: OPTION_D++_IMPLEMENTATION_PLAN.md Phase 1.1.2

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Ensure review-common.sh is loaded
if [[ -z "${REVIEW_PROJECT_ROOT:-}" ]]; then
    echo "Error: review-common.sh must be sourced before review-prompt-loader.sh" >&2
    exit 1
fi

# Review prompt file location
REVIEW_PROMPT_FILE="${REVIEW_PROMPT_FILE:-$REVIEW_PROJECT_ROOT/REVIEW-PROMPT.md}"
REVIEW_PROMPT_VERSION="${REVIEW_PROMPT_VERSION:-1.0}"

# ============================================================================
# P1.1.2.1: REVIEW-PROMPT.md Loading
# ============================================================================

# Load REVIEW-PROMPT.md content
# Usage: load_review_prompt
# Returns: Prompt content (stdout)
load_review_prompt() {
    # Validate file exists
    if ! validate_review_prompt "$REVIEW_PROMPT_FILE"; then
        echo "Error: Failed to validate REVIEW-PROMPT.md" >&2
        return 1
    fi

    # Read and return content
    cat "$REVIEW_PROMPT_FILE"
}

# Validate REVIEW-PROMPT.md existence and structure
# Usage: validate_review_prompt <file_path>
# Returns: 0 if valid, 1 if invalid
validate_review_prompt() {
    local file="$1"

    # Check file exists
    if [[ ! -f "$file" ]]; then
        echo "Error: REVIEW-PROMPT.md not found at: $file" >&2
        return 1
    fi

    # Check version header (Phase 0.1.2 requirement)
    if ! grep -q "Version: $REVIEW_PROMPT_VERSION" "$file"; then
        echo "Warning: REVIEW-PROMPT.md version mismatch. Expected: $REVIEW_PROMPT_VERSION" >&2
        # Non-fatal: allow older versions but warn
    fi

    # Check required sections
    local required_sections=("findings" "overall_correctness" "confidence_score")
    for section in "${required_sections[@]}"; do
        if ! grep -q "$section" "$file"; then
            echo "Error: REVIEW-PROMPT.md missing required section: $section" >&2
            return 1
        fi
    done

    return 0
}

# ============================================================================
# P1.1.2.2: AI-Specific Prompt Extension
# ============================================================================

# Extend prompt for Gemini (Web search focused)
# Usage: extend_prompt_for_gemini <base_prompt>
# Returns: Extended prompt (stdout)
extend_prompt_for_gemini() {
    local base_prompt="$1"

    cat << EOF
$base_prompt

## Gemini-Specific Instructions

As a security-focused reviewer with **Web search capabilities**, please enhance your review with:

1. **CVE/Vulnerability Research**:
   - Use Web search to identify known vulnerabilities (CVEs) for any libraries or frameworks in this diff
   - Check for outdated dependencies with known security issues
   - Report version-specific vulnerabilities with CVE IDs

2. **Latest Best Practices**:
   - Search for recent security advisories related to code patterns in this diff
   - Verify against current OWASP Top 10 guidelines
   - Check for latest recommendations on cryptographic implementations

3. **Security Standards**:
   - Cross-reference with industry security standards (e.g., CWE, SANS Top 25)
   - Identify compliance issues (GDPR, SOC2, etc.)

**Important**: Include Web search sources in your findings when referencing external information.
EOF
}

# Extend prompt for Qwen (Code quality focused)
# Usage: extend_prompt_for_qwen <base_prompt>
# Returns: Extended prompt (stdout)
extend_prompt_for_qwen() {
    local base_prompt="$1"

    cat << EOF
$base_prompt

## Qwen-Specific Instructions

As a code quality specialist with **fast prototyping capabilities**, please focus on:

1. **Strict Bug Detection**:
   - Apply rigorous bug detection criteria
   - Flag any potential runtime errors or edge cases
   - Identify type safety issues and potential null/undefined errors

2. **Refactoring Suggestions**:
   - Provide concrete refactoring alternatives using \`\`\`suggestion blocks
   - Keep suggestions minimal (3-5 lines max)
   - Preserve exact indentation (spaces vs tabs)
   - Include only replacement code, no explanatory comments inside blocks

3. **Code Quality Metrics**:
   - Comment on cyclomatic complexity if excessive (>10)
   - Flag duplicated code patterns
   - Suggest simplifications for overly complex logic

4. **Brief Comments**:
   - Keep all comments to 1 paragraph maximum
   - Be direct and actionable
   - Avoid verbose explanations

**Output Format**: Include a \`suggestion\` field in JSON findings when providing alternative code.
EOF
}

# Extend prompt for Droid (Enterprise focused)
# Usage: extend_prompt_for_droid <base_prompt>
# Returns: Extended prompt (stdout)
extend_prompt_for_droid() {
    local base_prompt="$1"

    cat << EOF
$base_prompt

## Droid-Specific Instructions

As an enterprise-grade reviewer focused on **production readiness**, please evaluate:

1. **SLA Compliance**:
   - Assess impact on system availability and reliability
   - Flag potential performance bottlenecks affecting SLAs
   - Identify single points of failure

2. **Audit Trail Sufficiency**:
   - Verify adequate logging for compliance and debugging
   - Check for sensitive data exposure in logs
   - Ensure audit events are properly captured

3. **Security Standards**:
   - Evaluate against enterprise security policies
   - Check for proper authentication/authorization
   - Verify encryption standards (TLS 1.2+, AES-256)

4. **Operational Concerns**:
   - Assess monitoring and observability
   - Evaluate deployment complexity
   - Check for proper error handling and graceful degradation

5. **Compliance Requirements**:
   - Flag potential regulatory issues (GDPR, HIPAA, SOC2)
   - Verify data retention policies
   - Check for proper security controls

**Output Format**: Include a \`compliance_checklist\` field in JSON findings for regulatory issues.
EOF
}

# Extend prompt for Claude Security (Security focused)
# Usage: extend_prompt_for_claude_security <base_prompt>
# Returns: Extended prompt (stdout)
extend_prompt_for_claude_security() {
    local base_prompt="$1"

    cat << EOF
$base_prompt

## Claude Security Review Instructions

Focus on **OWASP Top 10 and CWE-based security vulnerabilities**:

1. **Injection Flaws**:
   - SQL Injection (CWE-89)
   - Command Injection (CWE-77, CWE-78)
   - XSS (CWE-79)
   - Path Traversal (CWE-22)

2. **Authentication & Authorization**:
   - Broken authentication (CWE-287)
   - Session management issues (CWE-384)
   - Insufficient authorization (CWE-862)

3. **Sensitive Data**:
   - Hardcoded secrets (CWE-798)
   - Insecure cryptography (CWE-327)
   - Information exposure (CWE-200)

4. **Security Misconfiguration**:
   - Default credentials
   - Verbose error messages
   - Missing security headers

**Output Format**: Include CVSS v3.1 scores and CWE IDs in findings.
EOF
}

# Generic prompt extension router
# Usage: extend_prompt_for_ai <ai_name> <base_prompt>
# Returns: Extended prompt (stdout)
extend_prompt_for_ai() {
    local ai_name="$1"
    local base_prompt="$2"

    case "$ai_name" in
        gemini)
            extend_prompt_for_gemini "$base_prompt"
            ;;
        qwen)
            extend_prompt_for_qwen "$base_prompt"
            ;;
        droid)
            extend_prompt_for_droid "$base_prompt"
            ;;
        claude-security|claude_security)
            extend_prompt_for_claude_security "$base_prompt"
            ;;
        claude|codex|cursor|amp)
            # No AI-specific extension for these
            echo "$base_prompt"
            ;;
        *)
            echo "Warning: Unknown AI name '$ai_name', using base prompt" >&2
            echo "$base_prompt"
            ;;
    esac
}

# ============================================================================
# P1.1.2.3: JSON Output Validation
# ============================================================================

# Validate review JSON output against REVIEW-PROMPT format
# Usage: validate_review_output <json_output>
# Returns: 0 if valid, 1 if invalid
validate_review_output() {
    local json_output="$1"

    # Check if valid JSON
    if ! echo "$json_output" | jq empty 2>/dev/null; then
        echo "Error: Invalid JSON output" >&2
        return 1
    fi

    # Check required top-level fields
    local required_fields=("findings" "overall_correctness" "overall_explanation" "overall_confidence_score")
    for field in "${required_fields[@]}"; do
        if ! echo "$json_output" | jq -e ".$field" > /dev/null 2>&1; then
            echo "Error: Missing required field: $field" >&2
            return 1
        fi
    done

    # Validate overall_correctness enum
    local correctness
    correctness=$(echo "$json_output" | jq -r '.overall_correctness')
    if [[ "$correctness" != "patch is correct" && "$correctness" != "patch is incorrect" ]]; then
        echo "Error: Invalid overall_correctness value: $correctness" >&2
        return 1
    fi

    # Validate findings array structure
    local findings_count
    findings_count=$(echo "$json_output" | jq '.findings | length')

    for ((i=0; i<findings_count; i++)); do
        local finding
        finding=$(echo "$json_output" | jq ".findings[$i]")

        # Check required finding fields (code_location is optional per schema)
        local finding_fields=("title" "body" "confidence_score")
        for field in "${finding_fields[@]}"; do
            if ! echo "$finding" | jq -e ".$field" > /dev/null 2>&1; then
                echo "Error: Finding $i missing required field: $field" >&2
                return 1
            fi
        done

        # Validate code_location structure if present (code_location can be null)
        local has_location
        has_location=$(echo "$finding" | jq -r '.code_location')
        if [[ "$has_location" != "null" ]]; then
            if ! echo "$finding" | jq -e '.code_location.absolute_file_path' > /dev/null 2>&1; then
                echo "Error: Finding $i has code_location but missing absolute_file_path" >&2
                return 1
            fi
            if ! echo "$finding" | jq -e '.code_location.line_range' > /dev/null 2>&1; then
                echo "Error: Finding $i has code_location but missing line_range" >&2
                return 1
            fi
        fi
    done

    # Echo validated JSON to stdout
    echo "$json_output"
    return 0
}

# Parse review JSON and extract key information
# Usage: parse_review_json <json_output>
# Returns: Parsed data as JSON (stdout)
parse_review_json() {
    local json_output="$1"

    # Validate first
    if ! validate_review_output "$json_output"; then
        echo "Error: JSON validation failed" >&2
        return 1
    fi

    # Extract summary statistics
    local findings_count
    findings_count=$(echo "$json_output" | jq '.findings | length')

    local p0_count p1_count p2_count p3_count
    p0_count=$(echo "$json_output" | jq '[.findings[] | select(.priority == 0)] | length')
    p1_count=$(echo "$json_output" | jq '[.findings[] | select(.priority == 1)] | length')
    p2_count=$(echo "$json_output" | jq '[.findings[] | select(.priority == 2)] | length')
    p3_count=$(echo "$json_output" | jq '[.findings[] | select(.priority == 3)] | length')

    local overall_correctness
    overall_correctness=$(echo "$json_output" | jq -r '.overall_correctness')

    # Return summary
    cat << EOF
{
  "summary": {
    "total_findings": $findings_count,
    "p0_findings": $p0_count,
    "p1_findings": $p1_count,
    "p2_findings": $p2_count,
    "p3_findings": $p3_count,
    "overall_correctness": "$overall_correctness"
  },
  "raw_output": $json_output
}
EOF
}

# ============================================================================
# Exports
# ============================================================================

# Export all functions for use in review scripts
export -f load_review_prompt
export -f validate_review_prompt
export -f extend_prompt_for_gemini
export -f extend_prompt_for_qwen
export -f extend_prompt_for_droid
export -f extend_prompt_for_claude_security
export -f extend_prompt_for_ai
export -f validate_review_output
export -f parse_review_json

# Export configuration variables
export REVIEW_PROMPT_FILE
export REVIEW_PROMPT_VERSION
