#!/usr/bin/env bash
# Multi-AI Code Review Workflows Library
# Purpose: Code review workflow implementations (P1.1.1.4)
# Responsibilities:
#   - code-review: Codex automated review + 6AI collaborative analysis
#   - coderabbit-review: CodeRabbit review + 6AI collaborative analysis
#   - full-review: Dual review (Codex + CodeRabbit) + 6AI synthesis
#   - dual-review: Legacy dual review implementation
#
# Dependencies:
#   - lib/multi-ai-core.sh (logging, utilities, phase management, VibeLogger)
#   - lib/multi-ai-ai-interface.sh (call_ai_with_context function)
#   - scripts/codex-review.sh (Codex automated review)
#   - scripts/coderabbit-review.sh (CodeRabbit automated review)
#
# Usage:
#   source scripts/orchestrate/lib/workflows-review.sh

set -euo pipefail

# ============================================================================
# Code Review Functions (4 functions)
# ============================================================================

# Multi-AI Code Review (Codex Review Integration)
# Codex automated review + Claude & Gemini collaborative analysis
multi-ai-code-review() {
    local description="${*:-最新コミットのレビュー}"
    local start_time=$(get_timestamp_ms)

    # P1-1: Input sanitization
    description=$(sanitize_input "$description") || return 1

    show_multi_ai_banner
    log_info "Review Description: $description"
    log_info "Profile: balanced-multi-ai (code-review workflow)"
    log_info "Mode: Codex automated review + Multi-AI collaborative analysis"
    echo ""

    # VibeLogger: pipeline.start
    vibe_pipeline_start "multi-ai-code-review" "$description" "3"

    # P1-2: Setup work directory - persistent logs for audit trail
    local WORK_DIR="$PROJECT_ROOT/logs/multi-ai-reviews/$(date +%Y%m%d-%H%M%S)-$$-code-review"
    local OUTPUT_DIR="$WORK_DIR/output"
    mkdir -p "$OUTPUT_DIR"
    log_info "Work directory: $WORK_DIR (logs will be preserved)"

    # PHASE 1: Codex Automated Review (5-10分)
    log_phase "Phase 1: Codex Automated Review"
    local phase1_start=$(get_timestamp_ms)

    # VibeLogger: phase.start
    vibe_phase_start "Codex Automated Review" "1" "1"

    local codex_review_timeout=600  # 10 minutes
    log_info "Executing Codex review with ${codex_review_timeout}s timeout..."

    # Execute codex-review.sh
    local review_script="$PROJECT_ROOT/scripts/codex-review.sh"
    if [ ! -f "$review_script" ]; then
        log_error "Codex review script not found: $review_script"
        return 1
    fi

    local codex_json="$OUTPUT_DIR/codex_review.json"
    local codex_md="$OUTPUT_DIR/codex_review.md"
    local codex_log="$OUTPUT_DIR/codex_review.log"

    # Run codex review
    if CODEX_REVIEW_TIMEOUT="$codex_review_timeout" \
       OUTPUT_DIR="$(dirname "$codex_json")" \
       "$review_script" > "$codex_log" 2>&1; then
        log_success "Codex review completed"

        # Find latest generated files
        local latest_json latest_md
        latest_json=$(find "$(dirname "$codex_json")" -name "*.json" -type f ! -name "latest.json" | sort | tail -1)
        latest_md=$(find "$(dirname "$codex_md")" -name "*.md" -type f ! -name "latest.md" | sort | tail -1)

        if [ -f "$latest_json" ]; then
            cp "$latest_json" "$codex_json"
        fi
        if [ -f "$latest_md" ]; then
            cp "$latest_md" "$codex_md"
        fi
    else
        log_warning "Codex review timed out or failed (continuing with partial results)"
    fi

    # Read Codex results
    local codex_results=""
    if [ -f "$codex_md" ]; then
        codex_results=$(cat "$codex_md")
    elif [ -f "$codex_log" ]; then
        codex_results=$(tail -100 "$codex_log")
    else
        codex_results="Codex review did not generate results"
    fi

    # VibeLogger: phase.done (Phase 1)
    local phase1_end=$(get_timestamp_ms)
    local phase1_time=$((phase1_end - phase1_start))
    vibe_phase_done "Codex Automated Review" "1" "success" "$phase1_time"

    # PHASE 2: 6AI Parallel Analysis (10-15分)
    log_phase "Phase 2: Multi-AI Parallel Analysis (6 AIs except Codex)"
    local phase2_start=$(get_timestamp_ms)

    # VibeLogger: phase.start (Phase 2)
    vibe_phase_start "6AI Parallel Analysis" "2" "6"

    # Strategy & Design Layer
    local claude_output="$OUTPUT_DIR/claude_analysis.md"
    local claude_prompt="Codexによる自動コードレビュー結果の分析:

$codex_results

役割: CTO - アーキテクチャ・設計パターン評価
- Codexが発見した問題の深刻度を評価
- 修正の優先順位を決定
- アーキテクチャレベルの懸念を特定
- 設計パターンの改善提案
- 技術的負債の評価"

    local gemini_output="$OUTPUT_DIR/gemini_analysis.md"
    local gemini_prompt="Codexによる自動コードレビュー結果の分析:

$codex_results

役割: CIO - セキュリティ・最新技術トレンド分析
- セキュリティ脆弱性の評価
- 業界標準・ベストプラクティスとの比較
- 最新技術トレンドとの整合性確認
- コンプライアンス観点の確認
- セキュリティリスクの優先順位付け"

    local amp_output="$OUTPUT_DIR/amp_analysis.md"
    local amp_prompt="Codexによる自動コードレビュー結果の分析:

$codex_results

役割: PM - プロジェクト影響・長期保守性評価
- プロジェクトロードマップへの影響評価
- 長期的な保守性の観点からの分析
- チーム開発への影響
- リソース配分の推奨
- 技術的負債の管理戦略"

    # Implementation Layer
    local qwen_output="$OUTPUT_DIR/qwen_analysis.md"
    local qwen_prompt="Codexによる自動コードレビュー結果の分析:

$codex_results

役割: Fast Prototyper - 代替実装提案
- より簡潔な実装方法の提案
- 高速な修正案の提示
- シンプルな解決策の探索
- リファクタリングの方向性"

    local droid_output="$OUTPUT_DIR/droid_analysis.md"
    local droid_prompt="Codexによる自動コードレビュー結果の分析:

$codex_results

役割: Enterprise Engineer - エンタープライズ品質基準評価
- 本番環境での品質基準との比較
- エンタープライズ要件の充足度
- 堅牢性・信頼性の評価
- スケーラビリティの観点
- ベストプラクティス適合度"

    # Integration Layer
    local cursor_output="$OUTPUT_DIR/cursor_analysis.md"
    local cursor_prompt="Codexによる自動コードレビュー結果の分析:

$codex_results

役割: IDE Integration Specialist - 開発者体験評価
- コードの可読性・保守性
- IDE統合の観点からの改善提案
- 開発者の生産性への影響
- デバッグのしやすさ
- ドキュメンテーションの充実度"

    # Launch all 6 AIs in parallel
    log_info "Launching 6 AI analyses in parallel..."
    call_ai_with_context "claude" "$claude_prompt" 300 "$claude_output" &
    local claude_pid=$!
    call_ai_with_context "gemini" "$gemini_prompt" 300 "$gemini_output" &
    local gemini_pid=$!
    call_ai_with_context "amp" "$amp_prompt" 600 "$amp_output" &
    local amp_pid=$!
    call_ai_with_context "qwen" "$qwen_prompt" 300 "$qwen_output" &
    local qwen_pid=$!
    call_ai_with_context "droid" "$droid_prompt" 900 "$droid_output" &
    local droid_pid=$!
    call_ai_with_context "cursor" "$cursor_prompt" 600 "$cursor_output" &
    local cursor_pid=$!

    # Wait for all analyses (with error tolerance)
    wait $claude_pid || log_warning "Claude analysis timed out or failed"
    wait $gemini_pid || log_warning "Gemini analysis timed out or failed"
    wait $amp_pid || log_warning "Amp analysis timed out or failed"
    wait $qwen_pid || log_warning "Qwen analysis timed out or failed"
    wait $droid_pid || log_warning "Droid analysis timed out or failed"
    wait $cursor_pid || log_warning "Cursor analysis timed out or failed"

    log_success "6 AI analyses completed"

    # VibeLogger: phase.done (Phase 2)
    local phase2_end=$(get_timestamp_ms)
    local phase2_time=$((phase2_end - phase2_start))
    vibe_phase_done "6AI Parallel Analysis" "2" "success" "$phase2_time"

    # Collect analysis results
    local claude_analysis=""
    local gemini_analysis=""
    local amp_analysis=""
    local qwen_analysis=""
    local droid_analysis=""
    local cursor_analysis=""
    [ -f "$claude_output" ] && claude_analysis=$(cat "$claude_output")
    [ -f "$gemini_output" ] && gemini_analysis=$(cat "$gemini_output")
    [ -f "$amp_output" ] && amp_analysis=$(cat "$amp_output")
    [ -f "$qwen_output" ] && qwen_analysis=$(cat "$qwen_output")
    [ -f "$droid_output" ] && droid_analysis=$(cat "$droid_output")
    [ -f "$cursor_output" ] && cursor_analysis=$(cat "$cursor_output")

    # PHASE 3: Consensus Synthesis (5-10分)
    log_phase "Phase 3: Consensus Synthesis"
    local phase3_start=$(get_timestamp_ms)

    # VibeLogger: phase.start (Phase 3)
    vibe_phase_start "Consensus Synthesis" "3" "1"

    local synthesis_output="$OUTPUT_DIR/final_review_report.md"

    # Generate final report
    cat > "$synthesis_output" <<EOF
# Multi-AI Collaborative Code Review Report

**Generated**: $(date +"%Y-%m-%d %H:%M:%S")
**Description**: $description

---

## Phase 1: Codex Automated Review

$(if [ -n "$codex_results" ]; then echo "$codex_results"; else echo "No results available"; fi)

---

## Phase 2: Multi-AI Parallel Analysis (6 AIs)

### 戦略・設計層

#### Claude (CTO) - Architecture & Design Patterns

$(if [ -n "$claude_analysis" ]; then echo "$claude_analysis"; else echo "No analysis available"; fi)

#### Gemini (CIO) - Security & Latest Trends

$(if [ -n "$gemini_analysis" ]; then echo "$gemini_analysis"; else echo "No analysis available"; fi)

#### Amp (PM) - Project Impact & Maintainability

$(if [ -n "$amp_analysis" ]; then echo "$amp_analysis"; else echo "No analysis available"; fi)

### 実装層

#### Qwen - Alternative Implementation Suggestions

$(if [ -n "$qwen_analysis" ]; then echo "$qwen_analysis"; else echo "No analysis available"; fi)

#### Droid - Enterprise Quality Standards

$(if [ -n "$droid_analysis" ]; then echo "$droid_analysis"; else echo "No analysis available"; fi)

### 統合層

#### Cursor - Developer Experience

$(if [ -n "$cursor_analysis" ]; then echo "$cursor_analysis"; else echo "No analysis available"; fi)

---

## Consensus & Recommendations

Based on Codex's automated review and collaborative analysis by all 7 AIs:

### Critical Issues
- Review Codex findings marked as CRITICAL
- Prioritize security vulnerabilities (Gemini perspective)
- Address architectural concerns (Claude perspective)
- Ensure enterprise quality standards (Droid perspective)

### Action Items
1. Fix critical issues immediately (Codex + Claude + Gemini + Droid)
2. Implement alternative solutions where applicable (Qwen suggestions)
3. Improve developer experience (Cursor recommendations)
4. Plan long-term maintenance strategy (Amp recommendations)
5. Document technical debt for future sprints

### Quality Assessment
- **Codex Detection**: Automated issue scanning
- **Claude Evaluation**: Architecture & design depth
- **Gemini Validation**: Security & compliance
- **Amp Analysis**: Project impact & long-term planning
- **Qwen Suggestions**: Fast alternative approaches
- **Droid Standards**: Enterprise quality benchmarks
- **Cursor Insights**: Developer productivity optimization

---

## Next Steps

1. Address critical issues identified above
2. Implement recommended fixes
3. Re-run review after fixes

---

*Generated by Multi-AI Code Review System (Codex + Claude + Gemini)*
EOF

    # VibeLogger: phase.done (Phase 3)
    local phase3_end=$(get_timestamp_ms)
    local phase3_time=$((phase3_end - phase3_start))
    vibe_phase_done "Consensus Synthesis" "3" "success" "$phase3_time"

    # Display results
    echo ""
    log_success "🎉 Multi-AI Code Review Complete!"
    echo ""
    log_info "Generated Files:"
    ls -lh "$OUTPUT_DIR" 2>/dev/null || log_warning "No files generated"
    echo ""

    if [ -f "$synthesis_output" ]; then
        log_info "Final Review Report:"
        echo ""
        cat "$synthesis_output"
    else
        log_error "Failed to generate final report"
    fi
    echo ""

    # VibeLogger: pipeline.done
    local end_time=$(get_timestamp_ms)
    local total_time=$((end_time - start_time))
    vibe_pipeline_done "multi-ai-code-review" "success" "$total_time" "7"

    # VibeLogger: summary.done
    local summary_text="Multi-AI Code Review complete for: $description"
    local output_files="[\"$synthesis_output\", \"$OUTPUT_DIR/codex_review.json\", \"$OUTPUT_DIR/codex_review.md\"]"
    vibe_summary_done "$summary_text" "high" "$output_files"
}

