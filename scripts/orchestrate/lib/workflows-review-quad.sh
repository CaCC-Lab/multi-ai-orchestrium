#!/usr/bin/env bash
# Multi-AI Quad Review Workflow Library
# Purpose: 4-tool automated review workflow (Codex + CodeRabbit + Claude comprehensive + Claude security)
# Responsibilities:
#   - quad-review: 4 automated reviews + 6AI collaborative analysis
#
# Dependencies:
#   - lib/multi-ai-core.sh (logging, utilities, phase management, VibeLogger)
#   - lib/multi-ai-ai-interface.sh (call_ai_with_context function)
#   - scripts/codex-review.sh (Codex automated review)
#   - scripts/coderabbit-review.sh (CodeRabbit automated review)
#   - scripts/claude-review.sh (Claude comprehensive review)
#   - scripts/claude-security-review.sh (Claude security review)
#
# Usage:
#   source scripts/orchestrate/lib/workflows-review-quad.sh
#   multi-ai-quad-review "レビュー対象の説明"

set -euo pipefail

# ============================================================================
# Global State & Helpers (cleanup + fallback management)
# ============================================================================

declare -ag QUAD_REVIEW_PHASE1_PIDS=()
declare -ag QUAD_REVIEW_PHASE2_PIDS=()
declare -g QUAD_REVIEW_CLEANUP_REGISTERED=0
declare -g QUAD_REVIEW_MANUAL_FALLBACK_COMPLETED=0
declare -g QUAD_REVIEW_MANUAL_FALLBACK_EXIT_CODE=0
: "${QUAD_REVIEW_ENABLE_MANUAL_FALLBACK:=1}"

_quad_review_cleanup_background_jobs() {
    local pid cleaned=false
    local all_pids=("${QUAD_REVIEW_PHASE1_PIDS[@]:-}" "${QUAD_REVIEW_PHASE2_PIDS[@]:-}")

    for pid in "${all_pids[@]}"; do
        if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
            cleaned=true
            log_warning "Terminating active quad review background process (PID: $pid)"
            kill "$pid" 2>/dev/null || true
        fi
    done

    if $cleaned && [ "${#all_pids[@]}" -gt 0 ]; then
        wait "${all_pids[@]}" 2>/dev/null || true
    fi
}

_quad_review_register_cleanup_handler() {
    if [[ "${QUAD_REVIEW_CLEANUP_REGISTERED:-0}" -eq 1 ]]; then
        return 0
    fi

    if declare -f add_cleanup_handler >/dev/null 2>&1; then
        add_cleanup_handler "_quad_review_cleanup_background_jobs"
    else
        trap '_quad_review_cleanup_background_jobs' EXIT INT TERM
    fi

    QUAD_REVIEW_CLEANUP_REGISTERED=1
    return 0
}

_quad_review_remove_pid_from_array() {
    local pid="$1"
    local array_name="$2"

    if ! declare -p "$array_name" >/dev/null 2>&1; then
        return 0
    fi

    local -n array_ref="$array_name"
    local updated=()

    for existing in "${array_ref[@]:-}"; do
        if [[ "$existing" != "$pid" ]]; then
            updated+=("$existing")
        fi
    done

    array_ref=("${updated[@]}")
    return 0
}

_quad_review_track_pid() {
    local pid="$1"
    local phase="$2"

    _quad_review_register_cleanup_handler

    case "$phase" in
        phase1)
            QUAD_REVIEW_PHASE1_PIDS+=("$pid")
            ;;
        phase2)
            QUAD_REVIEW_PHASE2_PIDS+=("$pid")
            ;;
        *)
            log_warning "Unknown quad review phase for PID tracking: $phase ($pid)"
            ;;
    esac
}

