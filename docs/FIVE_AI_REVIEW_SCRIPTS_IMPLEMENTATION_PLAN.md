# 5AI Review Scripts Implementation Plan

**Project**: Multi-AI Orchestrium - 5AI Review Scripts
**Version**: 1.0.0
**Created**: 2025-10-26
**Target Completion**: 2025-10-27

---

## 📋 Overview

このドキュメントは、REVIEW-PROMPT.mdを活用した5つのAI専用レビュースクリプトの実装計画です。各AIの特性を最大限に活かし、包括的なコードレビュー体制を構築します。

### 🎯 Target Scripts

| Script | AI | Specialization | Priority |
|--------|-----|----------------|----------|
| `gemini-review.sh` | Gemini 2.5 | Security & Architecture | ✅ **DONE** |
| `qwen-review.sh` | Qwen3-Coder | Code Quality & Patterns | ✅ **DONE** |
| `cursor-review.sh` | Cursor | IDE Integration & DX | ✅ **DONE** |
| `amp-review.sh` | Amp | Project Management & Docs | ✅ **DONE** |
| `droid-review.sh` | Droid | Enterprise Standards | ✅ **DONE** |

---

## 🏗️ Implementation Tasks

### Phase 1: Core Script Implementation

#### ✅ Task 1.1: gemini-review.sh (COMPLETED)
- [x] Script structure setup
- [x] REVIEW-PROMPT.md integration
- [x] VibeLogger integration
- [x] Security-focused prompt generation
- [x] JSON/Markdown output generation
- [x] Error handling
- [x] Help message and CLI args

#### ✅ Task 1.2: qwen-review.sh (COMPLETED)

**Focus**: Code quality, implementation patterns, HumanEval 93.9% accuracy

**Subtasks**:
- [x] 1.2.1 Script structure setup
  - [x] Shebang, set -euo pipefail
  - [x] Configuration variables
  - [x] Load sanitization library
  - [x] Setup output directories
- [x] 1.2.2 VibeLogger integration
  - [x] vibe_log() function
  - [x] vibe_tool_start() function
  - [x] vibe_tool_done() function
  - [x] vibe_code_quality_analysis() function (custom)
- [x] 1.2.3 CLI argument parsing
  - [x] --timeout option
  - [x] --commit option
  - [x] --output option
  - [x] --focus option (custom: patterns, quality, performance)
  - [x] --help option
- [x] 1.2.4 Prerequisites check
  - [x] Check qwen-wrapper.sh availability
  - [x] Check git repository
  - [x] Verify commit existence
  - [x] Check REVIEW-PROMPT.md
- [x] 1.2.5 Review prompt generation
  - [x] Load REVIEW-PROMPT.md
  - [x] Extract commit diff
  - [x] Create code quality analysis prompt
  - [x] Add design pattern detection
  - [x] Add performance optimization suggestions
  - [x] Add best practices verification
- [x] 1.2.6 Qwen wrapper execution
  - [x] Create secure temp file (chmod 600)
  - [x] Execute with timeout
  - [x] Capture stdout/stderr
  - [x] Handle JSON/text output
- [x] 1.2.7 Output parsing and generation
  - [x] Parse JSON findings
  - [x] Extract code quality metrics
  - [x] Generate JSON report
  - [x] Generate Markdown report
  - [x] Create symlinks (latest_qwen.json/md)
- [x] 1.2.8 Error handling
  - [x] Timeout handling
  - [x] Non-zero exit codes
  - [x] Fallback mechanisms
  - [x] Cleanup temp files (trap EXIT)
- [x] 1.2.9 Custom features
  - [x] Pattern library comparison
  - [x] Code complexity calculation
  - [x] Maintainability index
  - [x] Technical debt estimation

**Expected Output Files**:
- `logs/qwen-reviews/{timestamp}_{commit}_qwen.json`
- `logs/qwen-reviews/{timestamp}_{commit}_qwen.md`
- `logs/ai-coop/{YYYYMMDD}/qwen_review_{HH}.jsonl` (VibeLogger)

**Estimated Time**: 3-4 hours

---

#### ✅ Task 1.3: cursor-review.sh (COMPLETED)

