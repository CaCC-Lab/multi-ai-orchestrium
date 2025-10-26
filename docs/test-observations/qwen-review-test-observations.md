# Test Observation Table: qwen-review.sh

**Script**: `scripts/qwen-review.sh`
**Version**: 1.0.0
**Purpose**: Code quality & design pattern review using Qwen3-Coder
**Created**: 2025-10-26

---

## 1. Equivalent Partitioning

### 1.1 CLI Arguments

| Parameter | Valid Classes | Invalid Classes |
|-----------|--------------|-----------------|
| `--timeout` | • Positive integers (1-3600)<br>• Default: 600 | • Negative numbers<br>• Zero<br>• Non-numeric strings<br>• Floats<br>• Very large (>10000) |
| `--commit` | • Valid commit hashes (short/full)<br>• HEAD<br>• Branch names<br>• Tags | • Non-existent commits<br>• Malformed hashes<br>• Empty strings<br>• Special chars (;, &, \|) |
| `--output` | • Valid directory paths<br>• Relative paths<br>• Absolute paths<br>• Default: logs/qwen-reviews | • Non-existent parent dir<br>• Read-only locations<br>• Paths with spaces |
| `--help` | • -h<br>• --help | • Other flags |

### 1.2 Environment State

| Category | Valid States | Invalid States |
|----------|-------------|----------------|
| Git Repository | • Valid git repo<br>• Clean working tree<br>• Dirty working tree | • Not a git repo<br>• Corrupted .git |
| Qwen Wrapper | • Executable script<br>• Correct permissions | • Missing script<br>• Non-executable<br>• Wrong path |
| Review Prompt | • Valid REVIEW-PROMPT.md<br>• Non-empty content | • Missing file<br>• Empty file<br>• Corrupted file |

### 1.3 Commit Diff Size

| Category | Description | Example |
|----------|-------------|---------|
| Empty | No changes | Empty commit |
| Small | 1-100 lines | Bug fix |
| Medium | 101-500 lines | Feature addition |
| Large | 501-2000 lines | Refactoring |
| Very Large | >2000 lines | Major rewrite |

### 1.4 Qwen Output Format

| Category | Valid Outputs | Invalid Outputs |
|----------|--------------|-----------------|
| JSON | • Valid JSON with findings<br>• Empty findings array<br>• Complete schema | • Malformed JSON<br>• Missing fields<br>• Incorrect types |
| Non-JSON | • Plain text analysis<br>• Markdown content | • Binary data<br>• Empty output |

---

## 2. Boundary Value Analysis

### 2.1 Timeout Parameter

| Test Case | Value | Expected Result |
|-----------|-------|-----------------|
| Minimum - 1 | 0 | ❌ Validation error: "Timeout must be greater than 0" |
| Minimum | 1 | ✅ Accept (very short timeout) |
| Minimum + 1 | 2 | ✅ Accept |
| Normal Low | 60 | ✅ Accept |
| Default | 600 | ✅ Accept |
| Normal High | 1800 | ✅ Accept |
| Maximum | 3600 | ✅ Accept |
| Maximum + 1 | 3601 | ✅ Accept (warning: very long) |
| Very Large | 100000 | ✅ Accept (system timeout may apply) |

### 2.2 Commit Hash Length

| Test Case | Hash Format | Expected Result |
|-----------|------------|-----------------|
| Too Short | abc (3 chars) | ❌ Git validation fails |
| Minimum | abcd (4 chars) | ✅ Accept (git minimum) |
| Short | 70d0347 (7 chars) | ✅ Accept (standard short) |
| Full | 70d0347abc...40 chars | ✅ Accept (full SHA-1) |
| Too Long | 41+ characters | ❌ Git validation fails |

### 2.3 Diff Content Size

| Test Case | Lines Changed | Expected Result |
|-----------|--------------|-----------------|
| Empty Diff | 0 lines | ✅ Accept (no changes to review) |
| Minimal | 1 line | ✅ Accept |
| Small | 50 lines | ✅ Accept |
| Medium | 500 lines | ✅ Accept |
| Large | 2000 lines | ✅ Accept (may truncate prompt) |
| Very Large | 10000+ lines | ✅ Accept (prompt truncation) |

### 2.4 Output Directory Path Length

