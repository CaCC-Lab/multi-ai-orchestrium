#!/bin/bash

# Additional test for worktree-state.sh functionality with multiple AIs

# Source the worktree state functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/orchestrate/lib/worktree-state.sh"

echo "Testing NDJSON state management functionality with multiple AIs..."

# Test with different AIs
echo "Test 1: Updating states for different AIs"
update_worktree_state "qwen" "creating" '"branch":"ai/qwen/20251108-150000","worktree":"worktrees/qwen"'
update_worktree_state "claude" "creating" '"branch":"ai/claude/20251108-150000","worktree":"worktrees/claude"'
update_worktree_state "qwen" "active" '"branch":"ai/qwen/20251108-150000","worktree":"worktrees/qwen"'
update_worktree_state "gpt" "creating" '"branch":"ai/gpt/20251108-150000","worktree":"worktrees/gpt"'

echo "Test 2: Getting state for each AI"
echo "Qwen state:"
get_worktree_state "qwen"
echo "Claude state:"
get_worktree_state "claude"
echo "GPT state:"
get_worktree_state "gpt"

echo "Test 3: Getting all states"
get_all_worktree_states

echo "Test 4: Testing state transitions"
echo "Valid transition none->creating:"
validate_worktree_state_transition "test" "none" "creating"
echo "Invalid transition creating->none:"
validate_worktree_state_transition "test" "creating" "none"
echo "Valid transition creating->active:"
validate_worktree_state_transition "test" "creating" "active"
echo "Valid transition active->cleaning:"
validate_worktree_state_transition "test" "active" "cleaning"
echo "Valid transition cleaning->none:"
validate_worktree_state_transition "test" "cleaning" "none"

echo "All additional tests completed!"