**Focus**: IDE integration, developer experience, real-time code completion insights

**Subtasks**:
- [x] 1.3.1 Script structure setup
  - [x] Shebang, set -euo pipefail
  - [x] Configuration variables
  - [x] Load sanitization library
  - [x] Setup output directories
- [x] 1.3.2 VibeLogger integration
  - [x] vibe_log() function
  - [x] vibe_tool_start() function
  - [x] vibe_tool_done() function
  - [x] vibe_dx_analysis() function (custom)
- [x] 1.3.3 CLI argument parsing
  - [x] --timeout option
  - [x] --commit option
  - [x] --output option
  - [x] --focus option (custom: readability, ide-friendliness, completion)
  - [x] --help option
- [x] 1.3.4 Prerequisites check
  - [x] Check cursor-wrapper.sh availability
  - [x] Check git repository
  - [x] Verify commit existence
  - [x] Check REVIEW-PROMPT.md
- [x] 1.3.5 Review prompt generation
  - [x] Load REVIEW-PROMPT.md
  - [x] Extract commit diff
  - [x] Create developer experience analysis prompt
  - [x] Add code readability assessment
  - [x] Add IDE integration suggestions
  - [x] Add autocomplete-friendly patterns
  - [x] Add refactoring opportunities
- [x] 1.3.6 Cursor wrapper execution
  - [x] Create secure temp file (chmod 600)
  - [x] Execute with timeout
  - [x] Capture stdout/stderr
  - [x] Handle JSON/text output
- [x] 1.3.7 Output parsing and generation
  - [x] Parse JSON findings
  - [x] Extract DX metrics
  - [x] Generate JSON report
  - [x] Generate Markdown report
  - [x] Create symlinks (latest_cursor.json/md)
- [x] 1.3.8 Error handling
  - [x] Timeout handling
  - [x] Non-zero exit codes
  - [x] Fallback mechanisms
  - [x] Cleanup temp files (trap EXIT)
- [x] 1.3.9 Custom features
  - [x] Code readability score
  - [x] IDE navigation efficiency
  - [x] Autocomplete coverage
  - [x] Refactoring impact analysis

**Expected Output Files**:
- `logs/cursor-reviews/{timestamp}_{commit}_cursor.json`
- `logs/cursor-reviews/{timestamp}_{commit}_cursor.md`
- `logs/vibe/{YYYYMMDD}/cursor_review_{HH}.jsonl` (VibeLogger)

**Estimated Time**: 3-4 hours

---

#### ✅ Task 1.4: amp-review.sh (COMPLETED)

**Focus**: Project management, documentation quality, stakeholder communication

**Subtasks**:
- [x] 1.4.1 Script structure setup
  - [x] Shebang, set -euo pipefail
  - [x] Configuration variables
  - [x] Load sanitization library
  - [x] Setup output directories
- [x] 1.4.2 VibeLogger integration
  - [x] vibe_log() function
  - [x] vibe_tool_start() function
  - [x] vibe_tool_done() function
  - [x] vibe_pm_analysis() function (custom)
- [x] 1.4.3 CLI argument parsing
  - [x] --timeout option
  - [x] --commit option
  - [x] --output option
  - [x] --focus option (custom: docs, communication, planning)
  - [x] --help option
- [x] 1.4.4 Prerequisites check
  - [x] Check amp-wrapper.sh availability
  - [x] Check git repository
  - [x] Verify commit existence
  - [x] Check REVIEW-PROMPT.md
- [x] 1.4.5 Review prompt generation
  - [x] Load REVIEW-PROMPT.md
  - [x] Extract commit diff
  - [x] Create project management analysis prompt
  - [x] Add documentation quality assessment
  - [x] Add stakeholder impact analysis
  - [x] Add technical debt tracking
  - [x] Add sprint planning alignment
- [x] 1.4.6 Amp wrapper execution
  - [x] Create secure temp file (chmod 600)
  - [x] Execute with timeout
  - [x] Capture stdout/stderr
  - [x] Handle JSON/text output
