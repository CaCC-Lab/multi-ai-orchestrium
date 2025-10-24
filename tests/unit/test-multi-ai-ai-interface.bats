#!/usr/bin/env bats
# test-multi-ai-ai-interface.bats - Unit tests for scripts/orchestrate/lib/multi-ai-ai-interface.sh

load '../helpers/test_helper'

setup() {
    setup_test_env
    source_lib "scripts/orchestrate/lib/multi-ai-core.sh"
    source_lib "scripts/orchestrate/lib/multi-ai-ai-interface.sh"
}

teardown() {
    teardown_test_env
}

# ============================================================================
# AI Availability Check Tests
# ============================================================================

@test "check_ai_available: requires AI name parameter" {
    run check_ai_available
    assert_failure
}

@test "check_ai_available: returns true for command in PATH" {
    skip "Requires actual AI CLI in PATH - tested in integration tests"
}

@test "check_ai_available: returns false for non-existent command" {
    run check_ai_available "nonexistent-ai-cli-12345"
    assert_failure
}

@test "check_ai_with_details: provides detailed availability info" {
    skip "Requires actual AI CLI in PATH - tested in integration tests"
}

# ============================================================================
# AI Calling Tests
# ============================================================================

@test "call_ai: requires AI name parameter" {
    run call_ai
    assert_failure
}

@test "call_ai: requires prompt parameter" {
    run call_ai "claude"
    assert_failure
}

@test "call_ai: delegates to call_ai_with_context" {
    skip "Requires AI CLI availability - tested in Phase 1 integration tests"
}

@test "call_ai_with_fallback: requires primary AI parameter" {
    run call_ai_with_fallback
    assert_failure
}

@test "call_ai_with_fallback: requires fallback AI parameter" {
    run call_ai_with_fallback "claude"
    assert_failure
}

@test "call_ai_with_fallback: requires prompt parameter" {
    run call_ai_with_fallback "claude" "gemini"
    assert_failure
}

@test "call_ai_with_fallback: tries primary then fallback" {
    skip "Requires AI CLI availability - tested in integration tests"
}

# ============================================================================
# File-Based Prompt System Tests
# ============================================================================
# NOTE: These functions are extensively tested in phase1-file-based-prompt-test.sh
#       (66 tests covering all scenarios). Unit tests here focus on basic validation.

@test "supports_file_input: returns 1 for stdin redirect (current behavior)" {
    # Currently all AIs use stdin redirect (return 1 = "use stdin redirect")
    # Phase 1.3: All wrappers use stdin redirect (<file) for now
    # Future: Add --prompt-file flag support in Phase 3
    run supports_file_input "claude"
    assert_failure  # return 1 = use stdin redirect

    run supports_file_input "gemini"
    assert_failure

    run supports_file_input "qwen"
    assert_failure
}

@test "create_secure_prompt_file: requires AI name" {
    skip "Covered by Phase 1 tests (12 test cases) - see phase1-file-based-prompt-test.sh"
}

@test "create_secure_prompt_file: requires prompt content" {
    skip "Covered by Phase 1 tests (12 test cases) - see phase1-file-based-prompt-test.sh"
}

@test "create_secure_prompt_file: creates file with 600 permissions" {
    skip "Covered by Phase 1 tests (12 test cases) - see phase1-file-based-prompt-test.sh"
}

@test "cleanup_prompt_file: safely removes file" {
    skip "Covered by Phase 1 tests (6 test cases) - see phase1-file-based-prompt-test.sh"
}

@test "cleanup_prompt_file: handles already-deleted files" {
    skip "Covered by Phase 1 tests (6 test cases) - see phase1-file-based-prompt-test.sh"
}

@test "call_ai_with_context: routes small prompts to command-line" {
    skip "Covered by Phase 1 tests (10 test cases) - see phase1-file-based-prompt-test.sh"
}

@test "call_ai_with_context: routes large prompts to file-based" {
    skip "Covered by Phase 1 tests (10 test cases) - see phase1-file-based-prompt-test.sh"
}

# ============================================================================
# Integration Tests
# ============================================================================

@test "integration: check availability and call AI" {
    skip "Requires AI CLI availability - tested in E2E tests"
}

@test "integration: fallback mechanism on primary failure" {
    skip "Requires AI CLI availability - tested in E2E tests"
}

@test "integration: file-based routing for large prompts" {
    skip "Covered by Phase 1 tests (66 total) - see phase1-file-based-prompt-test.sh"
}