_quad_review_mark_pid_complete() {
    local pid="$1"
    local phase="$2"

    case "$phase" in
        phase1)
            _quad_review_remove_pid_from_array "$pid" QUAD_REVIEW_PHASE1_PIDS
            ;;
        phase2)
            _quad_review_remove_pid_from_array "$pid" QUAD_REVIEW_PHASE2_PIDS
            ;;
    esac
}

_quad_review_trigger_manual_fallback() {
    local reason="$1"
    local project_root="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
    local manual_script="$project_root/scripts/manual-quad-review.sh"

    if [[ "${QUAD_REVIEW_ENABLE_MANUAL_FALLBACK:-1}" != "1" ]]; then
        return 1
    fi

    if [ ! -x "$manual_script" ]; then
        log_error "Manual quad review script not executable: $manual_script"
        return 1
    fi

    log_warning "Triggering manual quad review fallback ($reason)"
    local manual_exit_code=0
    if bash "$manual_script"; then
        manual_exit_code=0
        log_success "Manual quad review completed successfully (fallback path)"
    else
        manual_exit_code=$?
        log_error "Manual quad review fallback failed (exit code: $manual_exit_code)"
    fi

    QUAD_REVIEW_MANUAL_FALLBACK_COMPLETED=1
    QUAD_REVIEW_MANUAL_FALLBACK_EXIT_CODE=$manual_exit_code

    return "$manual_exit_code"
}

_quad_review_handle_failure() {
    local reason="$1"
    local default_exit="${2:-1}"
    local fallback_exit=0

    if _quad_review_trigger_manual_fallback "$reason"; then
        return 0
    else
        fallback_exit=$?
        if [ "$fallback_exit" -gt 1 ]; then
            return "$fallback_exit"
        fi
    fi

    return "$default_exit"
}

# ============================================================================
# Helper Functions for Phase 2 (6AI Collaborative Analysis)
# ============================================================================