| Test Case | Path Length | Expected Result |
|-----------|------------|-----------------|
| Empty | "" | ✅ Use default |
| Short | "out" (3 chars) | ✅ Accept |
| Normal | "logs/qwen-reviews" (17 chars) | ✅ Accept |
| Long | 100 characters | ✅ Accept |
| Very Long | 255 characters (PATH_MAX) | ✅ Accept (OS limit) |
| Too Long | 256+ characters | ❌ OS error |

---

## 3. Edge Cases

### 3.1 Git Repository Edge Cases

| Test Case | Scenario | Expected Behavior |
|-----------|----------|-------------------|
| Empty Repo | No commits | ❌ Error: "Commit not found: HEAD" |
| Initial Commit | Only 1 commit | ✅ Show diff against empty tree |
| Detached HEAD | Not on a branch | ✅ Accept commit hash |
| Shallow Clone | Limited history | ✅ Work with available commits |
| Submodule Changes | Submodule updates | ✅ Include in diff |
| Binary Files | Images, PDFs in diff | ✅ Show binary file markers |
| Merge Commit | Multiple parents | ✅ Show combined diff |
| Empty Commit | --allow-empty | ✅ Review empty diff |

### 3.2 File System Edge Cases

| Test Case | Scenario | Expected Behavior |
|-----------|----------|-------------------|
| Output Dir Exists | Directory pre-exists | ✅ Overwrite old files |
| Output Dir Missing | Parent doesn't exist | ❌ Error (mkdir -p bug - Droid found this!) |
| Read-only Output | No write permission | ❌ Error: "Permission denied" |
| Disk Full | No space left | ❌ Error: "No space left on device" |
| Symlink Output | Output is symlink | ✅ Follow symlink |
| Special Chars | Path with spaces/quotes | ✅ Handle with proper quoting |

### 3.3 Qwen Wrapper Edge Cases

| Test Case | Scenario | Expected Behavior |
|-----------|----------|-------------------|
| Wrapper Not Found | Missing bin/qwen-wrapper.sh | ❌ Prerequisites check fails |
| Wrapper Not Executable | chmod -x | ❌ Prerequisites check fails |
| Wrapper Timeout | Exceeds timeout limit | ❌ Timeout error, cleanup temp file |
| Wrapper Crashes | Exit code 139 (SIGSEGV) | ❌ Error handling, fallback report |
| Wrapper Returns Empty | No output | ✅ Generate fallback JSON |
| Wrapper Returns Non-JSON | Plain text | ✅ Parse keywords, generate fallback |
| Wrapper Returns Partial JSON | Truncated output | ❌ JSON parse error, use text fallback |

### 3.4 Content Edge Cases

| Test Case | Scenario | Expected Behavior |
|-----------|----------|-------------------|
| Unicode in Diff | Non-ASCII characters | ✅ Handle UTF-8 properly |
| Very Long Lines | 10000+ char line | ✅ Truncate in prompt |
| Control Characters | Tabs, newlines, null | ✅ Sanitize or escape |
| REVIEW-PROMPT.md Missing | File doesn't exist | ❌ Prerequisites check fails |
| REVIEW-PROMPT.md Empty | 0 bytes | ✅ Accept (empty guidelines) |
| REVIEW-PROMPT.md Large | 100KB+ | ✅ Include in prompt (may hit limit) |

---

## 4. Error Scenarios

### 4.1 Validation Errors

| Error Type | Trigger | Expected Error Message | Exit Code |
|------------|---------|----------------------|-----------|
| Invalid Timeout | --timeout abc | "Timeout must be a positive integer: abc" | 1 |
| Zero Timeout | --timeout 0 | "Timeout must be greater than 0: 0" | 1 |
| Unknown Option | --foo | "Unknown option: --foo" | 1 |

### 4.2 Prerequisites Errors

| Error Type | Trigger | Expected Error Message | Exit Code |
|------------|---------|----------------------|-----------|
| Wrapper Missing | mv bin/qwen-wrapper.sh | "Qwen wrapper not found at .../bin/qwen-wrapper.sh" | 1 |
| Not Git Repo | Run outside git | "Not in a git repository" | 1 |
| Commit Not Found | --commit abc123 | "Commit not found: abc123" | 1 |
| Prompt Missing | rm REVIEW-PROMPT.md | "REVIEW-PROMPT.md not found: ..." | 1 |

### 4.3 Execution Errors

