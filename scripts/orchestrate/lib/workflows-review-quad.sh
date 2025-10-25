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
# Quad Review Functions (1 function)
# ============================================================================

# Multi-AI Quad Review (4-Tool Automated Review Integration)
# Codex + CodeRabbit + Claude comprehensive + Claude security + 6AI collaborative analysis
multi-ai-quad-review() {
    local description="${*:-最新コミットの4ツール統合レビュー}"
    local start_time=$(get_timestamp_ms)

    # P1-1: Input sanitization
    description=$(sanitize_input "$description") || return 1

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
    log_info "  1. Codex automated review (10min timeout)"
    log_info "  2. CodeRabbit automated review (15min timeout)"
    log_info "  3. Claude comprehensive review (10min timeout)"
    log_info "  4. Claude security review (15min timeout)"
    echo ""

    # Output directories for each tool
    local codex_dir="$OUTPUT_DIR/codex"
    local coderabbit_dir="$OUTPUT_DIR/coderabbit"
    local claude_comp_dir="$OUTPUT_DIR/claude_comprehensive"
    local claude_sec_dir="$OUTPUT_DIR/claude_security"
    mkdir -p "$codex_dir" "$coderabbit_dir" "$claude_comp_dir" "$claude_sec_dir"

    # 1. Codex Review (background)
    local codex_pid
    log_info "[1/4] Starting Codex review..."
    (
        local review_script="$PROJECT_ROOT/scripts/codex-review.sh"
        if [ -f "$review_script" ]; then
            CODEX_REVIEW_TIMEOUT=600 \
            OUTPUT_DIR="$codex_dir" \
            "$review_script" > "$codex_dir/execution.log" 2>&1
        else
            log_warning "Codex review script not found: $review_script"
        fi
    ) &
    codex_pid=$!

    # 2. CodeRabbit Review (background)
    local coderabbit_pid
    log_info "[2/4] Starting CodeRabbit review..."
    (
        local review_script="$PROJECT_ROOT/scripts/coderabbit-review.sh"
        if [ -f "$review_script" ]; then
            CODERABBIT_REVIEW_TIMEOUT=900 \
            OUTPUT_DIR="$coderabbit_dir" \
            "$review_script" > "$coderabbit_dir/execution.log" 2>&1
        else
            log_warning "CodeRabbit review script not found: $review_script"
        fi
    ) &
    coderabbit_pid=$!

    # 3. Claude Comprehensive Review (background)
    local claude_comp_pid
    log_info "[3/4] Starting Claude comprehensive review..."
    (
        local review_script="$PROJECT_ROOT/scripts/claude-review.sh"
        if [ -f "$review_script" ]; then
            CLAUDE_REVIEW_TIMEOUT=600 \
            OUTPUT_DIR="$claude_comp_dir" \
            "$review_script" > "$claude_comp_dir/execution.log" 2>&1
        else
            log_warning "Claude comprehensive review script not found: $review_script"
        fi
    ) &
    claude_comp_pid=$!

    # 4. Claude Security Review (background)
    local claude_sec_pid
    log_info "[4/4] Starting Claude security review..."
    (
        local review_script="$PROJECT_ROOT/scripts/claude-security-review.sh"
        if [ -f "$review_script" ]; then
            CLAUDE_SECURITY_REVIEW_TIMEOUT=900 \
            OUTPUT_DIR="$claude_sec_dir" \
            "$review_script" > "$claude_sec_dir/execution.log" 2>&1
        else
            log_warning "Claude security review script not found: $review_script"
        fi
    ) &
    claude_sec_pid=$!

    # Wait for all 4 reviews to complete (check each individually for proper error handling)
    log_info "Waiting for all 4 automated reviews to complete..."

    local phase1_failed=false
    wait $codex_pid || { log_error "Codex review failed"; phase1_failed=true; }
    wait $coderabbit_pid || { log_error "CodeRabbit review failed"; phase1_failed=true; }
    wait $claude_comp_pid || { log_error "Claude comprehensive review failed"; phase1_failed=true; }
    wait $claude_sec_pid || { log_error "Claude security review failed"; phase1_failed=true; }

    if [ "$phase1_failed" = "true" ]; then
        log_error "Phase 1: One or more automated reviews failed"
        vibe_phase_done "Quad Automated Reviews" "1" "failed" "$(($(get_timestamp_ms) - phase1_start))"
        vibe_pipeline_done "multi-ai-quad-review" "failed" "$(($(get_timestamp_ms) - start_time))" "4"
        return 1
    fi

    log_success "All 4 automated reviews completed successfully"

    # Collect results from each tool
    local codex_results coderabbit_results claude_comp_results claude_sec_results

    # Codex results
    local codex_md=$(find "$codex_dir" -name "*.md" -type f | sort | tail -1)
    if [ -f "$codex_md" ]; then
        codex_results=$(cat "$codex_md")
    else
        codex_results="Codex review did not generate results"
    fi

    # CodeRabbit results
    local coderabbit_md=$(find "$coderabbit_dir" -name "*.md" -type f | sort | tail -1)
    if [ -f "$coderabbit_md" ]; then
        coderabbit_results=$(cat "$coderabbit_md")
    else
        coderabbit_results="CodeRabbit review did not generate results"
    fi

    # Claude comprehensive results
    local claude_comp_md=$(find "$claude_comp_dir" -name "*_claude.md" -type f | sort | tail -1)
    if [ -f "$claude_comp_md" ]; then
        claude_comp_results=$(cat "$claude_comp_md")
    else
        claude_comp_results="Claude comprehensive review did not generate results"
    fi

    # Claude security results
    local claude_sec_md=$(find "$claude_sec_dir" -name "*_claude_security.md" -type f | sort | tail -1)
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

    local gemini_result amp_result qwen_result droid_result codex_analysis_result cursor_result
    local gemini_pid amp_pid qwen_pid droid_pid codex_analysis_pid cursor_pid

    # Gemini: セキュリティ検証
    (
        gemini_result=$(call_ai_with_context "gemini" "セキュリティ観点からレビュー結果を検証:
$quad_context" 600)
        echo "$gemini_result" > "$OUTPUT_DIR/gemini_security_validation.txt"
    ) &
    gemini_pid=$!

    # Amp: メンテナンス性評価
    (
        amp_result=$(call_ai_with_context "amp" "メンテナンス性の観点からレビュー結果を評価:
$quad_context" 600)
        echo "$amp_result" > "$OUTPUT_DIR/amp_maintainability.txt"
    ) &
    amp_pid=$!

    # Qwen: 代替実装提案
    (
        qwen_result=$(call_ai_with_context "qwen" "指摘された問題の代替実装を提案:
$quad_context" 600)
        echo "$qwen_result" > "$OUTPUT_DIR/qwen_alternative_implementations.txt"
    ) &
    qwen_pid=$!

    # Droid: エンタープライズ基準評価
    (
        droid_result=$(call_ai_with_context "droid" "エンタープライズ基準の観点から評価:
$quad_context" 900)
        echo "$droid_result" > "$OUTPUT_DIR/droid_enterprise_standards.txt"
    ) &
    droid_pid=$!

    # Codex: 最適化提案（レビュー結果の分析）
    (
        codex_analysis_result=$(call_ai_with_context "codex" "4つのレビュー結果を分析し、最適化提案を提供:
$quad_context" 600)
        echo "$codex_analysis_result" > "$OUTPUT_DIR/codex_optimization_suggestions.txt"
    ) &
    codex_analysis_pid=$!

    # Cursor: 開発者体験評価
    (
        cursor_result=$(call_ai_with_context "cursor" "開発者体験の観点からレビュー結果を評価:
$quad_context" 600)
        echo "$cursor_result" > "$OUTPUT_DIR/cursor_developer_experience.txt"
    ) &
    cursor_pid=$!

    # Wait for all 6AI analysis to complete (check each individually for proper error handling)
    local phase2_failed=false
    wait $gemini_pid || { log_error "Gemini analysis failed"; phase2_failed=true; }
    wait $amp_pid || { log_error "Amp analysis failed"; phase2_failed=true; }
    wait $qwen_pid || { log_error "Qwen analysis failed"; phase2_failed=true; }
    wait $droid_pid || { log_error "Droid analysis failed"; phase2_failed=true; }
    wait $codex_analysis_pid || { log_error "Codex analysis failed"; phase2_failed=true; }
    wait $cursor_pid || { log_error "Cursor analysis failed"; phase2_failed=true; }

    if [ "$phase2_failed" = "true" ]; then
        log_error "Phase 2: One or more AI analyses failed"
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
    integrated_report=$(call_ai_with_context "claude" "$integrated_report_context" 300)

    # Save integrated report
    local report_file="$WORK_DIR/QUAD_REVIEW_REPORT.md"
    cat > "$report_file" <<EOF
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

    log_success "Integrated report generated: $report_file"

    local phase3_end=$(get_timestamp_ms)
    vibe_phase_done "Integrated Report Generation" "3" "success" "$((phase3_end - phase3_start))"

    # Summary
    local end_time=$(get_timestamp_ms)
    local total_duration=$((end_time - start_time))

    vibe_pipeline_done "multi-ai-quad-review" "success" "$total_duration" "10"

    show_multi_ai_summary "Quad Review" "$total_duration" "$report_file"

    echo ""
    log_success "Multi-AI Quad Review completed successfully!"
    log_info "📊 Report: $report_file"
    log_info "📁 Work Directory: $WORK_DIR"
    echo ""
}

# Export functions
export -f multi-ai-quad-review