# Gemini: セキュリティ検証
_quad_review_gemini() {
    local quad_context="$1"
    local output_file="$2"

    # Source required libraries
    source "$(dirname "${BASH_SOURCE[0]}")/multi-ai-core.sh"
    source "$(dirname "${BASH_SOURCE[0]}")/multi-ai-ai-interface.sh"

    local result
    # Non-interactive mode for automated workflow (bypass approval prompts)
    WRAPPER_NON_INTERACTIVE=1 result=$(call_ai_with_context "gemini" "セキュリティ観点からレビュー結果を検証:
$quad_context" 600)
    echo "$result" > "$output_file"
}

# Amp: メンテナンス性評価
_quad_review_amp() {
    local quad_context="$1"
    local output_file="$2"

    source "$(dirname "${BASH_SOURCE[0]}")/multi-ai-core.sh"
    source "$(dirname "${BASH_SOURCE[0]}")/multi-ai-ai-interface.sh"

    local result
    # Non-interactive mode for automated workflow (bypass approval prompts)
    WRAPPER_NON_INTERACTIVE=1 result=$(call_ai_with_context "amp" "メンテナンス性の観点からレビュー結果を評価:
$quad_context" 600)
    echo "$result" > "$output_file"
}

# Qwen: 代替実装提案
_quad_review_qwen() {
    local quad_context="$1"
    local output_file="$2"

    source "$(dirname "${BASH_SOURCE[0]}")/multi-ai-core.sh"
    source "$(dirname "${BASH_SOURCE[0]}")/multi-ai-ai-interface.sh"

    local result
    # Non-interactive mode for automated workflow (bypass approval prompts)
    WRAPPER_NON_INTERACTIVE=1 result=$(call_ai_with_context "qwen" "指摘された問題の代替実装を提案:
$quad_context" 600)
    echo "$result" > "$output_file"
}

# Droid: エンタープライズ基準評価
_quad_review_droid() {
    local quad_context="$1"
    local output_file="$2"

    source "$(dirname "${BASH_SOURCE[0]}")/multi-ai-core.sh"
    source "$(dirname "${BASH_SOURCE[0]}")/multi-ai-ai-interface.sh"

    local result
    # Non-interactive mode for automated workflow (bypass approval prompts)
    WRAPPER_NON_INTERACTIVE=1 result=$(call_ai_with_context "droid" "エンタープライズ基準の観点から評価:
$quad_context" 900)
    echo "$result" > "$output_file"
}

# Codex: 最適化提案
_quad_review_codex() {
    local quad_context="$1"
    local output_file="$2"

    source "$(dirname "${BASH_SOURCE[0]}")/multi-ai-core.sh"
    source "$(dirname "${BASH_SOURCE[0]}")/multi-ai-ai-interface.sh"

    local result
    # Non-interactive mode for automated workflow (bypass approval prompts)
    WRAPPER_NON_INTERACTIVE=1 result=$(call_ai_with_context "codex" "4つのレビュー結果を分析し、最適化提案を提供:
$quad_context" 600)
    echo "$result" > "$output_file"
}

# Cursor: 開発者体験評価
_quad_review_cursor() {
    local quad_context="$1"
    local output_file="$2"

    source "$(dirname "${BASH_SOURCE[0]}")/multi-ai-core.sh"
    source "$(dirname "${BASH_SOURCE[0]}")/multi-ai-ai-interface.sh"

    local result
    # Non-interactive mode for automated workflow (bypass approval prompts)
    WRAPPER_NON_INTERACTIVE=1 result=$(call_ai_with_context "cursor" "開発者体験の観点からレビュー結果を評価:
$quad_context" 600)
    echo "$result" > "$output_file"
}

# ============================================================================
# Quad Review Functions (1 function)
# ============================================================================

# Multi-AI Quad Review (4-Tool Automated Review Integration)
# Codex + CodeRabbit + Claude comprehensive + Claude security + 6AI collaborative analysis
multi-ai-quad-review() {
    local description="${*:-最新コミットの4ツール統合レビュー}"
    local start_time=$(get_timestamp_ms)
    local timeout_margin=${QUAD_REVIEW_TIMEOUT_MARGIN_SECONDS:-100}
    local codex_tool_timeout=${QUAD_REVIEW_CODEX_TIMEOUT_SECONDS:-600}
    local coderabbit_tool_timeout=${QUAD_REVIEW_CODERABBIT_TIMEOUT_SECONDS:-900}
    local claude_comp_tool_timeout=${QUAD_REVIEW_CLAUDE_COMPREHENSIVE_TIMEOUT_SECONDS:-600}
    local claude_sec_tool_timeout=${QUAD_REVIEW_CLAUDE_SECURITY_TIMEOUT_SECONDS:-900}
    local codex_hard_timeout=${QUAD_REVIEW_CODEX_HARD_TIMEOUT_SECONDS:-$((codex_tool_timeout + timeout_margin))}
    local coderabbit_hard_timeout=${QUAD_REVIEW_CODERABBIT_HARD_TIMEOUT_SECONDS:-$((coderabbit_tool_timeout + timeout_margin))}
    local claude_comp_hard_timeout=${QUAD_REVIEW_CLAUDE_COMPREHENSIVE_HARD_TIMEOUT_SECONDS:-$((claude_comp_tool_timeout + timeout_margin))}
    local claude_sec_hard_timeout=${QUAD_REVIEW_CLAUDE_SECURITY_HARD_TIMEOUT_SECONDS:-$((claude_sec_tool_timeout + timeout_margin))}

    QUAD_REVIEW_PHASE1_PIDS=()
    QUAD_REVIEW_PHASE2_PIDS=()
    QUAD_REVIEW_MANUAL_FALLBACK_COMPLETED=0
    QUAD_REVIEW_MANUAL_FALLBACK_EXIT_CODE=0
    _quad_review_register_cleanup_handler || true

    # P1-1: Input sanitization
    description=$(sanitize_input "$description") || return 1

    if ! command -v timeout >/dev/null 2>&1; then
        log_error "timeout command not found. Install GNU coreutils to enable quad review orchestration."
        return 1
    fi

    show_multi_ai_banner
    log_info "Review Description: $description"
    log_info "Profile: balanced-multi-ai (quad-review workflow)"
    log_info "Mode: Quad automated review (Codex + CodeRabbit + Claude comprehensive + Claude security) + 6AI collaborative analysis"
    echo ""

    # VibeLogger: pipeline.start
    vibe_pipeline_start "multi-ai-quad-review" "$description" "3"

    # P1-2: Setup work directory - persistent logs for audit trail
    local WORK_DIR="$PROJECT_ROOT/logs/multi-ai-reviews/$(date +%Y%m%d-%H%M%S)-$$-quad-review"
    local OUTPUT_DIR="$WORK_DIR/output"
    mkdir -p "$OUTPUT_DIR"
    log_info "Work directory: $WORK_DIR (logs will be preserved)"

    # PHASE 1: 4つの自動レビュー（並列実行、max_parallel_jobs=4を尊重）
    log_phase "Phase 1: Quad Automated Reviews (4 tools in parallel)"
    local phase1_start=$(get_timestamp_ms)

    # VibeLogger: phase.start
    vibe_phase_start "Quad Automated Reviews" "1" "4"

    log_info "Executing 4 automated reviews in parallel..."
    log_info "  1. Codex automated review (${codex_tool_timeout}s tool / ${codex_hard_timeout}s hard timeout)"
    log_info "  2. CodeRabbit automated review (${coderabbit_tool_timeout}s tool / ${coderabbit_hard_timeout}s hard timeout)"
    log_info "  3. Claude comprehensive review (${claude_comp_tool_timeout}s tool / ${claude_comp_hard_timeout}s hard timeout)"
    log_info "  4. Claude security review (${claude_sec_tool_timeout}s tool / ${claude_sec_hard_timeout}s hard timeout)"
    echo ""

    # Output directories for each tool
    local codex_dir="$OUTPUT_DIR/codex"
    local coderabbit_dir="$OUTPUT_DIR/coderabbit"
    local claude_comp_dir="$OUTPUT_DIR/claude_comprehensive"
    local claude_sec_dir="$OUTPUT_DIR/claude_security"
    mkdir -p "$codex_dir" "$coderabbit_dir" "$claude_comp_dir" "$claude_sec_dir"
    local codex_log="$codex_dir/execution.log"
    local coderabbit_log="$coderabbit_dir/execution.log"
    local claude_comp_log="$claude_comp_dir/execution.log"
    local claude_sec_log="$claude_sec_dir/execution.log"

    # 1. Codex Review (background with timeout)
    local codex_pid
    log_info "[1/4] Starting Codex review..."
    (
        local review_script="$PROJECT_ROOT/scripts/codex-review.sh"
        if [ -f "$review_script" ]; then
            # Set up proper environment and run with timeout
            export CODEX_REVIEW_TIMEOUT=$codex_tool_timeout
            export OUTPUT_DIR="$codex_dir"
            local exit_code=0
            timeout "$codex_hard_timeout" bash -c "cd '$PROJECT_ROOT' && bash '$review_script'" \
                > "$codex_log" 2>&1 || exit_code=$?
            # Ensure exit code is properly returned even after timeout
            if [ "${exit_code:-0}" -ne 0 ]; then
                exit $exit_code
            fi
        else
            log_warning "Codex review script not found: $review_script"
            exit 1
        fi
    ) &
    codex_pid=$!
    _quad_review_track_pid "$codex_pid" "phase1"

    # 2. CodeRabbit Review (background with timeout)
    local coderabbit_pid
    log_info "[2/4] Starting CodeRabbit review..."
    (
        local review_script="$PROJECT_ROOT/scripts/coderabbit-review.sh"
        if [ -f "$review_script" ]; then
            # Set up proper environment and run with timeout
            export CODERABBIT_REVIEW_TIMEOUT=$coderabbit_tool_timeout
            export OUTPUT_DIR="$coderabbit_dir"
            local exit_code=0
            timeout "$coderabbit_hard_timeout" bash -c "cd '$PROJECT_ROOT' && bash '$review_script'" \
                > "$coderabbit_log" 2>&1 || exit_code=$?
            # Ensure exit code is properly returned even after timeout
            if [ "${exit_code:-0}" -ne 0 ]; then
                exit $exit_code
            fi
        else
            log_warning "CodeRabbit review script not found: $review_script"
            exit 1
        fi
    ) &
    coderabbit_pid=$!
    _quad_review_track_pid "$coderabbit_pid" "phase1"

    # 3. Claude Comprehensive Review (background with timeout)
    local claude_comp_pid
    log_info "[3/4] Starting Claude comprehensive review..."
    (
        local review_script="$PROJECT_ROOT/scripts/claude-review.sh"
        if [ -f "$review_script" ]; then
            # Set up proper environment and run with timeout
            export CLAUDE_REVIEW_TIMEOUT=$claude_comp_tool_timeout
            export OUTPUT_DIR="$claude_comp_dir"
            local exit_code=0
            timeout "$claude_comp_hard_timeout" bash -c "cd '$PROJECT_ROOT' && bash '$review_script'" \
                > "$claude_comp_log" 2>&1 || exit_code=$?
            # Ensure exit code is properly returned even after timeout
            if [ "${exit_code:-0}" -ne 0 ]; then
                exit $exit_code
            fi
        else
            log_warning "Claude comprehensive review script not found: $review_script"
            exit 1
        fi
    ) &
    claude_comp_pid=$!
    _quad_review_track_pid "$claude_comp_pid" "phase1"

    # 4. Claude Security Review (background with timeout)
    local claude_sec_pid
    log_info "[4/4] Starting Claude security review..."
    (
        local review_script="$PROJECT_ROOT/scripts/claude-security-review.sh"
        if [ -f "$review_script" ]; then
            # Set up proper environment and run with timeout
            export CLAUDE_SECURITY_REVIEW_TIMEOUT=$claude_sec_tool_timeout
            export OUTPUT_DIR="$claude_sec_dir"
            local exit_code=0
            timeout "$claude_sec_hard_timeout" bash -c "cd '$PROJECT_ROOT' && bash '$review_script'" \
                > "$claude_sec_log" 2>&1 || exit_code=$?
            # Ensure exit code is properly returned even after timeout
            if [ "${exit_code:-0}" -ne 0 ]; then
                exit $exit_code
            fi
        else
            log_warning "Claude security review script not found: $review_script"
            exit 1
        fi
    ) &
    claude_sec_pid=$!
    _quad_review_track_pid "$claude_sec_pid" "phase1"

    # Wait for all 4 reviews to complete (check each individually for proper error handling)
    log_info "Waiting for all 4 automated reviews to complete..."

    local phase1_failed=false
    local failed_reviews=()
    
    if ! wait $codex_pid; then
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_error "Codex review timed out (${codex_hard_timeout}s). See $codex_log"
        else
            log_error "Codex review failed (exit code: $exit_code). See $codex_log"
        fi
        phase1_failed=true
        failed_reviews+=("codex")
    fi
    _quad_review_mark_pid_complete "$codex_pid" "phase1"
    
    if ! wait $coderabbit_pid; then
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_error "CodeRabbit review timed out (${coderabbit_hard_timeout}s). See $coderabbit_log"
        else
            log_error "CodeRabbit review failed (exit code: $exit_code). See $coderabbit_log"
        fi
        phase1_failed=true
        failed_reviews+=("coderabbit")
    fi
    _quad_review_mark_pid_complete "$coderabbit_pid" "phase1"
    
    if ! wait $claude_comp_pid; then
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_error "Claude comprehensive review timed out (${claude_comp_hard_timeout}s). See $claude_comp_log"
        else
            log_error "Claude comprehensive review failed (exit code: $exit_code). See $claude_comp_log"
        fi
        phase1_failed=true
        failed_reviews+=("claude_comprehensive")
    fi
    _quad_review_mark_pid_complete "$claude_comp_pid" "phase1"
    
    if ! wait $claude_sec_pid; then
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_error "Claude security review timed out (${claude_sec_hard_timeout}s). See $claude_sec_log"
        else
            log_error "Claude security review failed (exit code: $exit_code). See $claude_sec_log"
        fi
        phase1_failed=true
        failed_reviews+=("claude_security")
    fi
    _quad_review_mark_pid_complete "$claude_sec_pid" "phase1"

    if [ "$phase1_failed" = "true" ]; then
        log_error "Phase 1: Failed reviews: ${failed_reviews[*]}"
        log_warning "Partial results available in: $OUTPUT_DIR"
        vibe_phase_done "Quad Automated Reviews" "1" "failed" "$(($(get_timestamp_ms) - phase1_start))"
        vibe_pipeline_done "multi-ai-quad-review" "failed" "$(($(get_timestamp_ms) - start_time))" "4"
        return 1
    fi

    log_success "All 4 automated reviews completed successfully"

    # Collect results from each tool
    local codex_results coderabbit_results claude_comp_results claude_sec_results

    # Codex results
    local codex_md=$(find "$codex_dir" -name "*.md" -type f ! -name "latest_*" | sort | tail -1)
    if [ -f "$codex_md" ]; then
        codex_results=$(cat "$codex_md")
    else
        codex_results="Codex review did not generate results"
    fi

    # CodeRabbit results
    local coderabbit_md=$(find "$coderabbit_dir" -name "*.md" -type f ! -name "latest_*" | sort | tail -1)
    if [ -f "$coderabbit_md" ]; then
        coderabbit_results=$(cat "$coderabbit_md")
    else
        coderabbit_results="CodeRabbit review did not generate results"
    fi

    # Claude comprehensive results
    local claude_comp_md=$(find "$claude_comp_dir" -name "*_claude.md" -type f ! -name "latest_*" | sort | tail -1)
    if [ -f "$claude_comp_md" ]; then
        claude_comp_results=$(cat "$claude_comp_md")
    else
        claude_comp_results="Claude comprehensive review did not generate results"
    fi

    # Claude security results
    local claude_sec_md=$(find "$claude_sec_dir" -name "*_security.md" -type f ! -name "latest_*" | sort | tail -1)
    if [ -f "$claude_sec_md" ]; then
        claude_sec_results=$(cat "$claude_sec_md")
    else
        claude_sec_results="Claude security review did not generate results"
    fi

    local phase1_end=$(get_timestamp_ms)
    vibe_phase_done "Quad Automated Reviews" "1" "success" "$((phase1_end - phase1_start))"

    # PHASE 2: 6AI Collaborative Analysis
    log_phase "Phase 2: 6AI Collaborative Analysis (analyzing 4 review results)"
    local phase2_start=$(get_timestamp_ms)

    vibe_phase_start "6AI Collaborative Analysis" "2" "6"

    # Construct consolidated context for 6AI analysis
    local quad_context="以下は4つの自動レビューツールによる分析結果です：

【Codex自動レビュー】
$codex_results

【CodeRabbit自動レビュー】
$coderabbit_results

【Claude包括レビュー】
$claude_comp_results

【Claudeセキュリティレビュー】
$claude_sec_results

これら4つのレビュー結果を統合的に分析してください。"

    # Launch 6 AIs in parallel for collaborative analysis
    log_info "Launching 6 AIs for collaborative analysis..."

    local gemini_pid amp_pid qwen_pid droid_pid codex_analysis_pid cursor_pid

    # Gemini: セキュリティ検証
    _quad_review_gemini "$quad_context" "$OUTPUT_DIR/gemini_security_validation.txt" &
    gemini_pid=$!

    # Amp: メンテナンス性評価
    _quad_review_amp "$quad_context" "$OUTPUT_DIR/amp_maintainability.txt" &
    amp_pid=$!

    # Qwen: 代替実装提案
    _quad_review_qwen "$quad_context" "$OUTPUT_DIR/qwen_alternative_implementations.txt" &
    qwen_pid=$!

    # Droid: エンタープライズ基準評価
    _quad_review_droid "$quad_context" "$OUTPUT_DIR/droid_enterprise_standards.txt" &
    droid_pid=$!

    # Codex: 最適化提案（レビュー結果の分析）
    _quad_review_codex "$quad_context" "$OUTPUT_DIR/codex_optimization_suggestions.txt" &
    codex_analysis_pid=$!

    # Cursor: 開発者体験評価
    _quad_review_cursor "$quad_context" "$OUTPUT_DIR/cursor_developer_experience.txt" &
    cursor_pid=$!

    # Wait for all 6AI analysis to complete (check each individually for proper error handling)
    local phase2_failed=false
    local failed_analyses=()
    
    wait $gemini_pid || { 
        local exit_code=$?
        log_error "Gemini analysis failed (exit code: $exit_code)"
        phase2_failed=true
        failed_analyses+=("gemini")
    }
    wait $amp_pid || { 
        local exit_code=$?
        log_error "Amp analysis failed (exit code: $exit_code)"
        phase2_failed=true
        failed_analyses+=("amp")
    }
    wait $qwen_pid || { 
        local exit_code=$?
        log_error "Qwen analysis failed (exit code: $exit_code)"
        phase2_failed=true
        failed_analyses+=("qwen")
    }
    wait $droid_pid || { 
        local exit_code=$?
        log_error "Droid analysis failed (exit code: $exit_code)"
        phase2_failed=true
        failed_analyses+=("droid")
    }
    wait $codex_analysis_pid || { 
        local exit_code=$?
        log_error "Codex analysis failed (exit code: $exit_code)"
        phase2_failed=true
        failed_analyses+=("codex")
    }
    wait $cursor_pid || { 
        local exit_code=$?
        log_error "Cursor analysis failed (exit code: $exit_code)"
        phase2_failed=true
        failed_analyses+=("cursor")
    }

    if [ "$phase2_failed" = "true" ]; then
        log_error "Phase 2: Failed analyses: ${failed_analyses[*]}"
        vibe_phase_done "6AI Collaborative Analysis" "2" "failed" "$(($(get_timestamp_ms) - phase2_start))"
        vibe_pipeline_done "multi-ai-quad-review" "failed" "$(($(get_timestamp_ms) - start_time))" "10"
        return 1
    fi

    # Collect 6AI results
    gemini_result=$(cat "$OUTPUT_DIR/gemini_security_validation.txt" 2>/dev/null || echo "Gemini分析結果なし")
    amp_result=$(cat "$OUTPUT_DIR/amp_maintainability.txt" 2>/dev/null || echo "Amp分析結果なし")
    qwen_result=$(cat "$OUTPUT_DIR/qwen_alternative_implementations.txt" 2>/dev/null || echo "Qwen分析結果なし")
    droid_result=$(cat "$OUTPUT_DIR/droid_enterprise_standards.txt" 2>/dev/null || echo "Droid分析結果なし")
    codex_analysis_result=$(cat "$OUTPUT_DIR/codex_optimization_suggestions.txt" 2>/dev/null || echo "Codex分析結果なし")
    cursor_result=$(cat "$OUTPUT_DIR/cursor_developer_experience.txt" 2>/dev/null || echo "Cursor分析結果なし")

    log_success "6AI collaborative analysis completed"

    local phase2_end=$(get_timestamp_ms)
    vibe_phase_done "6AI Collaborative Analysis" "2" "success" "$((phase2_end - phase2_start))"

    # PHASE 3: Integrated Report Generation
    log_phase "Phase 3: Integrated Report Generation"
    local phase3_start=$(get_timestamp_ms)

    vibe_phase_start "Integrated Report Generation" "3" "1"

    # Generate integrated report using Claude
    local integrated_report_context="以下は4つの自動レビューツールと6AIの協調分析結果です。
これらを統合した包括的なレポートを生成してください。

【4つの自動レビュー結果】
1. Codex: $codex_results
2. CodeRabbit: $coderabbit_results
3. Claude包括: $claude_comp_results
4. Claudeセキュリティ: $claude_sec_results

【6AI協調分析結果】
1. Gemini (セキュリティ検証): $gemini_result
2. Amp (メンテナンス性): $amp_result
3. Qwen (代替実装): $qwen_result
4. Droid (エンタープライズ基準): $droid_result
5. Codex (最適化提案): $codex_analysis_result
6. Cursor (開発者体験): $cursor_result

以下の形式で統合レポートを生成してください：
1. エグゼクティブサマリー
2. 重要な発見事項（優先度順）
3. セキュリティ懸念事項
4. 推奨される改善策
5. 次のステップ"

    log_info "Generating integrated report with Claude..."
    local integrated_report
    # Force non-interactive mode for automated workflow (bypass approval prompts)
    if ! integrated_report=$(call_ai_with_context "claude" "$integrated_report_context" 300); then
        log_error "Failed to generate integrated report with Claude"
        # Create a basic report even if the integrated report generation fails
        log_warning "Creating basic report with raw data only"
        integrated_report="# Integrated Report Generation Failed

The AI was unable to generate a comprehensive integrated report. Please review the raw results below."
    fi

    # Save integrated report
    local report_file="$WORK_DIR/QUAD_REVIEW_REPORT.md"
    if ! cat > "$report_file" <<EOF
# Multi-AI Quad Review Report
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Description: $description

$integrated_report

---

## Raw Review Results

### Codex Automated Review
$codex_results

### CodeRabbit Automated Review
$coderabbit_results

### Claude Comprehensive Review
$claude_comp_results

### Claude Security Review
$claude_sec_results

---

## 6AI Collaborative Analysis

### Gemini (Security Validation)
$gemini_result

### Amp (Maintainability Assessment)
$amp_result

### Qwen (Alternative Implementations)
$qwen_result

### Droid (Enterprise Standards)
$droid_result

### Codex (Optimization Suggestions)
$codex_analysis_result

### Cursor (Developer Experience)
$cursor_result

---

**Report Location:** $report_file
**Work Directory:** $WORK_DIR
EOF
    then
        log_error "Failed to write report file: $report_file"
        vibe_phase_done "Integrated Report Generation" "3" "failed" "$(($(get_timestamp_ms) - phase3_start))"
        vibe_pipeline_done "multi-ai-quad-review" "failed" "$(($(get_timestamp_ms) - start_time))" "10"
        return 1
    fi

    log_success "Integrated report generated: $report_file"

    local phase3_end=$(get_timestamp_ms)
    vibe_phase_done "Integrated Report Generation" "3" "success" "$((phase3_end - phase3_start))"

    # Summary
    local end_time=$(get_timestamp_ms)
    local total_duration=$((end_time - start_time))

    vibe_pipeline_done "multi-ai-quad-review" "success" "$total_duration" "10"

    # Note: show_multi_ai_summary function is not yet implemented
    # show_multi_ai_summary "Quad Review" "$total_duration" "$report_file"

    echo ""
    log_success "Multi-AI Quad Review completed successfully!"
    log_info "📊 Report: $report_file"
    log_info "📁 Work Directory: $WORK_DIR"
    echo ""
}

# Export functions
export -f multi-ai-quad-review
