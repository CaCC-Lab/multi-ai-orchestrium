#!/usr/bin/env bash
# adapter-droid.sh - Droid-specific review adapter
# Version: 1.0.0
# Purpose: Enterprise-grade production readiness review using Droid AI
# Reference: OPTION_D++_IMPLEMENTATION_PLAN.md Phase 1.2.3

set -euo pipefail

# ============================================================================
# Source Dependencies
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTER_BASE="${SCRIPT_DIR}/adapter-base.sh"
REVIEW_LIB_DIR="$(dirname "$SCRIPT_DIR")"
REVIEW_PROMPT_LOADER="${REVIEW_LIB_DIR}/review-prompt-loader.sh"

# Source base adapter template
if [[ -f "$ADAPTER_BASE" ]]; then
    source "$ADAPTER_BASE"
else
    echo "Error: adapter-base.sh not found at: $ADAPTER_BASE" >&2
    exit 1
fi

# Source review prompt loader (for extend_prompt_for_droid)
if [[ -f "$REVIEW_PROMPT_LOADER" ]]; then
    source "$REVIEW_PROMPT_LOADER"
else
    echo "Error: review-prompt-loader.sh not found at: $REVIEW_PROMPT_LOADER" >&2
    exit 1
fi

# ============================================================================
# Configuration
# ============================================================================

# AI name for this adapter
AI_NAME="droid"

# Default timeout (15 minutes for comprehensive analysis)
DEFAULT_TIMEOUT=900

# Enterprise thresholds and standards
MIN_TEST_COVERAGE="${MIN_TEST_COVERAGE:-80}"
MIN_AVAILABILITY_SLA="${MIN_AVAILABILITY_SLA:-99.9}"
REQUIRED_TLS_VERSION="${REQUIRED_TLS_VERSION:-1.2}"
REQUIRED_ENCRYPTION="${REQUIRED_ENCRYPTION:-AES-256}"

# Compliance frameworks
COMPLIANCE_FRAMEWORKS="${COMPLIANCE_FRAMEWORKS:-GDPR,SOC2,HIPAA}"

# ============================================================================
# P1.2.3.1: Enterprise-Specialized Prompt
# ============================================================================

# This functionality is already implemented in review-prompt-loader.sh
# as extend_prompt_for_droid(). We inherit it from the base adapter.

# ============================================================================
# P1.2.3.2: Droid CLI Invocation
# ============================================================================

# Call Droid wrapper with appropriate timeout
# Usage: call_droid_review <prompt> [timeout]
# Returns: Review output (stdout)
call_droid_review() {
    local prompt="$1"
    local timeout="${2:-$DEFAULT_TIMEOUT}"

    # Extend prompt with Droid-specific instructions
    local extended_prompt
    extended_prompt=$(extend_prompt_for_droid "$prompt")

    # Call base adapter's execute_ai_review
    execute_ai_review "$AI_NAME" "$extended_prompt" "$timeout"
}

# ============================================================================
# P1.2.3.3: Compliance Layer
# ============================================================================