| Error Type | Trigger | Expected Behavior | Exit Code |
|------------|---------|------------------|-----------|
| Timeout Exceeded | Very long analysis | Kill wrapper, cleanup temp file, error message | Non-zero |
| Wrapper Crash | Wrapper exits 1 | Log error, no output generated | Non-zero |
| JSON Parse Error | Malformed JSON | Fall back to text parsing, generate report | 0 (success with fallback) |
| Write Permission Error | Read-only output dir | Error message, no files created | 1 |

### 4.4 External Dependency Failures

| Error Type | Trigger | Expected Behavior | Exit Code |
|------------|---------|------------------|-----------|
| Git Command Fails | Corrupted repo | Error message from git | 1 |
| jq Not Available | jq not in PATH | Fallback to grep/sed parsing | 0 |
| mktemp Fails | /tmp full or read-only | Error message | 1 |
| Date Command Fails | Invalid system clock | Use fallback timestamp | 0 |

---

## 5. Test Execution Priorities

### Priority 0 (Critical - Must Pass)
- [ ] Valid commit with default options works
- [ ] Invalid commit hash fails gracefully
- [ ] Missing wrapper fails with clear error
- [ ] Timeout parameter validation works
- [ ] JSON output is generated for valid responses

### Priority 1 (High - Should Pass)
- [ ] Custom timeout is respected
- [ ] Custom output directory works
- [ ] Non-JSON response falls back correctly
- [ ] Empty diff is handled
- [ ] Large diff is handled

### Priority 2 (Medium - Nice to Have)
- [ ] Symlinks in output path work
- [ ] Unicode content is preserved
- [ ] Multiple rapid executions don't conflict
- [ ] Markdown report is human-readable

### Priority 3 (Low - Edge Cases)
- [ ] Very long file paths work
- [ ] Binary files in diff are handled
- [ ] Merge commits are processed
- [ ] Submodule changes are included

---

## 6. Coverage Requirements

### Branch Coverage Target: 100%

| Branch Type | Required Coverage |
|-------------|------------------|
| Argument parsing | All options and combinations |
| Validation checks | Valid and invalid paths |
| Prerequisites | Success and failure paths |
| Wrapper execution | Success, timeout, error |
| Output parsing | JSON, non-JSON, empty |
| Error handling | All catch blocks |
| Cleanup | Normal and exceptional exits |

### Function Coverage

| Function | Coverage Target | Critical Paths |
|----------|----------------|----------------|
| `parse_args()` | 100% | All options, unknown option |
| `validate_args()` | 100% | Valid/invalid timeout, commit |
| `check_prerequisites()` | 100% | All checks pass/fail |
| `execute_qwen_review()` | 100% | Success, timeout, error |
| `generate_fallback_json()` | 100% | Text extraction |
| `generate_markdown_report()` | 100% | All priority levels |
| `create_symlinks()` | 100% | Success path |

---

## 7. Test Data Requirements

### Required Test Commits

| Commit Type | Purpose | Creation Method |
|-------------|---------|----------------|
| Clean Code | No issues expected | Manual commit |
| Quality Issues | Trigger findings | Intentional bad code |
| Empty Commit | Test empty diff | git commit --allow-empty |
| Large Commit | Stress test | Multi-file changes |
| Binary Files | Non-text handling | Add images |

### Required Test Fixtures

| Fixture | Location | Purpose |
|---------|----------|---------|
| Mock Qwen JSON | tests/fixtures/qwen-valid.json | Valid response |
| Malformed JSON | tests/fixtures/qwen-malformed.json | Parse error |
| Plain Text | tests/fixtures/qwen-text.txt | Fallback scenario |
| Empty Output | tests/fixtures/qwen-empty.txt | Edge case |

---

## 8. Expected Test Results

### Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| Test Pass Rate | 100% | All tests pass |
| Branch Coverage | 100% | gcov/lcov report |
| Normal Case Time | <5s | Execution time |
| Edge Case Time | <10s | Execution time |
| Error Detection | 100% | All error paths tested |

### Failure Modes to Test

| Failure Type | Test Count | Examples |
|-------------|-----------|----------|
| Invalid Input | 10+ | Bad timeout, commit, path |
| Missing Dependencies | 5+ | No wrapper, git, prompt |
| Execution Failures | 5+ | Timeout, crash, empty |
| File System Errors | 5+ | Permissions, disk full |

---

**Test Observation Table Status**: ✅ Complete
**Total Test Scenarios**: 80+
**Estimated Test Code**: 500-700 lines
**Coverage Target**: 100% branch coverage
