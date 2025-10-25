#!/usr/bin/env bash
# Multi-AI Core Workflows Library
# Purpose: Core workflow implementations (P1.1.1.1)
# Responsibilities:
#   - full-orchestrate: Balanced 5-8min workflow
#   - speed-prototype: Fast 2-4min workflow (TRUE 7AI participation)
#   - enterprise-quality: Comprehensive 15-20min workflow
#   - hybrid-development: Adaptive workflow (推奨)
#   - consensus-review: Consensus-based review
#   - chatdev-develop: Role-based development workflow
#
# Dependencies:
#   - lib/multi-ai-core.sh (logging, utilities)
#   - lib/multi-ai-ai-interface.sh (call_ai_with_context)
#   - lib/multi-ai-config.sh (execute_yaml_workflow)
#
# Usage:
#   source scripts/orchestrate/lib/workflows-core.sh

set -euo pipefail

# ============================================================================
# Core Workflows (5 functions)
# ============================================================================

# Multi-AI Full Orchestrate (5-8分) - Balanced Multi-AI workflow
# P2-1 & P2-2: YAML-driven with parallel execution
multi-ai-full-orchestrate() {
    local task="$*"

    # P1-1: Input sanitization
    task=$(sanitize_input "$task") || return 1

    show_multi_ai_banner
    log_info "Task: $task"
    log_info "Profile: balanced-multi-ai (5-8分想定)"
    log_info "Mode: YAML-driven with parallel execution"
    echo ""

    # P2-1 & P2-2: Execute workflow using YAML configuration
    execute_yaml_workflow "$DEFAULT_PROFILE" "multi-ai-full-orchestrate" "$task"
}

