# Input Sanitization Migration Guide

**Version**: v3.3.0
**Date**: 2025-10-25
**Status**: P0.2.1 Implementation
**Tracking Issue**: P0 Critical Fix Implementation Plan

---

## Executive Summary

Multi-AI Orchestrium is migrating from the legacy `sanitize_input()` function to the new security-hardened `sanitize_input_strict()` function. This migration implements Gemini CIO's security recommendations from the 7AI Comprehensive Review.

**Migration Timeline**:
- P0.2.1 (Complete): Implement `sanitize_input_strict()` and deprecation warnings
- P1.1 (Week 2): Migrate critical user-facing inputs
- P1.2 (Week 3): Migrate medium-priority workflow inputs
- P1.3 (Week 4): Complete migration and remove deprecation warnings

**Impact**:
- Security: Prevents command injection attacks (defense in depth)
- Performance: Minimal (<5ms per sanitization)
- Compatibility: Backward compatible via deprecation period

---

## Background

### Security Vulnerability (7AI Review Finding)

**Discovered by**: Gemini CIO + Codex
**Severity**: 🟡 High
**Impact**: Command injection vulnerability in user input handling

**Problem**: The legacy `sanitize_input()` function uses a blacklist approach, which can be bypassed by:
- Novel shell metacharacter combinations
- Unicode escaping techniques
- Multi-byte character exploits

**Solution**: Implement whitelist-based `sanitize_input_strict()` with:
1. **Layer 1**: Whitelist (only safe characters allowed)
2. **Layer 2**: Blocklist (explicit dangerous pattern rejection)
3. **Layer 3**: Validation (length, emptiness, format checks)

---

## Migration Strategy

### Three-Tier Categorization

| Category | Description | Function to Use | Priority |
|----------|-------------|-----------------|----------|
| **Critical** | User-facing CLI inputs, external API data | `sanitize_input_strict()` | 🔴 High |
| **Standard** | Internal workflow prompts (<2KB) | `sanitize_input_strict()` | 🟡 Medium |
| **Relaxed** | Large workflow prompts (>2KB), file-based | `sanitize_input()` or `sanitize_input_for_file()` | 🟢 Low |

### Decision Tree

```
User input source?
├─ CLI argument / stdin → Use sanitize_input_strict()
├─ External API / webhook → Use sanitize_input_strict()
├─ Workflow prompt (<2KB) → Use sanitize_input_strict()
├─ Workflow prompt (>2KB) → Use sanitize_input() (keep existing)
└─ File-based prompt → Use sanitize_input_for_file() (keep existing)
```

---

## Migration Checklist

### Phase 1: Critical User Inputs (P1.1 - Week 2)

**Files to migrate** (3 files):

- [ ] `tests/phase1-file-based-prompt-test.sh`
  - Priority: 🔴 Critical (test validation)
  - Lines: ~50-100 estimated
  - Action: Replace `sanitize_input()` with `sanitize_input_strict()` for test inputs

- [ ] `tests/phase1-integration-test.sh`
  - Priority: 🔴 Critical (test validation)
  - Lines: ~50-100 estimated
  - Action: Replace `sanitize_input()` with `sanitize_input_strict()` for test inputs

- [ ] `scripts/orchestrate/lib/multi-ai-core.sh`
  - Priority: 🟢 Low (definition file)
  - Lines: Already contains both functions
  - Action: No migration needed (maintains backward compatibility)

**Current Usage Count**: 3 files (confirmed via grep)

**Note**: The low file count indicates `sanitize_input()` is well-encapsulated. Most scripts use it indirectly via wrapper functions.

### Phase 2: Standard Workflow Inputs (P1.2 - Week 3)

**Audit Required**: Search for indirect usages via:
```bash
# Find calls to functions that call sanitize_input()
grep -r "call_ai\|execute_phase\|run_workflow" scripts/ --include="*.sh"
```

**Expected Files** (~5-10 additional files):
- Wrapper scripts in `bin/`
- Workflow scripts in `scripts/orchestrate/lib/`
- TDD scripts in `scripts/tdd/`

### Phase 3: Cleanup (P1.3 - Week 4)

- [ ] Remove deprecation warnings from `sanitize_input()`
- [ ] Update CLAUDE.md with final sanitization guidelines
- [ ] Run security audit (`/quality --security`)
- [ ] Verify all tests pass

---

## Migration Examples

### Before (Deprecated)

```bash
#!/bin/bash
source scripts/orchestrate/lib/multi-ai-core.sh

# Old approach - blacklist-based
user_prompt="$1"
sanitized=$(sanitize_input "$user_prompt")  # ⚠️ DEPRECATED

if [ $? -eq 0 ]; then
    echo "Processing: $sanitized"
fi
```

### After (Secure)

```bash
#!/bin/bash
source scripts/orchestrate/lib/multi-ai-core.sh

# New approach - whitelist-based
user_prompt="$1"
sanitized=$(sanitize_input_strict "$user_prompt")  # ✅ SECURE

if [ $? -eq 0 ]; then
    echo "Processing: $sanitized"
else
    echo "ERROR: Invalid input - only alphanumeric and safe punctuation allowed"
    exit 1
fi
```

### Large Prompts (No Change)

```bash
#!/bin/bash
source scripts/orchestrate/lib/multi-ai-core.sh

# Large workflow prompts - continue using existing functions
large_workflow_prompt=$(cat workflow-spec.md)

# Option 1: Use sanitize_input() (auto-delegates to sanitize_input_for_file())
sanitized=$(sanitize_input "$large_workflow_prompt")

# Option 2: Use sanitize_input_for_file() directly
sanitized=$(sanitize_input_for_file "$large_workflow_prompt")
```

