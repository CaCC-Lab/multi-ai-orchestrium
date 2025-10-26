# Test Observation Table: amp-review.sh

**Script**: `scripts/amp-review.sh`
**Version**: 1.0.0
**Purpose**: Project management & documentation quality review using Amp
**Created**: 2025-10-26

---

## 1. Equivalent Partitioning

### 1.1 CLI Arguments

| Parameter | Valid Classes | Invalid Classes |
|-----------|--------------|-----------------|
| `--timeout` | • Positive integers (1-3600)<br>• Default: 600 | • Negative<br>• Zero<br>• Non-numeric |
| `--commit` | • Valid hashes<br>• HEAD<br>• Tags | • Non-existent<br>• Malformed |
| `--output` | • Valid paths<br>• Default: logs/amp-reviews | • Read-only<br>• Missing parent |
| `--help` | • -h<br>• --help | • Other flags |

### 1.2 Documentation Analysis Areas

| Category | Valid Targets | Invalid Targets |
|----------|--------------|----------------|
| README | • Complete README<br>• Usage examples | • Missing README<br>• Outdated |
| API Docs | • JSDoc/docstrings<br>• Type definitions | • No docs<br>• Incomplete |
| Comments | • Explanatory comments<br>• TODOs | • No comments<br>• Stale comments |
| Changelog | • Updated CHANGELOG<br>• Version notes | • Missing updates<br>• Vague entries |

### 1.3 Stakeholder Communication

| Category | Valid Examples | Invalid Examples |
|----------|---------------|------------------|
| Commit Messages | • Clear summary<br>• Context<br>• Breaking changes | • Vague<br>• No context<br>• Typos |
| PR Descriptions | • Problem statement<br>• Solution<br>• Testing | • Missing info<br>• Unclear |
| Release Notes | • User impact<br>• Migration guide | • Technical jargon<br>• No examples |

---

## 2. Boundary Value Analysis

### 2.1 Documentation Coverage

| Test Case | Coverage % | Expected Assessment |
|-----------|-----------|-------------------|
| No Docs | 0% | ❌ Critical PM issue |
| Minimal | 1-25% | ❌ Urgent improvement needed |
| Partial | 26-50% | ⚠️ Should improve |
| Good | 51-75% | ✅ Acceptable |
| Excellent | 76-100% | ✅ Well-documented |

### 2.2 Commit Message Quality

| Test Case | Message Length | Expected Result |
|-----------|---------------|-----------------|
| Too Short | <10 chars | ❌ Flag as unclear |
| Minimal | 10-20 chars | ⚠️ Could be clearer |
| Good | 21-50 chars | ✅ Acceptable |
| Detailed | 51-72 chars | ✅ Ideal |
| Too Long | >72 chars | ⚠️ Suggest line wrap |

---

## 3. Edge Cases

### 3.1 Documentation Scenarios

| Test Case | Scenario | Expected Behavior |
|-----------|----------|-------------------|
| New Feature, No Docs | Code added, no README update | ❌ Flag as P1 issue |
| Breaking Change, No Migration | API changed, no guide | ❌ Flag as P0 issue |
| TODO Comments Added | New TODOs in code | ⚠️ Flag for tracking |
| Outdated Examples | Examples don't work | ❌ Flag as documentation debt |
| Missing API Docs | Public functions undocumented | ⚠️ Flag as P2 issue |

### 3.2 Stakeholder Communication Cases

| Test Case | Scenario | Expected Behavior |
|-----------|----------|-------------------|
| Vague Commit | "fix stuff" | ❌ Flag as unclear |
| No Breaking Change Notice | Breaking change, no warning | ❌ Flag as P1 issue |
| Missing Test Plan | No testing information | ⚠️ Suggest adding |
| Technical Jargon | User-facing change with jargon | ⚠️ Suggest simplification |

### 3.3 Sprint Planning Cases

| Test Case | Scenario | Expected Behavior |
|-----------|----------|-------------------|
| Partial Implementation | Feature 50% done | ⚠️ Flag as incomplete |
| Scope Creep | Unrelated changes | ⚠️ Flag as off-track |
| Missing Dependencies | Depends on unfinished work | ❌ Flag as blocked |
| Technical Debt Added | Quick fix without proper solution | ⚠️ Flag debt increase |

---

## 4. Error Scenarios

### 4.1 Validation Errors

| Error Type | Trigger | Expected Error Message | Exit Code |
|------------|---------|----------------------|-----------|
| Invalid Timeout | --timeout abc | "Timeout must be a positive integer: abc" | 1 |
| Zero Timeout | --timeout 0 | "Timeout must be greater than 0" | 1 |
| Unknown Option | --foo | "Unknown option: --foo" | 1 |

### 4.2 Prerequisites Errors

| Error Type | Trigger | Expected Error Message | Exit Code |
|------------|---------|----------------------|-----------|
| Wrapper Missing | Missing amp-wrapper.sh | "Amp wrapper not found" | 1 |
| Not Git Repo | Outside git | "Not in a git repository" | 1 |
| Commit Not Found | Invalid hash | "Commit not found: ..." | 1 |

---

## 5. Test Execution Priorities

### Priority 0 (Critical)
- [ ] Missing documentation for new features is detected
- [ ] Breaking changes without migration guide flagged
- [ ] Vague commit messages identified
- [ ] Scope creep detected

### Priority 1 (High)
- [ ] README updates verified
- [ ] API documentation completeness checked
- [ ] Stakeholder communication clarity assessed
- [ ] Sprint alignment verified

### Priority 2 (Medium)
- [ ] Changelog updates tracked
- [ ] TODO comments cataloged
- [ ] Technical debt quantified
- [ ] Risk assessment performed

---

## 6. Expected Test Results

**Total Test Scenarios**: 60+
**Estimated Test Code**: 400-500 lines
**Coverage Target**: 100% branch coverage

---

**Status**: ✅ Complete