- [x] 1.4.7 Output parsing and generation
  - [x] Parse JSON findings
  - [x] Extract PM metrics
  - [x] Generate JSON report
  - [x] Generate Markdown report
  - [x] Create symlinks (latest_amp.json/md)
- [x] 1.4.8 Error handling
  - [x] Timeout handling
  - [x] Non-zero exit codes
  - [x] Fallback mechanisms
  - [x] Cleanup temp files (trap EXIT)
- [x] 1.4.9 Custom features
  - [x] Documentation coverage score
  - [x] Stakeholder communication clarity
  - [x] Sprint alignment check
  - [x] Risk assessment

**Expected Output Files**:
- `logs/amp-reviews/{timestamp}_{commit}_amp.json`
- `logs/amp-reviews/{timestamp}_{commit}_amp.md`
- `logs/ai-coop/{YYYYMMDD}/amp_review_{HH}.jsonl` (VibeLogger)

**Estimated Time**: 3-4 hours

---

#### ✅ Task 1.5: droid-review.sh (COMPLETED)

**Focus**: Enterprise standards, comprehensive quality assurance, production readiness

**Subtasks**:
- [x] 1.5.1 Script structure setup
  - [x] Shebang, set -euo pipefail
  - [x] Configuration variables
  - [x] Load sanitization library
  - [x] Setup output directories
- [x] 1.5.2 VibeLogger integration
  - [x] vibe_log() function
  - [x] vibe_tool_start() function
  - [x] vibe_tool_done() function
  - [x] vibe_enterprise_analysis() function (custom)
- [x] 1.5.3 CLI argument parsing
  - [x] --timeout option
  - [x] --commit option
  - [x] --output option
  - [x] --focus option (custom: compliance, scalability, reliability)
  - [x] --compliance-mode flag
  - [x] --help option
- [x] 1.5.4 Prerequisites check
  - [x] Check droid-wrapper.sh availability
  - [x] Check git repository
  - [x] Verify commit existence
  - [x] Check REVIEW-PROMPT.md
- [x] 1.5.5 Review prompt generation
  - [x] Load REVIEW-PROMPT.md
  - [x] Extract commit diff
  - [x] Create enterprise standards analysis prompt
  - [x] Add compliance verification (GDPR, SOC2, HIPAA)
  - [x] Add scalability assessment
  - [x] Add reliability evaluation
  - [x] Add maintainability review
  - [x] Add production readiness checklist
- [x] 1.5.6 Droid wrapper execution
  - [x] Create secure temp file (chmod 600)
  - [x] Execute with timeout (900s default)
  - [x] Capture stdout/stderr
  - [x] Handle JSON/text output
- [x] 1.5.7 Output parsing and generation
  - [x] Parse JSON findings
  - [x] Extract enterprise metrics
  - [x] Generate JSON report
  - [x] Generate Markdown report
  - [x] Generate compliance report (if --compliance-mode)
  - [x] Create symlinks (latest_droid.json/md)
- [x] 1.5.8 Error handling
  - [x] Timeout handling
  - [x] Non-zero exit codes
  - [x] Fallback mechanisms
  - [x] Cleanup temp files (trap EXIT)
- [x] 1.5.9 Custom features
  - [x] Enterprise checklist scoring
  - [x] Compliance violation detection
  - [x] Scalability bottleneck identification
  - [x] SLA/SLO impact analysis
  - [x] Production deployment risk assessment

**Expected Output Files**:
- `logs/droid-reviews/{timestamp}_{commit}_droid.json`
- `logs/droid-reviews/{timestamp}_{commit}_droid.md`
- `logs/droid-reviews/{timestamp}_{commit}_droid_compliance.json` (if --compliance-mode)
- `logs/ai-coop/{YYYYMMDD}/droid_review_{HH}.jsonl` (VibeLogger)

**Estimated Time**: 4-5 hours

---

### Phase 2: Testing Infrastructure

#### ✅ Task 2.1: Test Observation Tables (COMPLETED)

**Subtasks**:
- [x] 2.1.1 Create test observation table for qwen-review.sh
  - [x] Equivalent partitioning
  - [x] Boundary value analysis
  - [x] Edge cases
  - [x] Error scenarios