# Multi-AI Speed Prototype (2-4分)
# TRUE Multi-AI: All 7 AIs participate
multi-ai-speed-prototype() {
    local task="$*"

    # P1-1: Input sanitization
    task=$(sanitize_input "$task") || return 1

    show_multi_ai_banner
    log_info "Task: $task"
    log_info "Profile: speed-first-7ai (TRUE Multi-AI - 全AI参加)"
    echo ""

    # P1-2: Setup work directory
    # P1-2: Setup work directory - persistent logs for audit trail
    local WORK_DIR="$PROJECT_ROOT/logs/multi-ai-reviews/$(date +%Y%m%d-%H%M%S)-$$-full-orchestrate"
    local OUTPUT_DIR="$WORK_DIR/output"
    mkdir -p "$OUTPUT_DIR"
    log_info "Work directory: $WORK_DIR (logs will be preserved)"

    # PHASE 1: 戦略・設計層 (Claude, Gemini, Amp - 並列実行)
    log_phase "Phase 1: Strategic Layer (Claude + Gemini + Amp 並列)"

    local claude_output="$OUTPUT_DIR/claude_architecture.md"
    local claude_prompt="$task

ファイルパス: $PROJECT_ROOT/examples/eva_tetris.py

役割: CTO - アーキテクチャレビュー
- 全体設計の妥当性を評価
- 技術的リスクを特定
- 改善アーキテクチャを提案"

    local gemini_output="$OUTPUT_DIR/gemini_research.md"
    local gemini_prompt="$task

ファイルパス: $PROJECT_ROOT/examples/eva_tetris.py

役割: CIO - 技術調査
- 主要な技術スタック、ライブラリ、アプローチを提案
- 最新のベストプラクティスを調査"

    local amp_output="$OUTPUT_DIR/amp_project_plan.md"
    local amp_prompt="$task

ファイルパス: $PROJECT_ROOT/examples/eva_tetris.py

役割: PM - プロジェクト管理
- 実装計画を策定
- タスクの優先順位を決定
- リスク管理計画を作成"

    # Launch strategic layer in parallel
    call_ai_with_context "claude" "$claude_prompt" 120 "$claude_output" &
    local claude_pid=$!
    call_ai_with_context "gemini" "$gemini_prompt" 180 "$gemini_output" &
    local gemini_pid=$!
    call_ai_with_context "amp" "$amp_prompt" 120 "$amp_output" &
    local amp_pid=$!

    # Wait for all strategic layer AIs
    wait $claude_pid || log_warning "Claude architecture review timed out or failed"
    wait $gemini_pid || log_warning "Gemini research timed out or failed"
    wait $amp_pid || log_warning "Amp planning timed out or failed"

    # Collect strategic layer results
    local architecture=""
    local research=""
    local plan=""
    [ -f "$claude_output" ] && architecture=$(cat "$claude_output")
    [ -f "$gemini_output" ] && research=$(cat "$gemini_output")
    [ -f "$amp_output" ] && plan=$(cat "$amp_output")

    # PHASE 2: 実装層 (Qwen + Droid - 並列/冗長実行)
    log_phase "Phase 2: Implementation Layer (Qwen + Droid 並列競争)"

    local qwen_output="$OUTPUT_DIR/qwen_prototype.py"
    local qwen_prompt="タスク: $task

ファイルパス: $PROJECT_ROOT/examples/eva_tetris.py

Claudeのアーキテクチャレビュー:
$architecture

Geminiの調査結果:
$research

Ampのプロジェクト計画:
$plan

役割: 高速プロトタイパー (目標37秒)
- 上記を参考に高速プロトタイプを生成
- 実行可能なコード
- 基本的なエラーハンドリング
- コメント付き

重要: ファイルは $PROJECT_ROOT/examples/eva_tetris.py に存在します。"

    local droid_output="$OUTPUT_DIR/droid_enterprise.py"
    local droid_prompt="タスク: $task

ファイルパス: $PROJECT_ROOT/examples/eva_tetris.py

Claudeのアーキテクチャレビュー:
$architecture

Geminiの調査結果:
$research

Ampのプロジェクト計画:
$plan

役割: エンタープライズエンジニア (目標180秒)
- 上記を参考に本番品質のコードを生成
- 完全なエラーハンドリング
- 包括的なドキュメント
- セキュリティとパフォーマンスを考慮

重要: ファイルは $PROJECT_ROOT/examples/eva_tetris.py に存在します。"

    # Launch implementation layer in parallel
    call_ai_with_context "qwen" "$qwen_prompt" 240 "$qwen_output" &
    local qwen_pid=$!
    call_ai_with_context "droid" "$droid_prompt" 900 "$droid_output" &  # 300→900秒: 実測で600秒でも大規模タスク失敗
    local droid_pid=$!

    # Wait for both implementations
    wait $qwen_pid || log_warning "Qwen prototype timed out or failed"
    wait $droid_pid || log_warning "Droid enterprise implementation timed out or failed"

    # Collect implementation results
    local qwen_impl=""
    local droid_impl=""
    [ -f "$qwen_output" ] && qwen_impl=$(cat "$qwen_output")
    [ -f "$droid_output" ] && droid_impl=$(cat "$droid_output")

    # PHASE 3: レビュー層 (Codex)
    log_phase "Phase 3: Review Layer (Codex)"

    local codex_output="$OUTPUT_DIR/codex_review.md"
    local codex_prompt="以下の2つの実装をレビューしてください:

対象ファイル: $PROJECT_ROOT/examples/eva_tetris.py

【Qwen高速プロトタイプ】:
$qwen_impl

【Droid本番実装】:
$droid_impl

レビュー観点:
1. Qwen vs Droid の比較評価
2. 明らかなバグ
3. セキュリティリスク
4. パフォーマンス問題
5. 最終実装への推奨事項"

    call_ai_with_context "codex" "$codex_prompt" 240 "$codex_output"

    local review=""
    [ -f "$codex_output" ] && review=$(cat "$codex_output")

    # PHASE 4: 統合層 (Cursor)
    log_phase "Phase 4: Integration Layer (Cursor)"

    local cursor_output="$OUTPUT_DIR/final_implementation.py"

    # Create highly summarized results for efficient processing
    local strategic_summary="戦略層要点: アーキテクチャ-$(( $(echo "$architecture" | wc -l) > 0 ? 1 : 0 ))件、技術調査-$(( $(echo "$research" | wc -l) > 0 ? 1 : 0 ))件、プロジェクト計画-$(( $(echo "$plan" | wc -l) > 0 ? 1 : 0 ))件"
    local implementation_summary="実装層要点: Qwen-$(( $(echo "$qwen_impl" | wc -l) > 0 ? 1 : 0 ))件、Droid-$(( $(echo "$droid_impl" | wc -l) > 0 ? 1 : 0 ))件コード生成完了"
    local review_summary="レビュー層要点: Codex-$(( $(echo "$review" | wc -l) > 0 ? 1 : 0 ))件の改善提案あり"

    # Create detailed reference files for full context
    echo "$architecture" > "$OUTPUT_DIR/claude_full.txt"
    echo "$research" > "$OUTPUT_DIR/gemini_full.txt"
    echo "$plan" > "$OUTPUT_DIR/amp_full.txt"
    echo "$qwen_impl" > "$OUTPUT_DIR/qwen_full.txt"
    echo "$droid_impl" > "$OUTPUT_DIR/droid_full.txt"
    echo "$review" > "$OUTPUT_DIR/codex_full.txt"

    # Create a shorter reference guide for Cursor
    cat > "$OUTPUT_DIR/reference_guide.txt" << EOF
==== Multi-AI SPEED PROTOTYPE REFERENCE GUIDE ====

TARGET: $PROJECT_ROOT/examples/eva_tetris.py

1. STRATEGIC INPUTS:
$strategic_summary

2. IMPLEMENTATION RESULTS:
$implementation_summary

3. REVIEW FEEDBACK:
$review_summary

4. DETAILED FILES:
- $OUTPUT_DIR/claude_full.txt  # Architecture
- $OUTPUT_DIR/gemini_full.txt  # Research
- $OUTPUT_DIR/amp_full.txt     # Project Plan
- $OUTPUT_DIR/qwen_full.txt    # Qwen Prototype
- $OUTPUT_DIR/droid_full.txt   # Droid Implementation
- $OUTPUT_DIR/codex_full.txt   # Review & Recommendations

5. INTEGRATION OBJECTIVES:
- Merge best elements from Qwen (speed) and Droid (quality)
- Apply Codex review recommendations
- Generate executable, well-tested code
- Add comprehensive test cases

==== END REFERENCE GUIDE ====
EOF

    local cursor_prompt="統合タスク: $PROJECT_ROOT/examples/eva_tetris.py

要約: Multi-AI協調プロセスの成果を統合して最終実装を生成

役割: IDE統合スペシャリスト

要件:
- Codexレビューの推奨事項を反映
- Qwenの高速性 + Droidの品質を統合
- 実行可能なコード生成
- テストケース追加

詳細情報は $OUTPUT_DIR/reference_guide.txt に記載されています。

重要: 効率的な処理のため、上記要約を参考にしながら、必要に応じてreference_guide.txtの詳細ファイルを参照してください。"

    call_ai_with_context "cursor" "$cursor_prompt" 900 "$cursor_output"

    # Display results
    echo ""
    log_success "🎉 TRUE Multi-AI Speed Prototype Complete!"
    echo ""
    log_info "Generated Files (7 AIs):"
    ls -lh "$OUTPUT_DIR" 2>/dev/null || log_warning "No files generated"
    echo ""

    if [ -f "$cursor_output" ]; then
        log_info "Final Implementation (Cursor統合):"
        echo ""
        cat "$cursor_output"
    elif [ -f "$droid_output" ]; then
        log_warning "Cursor failed, showing Droid implementation:"
        echo ""
        cat "$droid_output"
    elif [ -f "$qwen_output" ]; then
        log_warning "Droid & Cursor failed, showing Qwen prototype:"
        echo ""
        cat "$qwen_output"
    else
        log_error "No implementation generated"
    fi
    echo ""
}