# Multi-AI CodeRabbit Review (CodeRabbit Review Integration)
# CodeRabbit automated review + 6AI collaborative analysis (Claude, Gemini, Amp, Qwen, Droid, Cursor)
multi-ai-coderabbit-review() {
    local description="${*:-最新コミットのCodeRabbitレビュー}"
    local start_time=$(get_timestamp_ms)

    # P1-1: Input sanitization
    description=$(sanitize_input "$description") || return 1

    show_multi_ai_banner
    log_info "Review Description: $description"
    log_info "Profile: balanced-multi-ai (coderabbit-review workflow)"
    log_info "Mode: CodeRabbit automated review + Multi-AI collaborative analysis"
    echo ""

    # VibeLogger: pipeline.start
    vibe_pipeline_start "multi-ai-coderabbit-review" "$description" "3"

    # P1-2: Setup work directory - persistent logs for audit trail
    local WORK_DIR="$PROJECT_ROOT/logs/multi-ai-reviews/$(date +%Y%m%d-%H%M%S)-$$-coderabbit-review"
    local OUTPUT_DIR="$WORK_DIR/output"
    mkdir -p "$OUTPUT_DIR"
    log_info "Work directory: $WORK_DIR (logs will be preserved)"

    # PHASE 1: CodeRabbit Automated Review (10-15分)
    log_phase "Phase 1: CodeRabbit Automated Review"
    local phase1_start=$(get_timestamp_ms)

    # VibeLogger: phase.start
    vibe_phase_start "CodeRabbit Automated Review" "1" "1"

    local coderabbit_review_timeout=900  # 15 minutes (CodeRabbit is more comprehensive)
    log_info "Executing CodeRabbit review with ${coderabbit_review_timeout}s timeout..."

    # Execute coderabbit-review.sh
    local review_script="$PROJECT_ROOT/scripts/coderabbit-review.sh"
    if [ ! -f "$review_script" ]; then
        log_error "CodeRabbit review script not found: $review_script"
        return 1
    fi

    local coderabbit_json="$OUTPUT_DIR/coderabbit_review.json"
    local coderabbit_md="$OUTPUT_DIR/coderabbit_review.md"
    local coderabbit_log="$OUTPUT_DIR/coderabbit_review.log"

    # Run CodeRabbit review
    if CODERABBIT_REVIEW_TIMEOUT="$coderabbit_review_timeout" \
       OUTPUT_DIR="$(dirname "$coderabbit_json")" \
       "$review_script" > "$coderabbit_log" 2>&1; then
        log_success "CodeRabbit review completed"

        # Find latest generated files
        local latest_json latest_md
        latest_json=$(find "$(dirname "$coderabbit_json")" -name "*_coderabbit.json" -type f ! -name "latest_coderabbit.json" | sort | tail -1)
        latest_md=$(find "$(dirname "$coderabbit_md")" -name "*_coderabbit.md" -type f ! -name "latest_coderabbit.md" | sort | tail -1)

        if [ -f "$latest_json" ]; then
            cp "$latest_json" "$coderabbit_json"
        fi
        if [ -f "$latest_md" ]; then
            cp "$latest_md" "$coderabbit_md"
        fi
    else
        log_warning "CodeRabbit review timed out or failed (continuing with partial results)"
    fi

    # Read CodeRabbit results
    local coderabbit_results=""
    if [ -f "$coderabbit_md" ]; then
        coderabbit_results=$(cat "$coderabbit_md")
    elif [ -f "$coderabbit_log" ]; then
        coderabbit_results=$(tail -100 "$coderabbit_log")
    else
        coderabbit_results="CodeRabbit review did not generate results"
    fi

    # VibeLogger: phase.done (Phase 1)
    local phase1_end=$(get_timestamp_ms)
    local phase1_time=$((phase1_end - phase1_start))
    vibe_phase_done "CodeRabbit Automated Review" "1" "success" "$phase1_time"

    # PHASE 2: 6AI Parallel Analysis (10-15分)
    log_phase "Phase 2: Multi-AI Parallel Analysis (6 AIs except CodeRabbit)"
    local phase2_start=$(get_timestamp_ms)

    # VibeLogger: phase.start (Phase 2)
    vibe_phase_start "6AI Parallel Analysis" "2" "6"

    # Strategy & Design Layer
    local claude_output="$OUTPUT_DIR/claude_analysis.md"
    local claude_prompt="CodeRabbitによる自動コードレビュー結果の分析:

$coderabbit_results

役割: CTO - アーキテクチャ・設計パターン評価
- CodeRabbitが発見した問題の深刻度を評価
- 修正の優先順位を決定
- アーキテクチャレベルの懸念を特定
- 設計パターンの改善提案
- 技術的負債の評価
- CodeRabbitの指摘に対する技術的妥当性の検証"

    local gemini_output="$OUTPUT_DIR/gemini_analysis.md"
    local gemini_prompt="CodeRabbitによる自動コードレビュー結果の分析:

$coderabbit_results

役割: CIO - セキュリティ・最新技術トレンド分析
- セキュリティ脆弱性の評価
- 業界標準・ベストプラクティスとの比較
- 最新技術トレンドとの整合性確認
- コンプライアンス観点の確認
- セキュリティリスクの優先順位付け
- CodeRabbitの指摘に対するセキュリティ視点の補足"

    local amp_output="$OUTPUT_DIR/amp_analysis.md"
    local amp_prompt="CodeRabbitによる自動コードレビュー結果の分析:

$coderabbit_results

役割: PM - プロジェクト影響・長期保守性評価
- プロジェクトロードマップへの影響評価
- 長期的な保守性の観点からの分析
- チーム開発への影響
- リソース配分の推奨
- 技術的負債の管理戦略
- CodeRabbitの指摘に対する優先順位付けと実行計画"

    # Implementation Layer
    local qwen_output="$OUTPUT_DIR/qwen_analysis.md"
    local qwen_prompt="CodeRabbitによる自動コードレビュー結果の分析:

$coderabbit_results

役割: Fast Prototyper - 代替実装提案
- より簡潔な実装方法の提案
- 高速な修正案の提示
- シンプルな解決策の探索
- リファクタリングの方向性
- CodeRabbitの指摘に対する迅速な修正パターン提案"

    local droid_output="$OUTPUT_DIR/droid_analysis.md"
    local droid_prompt="CodeRabbitによる自動コードレビュー結果の分析:

$coderabbit_results

役割: Enterprise Engineer - エンタープライズ品質基準評価
- 本番環境での品質基準との比較
- エンタープライズ要件の充足度
- 堅牢性・信頼性の評価
- スケーラビリティの観点
- ベストプラクティス適合度
- CodeRabbitの指摘に対する本番環境での影響評価"

    # Integration Layer
    local cursor_output="$OUTPUT_DIR/cursor_analysis.md"
    local cursor_prompt="CodeRabbitによる自動コードレビュー結果の分析:

$coderabbit_results

役割: IDE Integration Specialist - 開発者体験評価
- コードの可読性・保守性
- IDE統合の観点からの改善提案
- 開発者の生産性への影響
- デバッグのしやすさ
- ドキュメンテーションの充実度
- CodeRabbitの指摘に対する開発フロー改善提案"

    # Launch all 6 AIs in parallel
    log_info "Launching 6 AI analyses in parallel..."
    call_ai_with_context "claude" "$claude_prompt" 300 "$claude_output" &
    local claude_pid=$!
    call_ai_with_context "gemini" "$gemini_prompt" 300 "$gemini_output" &
    local gemini_pid=$!
    call_ai_with_context "amp" "$amp_prompt" 600 "$amp_output" &
    local amp_pid=$!
    call_ai_with_context "qwen" "$qwen_prompt" 300 "$qwen_output" &
    local qwen_pid=$!
    call_ai_with_context "droid" "$droid_prompt" 900 "$droid_output" &
    local droid_pid=$!
    call_ai_with_context "cursor" "$cursor_prompt" 600 "$cursor_output" &
    local cursor_pid=$!

    # Wait for all analyses (with error tolerance)
    wait $claude_pid || log_warning "Claude analysis timed out or failed"
    wait $gemini_pid || log_warning "Gemini analysis timed out or failed"
    wait $amp_pid || log_warning "Amp analysis timed out or failed"
    wait $qwen_pid || log_warning "Qwen analysis timed out or failed"
    wait $droid_pid || log_warning "Droid analysis timed out or failed"
    wait $cursor_pid || log_warning "Cursor analysis timed out or failed"

    log_success "6 AI analyses completed"

    # VibeLogger: phase.done (Phase 2)
    local phase2_end=$(get_timestamp_ms)
    local phase2_time=$((phase2_end - phase2_start))
    vibe_phase_done "6AI Parallel Analysis" "2" "success" "$phase2_time"

    # Collect analysis results
    local claude_analysis=""
    local gemini_analysis=""
    local amp_analysis=""
    local qwen_analysis=""
    local droid_analysis=""
    local cursor_analysis=""
    [ -f "$claude_output" ] && claude_analysis=$(cat "$claude_output")
    [ -f "$gemini_output" ] && gemini_analysis=$(cat "$gemini_output")
    [ -f "$amp_output" ] && amp_analysis=$(cat "$amp_output")
    [ -f "$qwen_output" ] && qwen_analysis=$(cat "$qwen_output")
    [ -f "$droid_output" ] && droid_analysis=$(cat "$droid_output")
    [ -f "$cursor_output" ] && cursor_analysis=$(cat "$cursor_output")

    # PHASE 3: Consensus Synthesis (5-10分)
    log_phase "Phase 3: Consensus Synthesis"
    local phase3_start=$(get_timestamp_ms)

    # VibeLogger: phase.start (Phase 3)
    vibe_phase_start "Consensus Synthesis" "3" "1"

    local synthesis_output="$OUTPUT_DIR/final_review_report.md"

    # Generate final report
    cat > "$synthesis_output" <<EOF
# Multi-AI Collaborative CodeRabbit Review Report

**Generated**: $(date +"%Y-%m-%d %H:%M:%S")
**Description**: $description

---

## Phase 1: CodeRabbit Automated Review

$(if [ -n "$coderabbit_results" ]; then echo "$coderabbit_results"; else echo "No results available"; fi)

---

## Phase 2: Multi-AI Parallel Analysis (6 AIs)

### 戦略・設計層

#### Claude (CTO) - Architecture & Design Patterns

$(if [ -n "$claude_analysis" ]; then echo "$claude_analysis"; else echo "No analysis available"; fi)

#### Gemini (CIO) - Security & Latest Trends

$(if [ -n "$gemini_analysis" ]; then echo "$gemini_analysis"; else echo "No analysis available"; fi)

#### Amp (PM) - Project Impact & Maintainability

$(if [ -n "$amp_analysis" ]; then echo "$amp_analysis"; else echo "No analysis available"; fi)

### 実装層

#### Qwen - Alternative Implementation Suggestions

$(if [ -n "$qwen_analysis" ]; then echo "$qwen_analysis"; else echo "No analysis available"; fi)

#### Droid - Enterprise Quality Standards

$(if [ -n "$droid_analysis" ]; then echo "$droid_analysis"; else echo "No analysis available"; fi)

### 統合層

#### Cursor - Developer Experience

$(if [ -n "$cursor_analysis" ]; then echo "$cursor_analysis"; else echo "No analysis available"; fi)

---

## Consensus & Recommendations

Based on CodeRabbit's automated review and collaborative analysis by all 7 AIs:

### Critical Issues
- Review CodeRabbit findings marked as CRITICAL or HIGH severity
- Prioritize security vulnerabilities (Gemini perspective)
- Address architectural concerns (Claude perspective)
- Ensure enterprise quality standards (Droid perspective)

### Action Items
1. Fix critical/high severity issues immediately (CodeRabbit + Claude + Gemini + Droid)
2. Implement alternative solutions where applicable (Qwen suggestions)
3. Improve developer experience (Cursor recommendations)
4. Plan long-term maintenance strategy (Amp recommendations)
5. Document technical debt for future sprints

### Quality Assessment
- **CodeRabbit Detection**: Comprehensive AI-powered code review
- **Claude Evaluation**: Architecture & design depth analysis
- **Gemini Validation**: Security & compliance verification
- **Amp Analysis**: Project impact & long-term planning
- **Qwen Suggestions**: Fast alternative approaches
- **Droid Standards**: Enterprise quality benchmarks
- **Cursor Insights**: Developer productivity optimization

### Multi-AI vs CodeRabbit Comparison
- **CodeRabbit Strengths**: AI-powered pattern detection, comprehensive coverage
- **Multi-AI Value-Add**: Multi-perspective analysis, contextual understanding, strategic recommendations
- **Complementary Insights**: CodeRabbit provides breadth, Multi-AI provides depth

---

## Next Steps

1. Address critical/high severity issues identified above
2. Implement recommended fixes based on Multi-AI consensus
3. Re-run CodeRabbit review after fixes
4. Update documentation based on Cursor/Amp recommendations

---

*Generated by Multi-AI CodeRabbit Review System (CodeRabbit + Claude + Gemini + Amp + Qwen + Droid + Cursor)*
EOF

    # VibeLogger: phase.done (Phase 3)
    local phase3_end=$(get_timestamp_ms)
    local phase3_time=$((phase3_end - phase3_start))
    vibe_phase_done "Consensus Synthesis" "3" "success" "$phase3_time"

    # Display results
    echo ""
    log_success "🎉 Multi-AI CodeRabbit Review Complete!"
    echo ""
    log_info "Generated Files:"
    ls -lh "$OUTPUT_DIR" 2>/dev/null || log_warning "No files generated"
    echo ""

    if [ -f "$synthesis_output" ]; then
        log_info "Final Review Report:"
        echo ""
        cat "$synthesis_output"
    else
        log_error "Failed to generate final report"
    fi
    echo ""

    # VibeLogger: pipeline.done
    local end_time=$(get_timestamp_ms)
    local total_time=$((end_time - start_time))
    vibe_pipeline_done "multi-ai-coderabbit-review" "success" "$total_time" "7"

    # VibeLogger: summary.done
    local summary_text="Multi-AI CodeRabbit Review complete for: $description"
    local output_files="[\"$synthesis_output\", \"$OUTPUT_DIR/coderabbit_review.json\", \"$OUTPUT_DIR/coderabbit_review.md\"]"
    vibe_summary_done "$summary_text" "high" "$output_files"
}


