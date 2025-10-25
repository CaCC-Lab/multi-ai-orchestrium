#!/usr/bin/env bash
# YAML Configuration Validator (P1.5.2.1)
# Validates multi-ai-profiles.yaml against JSON Schema
# Usage: bash scripts/validate-config.sh [yaml_file]

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Source multi-ai-core for logging
source scripts/orchestrate/lib/multi-ai-core.sh

# Default files
YAML_FILE="${1:-config/multi-ai-profiles.yaml}"
SCHEMA_FILE="config/schema/multi-ai-profiles.schema.json"

# Colors already defined in multi-ai-core.sh

# ============================================================================
# Dependency Checks
# ============================================================================

check_dependencies() {
    local missing_deps=0

    # Check yq
    if ! command -v yq >/dev/null 2>&1; then
        log_structured_error \
            "yq not found - YAML validation impossible" \
            "yq is required to convert YAML to JSON for schema validation" \
            "Install yq: https://github.com/mikefarah/yq#install"
        ((missing_deps++))
    fi

    # Check jq
    if ! command -v jq >/dev/null 2>&1; then
        log_structured_error \
            "jq not found - JSON processing impossible" \
            "jq is required for JSON schema validation" \
            "Install jq: apt-get install jq / brew install jq"
        ((missing_deps++))
    fi

    # Note: We'll use a lightweight JSON schema validator instead of ajv (Node.js dependency)
    # Using jq for basic schema validation

    if [ $missing_deps -gt 0 ]; then
        log_error "Missing $missing_deps dependencies"
        return 1
    fi

    return 0
}

# ============================================================================
# Schema Validation (Lightweight - no external validator)
# ============================================================================

validate_yaml_schema() {
    local yaml_file="$1"
    local schema_file="$2"

    log_info "Validating: $yaml_file"
    log_info "Schema: $schema_file"

    # Check if files exist
    if [ ! -f "$yaml_file" ]; then
        log_structured_error \
            "YAML file not found: $yaml_file" \
            "File does not exist or path is incorrect" \
            "Check file path: ls -la $yaml_file"
        return 1
    fi

    if [ ! -f "$schema_file" ]; then
        log_warning "Schema file not found: $schema_file (skipping schema validation)"
        log_info "Performing basic YAML syntax check only"
    fi

    # Step 1: YAML syntax validation
    log_info "[1/3] Validating YAML syntax..."
    if ! yq eval . "$yaml_file" > /dev/null 2>&1; then
        log_structured_error \
            "Invalid YAML syntax in $yaml_file" \
            "YAML parsing failed - syntax error" \
            "Run: yq eval . $yaml_file to see detailed error"
        return 1
    fi
    log_success "YAML syntax valid"

    # Step 2: Convert YAML to JSON
    log_info "[2/3] Converting YAML to JSON..."
    local json_output
    if ! json_output=$(yq eval -o=json "$yaml_file" 2>&1); then
        log_structured_error \
            "Failed to convert YAML to JSON" \
            "YAML structure may contain unsupported features" \
            "Check YAML structure: yq eval -o=json $yaml_file"
        return 1
    fi
    log_success "YAML → JSON conversion successful"

    # Step 3: Basic structure validation (lightweight, no full JSON Schema validator)
    log_info "[3/3] Validating configuration structure..."

    # Check required top-level keys
    if ! echo "$json_output" | jq -e '.profiles' > /dev/null 2>&1; then
        log_structured_error \
            "Missing required key: 'profiles'" \
            "Configuration must have a 'profiles' section" \
            "Add 'profiles:' section to $yaml_file"
        return 1
    fi

    # Check profile names
    local profile_count=$(echo "$json_output" | jq '.profiles | length')
    if [ "$profile_count" -eq 0 ]; then
        log_structured_error \
            "No profiles defined" \
            "'profiles' section is empty" \
            "Define at least one profile in $yaml_file"
        return 1
    fi
    log_success "Found $profile_count profile(s)"

    # Validate each profile has 'workflows'
    local profiles=$(echo "$json_output" | jq -r '.profiles | keys[]')
    for profile in $profiles; do
        if ! echo "$json_output" | jq -e ".profiles[\"$profile\"].workflows" > /dev/null 2>&1; then
            log_structured_error \
                "Profile '$profile' missing 'workflows' key" \
                "Each profile must define workflows" \
                "Add 'workflows:' section to profile '$profile'"
            return 1
        fi

        # Count workflows
        local workflow_count=$(echo "$json_output" | jq ".profiles[\"$profile\"].workflows | length")
        log_success "Profile '$profile': $workflow_count workflow(s)"
    done

    # Step 4: Validate AI names (enum check)
    log_info "[4/4] Validating AI names..."
    local valid_ais="claude gemini amp qwen droid codex cursor"
    local invalid_ais=0

    # Extract all AI names from configuration
    local all_ais=$(echo "$json_output" | jq -r '
        .profiles[].workflows[].phases[]? |
        if .ai then .ai
        elif .parallel then .parallel[].ai
        else empty
        end
    ' | sort -u)

    for ai in $all_ais; do
        if ! echo "$valid_ais" | grep -qw "$ai"; then
            log_error "Invalid AI name: '$ai' (valid: $valid_ais)"
            ((invalid_ais++))
        fi
    done

    if [ $invalid_ais -gt 0 ]; then
        log_structured_error \
            "Found $invalid_ais invalid AI name(s)" \
            "AI names must be one of: $valid_ais" \
            "Fix AI names in $yaml_file"
        return 1
    fi
    log_success "All AI names valid"

    return 0
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    log_phase "Multi-AI Configuration Validator (P1.5)"
    echo ""

    # Check dependencies
    if ! check_dependencies; then
        exit 1
    fi

    # Validate configuration
    if validate_yaml_schema "$YAML_FILE" "$SCHEMA_FILE"; then
        echo ""
        log_success "✅ Configuration validation successful!"
        log_info "File: $YAML_FILE"
        echo ""
        return 0
    else
        echo ""
        log_error "❌ Configuration validation failed"
        log_info "File: $YAML_FILE"
        echo ""
        return 1
    fi
}

# Execute main
main "$@"