# Multi-AI Enterprise Quality (15-20分)
# P2-1 & P2-2: YAML-driven with parallel execution
multi-ai-enterprise-quality() {
    local task="$*"

    # P1-1: Input sanitization
    task=$(sanitize_input "$task") || return 1

    show_multi_ai_banner
    log_info "Task: $task"
    log_info "Profile: balanced-multi-ai (15-20分想定)"
    log_info "Workflow: multi-ai-enterprise-quality"
    log_info "Mode: YAML-driven with parallel execution"
    echo ""

    # P2-1 & P2-2: Execute workflow using YAML configuration
    execute_yaml_workflow "$DEFAULT_PROFILE" "multi-ai-enterprise-quality" "$task"
}

# Multi-AI Hybrid Development (推奨)
# P2-1 & P2-2: YAML-driven with parallel execution
multi-ai-hybrid-development() {
    local task="$*"

    # P1-1: Input sanitization
    task=$(sanitize_input "$task") || return 1

    show_multi_ai_banner
    log_info "Task: $task"
    log_info "Profile: balanced-multi-ai (hybrid-development workflow)"
    log_info "Mode: YAML-driven with parallel execution (推奨)"
    echo ""

    # P2-1 & P2-2: Execute workflow using YAML configuration
    execute_yaml_workflow "$DEFAULT_PROFILE" "multi-ai-hybrid-development" "$task"
}

# Multi-AI Consensus Review
# P2-1 & P2-2: YAML-driven with parallel execution
multi-ai-consensus-review() {
    local target="$*"

    # P1-1: Input sanitization
    target=$(sanitize_input "$target") || return 1

    show_multi_ai_banner
    log_info "Target: $target"
    log_info "Profile: balanced-multi-ai (consensus-review workflow)"
    log_info "Mode: YAML-driven with parallel execution"
    echo ""

    # P2-1 & P2-2: Execute workflow using YAML configuration
    execute_yaml_workflow "$DEFAULT_PROFILE" "multi-ai-consensus-review" "$target"
}

# ============================================================================
# ChatDev Workflows (1 function)
# ============================================================================

# Multi-AI ChatDev Development
# P2-1 & P2-2: YAML-driven with parallel execution
multi-ai-chatdev-develop() {
    local project="$*"

    # P1-1: Input sanitization
    project=$(sanitize_input "$project") || return 1

    show_multi_ai_banner
    log_info "Project: $project"
    log_info "Profile: balanced-multi-ai (chatdev-develop workflow)"
    log_info "Mode: Role-based development (CEO→CTO→Programmers→Reviewer→Tester)"
    echo ""

    # P2-1 & P2-2: Execute workflow using YAML configuration
    execute_yaml_workflow "$DEFAULT_PROFILE" "multi-ai-chatdev-develop" "$project"
}