- [x] 2.1.2 Create test observation table for cursor-review.sh
  - [x] Equivalent partitioning
  - [x] Boundary value analysis
  - [x] Edge cases
  - [x] Error scenarios
- [x] 2.1.3 Create test observation table for amp-review.sh
  - [x] Equivalent partitioning
  - [x] Boundary value analysis
  - [x] Edge cases
  - [x] Error scenarios
- [x] 2.1.4 Create test observation table for droid-review.sh
  - [x] Equivalent partitioning
  - [x] Boundary value analysis
  - [x] Edge cases
  - [x] Error scenarios

**Expected Output**: `docs/test-observations/` directory with 4 Markdown files ✅

**Estimated Time**: 2 hours
**Actual Time**: ~2 hours (2025-10-26 19:02 COMPLETED)

---

#### Task 2.2: Test Code Implementation

**Subtasks**:
- [ ] 2.2.1 Create test file structure
  - [ ] `tests/` directory
  - [ ] `tests/fixtures/` for test data
  - [ ] `tests/lib/test-helpers.sh` for common functions
- [ ] 2.2.2 Implement qwen-review.sh tests
  - [ ] Normal cases (happy path)
  - [ ] Abnormal cases (validation errors)
  - [ ] Boundary values (empty commit, huge diff, etc.)
  - [ ] Invalid inputs (non-existent commit, etc.)
  - [ ] External dependency failures (wrapper not found, timeout)
  - [ ] Exception verification
  - [ ] Given/When/Then comments
- [ ] 2.2.3 Implement cursor-review.sh tests
  - [ ] Normal cases
  - [ ] Abnormal cases
  - [ ] Boundary values
  - [ ] Invalid inputs
  - [ ] External dependency failures
  - [ ] Exception verification
  - [ ] Given/When/Then comments
- [ ] 2.2.4 Implement amp-review.sh tests
  - [ ] Normal cases
  - [ ] Abnormal cases
  - [ ] Boundary values
  - [ ] Invalid inputs
  - [ ] External dependency failures
  - [ ] Exception verification
  - [ ] Given/When/Then comments
- [ ] 2.2.5 Implement droid-review.sh tests
  - [ ] Normal cases
  - [ ] Abnormal cases
  - [ ] Boundary values
  - [ ] Invalid inputs
  - [ ] External dependency failures
  - [ ] Exception verification
  - [ ] Given/When/Then comments
- [ ] 2.2.6 Create test runner script
  - [ ] `tests/run-all-tests.sh`
  - [ ] Coverage report generation
  - [ ] Test result summary
- [ ] 2.2.7 Verify coverage
  - [ ] Ensure 100% branch coverage
  - [ ] Document uncovered branches (if any)

**Expected Output**:
- `tests/test-qwen-review.sh`
- `tests/test-cursor-review.sh`
- `tests/test-amp-review.sh`
- `tests/test-droid-review.sh`
- `tests/run-all-tests.sh`

**Coverage Target**: 100% branch coverage

**Estimated Time**: 8-10 hours

---

### Phase 3: Documentation

#### Task 3.1: User Documentation

**Subtasks**:
- [ ] 3.1.1 Update CLAUDE.md
  - [ ] Add 5AI review scripts section
  - [ ] Usage examples
  - [ ] Integration with existing workflows
- [ ] 3.1.2 Create FIVE_AI_REVIEW_GUIDE.md
  - [ ] Overview
  - [ ] When to use each script
  - [ ] Workflow recommendations
  - [ ] Output interpretation guide
- [ ] 3.1.3 Create individual script README files
  - [ ] `docs/reviews/gemini-review-guide.md`
  - [ ] `docs/reviews/qwen-review-guide.md`
  - [ ] `docs/reviews/cursor-review-guide.md`
  - [ ] `docs/reviews/amp-review-guide.md`
  - [ ] `docs/reviews/droid-review-guide.md`

**Expected Output**: 6 documentation files

**Estimated Time**: 3-4 hours

---

#### Task 3.2: Developer Documentation

**Subtasks**:
- [ ] 3.2.1 Create ARCHITECTURE.md
  - [ ] Script architecture overview
  - [ ] VibeLogger integration details
  - [ ] REVIEW-PROMPT.md usage
  - [ ] Output format specifications
