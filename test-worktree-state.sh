#!/bin/bash

# Test script for worktree-state.sh functionality

# Source the worktree state functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/orchestrate/lib/worktree-state.sh"

echo "Testing NDJSON state management functionality..."

# Test 1: Update worktree state
echo "Test 1: Updating worktree state to 'creating'"
update_worktree_state "qwen" "creating" '"branch":"ai/qwen/20251108-140000","worktree":"worktrees/qwen"'

echo "Test 2: Updating worktree state to 'active'"
update_worktree_state "qwen" "active" '"branch":"ai/qwen/20251108-140000","worktree":"worktrees/qwen"'

echo "Test 3: Getting current worktree state for qwen"
get_worktree_state "qwen"

echo "Test 4: Getting all worktree states"
get_all_worktree_states

echo "Test 5: Validating state transition (should succeed: none -> creating)"
if validate_worktree_state_transition "test-ai" "none" "creating"; then
    echo "Valid transition: none -> creating"
else
    echo "Invalid transition: none -> creating"
fi

echo "Test 6: Validating invalid state transition (should fail: creating -> none)"
if validate_worktree_state_transition "test-ai" "creating" "none"; then
    echo "Valid transition: creating -> none"
else
    echo "Invalid transition: creating -> none"
fi

echo "Test 7: Checking if 'active' is a valid state"
if is_valid_state "active"; then
    echo "'active' is a valid state"
else
    echo "'active' is not a valid state"
fi

echo "Test 8: Getting just the state value for qwen"
get_worktree_state_value "qwen"

echo "All tests completed!"