---

## API Reference

### `sanitize_input_strict()`

**Signature**:
```bash
sanitize_input_strict <input> [max_len]
```

**Parameters**:
- `input` (required): User input string
- `max_len` (optional): Maximum length in bytes (default: 102400 / 100KB)

**Returns**:
- `0`: Success (sanitized input on stdout)
- `1`: Failure (error logged via `log_structured_error`)

**Allowed Characters**:
- Alphanumeric: `a-zA-Z0-9`
- Whitespace: space, tab, newline
- Safe punctuation: `. , ; : ! ? ' " ( ) [ ] { } / @ # % * + = _ -`
- Japanese/UTF-8: High-bit characters (0x80-0xFF)

**Blocked Patterns**:
- Command substitution: `$(...)`, `` `...` ``
- Variable expansion: `${...}`
- Command chaining: `&&`, `||`, `;`
- Redirection: `>`, `<`, `|`
- Dangerous commands: `eval`, `exec`, `source`, `rm -rf`
- System paths: `/dev/`, `/proc/`

**Example**:
```bash
# Valid input
sanitized=$(sanitize_input_strict "Hello World 123!")
# Output: "Hello World 123!"

# Invalid input (command injection)
sanitized=$(sanitize_input_strict "test\$(whoami)")
# Output: (none)
# Logs: ERROR: Input contains dangerous pattern: \$(

# Japanese input
sanitized=$(sanitize_input_strict "テスト文字列")
# Output: "テスト文字列"
```

---

## Testing

### Unit Tests

**File**: `tests/unit/test-sanitize.bats` (to be created in P0.2.2)

Required test coverage:
- [ ] Valid input (alphanumeric + safe punctuation)
- [ ] Invalid input (command injection patterns)
- [ ] Boundary values (0 bytes, 1 byte, 100KB-1, 100KB, 100KB+1)
- [ ] Unicode/Japanese characters
- [ ] Empty input
- [ ] Whitespace-only input
- [ ] Mixed safe + unsafe characters

**Test Execution**:
```bash
# Run sanitization tests
bats tests/unit/test-sanitize.bats --tap

# Expected: 25+ tests, 100% pass rate
```

### Integration Tests

**File**: `tests/integration/test-sanitization-migration.sh` (to be created in P1.1)

Scenarios:
- [ ] End-to-end CLI input flow
- [ ] Workflow prompt processing
- [ ] File-based prompt handling
- [ ] Error handling and recovery

---

## Security Validation

### Pre-Migration Checklist

- [x] `sanitize_input_strict()` implemented (P0.2.1)
- [x] Deprecation warnings added to `sanitize_input()` (P0.2.1)
- [ ] Unit tests created (P0.2.2)
- [ ] Integration tests created (P1.1)
- [ ] Security audit passed (P1.3)

### Post-Migration Verification

Run the comprehensive quality check:

```bash
source scripts/orchestrate/orchestrate-multi-ai.sh
multi-ai-quality-check --security --all
```

Expected results:
- ✅ No command injection vulnerabilities
- ✅ All sanitization tests pass
- ✅ 85-90% test coverage maintained
- ✅ Zero deprecation warnings

---

## Rollback Plan

If critical issues arise during migration:

### Immediate Rollback (P1.1-P1.2)

1. Revert code changes:
   ```bash
   git revert <migration-commit-sha>
   git push origin main
   ```

2. Remove deprecation warnings:
   ```bash
   # Edit multi-ai-core.sh
   # Comment out lines 244-248 (deprecation warning)
   ```

3. Notify team via issue tracker

### Long-term Support

- `sanitize_input()` will remain available for **minimum 6 months** after P1.3 completion
- Gradual transition period allows thorough testing
- Critical security patches will be backported to both functions

---

## Support and Resources

### Documentation

- Implementation Plan: `docs/P0_CRITICAL_FIX_PLAN.md`
- Security Guide: `CLAUDE.md` → Security section
- 7AI Review: `docs/7AI_COMPREHENSIVE_REVIEW.md` (if exists)

### Getting Help

1. Check existing tests: `tests/unit/test-multi-ai-core.bats`
2. Review function documentation: `scripts/orchestrate/lib/multi-ai-core.sh:316-422`
3. Run security validation: `/quality --security`
4. File issue: GitHub Issues (security-related issues marked 🔒)

### Migration Support Commands

```bash
# Find all sanitize_input() usages
grep -r "sanitize_input(" . --include="*.sh" --exclude-dir=tests

# Validate syntax after migration
bash -n <modified-file.sh>

# Run shellcheck
shellcheck <modified-file.sh>

# Test specific function
bats tests/unit/test-sanitize.bats --filter "sanitize_input_strict"
```

---

## Changelog

### v3.3.0 (P0.2.1 - 2025-10-25)

- ✅ Added `sanitize_input_strict()` with 3-layer security
- ✅ Deprecated `sanitize_input()` with migration warnings
- ✅ Created migration guide (this document)
- 📋 Pending: Unit tests (P0.2.2)
- 📋 Pending: Integration tests (P1.1)

### Future Releases

- v3.3.1 (P1.1): Critical input migration
- v3.3.2 (P1.2): Standard input migration
- v3.3.3 (P1.3): Migration complete, deprecation warnings removed

---

**Document Maintained By**: Multi-AI Orchestrium Team
**Last Updated**: 2025-10-25
**Next Review**: P1.1 Start Date