- [ ] 3.2.2 Create CONTRIBUTING.md
  - [ ] How to add new review scripts
  - [ ] Testing guidelines
  - [ ] Code style requirements
- [ ] 3.2.3 Add inline code documentation
  - [ ] Function-level comments
  - [ ] Complex logic explanations
  - [ ] Security considerations

**Expected Output**: 2 documentation files + inline comments

**Estimated Time**: 2-3 hours

---

### Phase 4: Integration & Orchestration

#### Task 4.1: Multi-AI Review Orchestration

**Subtasks**:
- [ ] 4.1.1 Update multi-ai-review.sh
  - [ ] Add --ai option (gemini, qwen, cursor, amp, droid, all)
  - [ ] Parallel execution support
  - [ ] Unified report generation
- [ ] 4.1.2 Create review-dispatcher.sh
  - [ ] Automatic AI selection based on commit type
  - [ ] Security changes → Gemini
  - [ ] Code implementation → Qwen
  - [ ] UI/UX changes → Cursor
  - [ ] Documentation changes → Amp
  - [ ] Production release → Droid
- [ ] 4.1.3 Update quad-review workflow
  - [ ] Integrate 5AI reviews into quad-review
  - [ ] Comparison report generation

**Expected Output**:
- Updated `scripts/multi-ai-review.sh`
- New `scripts/review-dispatcher.sh`

**Estimated Time**: 4-5 hours

---

#### Task 4.2: CI/CD Integration

**Subtasks**:
- [ ] 4.2.1 Create GitHub Actions workflow
  - [ ] `.github/workflows/5ai-review.yml`
  - [ ] Trigger on PR creation
  - [ ] Run appropriate AI reviews
  - [ ] Comment results on PR
- [ ] 4.2.2 Create pre-commit hook
  - [ ] Quick review with Qwen (fastest)
  - [ ] Block commit on P0/P1 issues
- [ ] 4.2.3 Create pre-push hook
  - [ ] Full 5AI review
  - [ ] Generate summary report

**Expected Output**: 3 integration files

**Estimated Time**: 3-4 hours

---

## 📊 Testing Requirements

### Test Coverage Requirements

**Minimum Coverage**: 100% branch coverage

**Test Categories** (Equal weight to failures):

1. **Normal Cases** (20% of tests)
   - Happy path scenarios
   - Expected input/output
   - Default configurations

2. **Abnormal Cases** (40% of tests)
   - Validation errors
   - Invalid configurations
   - Permission errors
   - Resource unavailability

3. **Boundary Values** (20% of tests)
   - Zero values
   - Minimum/Maximum values
   - ±1 from boundaries
   - Empty strings/arrays
   - NULL/undefined

4. **Invalid Inputs** (10% of tests)
   - Wrong types
   - Malformed data
   - Injection attempts

5. **External Dependencies** (10% of tests)
   - Wrapper script failures
   - Timeout scenarios
   - Network failures (if applicable)

### Test Format

Every test must include:
```bash
test_function_name() {
    # Given: Initial state
    local commit="abc123"
    local timeout=600

    # When: Action performed
    local result=$(execute_review "$commit" "$timeout")

    # Then: Expected outcome
    assertEquals "Expected status" "success" "$result"
}
```

### Test Execution Commands

```bash
# Run all tests
bash tests/run-all-tests.sh

# Run specific script tests
bash tests/test-qwen-review.sh

# Generate coverage report
bash tests/run-all-tests.sh --coverage

# Run with verbose output
bash tests/run-all-tests.sh --verbose
```

---

## 🎯 Milestones

### Milestone 1: Core Implementation (Day 1) ✅ COMPLETE
- [x] qwen-review.sh complete
- [x] cursor-review.sh complete
- [x] amp-review.sh complete
- [x] droid-review.sh complete
- [x] Basic testing for all scripts

**Target**: 2025-10-26 EOD
**Actual**: 2025-10-26 18:50 (ACHIEVED)

---