# Generate compliance checklist based on code changes
# Usage: generate_compliance_checklist <code_or_diff>
# Returns: Compliance checklist (JSON format)
generate_compliance_checklist() {
    local code="$1"

    # Parse compliance frameworks
    IFS=',' read -ra frameworks <<< "$COMPLIANCE_FRAMEWORKS"

    # Initialize checklist
    local checklist_items=()

    # Check each framework
    for framework in "${frameworks[@]}"; do
        case "$framework" in
            GDPR)
                checklist_items+=(
                    '{"framework": "GDPR", "requirement": "Data minimization", "status": "needs_review"}'
                    '{"framework": "GDPR", "requirement": "Right to be forgotten", "status": "needs_review"}'
                    '{"framework": "GDPR", "requirement": "Data portability", "status": "needs_review"}'
                    '{"framework": "GDPR", "requirement": "Consent management", "status": "needs_review"}'
                )
                ;;
            SOC2)
                checklist_items+=(
                    '{"framework": "SOC2", "requirement": "Access controls", "status": "needs_review"}'
                    '{"framework": "SOC2", "requirement": "Logging and monitoring", "status": "needs_review"}'
                    '{"framework": "SOC2", "requirement": "Encryption in transit/rest", "status": "needs_review"}'
                    '{"framework": "SOC2", "requirement": "Incident response", "status": "needs_review"}'
                )
                ;;
            HIPAA)
                checklist_items+=(
                    '{"framework": "HIPAA", "requirement": "PHI encryption", "status": "needs_review"}'
                    '{"framework": "HIPAA", "requirement": "Access audit logs", "status": "needs_review"}'
                    '{"framework": "HIPAA", "requirement": "Data retention policies", "status": "needs_review"}'
                    '{"framework": "HIPAA", "requirement": "Business associate agreements", "status": "needs_review"}'
                )
                ;;
        esac
    done

    # Build JSON array
    local checklist_json="["
    for ((i=0; i<${#checklist_items[@]}; i++)); do
        checklist_json+="${checklist_items[$i]}"
        if [[ $i -lt $((${#checklist_items[@]} - 1)) ]]; then
            checklist_json+=","
        fi
    done
    checklist_json+="]"

    echo "$checklist_json"
}

# Validate SLA compliance
# Usage: validate_sla_compliance <code>
# Returns: SLA compliance report (JSON format)
validate_sla_compliance() {
    local code="$1"

    # Check for potential SLA impacts
    local issues=()

    # Check for blocking operations
    if echo "$code" | grep -qi "sleep\|wait\|lock"; then
        issues+='{"category": "blocking_operations", "severity": "medium", "description": "Blocking operations detected that may impact availability"}'
    fi

    # Check for single points of failure
    if echo "$code" | grep -qi "singleton\|global"; then
        issues+='{"category": "single_point_of_failure", "severity": "high", "description": "Potential single point of failure detected"}'
    fi

    # Check for proper error handling
    if ! echo "$code" | grep -qi "try\|catch\|error\|exception"; then
        issues+='{"category": "error_handling", "severity": "high", "description": "Insufficient error handling may cause service disruption"}'
    fi

    # Build JSON
    cat <<EOF
{
  "target_sla": "$MIN_AVAILABILITY_SLA%",
  "issues_found": ${#issues[@]},
  "issues": [
    $(IFS=,; echo "${issues[*]}")
  ]
}
EOF
}

# Check audit trail sufficiency
# Usage: check_audit_trail <code>
# Returns: Audit trail report (JSON format)
check_audit_trail() {
    local code="$1"

    local findings=()

    # Check for logging statements
    local has_logging=false
    if echo "$code" | grep -Eqi "log\.|logger\.|console\.|print"; then
        has_logging=true
    fi

    # Check for sensitive data exposure
    local sensitive_patterns=("password" "secret" "token" "api_key" "private_key")
    for pattern in "${sensitive_patterns[@]}"; do
        if echo "$code" | grep -qi "$pattern"; then
            findings+='{"issue": "sensitive_data_logging", "pattern": "'"$pattern"'", "severity": "critical"}'
        fi
    done

    # Check for audit events
    local audit_events=("create" "update" "delete" "access" "authenticate")
    local covered_events=()
    for event in "${audit_events[@]}"; do
        if echo "$code" | grep -Eqi "log.*$event|audit.*$event"; then
            covered_events+=("$event")
        fi
    done

    cat <<EOF
{
  "has_logging": $has_logging,
  "covered_audit_events": [$(printf '"%s",' "${covered_events[@]}" | sed 's/,$//') ],
  "findings": [
    $(IFS=,; echo "${findings[*]}")
  ],
  "recommendation": "Ensure all critical operations are logged with proper audit context"
}
EOF
}

# Verify security standards
# Usage: verify_security_standards <code>
# Returns: Security standards report (JSON format)
verify_security_standards() {
    local code="$1"

    local issues=()

    # Check TLS version
    if echo "$code" | grep -Eqi "tls|ssl"; then
        if echo "$code" | grep -Eqi "tls.*1\.[0-1]|ssl"; then
            issues+='{"standard": "TLS", "issue": "Outdated TLS version", "required": "'"$REQUIRED_TLS_VERSION"'", "severity": "high"}'
        fi
    fi

    # Check encryption algorithm
    if echo "$code" | grep -Eqi "encrypt|crypto"; then
        if echo "$code" | grep -Eqi "des|md5|sha1"; then
            issues+='{"standard": "Encryption", "issue": "Weak encryption algorithm", "required": "'"$REQUIRED_ENCRYPTION"'", "severity": "critical"}'
        fi
    fi

    # Check authentication
    if echo "$code" | grep -Eqi "auth|login|password"; then
        if ! echo "$code" | grep -Eqi "hash|bcrypt|argon2"; then
            issues+='{"standard": "Authentication", "issue": "Weak password handling", "severity": "critical"}'
        fi
    fi

    cat <<EOF
{
  "required_tls": "$REQUIRED_TLS_VERSION+",
  "required_encryption": "$REQUIRED_ENCRYPTION",
  "issues": [
    $(IFS=,; echo "${issues[*]}")
  ]
}
EOF
}

# ============================================================================
# Droid-Specific Review Function
# ============================================================================

# Main review function for Droid adapter
# Usage: droid_review <commit_hash_or_diff> [timeout] [--compliance]
# Returns: Structured review output (JSON format)
droid_review() {
    local target="$1"
    local timeout="${2:-$DEFAULT_TIMEOUT}"
    local compliance_mode="${3:-false}"

    # Load base review prompt
    local base_prompt
    base_prompt=$(load_review_prompt)

    # Add commit/diff context
    local full_prompt
    full_prompt=$(cat <<EOF
$base_prompt

## Code to Review

$target

## Enterprise Standards

- Minimum Test Coverage: $MIN_TEST_COVERAGE%
- Target SLA: $MIN_AVAILABILITY_SLA%
- Required TLS Version: $REQUIRED_TLS_VERSION+
- Required Encryption: $REQUIRED_ENCRYPTION
- Compliance Frameworks: $COMPLIANCE_FRAMEWORKS

EOF
)

    # Add compliance checklist if in compliance mode
    if [[ "$compliance_mode" == "--compliance" || "$compliance_mode" == "true" ]]; then
        local checklist
        checklist=$(generate_compliance_checklist "$target")

        full_prompt+=$(cat <<EOF

## Compliance Checklist

Please review each of these compliance requirements:

$checklist

EOF
)
    fi

    # Execute review with enterprise focus
    local review_output
    review_output=$(call_droid_review "$full_prompt" "$timeout")

    # Add compliance layer metadata if enabled
    if [[ "$compliance_mode" == "--compliance" || "$compliance_mode" == "true" ]]; then
        if echo "$review_output" | jq empty 2>/dev/null; then
            # Enhance JSON with compliance metadata
            review_output=$(echo "$review_output" | jq --argjson cl "$checklist" '. + {compliance_checklist: $cl}')
        fi
    fi

    echo "$review_output"
}

# Enterprise compliance review mode
# Usage: droid_compliance_review <commit_hash_or_diff>
# Returns: Enhanced review output with full compliance analysis
droid_compliance_review() {
    local target="$1"

    # Run standard review with compliance mode
    local review_output
    review_output=$(droid_review "$target" "$DEFAULT_TIMEOUT" true)

    # Add additional compliance layers
    local sla_report
    sla_report=$(validate_sla_compliance "$target")

    local audit_report
    audit_report=$(check_audit_trail "$target")

    local security_report
    security_report=$(verify_security_standards "$target")

    # Merge all reports
    if echo "$review_output" | jq empty 2>/dev/null; then
        echo "$review_output" | jq \
            --argjson sla "$sla_report" \
            --argjson audit "$audit_report" \
            --argjson sec "$security_report" \
            '. + {
                sla_compliance: $sla,
                audit_trail: $audit,
                security_standards: $sec,
                metadata: (.metadata + {compliance_mode: true})
            }'
    else
        echo "$review_output"
    fi
}

# ============================================================================
# Exports
# ============================================================================

# Export Droid-specific functions
export -f call_droid_review
export -f droid_review
export -f droid_compliance_review
export -f generate_compliance_checklist
export -f validate_sla_compliance
export -f check_audit_trail
export -f verify_security_standards

# Export configuration
export AI_NAME
export DEFAULT_TIMEOUT
export MIN_TEST_COVERAGE
export MIN_AVAILABILITY_SLA
export REQUIRED_TLS_VERSION
export REQUIRED_ENCRYPTION
export COMPLIANCE_FRAMEWORKS

# ============================================================================
# Standalone Execution Support
# ============================================================================

# Allow this adapter to be run standalone for testing
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Parse arguments
    COMMIT_OR_DIFF="${1:-HEAD}"
    TIMEOUT="${2:-$DEFAULT_TIMEOUT}"
    COMPLIANCE_MODE="${3:-false}"

    echo "Running Droid review adapter..." >&2
    echo "Target: $COMMIT_OR_DIFF" >&2
    echo "Timeout: ${TIMEOUT}s" >&2
    echo "Compliance mode: $COMPLIANCE_MODE" >&2
    echo "" >&2

    # Execute review
    if [[ "$COMPLIANCE_MODE" == "--compliance" || "$COMPLIANCE_MODE" == "true" ]]; then
        droid_compliance_review "$COMMIT_OR_DIFF"
    else
        droid_review "$COMMIT_OR_DIFF" "$TIMEOUT"
    fi
fi