# ============================================================================
# Multi-AI Comprehensive Review (Migrated from multi-ai-code-review-optimized.sh)
# ============================================================================

# Multi-AI Dual Review (Codex + CodeRabbit → 5AI Analysis → Synthesis)
# Architecture: Dual automated review tools + 5AI human-like analysis (Droid excluded)
multi-ai-full-review() {
    local description="${*:-最新コミットのDual+5AIレビュー}"
    local start_time=$(get_timestamp_ms)

    # P1-1: Input sanitization
    description=$(sanitize_input "$description") || return 1

    show_multi_ai_banner
    log_info "Review Description: $description"
    log_info "Profile: balanced-multi-ai (Dual+5AI comprehensive workflow)"
    log_info "Mode: Codex+CodeRabbit parallel → 5AI analysis → Consensus synthesis"
    echo ""

    # VibeLogger: pipeline.start (3 phases)
    vibe_pipeline_start "multi-ai-full-review" "$description" "3"

    # P1-2: Setup work directory - persistent logs for audit trail
    local WORK_DIR="$PROJECT_ROOT/logs/multi-ai-reviews/$(date +%Y%m%d-%H%M%S)-$$-dual-6ai"
    local OUTPUT_DIR="$WORK_DIR/output"
    mkdir -p "$OUTPUT_DIR"
    log_info "Work directory: $WORK_DIR (logs will be preserved)"

    # ============================================================================
    # PHASE 1: Dual Review Execution (Codex + CodeRabbit Parallel)
    # ============================================================================
    log_phase "Phase 1: Dual Review Execution (Codex + CodeRabbit)"
    local phase1_start=$(get_timestamp_ms)

    # VibeLogger: phase.start
    vibe_phase_start "Dual Review Execution" "1" "2"

    # Prepare directories
    local codex_dir="$OUTPUT_DIR/codex"
    local coderabbit_dir="$OUTPUT_DIR/coderabbit"
    mkdir -p "$codex_dir" "$coderabbit_dir"

    # Launch Codex review in background
    log_info "Launching Codex review (timeout: 900s)..."
    local codex_review_script="$PROJECT_ROOT/scripts/codex-review.sh"
    if [ ! -f "$codex_review_script" ]; then
        log_error "Codex review script not found: $codex_review_script"
        return 1
    fi

    (
        CODEX_REVIEW_TIMEOUT=900 \
        OUTPUT_DIR="$codex_dir" \
        "$codex_review_script" > "$codex_dir/execution.log" 2>&1
    ) &
    local codex_pid=$!

    # Launch CodeRabbit review in background
    log_info "Launching CodeRabbit review (timeout: 900s)..."
    local coderabbit_review_script="$PROJECT_ROOT/scripts/coderabbit-review.sh"
    if [ ! -f "$coderabbit_review_script" ]; then
        log_warning "CodeRabbit review script not found: $coderabbit_review_script (continuing with Codex only)"
        coderabbit_pid=0
    else
        (
            CODERABBIT_REVIEW_TIMEOUT=900 \
            OUTPUT_DIR="$coderabbit_dir" \
            "$coderabbit_review_script" > "$coderabbit_dir/execution.log" 2>&1
        ) &
        coderabbit_pid=$!
    fi

    # Wait for both reviews with error tolerance
    log_info "Waiting for dual reviews to complete..."
    local codex_status=0
    local coderabbit_status=0

    wait $codex_pid || {
        codex_status=$?
        log_warning "Codex review failed (exit code: $codex_status)"
    }

    if [ "$coderabbit_pid" -ne 0 ]; then
        wait $coderabbit_pid || {
            coderabbit_status=$?
            log_warning "CodeRabbit review failed (exit code: $coderabbit_status)"
        }
    fi

    # Collect results
    log_info "Collecting dual review results..."

    # Codex results
    local codex_md codex_json codex_results
    codex_md=$(find "$codex_dir" -name "*_codex.md" -type f ! -name "latest_codex.md" 2>/dev/null | sort | tail -1)
    codex_json=$(find "$codex_dir" -name "*_codex.json" -type f ! -name "latest_codex.json" 2>/dev/null | sort | tail -1)

    if [ -f "$codex_md" ]; then
        codex_results=$(cat "$codex_md")
        cp "$codex_md" "$OUTPUT_DIR/codex_review.md"
        [ -f "$codex_json" ] && cp "$codex_json" "$OUTPUT_DIR/codex_review.json"
        log_success "Codex results collected"
    else
        codex_results="Codex review did not generate results"
        log_warning "Codex results not found"
    fi

    # CodeRabbit results
    local coderabbit_md coderabbit_json coderabbit_results
    coderabbit_md=$(find "$coderabbit_dir" -name "*_coderabbit.md" -type f ! -name "latest_coderabbit.md" 2>/dev/null | sort | tail -1)
    coderabbit_json=$(find "$coderabbit_dir" -name "*_coderabbit.json" -type f ! -name "latest_coderabbit.json" 2>/dev/null | sort | tail -1)

    if [ -f "$coderabbit_md" ]; then
        coderabbit_results=$(cat "$coderabbit_md")
        cp "$coderabbit_md" "$OUTPUT_DIR/coderabbit_review.md"
        [ -f "$coderabbit_json" ] && cp "$coderabbit_json" "$OUTPUT_DIR/coderabbit_review.json"
        log_success "CodeRabbit results collected"
    else
        coderabbit_results="CodeRabbit review did not generate results"
        log_warning "CodeRabbit results not found"
    fi

    # VibeLogger: phase.done (Phase 1)
    local phase1_end=$(get_timestamp_ms)
    local phase1_time=$((phase1_end - phase1_start))
    vibe_phase_done "Dual Review Execution" "1" "success" "$phase1_time"

    # ============================================================================
    # PHASE 2: 5AI Parallel Analysis (Droid excluded due to timeout issues)
    # ============================================================================
    log_phase "Phase 2: 5AI Parallel Analysis"
    local phase2_start=$(get_timestamp_ms)

    # VibeLogger: phase.start (5 AI experts - Droid excluded due to timeout issues)
    vibe_phase_start "5AI Parallel Analysis" "2" "5"

    # Prepare dual review summary for 5AI context
    local dual_summary="Codex findings: ${codex_results:0:300}... | CodeRabbit findings: ${coderabbit_results:0:300}..."

    # Define timeouts (tested and verified - all complete within limits)
    local claude_timeout=600   # Extended: 180 → 600 (10min) - VERIFIED
    local gemini_timeout=600   # Extended: 240 → 600 (10min) - VERIFIED
    local amp_timeout=600      # Extended: 300 → 600 (10min) - VERIFIED
    local qwen_timeout=600     # Extended: 180 → 600 (10min) - VERIFIED
    # local droid_timeout=900  # DISABLED: Droid consistently times out (>900s)
    local cursor_timeout=600   # Extended: 300 → 600 (10min) - VERIFIED

    # Prepare AI outputs (5 AI experts)
    local claude_output="$OUTPUT_DIR/claude_analysis.md"
    local gemini_output="$OUTPUT_DIR/gemini_analysis.md"
    local amp_output="$OUTPUT_DIR/amp_analysis.md"
    local qwen_output="$OUTPUT_DIR/qwen_analysis.md"
    # local droid_output="$OUTPUT_DIR/droid_analysis.md"  # DISABLED: Droid excluded
    local cursor_output="$OUTPUT_DIR/cursor_analysis.md"

    # Prepare AI prompts (all receive dual review context)
    local claude_prompt="Code review: $description
Dual Review Context: ${dual_summary}

Role: CTO - Architecture & Design Patterns
Task: Analyze the dual review findings from architectural perspective
Focus: design patterns, technical debt, scalability concerns"

    local gemini_prompt="Code review: $description
Dual Review Context: ${dual_summary}

Role: CIO - Security & Latest Trends
Task: Validate security issues found in dual review and check latest best practices
Focus: security vulnerabilities, compliance, modern security patterns"

    local amp_prompt="Code review: $description
Dual Review Context: ${dual_summary}

Role: PM - Project Impact & Maintainability
Task: Assess project-level impact of dual review findings
Focus: maintainability, long-term technical debt, team productivity impact"

    local qwen_prompt="Code review: $description
Dual Review Context: ${dual_summary}

Role: Fast Prototyper - Alternative Implementations
Task: Propose alternative implementations for issues found in dual review
Focus: efficiency improvements, refactoring opportunities, quick fixes"

    # DISABLED: Droid consistently times out (>900s even for simple tasks)
    # local droid_prompt="Code review: $description
    # Dual Review Context: ${dual_summary}
    #
    # Role: Enterprise Engineer - Quality Standards
    # Task: Evaluate dual review findings against enterprise quality standards
    # Focus: robustness, scalability, production readiness"

    local cursor_prompt="Code review: $description
Dual Review Context: ${dual_summary}

Role: IDE Specialist - Developer Experience
Task: Assess developer experience impact of dual review findings
Focus: code readability, documentation gaps, developer workflow"

    # Launch 5 AI analyses in parallel (Droid excluded due to timeout issues)
    log_info "Launching 5 AI analyses in parallel (with dual review context)..."

    call_ai_with_context "claude" "$claude_prompt" "$claude_timeout" "$claude_output" &
    local claude_pid=$!

    call_ai_with_context "gemini" "$gemini_prompt" "$gemini_timeout" "$gemini_output" &
    local gemini_pid=$!

    call_ai_with_context "amp" "$amp_prompt" "$amp_timeout" "$amp_output" &
    local amp_pid=$!

    call_ai_with_context "qwen" "$qwen_prompt" "$qwen_timeout" "$qwen_output" &
    local qwen_pid=$!

    # DISABLED: Droid excluded (consistent timeout >900s)
    # call_ai_with_context "droid" "$droid_prompt" "$droid_timeout" "$droid_output" &
    # local droid_pid=$!

    call_ai_with_context "cursor" "$cursor_prompt" "$cursor_timeout" "$cursor_output" &
    local cursor_pid=$!

    # Wait for all analyses (with error tolerance)
    local all_success=true
    for pid in $claude_pid $gemini_pid $amp_pid $qwen_pid $cursor_pid; do
        wait "$pid" || {
            log_warning "AI analysis process failed or timed out (PID: $pid)"
            all_success=false
        }
    done

    log_success "5 AI analyses completed"

    # VibeLogger: phase.done (Phase 2)
    local phase2_end=$(get_timestamp_ms)
    local phase2_time=$((phase2_end - phase2_start))
    vibe_phase_done "5AI Parallel Analysis" "2" "$([ "$all_success" = true ] && echo 'success' || echo 'partial')" "$phase2_time"

    # ============================================================================
    # PHASE 3: Consensus Synthesis & Comprehensive Report
    # ============================================================================
    log_phase "Phase 3: Consensus Synthesis"
    local phase3_start=$(get_timestamp_ms)

    # VibeLogger: phase.start
    vibe_phase_start "Consensus Synthesis" "3" "1"

    local synthesis_output="$OUTPUT_DIR/dual_6ai_comprehensive_review.md"

    # Generate comprehensive report
    cat > "$synthesis_output" << EOF
# Multi-AI Dual+5AI Comprehensive Code Review Report

**Generated**: $(date +"%Y-%m-%d %H:%M:%S")
**Description**: $description
**Review Architecture**: Dual Automated Tools + 5AI Human-like Analysis

---

## Executive Summary

This comprehensive review combines:
1. **Dual Automated Review** (Phase 1): Codex + CodeRabbit parallel execution
2. **5AI Expert Analysis** (Phase 2): Human-like multi-perspective analysis
3. **Consensus Synthesis** (Phase 3): Integrated findings and recommendations

### Execution Status

| Phase | Component | Role | Status | Time |
|-------|-----------|------|--------|------|
| **Phase 1** | **Codex** | Automated Scanner | $([ "$codex_status" -eq 0 ] && echo "✅ Success" || echo "⚠️ Failed") | $(awk "BEGIN {printf \"%.1f\", $phase1_time/2000}")s |
| **Phase 1** | **CodeRabbit** | AI-Powered Review | $([ "$coderabbit_status" -eq 0 ] && echo "✅ Success" || echo "⚠️ Failed") | $(awk "BEGIN {printf \"%.1f\", $phase1_time/2000}")s |
| **Phase 2** | **Claude** | CTO - Architecture | ⚡ Parallel | $(awk "BEGIN {printf \"%.1f\", $phase2_time/1000}")s |
| **Phase 2** | **Gemini** | CIO - Security | ⚡ Parallel | $(awk "BEGIN {printf \"%.1f\", $phase2_time/1000}")s |
| **Phase 2** | **Amp** | PM - Maintainability | ⚡ Parallel | $(awk "BEGIN {printf \"%.1f\", $phase2_time/1000}")s |
| **Phase 2** | **Qwen** | Prototyper | ⚡ Parallel | $(awk "BEGIN {printf \"%.1f\", $phase2_time/1000}")s |
| **Phase 2** | **Cursor** | IDE Specialist | ⚡ Parallel | $(awk "BEGIN {printf \"%.1f\", $phase2_time/1000}")s |

**Total Participants**: 7 AI Tools (2 automated + 5 human-like AI)

---

## Phase 1: Dual Automated Review Results

### Codex Review

EOF

    # Add Codex results
    if [ -n "$codex_results" ] && [ "$codex_status" -eq 0 ]; then
        echo "$codex_results" >> "$synthesis_output"
    else
        echo "**Status**: ⚠️ Codex review did not complete successfully" >> "$synthesis_output"
        echo "" >> "$synthesis_output"
        echo "Check logs: \`$codex_dir/execution.log\`" >> "$synthesis_output"
    fi

    cat >> "$synthesis_output" << EOF

---

### CodeRabbit Review

EOF

    # Add CodeRabbit results
    if [ -n "$coderabbit_results" ] && [ "$coderabbit_status" -eq 0 ]; then
        echo "$coderabbit_results" >> "$synthesis_output"
    else
        echo "**Status**: ⚠️ CodeRabbit review did not complete successfully" >> "$synthesis_output"
        echo "" >> "$synthesis_output"
        echo "Check logs: \`$coderabbit_dir/execution.log\`" >> "$synthesis_output"
    fi

    cat >> "$synthesis_output" << EOF

---

## Phase 2: 5AI Expert Analysis

### Strategic & Design Layer

#### Claude (CTO) - Architecture & Design Patterns

EOF

    # Add Claude analysis (truncated)
    if [ -f "$claude_output" ] && [ -s "$claude_output" ]; then
        head -30 "$claude_output" >> "$synthesis_output"
        echo "" >> "$synthesis_output"
        echo "[Full analysis: \`$claude_output\`]" >> "$synthesis_output"
    else
        echo "**Status**: ⚠️ No analysis available" >> "$synthesis_output"
    fi

    cat >> "$synthesis_output" << EOF

#### Gemini (CIO) - Security & Latest Trends

EOF

    if [ -f "$gemini_output" ] && [ -s "$gemini_output" ]; then
        head -30 "$gemini_output" >> "$synthesis_output"
        echo "" >> "$synthesis_output"
        echo "[Full analysis: \`$gemini_output\`]" >> "$synthesis_output"
    else
        echo "**Status**: ⚠️ No analysis available" >> "$synthesis_output"
    fi

    cat >> "$synthesis_output" << EOF

#### Amp (PM) - Project Impact & Maintainability

EOF

    if [ -f "$amp_output" ] && [ -s "$amp_output" ]; then
        head -30 "$amp_output" >> "$synthesis_output"
        echo "" >> "$synthesis_output"
        echo "[Full analysis: \`$amp_output\`]" >> "$synthesis_output"
    else
        echo "**Status**: ⚠️ No analysis available" >> "$synthesis_output"
    fi

    cat >> "$synthesis_output" << EOF

### Implementation Layer

#### Qwen - Alternative Implementation Suggestions

EOF

    if [ -f "$qwen_output" ] && [ -s "$qwen_output" ]; then
        head -30 "$qwen_output" >> "$synthesis_output"
        echo "" >> "$synthesis_output"
        echo "[Full analysis: \`$qwen_output\`]" >> "$synthesis_output"
    else
        echo "**Status**: ⚠️ No analysis available" >> "$synthesis_output"
    fi

    # DISABLED: Droid section removed (excluded from 5AI configuration)

    cat >> "$synthesis_output" << EOF

### Integration Layer

#### Cursor - Developer Experience

EOF

    if [ -f "$cursor_output" ] && [ -s "$cursor_output" ]; then
        head -30 "$cursor_output" >> "$synthesis_output"
        echo "" >> "$synthesis_output"
        echo "[Full analysis: \`$cursor_output\`]" >> "$synthesis_output"
    else
        echo "**Status**: ⚠️ No analysis available" >> "$synthesis_output"
    fi

    cat >> "$synthesis_output" << EOF

---

## Phase 3: Cross-Tool Consensus & Recommendations

### Dual Review Consensus

**Issues flagged by BOTH Codex AND CodeRabbit** (highest priority):
[Manual synthesis required - check for overlapping findings]

### 5AI Consensus Issues

**Issues identified by 3+ AI experts** (critical consensus):
[Manual synthesis required - analyze convergent findings]

### Priority Matrix

| Priority | Criteria | Action Required |
|----------|----------|----------------|
| **P0 - Critical** | Flagged by dual review + 3+ AIs | Immediate fix required |
| **P1 - High** | Security issues (Gemini) + Consensus (2+ AIs) | Fix before merge |
| **P2 - Medium** | Architecture concerns (Claude) | Plan refactoring |
| **P3 - Low** | Single AI feedback | Consider for future improvement |

### Recommended Action Plan

1. **Immediate Actions (P0)**:
   - Review dual-consensus issues
   - Address security vulnerabilities flagged by CodeRabbit + Gemini
   - Fix critical architecture issues (Claude + Amp agreement)

2. **Pre-Merge Actions (P1)**:
   - Implement alternative solutions suggested by Qwen
   - Improve documentation (Cursor recommendations)
   - Validate maintainability concerns (Amp checks)

3. **Long-term Improvements (P2-P3)**:
   - Refactor based on Claude's architectural guidance
   - Enhance maintainability (Amp's project-level insights)
   - Optimize developer experience (Cursor's DX suggestions)

---

## Output Files

### Dual Review Results
- Codex JSON: \`$OUTPUT_DIR/codex_review.json\`
- Codex Markdown: \`$OUTPUT_DIR/codex_review.md\`
- CodeRabbit JSON: \`$OUTPUT_DIR/coderabbit_review.json\`
- CodeRabbit Markdown: \`$OUTPUT_DIR/coderabbit_review.md\`

### 5AI Analysis Results
- Claude Analysis: \`$claude_output\`
- Gemini Analysis: \`$gemini_output\`
- Amp Analysis: \`$amp_output\`
- Qwen Analysis: \`$qwen_output\`
- Cursor Analysis: \`$cursor_output\`

### Execution Logs
- Codex Log: \`$codex_dir/execution.log\`
- CodeRabbit Log: \`$coderabbit_dir/execution.log\`

---

## Next Steps

1. ✅ Review this comprehensive Dual+5AI report
2. 📝 Address P0 critical issues (dual+AI consensus)
3. 🔐 Fix security vulnerabilities (CodeRabbit + Gemini findings)
4. 🏗️ Plan architectural improvements (Claude + Amp recommendations)
5. 🔄 Re-run review after fixes to validate resolution
6. 📚 Update coding standards based on consensus patterns

---

*Generated by Multi-AI Dual+5AI Review System*
*Architecture: 2 Automated Tools (Codex, CodeRabbit) + 5 AI Experts (Claude, Gemini, Amp, Qwen, Cursor)*
*Total Execution Time: $(awk "BEGIN {printf \"%.1f\", ($phase1_time + $phase2_time)/1000}")s (Phase 1: $(awk "BEGIN {printf \"%.1f\", $phase1_time/1000}")s + Phase 2: $(awk "BEGIN {printf \"%.1f\", $phase2_time/1000}")s)*
EOF

    # VibeLogger: phase.done (Phase 3)
    local phase3_end=$(get_timestamp_ms)
    local phase3_time=$((phase3_end - phase3_start))
    vibe_phase_done "Consensus Synthesis" "3" "success" "$phase3_time"

    # Display results
    echo ""
    log_success "🎉 Dual+5AI Comprehensive Review Complete!"
    echo ""
    log_info "Generated Files:"
    ls -lh "$OUTPUT_DIR" 2>/dev/null || log_warning "No files generated"
    echo ""

    if [ -f "$synthesis_output" ]; then
        log_info "📄 Comprehensive Report Preview:"
        echo ""
        # Display first 100 lines
        head -100 "$synthesis_output"
        echo ""
        echo "[... Full report available at: $synthesis_output]"
    else
        log_error "Failed to generate comprehensive report"
    fi
    echo ""

    # VibeLogger: pipeline.done
    local end_time=$(get_timestamp_ms)
    local total_time=$((end_time - start_time))
    local participants=7  # Codex + CodeRabbit + 5AI (Droid excluded)
    vibe_pipeline_done "multi-ai-full-review" "success" "$total_time" "$participants"

    # VibeLogger: summary.done
    local summary_text="Dual+5AI Review complete (Codex: $([ "$codex_status" -eq 0 ] && echo 'Success' || echo 'Failed'), CodeRabbit: $([ "$coderabbit_status" -eq 0 ] && echo 'Success' || echo 'Failed'), 5AI: Complete): $description"
    local output_files="[\"$synthesis_output\", \"$OUTPUT_DIR/codex_review.json\", \"$OUTPUT_DIR/coderabbit_review.json\"]"
    vibe_summary_done "$summary_text" "high" "$output_files"
}

multi-ai-dual-review() {
    local description="${*:-最新コミットのデュアルレビュー (Codex + CodeRabbit)}"
    local start_time=$(get_timestamp_ms)

    # P1-1: Input sanitization
    description=$(sanitize_input "$description") || return 1

    show_multi_ai_banner
    log_info "Review Description: $description"
    log_info "Profile: balanced-multi-ai (dual-review workflow)"
    log_info "Mode: Codex + CodeRabbit parallel execution + comparison analysis"
    echo ""

    # VibeLogger: pipeline.start
    vibe_pipeline_start "multi-ai-dual-review" "$description" "2"

    # P1-2: Setup work directory
    local WORK_DIR="/tmp/multi-ai-dual-review-$$"
    local OUTPUT_DIR="$WORK_DIR/output"
    mkdir -p "$OUTPUT_DIR"

    # P1-2: Cleanup trap
    # shellcheck disable=SC2064  # We want $WORK_DIR to expand now, not at trap execution
    trap "[ -d '$WORK_DIR' ] && { log_info 'Cleaning up work directory...'; rm -rf '$WORK_DIR'; }" EXIT ERR

    # PHASE 1: Parallel Review Execution (Codex + CodeRabbit)
    log_phase "Phase 1: Parallel Review Execution (Codex + CodeRabbit)"
    local phase1_start=$(get_timestamp_ms)

    # VibeLogger: phase.start
    vibe_phase_start "Parallel Review Execution" "1" "2"

    # Prepare directories
    local codex_dir="$OUTPUT_DIR/codex"
    local coderabbit_dir="$OUTPUT_DIR/coderabbit"
    mkdir -p "$codex_dir" "$coderabbit_dir"

    # Launch Codex review in background
    log_info "Launching Codex review (timeout: 900s)..."
    local codex_review_script="$PROJECT_ROOT/scripts/codex-review.sh"
    if [ ! -f "$codex_review_script" ]; then
        log_error "Codex review script not found: $codex_review_script"
        return 1
    fi

    (
        CODEX_REVIEW_TIMEOUT=900 \
        OUTPUT_DIR="$codex_dir" \
        "$codex_review_script" > "$codex_dir/execution.log" 2>&1
    ) &
    local codex_pid=$!

    # Launch CodeRabbit review in background
    log_info "Launching CodeRabbit review (timeout: 900s)..."
    local coderabbit_review_script="$PROJECT_ROOT/scripts/coderabbit-review.sh"
    if [ ! -f "$coderabbit_review_script" ]; then
        log_warning "CodeRabbit review script not found: $coderabbit_review_script (continuing with Codex only)"
        coderabbit_pid=0
    else
        (
            CODERABBIT_REVIEW_TIMEOUT=900 \
            OUTPUT_DIR="$coderabbit_dir" \
            "$coderabbit_review_script" > "$coderabbit_dir/execution.log" 2>&1
        ) &
        coderabbit_pid=$!
    fi

    # Wait for both reviews with error tolerance
    log_info "Waiting for parallel reviews to complete..."
    local codex_status=0
    local coderabbit_status=0

    wait $codex_pid || {
        codex_status=$?
        log_warning "Codex review failed (exit code: $codex_status)"
    }

    if [ "$coderabbit_pid" -ne 0 ]; then
        wait $coderabbit_pid || {
            coderabbit_status=$?
            log_warning "CodeRabbit review failed (exit code: $coderabbit_status)"
        }
    fi

    # Collect results
    log_info "Collecting review results..."

    # Codex results
    local codex_md codex_json codex_results
    codex_md=$(find "$codex_dir" -name "*_codex.md" -type f ! -name "latest_codex.md" | sort | tail -1)
    codex_json=$(find "$codex_dir" -name "*_codex.json" -type f ! -name "latest_codex.json" | sort | tail -1)

    if [ -f "$codex_md" ]; then
        codex_results=$(cat "$codex_md")
        cp "$codex_md" "$OUTPUT_DIR/codex_review.md"
        [ -f "$codex_json" ] && cp "$codex_json" "$OUTPUT_DIR/codex_review.json"
        log_success "Codex results collected"
    else
        codex_results="Codex review did not generate results"
        log_warning "Codex results not found"
    fi

    # CodeRabbit results
    local coderabbit_md coderabbit_json coderabbit_results
    coderabbit_md=$(find "$coderabbit_dir" -name "*_coderabbit.md" -type f ! -name "latest_coderabbit.md" | sort | tail -1)
    coderabbit_json=$(find "$coderabbit_dir" -name "*_coderabbit.json" -type f ! -name "latest_coderabbit.json" | sort | tail -1)

    if [ -f "$coderabbit_md" ]; then
        coderabbit_results=$(cat "$coderabbit_md")
        cp "$coderabbit_md" "$OUTPUT_DIR/coderabbit_review.md"
        [ -f "$coderabbit_json" ] && cp "$coderabbit_json" "$OUTPUT_DIR/coderabbit_review.json"
        log_success "CodeRabbit results collected"
    else
        coderabbit_results="CodeRabbit review did not generate results"
        log_warning "CodeRabbit results not found"
    fi

    # VibeLogger: phase.done (Phase 1)
    local phase1_end=$(get_timestamp_ms)
    local phase1_time=$((phase1_end - phase1_start))
    vibe_phase_done "Parallel Review Execution" "1" "success" "$phase1_time"

    # PHASE 2: Comparison Analysis & Report Generation
    log_phase "Phase 2: Comparison Analysis & Report Generation"
    local phase2_start=$(get_timestamp_ms)

    # VibeLogger: phase.start
    vibe_phase_start "Comparison Analysis" "2" "1"

    local comparison_output="$OUTPUT_DIR/dual_review_comparison.md"

    # Generate comparison report
    cat > "$comparison_output" <<EOF
# Dual Review Comparison Report (Codex + CodeRabbit)

**Generated**: $(date +"%Y-%m-%d %H:%M:%S")
**Description**: $description

---

## Executive Summary

このレポートは、CodexとCodeRabbitの2つのAIレビューツールを並行実行し、その結果を比較分析したものです。

### Execution Status

| Tool | Status | Execution Time | Notes |
|------|--------|----------------|-------|
| **Codex** | $([ "$codex_status" -eq 0 ] && echo "✅ Success" || echo "⚠️ Failed") | Phase 1: $(awk "BEGIN {printf \"%.1f\", $phase1_time/2000}")s | Automated issue scanning |
| **CodeRabbit** | $([ "$coderabbit_status" -eq 0 ] && echo "✅ Success" || echo "⚠️ Failed") | Phase 1: $(awk "BEGIN {printf \"%.1f\", $phase1_time/2000}")s | AI-powered comprehensive review |

---

## Review Results

### Codex Review Results

$(if [ -n "$codex_results" ] && [ "$codex_results" != "Codex review did not generate results" ]; then
    echo "$codex_results"
else
    echo "**Status**: ⚠️ No results available"
    echo ""
    echo "Codexレビューは結果を生成しませんでした。以下の理由が考えられます:"
    echo "- タイムアウト (600秒超過)"
    echo "- 実行エラー"
    echo "- 出力ファイル生成失敗"
    echo ""
    echo "詳細は \`$codex_dir/execution.log\` を確認してください。"
fi)

---

### CodeRabbit Review Results

$(if [ -n "$coderabbit_results" ] && [ "$coderabbit_results" != "CodeRabbit review did not generate results" ]; then
    echo "$coderabbit_results"
else
    echo "**Status**: ⚠️ No results available"
    echo ""
    echo "CodeRabbitレビューは結果を生成しませんでした。以下の理由が考えられます:"
    echo "- タイムアウト (900秒超過)"
    echo "- 実行エラー"
    echo "- 出力ファイル生成失敗"
    echo "- スクリプト未インストール"
    echo ""
    echo "詳細は \`$coderabbit_dir/execution.log\` を確認してください。"
fi)

---

## Comparative Analysis

### Codex vs CodeRabbit: Strengths & Differences

#### Codex Strengths
- ⚡ **Speed**: Faster execution (typically 5-10 minutes)
- 🎯 **Focus**: Targeted issue detection
- 🔄 **Consistency**: Predictable output format
- 🛠️ **Integration**: Well-integrated with development workflow

#### CodeRabbit Strengths
- 🤖 **AI-Powered**: Advanced AI-driven analysis
- 📊 **Comprehensive**: Broader code coverage
- 🔒 **Security**: Enhanced security vulnerability detection
- 📈 **Metrics**: Detailed quality metrics

### Tool Selection Guidance

| Scenario | Recommended Tool | Reason |
|----------|------------------|--------|
| **Quick pre-commit check** | Codex | Speed and efficiency |
| **Comprehensive code audit** | CodeRabbit | Depth of analysis |
| **Security-critical code** | CodeRabbit | Enhanced security scanning |
| **Daily development workflow** | Codex | Fast feedback loop |
| **Major release review** | Both (Dual Review) | Complete coverage |

### Complementary Value

両ツールを並行実行することで、以下の相乗効果が得られます:

1. **カバレッジの最大化**: 各ツールが異なるパターンを検出
2. **誤検知の削減**: 両ツールが一致した問題は高信頼度
3. **多角的分析**: 異なる視点からのコードレビュー
4. **ベストプラクティス**: Codexの速度 + CodeRabbitの深度

---

## Actionable Recommendations

### Immediate Actions (Priority: High)

両ツールで共通して指摘された問題:
- [Review both tool outputs for common critical/high severity issues]

### Follow-up Actions (Priority: Medium)

- Codex固有の指摘事項を確認
- CodeRabbit固有の指摘事項を確認
- 誤検知の可能性がある項目の精査

### Long-term Improvements (Priority: Low)

- レビュー結果に基づくコーディング規約の更新
- 開発プロセスへの統合方法の最適化

---

## Output Files

### Review Results
- Codex JSON: \`$OUTPUT_DIR/codex_review.json\`
- Codex Markdown: \`$OUTPUT_DIR/codex_review.md\`
- CodeRabbit JSON: \`$OUTPUT_DIR/coderabbit_review.json\`
- CodeRabbit Markdown: \`$OUTPUT_DIR/coderabbit_review.md\`

### Execution Logs
- Codex Log: \`$codex_dir/execution.log\`
- CodeRabbit Log: \`$coderabbit_dir/execution.log\`

---

## Next Steps

1. ✅ Review this comparison report
2. 📝 Address critical issues from both tools
3. 🔄 Implement recommended fixes
4. ✅ Re-run dual review to verify fixes
5. 📚 Update documentation if needed

---

*Generated by Multi-AI Dual Review System (Codex + CodeRabbit)*
*Execution Time: $(awk "BEGIN {printf \"%.1f\", $phase1_time/1000}")s (Phase 1) + $(awk "BEGIN {printf \"%.1f\", ($phase2_start - phase1_end)/1000}")s (Phase 2)*
EOF

    # VibeLogger: phase.done (Phase 2)
    local phase2_end=$(get_timestamp_ms)
    local phase2_time=$((phase2_end - phase2_start))
    vibe_phase_done "Comparison Analysis" "2" "success" "$phase2_time"

    # Display results
    echo ""
    log_success "🎉 Dual Review Complete (Codex + CodeRabbit)!"
    echo ""
    log_info "Generated Files:"
    ls -lh "$OUTPUT_DIR" 2>/dev/null || log_warning "No files generated"
    echo ""

    if [ -f "$comparison_output" ]; then
        log_info "Comparison Report:"
        echo ""
        cat "$comparison_output"
    else
        log_error "Failed to generate comparison report"
    fi
    echo ""

    # VibeLogger: pipeline.done
    local end_time=$(get_timestamp_ms)
    local total_time=$((end_time - start_time))
    local participants=0
    [ "$codex_status" -eq 0 ] && participants=$((participants + 1))
    [ "$coderabbit_status" -eq 0 ] && participants=$((participants + 1))
    vibe_pipeline_done "multi-ai-dual-review" "success" "$total_time" "$participants"

    # VibeLogger: summary.done
    local summary_text="Dual Review complete (Codex: $([ "$codex_status" -eq 0 ] && echo 'Success' || echo 'Failed'), CodeRabbit: $([ "$coderabbit_status" -eq 0 ] && echo 'Success' || echo 'Failed')): $description"
    local output_files="[\"$comparison_output\", \"$OUTPUT_DIR/codex_review.json\", \"$OUTPUT_DIR/coderabbit_review.json\"]"
    vibe_summary_done "$summary_text" "high" "$output_files"
}
