# Multi-AI Orchestrium Test Suite

**Version**: 3.2.0
**Last Updated**: 2025-10-24
**Test Coverage**: 106 bats unit tests + 66 legacy tests + 12 E2E tests + Performance benchmarks
**Overall Pass Rate**: 99.1% (Unit: 99.1% [105/106], Phase 1: 100%, Phase 4: Partial)

## Table of Contents

1. [Quick Start](#quick-start)
2. [Test Organization](#test-organization)
3. [Running Tests](#running-tests)
4. [Test Suites](#test-suites)
5. [Expected Results](#expected-results)
6. [Troubleshooting](#troubleshooting)
7. [CI/CD Integration](#cicd-integration)

---

## Quick Start

```bash
# Navigate to project root
cd /path/to/multi-ai-orchestrium

# Run bats unit tests (NEW - fast, ~2 seconds)
bash tests/run-unit-tests.sh

# Run all Phase 1 unit tests (fast, ~30 seconds)
bash tests/phase1-file-based-prompt-test.sh

# Run Phase 4 E2E tests (slow, ~30-45 minutes with real AI calls)
bash tests/phase4-e2e-test.sh

# Run performance benchmarks
bash tests/performance-benchmark.sh

# Run entire test suite
bash tests/test_suite.sh
```

---

## Test Organization

### Test Structure

```
tests/
├── README.md                           # This file
├── run-unit-tests.sh                   # Bats unit test runner (NEW)
├── unit/                               # Bats unit tests (NEW)
│   ├── test-common-wrapper-lib.bats    # 20 tests for bin/common-wrapper-lib.sh
│   ├── test-multi-ai-core.bats         # 33 tests for scripts/orchestrate/lib/multi-ai-core.sh
│   ├── test-multi-ai-config.bats       # 31 tests for scripts/orchestrate/lib/multi-ai-config.sh
│   └── test-multi-ai-ai-interface.bats # 22 tests for scripts/orchestrate/lib/multi-ai-ai-interface.sh (NEW)
├── helpers/                            # Test helpers (NEW)
│   └── test_helper.bash                # Common setup/teardown
├── reports/                            # Test reports (NEW)
│   ├── unit-test-tap_*.tap             # TAP format results
│   └── unit-test-report_*.txt
├── phase1-file-based-prompt-test.sh    # Legacy unit tests (66 tests, 43KB)
├── phase1-integration-test.sh          # Integration tests (6.4KB)
├── phase4-e2e-test.sh                  # End-to-end tests (12 tests, 18KB)
├── performance-benchmark.sh            # Performance tests (4.2KB)
└── test_suite.sh                       # Test runner orchestrator (2.8KB)
```

### Test Categories

| Category | File | Tests | Duration | Prerequisites |
|----------|------|-------|----------|---------------|
| **Unit** | phase1-file-based-prompt-test.sh | 66 | ~30s | None |
| **Integration** | phase1-integration-test.sh | TBD | ~2min | None |
| **E2E** | phase4-e2e-test.sh | 12 | ~30-45min | AI CLI tools installed |
| **Performance** | performance-benchmark.sh | Benchmark | ~5min | AI CLI tools installed |

---

## Running Tests

### Phase 1: Unit Tests

**Purpose**: Test file-based prompt system functions in isolation.

**Coverage**:
- `supports_file_input()` - 8 tests
- `create_secure_prompt_file()` - 12 tests
- `cleanup_prompt_file()` - 6 tests
- `call_ai_with_context()` - 10 tests
- `sanitize_input()` - 15 tests (including 100KB+ prompts)
- `sanitize_input_for_file()` - 10 tests
- `call_ai()` backward compatibility - 5 tests

**Run**:
```bash
bash tests/phase1-file-based-prompt-test.sh
```

**Expected Output**:
```
============================================================================
PHASE 1 TEST SUITE - FILE-BASED PROMPT SYSTEM
============================================================================

[Test Suite 1] supports_file_input() - AI Capability Detection
[Test Suite 2] create_secure_prompt_file() - Secure File Creation
[Test Suite 3] cleanup_prompt_file() - Safe Cleanup
[Test Suite 4] call_ai_with_context() - Size-Based Routing
[Test Suite 5] sanitize_input() - Input Validation (Including Large Prompts)
[Test Suite 6] sanitize_input_for_file() - File-Safe Validation
[Test Suite 7] call_ai() - Backward Compatibility

Total Tests:  66
Passed:       66
Failed:       0
Skipped:      0
Pass Rate:    100%
```

### Phase 1: Integration Tests

**Purpose**: Test interactions between components.

**Run**:
```bash
bash tests/phase1-integration-test.sh
```

### Phase 4: End-to-End Tests

**Purpose**: Validate file-based prompt system with real AI workflows at scale.

**Coverage**:
1. 10KB prompt with `multi-ai-chatdev-develop` workflow
2. 50KB document with `multi-ai-coa-analyze` workflow
3. 100KB context with `multi-ai-5ai-orchestrate` workflow
4. Concurrent workflow execution (stress test)

**Prerequisites**:
- All 7 AI CLI tools installed: `claude`, `gemini`, `amp`, `qwen`, `droid`, `codex`, `cursor`
- AI tools accessible in PATH
- Valid AI API credentials configured

**Run**:
```bash
# Full E2E test suite (~30-45 minutes)
bash tests/phase4-e2e-test.sh

# View real-time logs
tail -f /tmp/phase4-e2e-tests/test-execution.log
```

**Success Criteria**:
- ✅ All workflows complete without errors
- ✅ Large prompts route through file-based system
- ✅ No performance regression vs command-line
- ✅ Concurrent execution handles file conflicts gracefully

### Performance Benchmarks

**Purpose**: Measure file I/O overhead and system performance.

**Run**:
```bash
bash tests/performance-benchmark.sh
```

**Metrics Measured**:
- File creation time (`mktemp`, `chmod 600`)
- Write performance (1KB, 10KB, 100KB, 1MB prompts)
- Cleanup time (`rm -f`)
- Parallel execution scalability (2, 5, 10 concurrent)

**Expected Results** (from Phase 7 verification):
| Prompt Size | File I/O Overhead | Notes |
|-------------|------------------|-------|
| 1KB | 2ms | Below file threshold (CLI used) |
| 10KB | 2ms | Constant time |
| 100KB | 4ms | Slight increase |
| 1MB | 25ms | Write time dominates |

### Test Suite Orchestrator

**Purpose**: Run all tests in sequence with summary report.

**Run**:
```bash
bash tests/test_suite.sh
```

**Output**: Combined results from all test categories.

---

## Test Suites

### Test Suite 1: supports_file_input()

**Tests**: AI capability detection

```bash
# Expected behavior
supports_file_input "claude"  # Returns 1 (use stdin redirect)
supports_file_input "gemini"  # Returns 1 (use stdin redirect)
```

**Why**: Currently all AIs use stdin redirect. Future: support --prompt-file flags.

### Test Suite 2: create_secure_prompt_file()

**Tests**: Secure temporary file creation

**Security Features Tested**:
- Unique filename generation (`mktemp`)
- Strict permissions (`chmod 600`)
- AI name in filename for debugging
- Error handling and fallback

**Example**:
```bash
prompt_file=$(create_secure_prompt_file "claude" "Test content")
# Expected: /tmp/prompt-claude-XXXXXX with mode 600
```

### Test Suite 3: cleanup_prompt_file()

**Tests**: Safe file deletion

**Scenarios**:
- Normal cleanup
- File already deleted (no error)
- Permission denied (warning only)
- Multiple cleanup calls (idempotent)

### Test Suite 4: call_ai_with_context()

**Tests**: Automatic size-based routing

**Routing Logic Tested**:
```
Prompt < 1KB  → Command-line arguments (fast)
Prompt >= 1KB → File-based routing (secure)
```

**Test Cases**:
- 100 byte prompt (CLI)
- 500 byte prompt (CLI)
- 1024 byte prompt (file-based)
- 10KB prompt (file-based)
- 100KB prompt (file-based with relaxed sanitization)

### Test Suite 5: sanitize_input()

**Tests**: Input validation with size-based rules

**Validation Layers**:
1. **Small prompts (<2KB)**: Strict character filtering
2. **Medium prompts (2KB-100KB)**: Relaxed filtering
3. **Large prompts (>100KB)**: File-only validation

**Critical Tests**:
- T5.15: 100KB+ prompts pass validation
- Command injection prevention
- Path traversal blocking
- Empty input rejection

### Test Suite 6: sanitize_input_for_file()

**Tests**: File-safe input validation

**Protection Against**:
- Path traversal (`../../../etc/passwd`)
- Absolute paths (`/etc/passwd`, `/bin/sh`)
- Shell metacharacters (allows Markdown, JSON, code)

### Test Suite 7: call_ai()

**Tests**: Backward compatibility wrapper

**Validates**:
- Existing `call_ai()` calls still work
- Proper delegation to `call_ai_with_context()`
- No breaking changes in API

---

## Expected Results

### Phase 1 Unit Tests

```
Total Tests:  66
Passed:       66
Failed:       0
Skipped:      0
Pass Rate:    100%
```

**Known Issues**: None (all tests passing as of v3.2.0)

### Phase 4 E2E Tests

```
Total Tests:  12
Passed:       10-12 (varies by AI availability)
Failed:       0-2
Pass Rate:    83-100%
```

**Known Issues**:
- CoA analyze workflow may fail if AI tools timeout
- Requires all 7 AI CLIs installed and configured
- Network connectivity required for AI API calls

### Performance Benchmarks

**Expected Overhead**: <200ms for prompts up to 1MB

**Targets**:
- File creation: <5ms
- Write 10KB: <10ms
- Write 100KB: <50ms
- Cleanup: <5ms

---

## Troubleshooting

### Common Issues

#### Issue: "AI tool not found"

**Cause**: AI CLI not installed or not in PATH

**Solution**:
```bash
# Check AI tool availability
command -v claude
command -v gemini
command -v qwen

# Install missing tools
# (Instructions vary by AI tool)
```

#### Issue: Tests fail with "Permission denied"

**Cause**: `/tmp` not writable or test files not executable

**Solution**:
```bash
# Check /tmp permissions
touch /tmp/test && rm /tmp/test

# Make test files executable
chmod +x tests/*.sh

# Check disk space
df -h /tmp
```

#### Issue: "Failed to create temporary file"

**Cause**: `/tmp` full or permissions issue

**Solution**:
```bash
# Free up space
df -h /tmp
rm -f /tmp/prompt-*

# Use alternative TMPDIR
export TMPDIR=/home/user/tmp
mkdir -p $TMPDIR
chmod 700 $TMPDIR
```

#### Issue: Phase 4 E2E tests timeout

**Cause**: AI API calls taking longer than expected

**Solution**:
```bash
# Increase timeout in test configuration
# Edit tests/phase4-e2e-test.sh
# Change: TEST_TIMEOUT=600
# To: TEST_TIMEOUT=1800  # 30 minutes
```

#### Issue: "Prompt too long" error

**Cause**: Old version of sanitize_input() doesn't support large prompts

**Solution**: Verify you're on v3.2.0+
```bash
grep "sanitize_input_for_file" scripts/orchestrate/lib/multi-ai-core.sh
# Should exist if v3.2.0+
```

### Debug Mode

Enable verbose logging for debugging:

```bash
# VibeLogger debug mode
export VIBELOGGER_DEBUG=1

# Bash trace mode
bash -x tests/phase1-file-based-prompt-test.sh

# Keep temporary files (skip cleanup)
export SKIP_CLEANUP=1
bash tests/phase1-file-based-prompt-test.sh
ls /tmp/prompt-*
```

### Test Logs

Test execution logs are saved to:

```bash
# Phase 4 E2E logs
/tmp/phase4-e2e-tests/test-execution.log

# Performance benchmark results
/tmp/performance-benchmark-YYYYMMDD.log

# VibeLogger structured logs
logs/vibe/YYYYMMDD/*.jsonl
```

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Phase 1 Unit Tests
        run: bash tests/phase1-file-based-prompt-test.sh
      - name: Check pass rate
        run: |
          if [ $? -ne 0 ]; then
            echo "Unit tests failed"
            exit 1
          fi

  e2e-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v3
      - name: Install AI CLIs
        run: |
          # Install your AI CLIs here
          npm install -g @anthropics/claude-cli
          # ... other AI tools
      - name: Run E2E Tests
        run: bash tests/phase4-e2e-test.sh
        timeout-minutes: 60
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running Phase 1 unit tests..."
bash tests/phase1-file-based-prompt-test.sh

if [ $? -ne 0 ]; then
    echo "Tests failed. Commit aborted."
    exit 1
fi

echo "All tests passed!"
exit 0
```

---

## Test Development Guidelines

### Adding New Tests

1. **Choose appropriate test file**:
   - Unit tests → `phase1-file-based-prompt-test.sh`
   - E2E tests → `phase4-e2e-test.sh`
   - Performance → `performance-benchmark.sh`

2. **Follow naming convention**:
   ```bash
   test_descriptive_name() {
       # Test implementation
   }
   ```

3. **Use assertion functions**:
   ```bash
   assert_equals "expected" "$actual" "Test description"
   assert_file_exists "/tmp/prompt-file"
   assert_exit_code 0 "call_ai_with_context 'claude' 'test' 300"
   ```

4. **Document test purpose**:
   ```bash
   # Test Suite 8: New Feature Tests
   # Purpose: Validate new feature XYZ
   # Coverage: ...
   ```

### Test Maintenance

- Update test specifications in `docs/test-plans/` when adding tests
- Keep this README synchronized with test changes
- Review and update expected results after major releases
- Archive old test versions in `docs/test-plans/archive/`

---

## Additional Resources

- **Test Specifications**: `docs/test-plans/phase1-test-specification.md`
- **File-Based Prompt System Docs**: `docs/FILE_BASED_PROMPT_SYSTEM.md`
- **Implementation Plan**: `docs/IMPLEMENTATION_PLAN_PHASE9.md`
- **Bug Reports**: Create issues at project repository
- **Performance Metrics**: `CHANGELOG.md` (Phase 7 benchmark data)

---

**Document Version**: 1.0
**Authors**: Multi-AI Development Team
**Maintainer**: Claude 4 (CTO)
**Support**: Open an issue or contact maintainers