### Milestone 2: Extended Implementation (Day 2) - ⚠️ PARTIALLY COMPLETE
- [x] amp-review.sh complete ✅ (2025-10-26)
- [x] droid-review.sh complete ✅ (2025-10-26)
- [x] All test observation tables complete ✅ (2025-10-26)
- [ ] 50% of test code complete (IN PROGRESS - Task 2.2)

**Target**: 2025-10-27 Noon
**Status**: 75% complete - ahead of schedule!

---

### Milestone 3: Testing & Documentation (Day 2 continued)
- [ ] 100% test code complete
- [ ] 100% branch coverage achieved
- [ ] All user documentation complete
- [ ] All developer documentation complete

**Target**: 2025-10-27 EOD

---

### Milestone 4: Integration (Day 3)
- [ ] Multi-AI orchestration complete
- [ ] CI/CD integration complete
- [ ] End-to-end testing complete
- [ ] Production deployment

**Target**: 2025-10-28 EOD

---

## 📈 Progress Tracking

### Overall Progress: 100% (5/5 scripts complete) ✅ PHASE 1 COMPLETE

| Script | Status | Progress | Estimated Completion |
|--------|--------|----------|---------------------|
| gemini-review.sh | ✅ Complete | 100% | 2025-10-26 |
| qwen-review.sh | ✅ Complete | 100% | 2025-10-26 |
| cursor-review.sh | ✅ Complete | 100% | 2025-10-26 |
| amp-review.sh | ✅ Complete | 100% | 2025-10-26 |
| droid-review.sh | ✅ Complete | 100% | 2025-10-26 |

### Testing Progress: 50% (Task 2.1 Complete)

| Category | Target | Completed | Coverage |
|----------|--------|-----------|----------|
| Test Observation Tables | 4 | 4 | ✅ 100% |
| Test Code Files | 4 | 0 | 0% |
| Branch Coverage | 100% | 0% | 0% |

### Documentation Progress: 0%

| Document | Status | Progress |
|----------|--------|----------|
| User Guides | ⏸️ Pending | 0% |
| Developer Docs | ⏸️ Pending | 0% |
| CLAUDE.md Update | ⏸️ Pending | 0% |

---

## 🚀 Next Actions

### Completed ✅
1. ✅ Create implementation plan (this file)
2. ✅ Create test observation tables (4 files)
3. ✅ Implement qwen-review.sh
4. ✅ Implement cursor-review.sh
5. ✅ Implement amp-review.sh
6. ✅ Implement droid-review.sh

### Immediate (Next 4 hours) - Task 2.2
7. 🔄 Create test file structure
8. 🔄 Implement qwen-review.sh tests
9. 🔄 Implement cursor-review.sh tests

### Today Evening (Next 4-6 hours)
10. Implement amp-review.sh tests
11. Implement droid-review.sh tests
12. Create test runner script
13. Verify 100% branch coverage

### Tomorrow
14. Complete documentation (Phase 3)
15. Integration & orchestration (Phase 4)
16. CI/CD integration

---

## 📝 Notes

### Design Decisions

1. **REVIEW-PROMPT.md**: All scripts use the same base prompt format for consistency
2. **VibeLogger**: All scripts log to separate hourly files for easier debugging
3. **Output Format**: JSON for machine parsing, Markdown for human reading
4. **Error Handling**: Graceful degradation with fallback mechanisms
5. **Security**: All temp files use chmod 600 and automatic cleanup

### Dependencies

- REVIEW-PROMPT.md (must exist)
- bin/*-wrapper.sh (AI-specific wrappers)
- scripts/lib/sanitize.sh (input validation)
- bin/vibe-logger-lib.sh (structured logging)

### Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| AI wrapper unavailable | Check prerequisites, provide clear error messages |
| Timeout issues | Configurable timeouts, graceful handling |
| Non-JSON output from AI | Fallback parsing, text extraction |
| Large diffs causing issues | Truncate to reasonable size, summarize |

---

**Last Updated**: 2025-10-26 20:00 JST
**Next Review**: 2025-10-27 (after Task 2.2 completion)
**Current Status**: Phase 1 COMPLETE ✅ | Task 2.1 COMPLETE ✅ | Task 2.2 IN PROGRESS 🔄
