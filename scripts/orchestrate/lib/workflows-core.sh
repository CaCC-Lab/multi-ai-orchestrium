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
# Core Dependencies (Load First)
# ============================================================================

# CRITICAL: Load multi-ai-core.sh BEFORE any log function usage
# Provides: log_info, log_warning, log_error, log_success, color variables
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

if ! declare -f log_info > /dev/null 2>&1; then
    source "$SCRIPT_DIR/multi-ai-core.sh" 2>/dev/null || {
        echo "ERROR: multi-ai-core.sh not found" >&2
        return 1
    }
fi

# ============================================================================
# Feature Flags & Dependencies
# ============================================================================

# Git Worktrees統合フラグ（Day 3実装）
ENABLE_WORKTREES="${ENABLE_WORKTREES:-false}"
WORKTREE_SHADOW_MODE="${WORKTREE_SHADOW_MODE:-false}"
WORKTREE_ENABLED_AIS="${WORKTREE_ENABLED_AIS:-claude,gemini,amp,qwen,droid,codex,cursor}"

# ワークツリーモジュールのロード
if [[ "$ENABLE_WORKTREES" == "true" || "$WORKTREE_SHADOW_MODE" == "true" ]]; then
    source "$SCRIPT_DIR/worktree-manager.sh" 2>/dev/null || {
        log_warning "worktree-manager.sh not found, Worktrees disabled"
        ENABLE_WORKTREES=false
    }
    source "$SCRIPT_DIR/worktree-parallel.sh" 2>/dev/null || {
        log_warning "worktree-parallel.sh not found, parallel optimization disabled"
    }

    if [[ "$WORKTREE_SHADOW_MODE" == "true" ]]; then
        log_info "✓ Git Worktrees: Shadow Mode (logging only)"
    elif [[ "$ENABLE_WORKTREES" == "true" ]]; then
        log_info "✓ Git Worktrees: Enabled for [$WORKTREE_ENABLED_AIS]"
    fi
fi

# AsyncThink Phase 2: JOIN待機ポリシー & リソース管理
source "$SCRIPT_DIR/lib/join-policy.sh" 2>/dev/null || log_warning "JOIN Policy library not found"
source "$SCRIPT_DIR/lib/resource-limiter.sh" 2>/dev/null || log_warning "Resource Limiter library not found"

# JOIN待機ポリシー設定（eager | lazy | hybrid）
JOIN_POLICY="${JOIN_POLICY:-hybrid}"
log_info "✓ JOIN Policy: $JOIN_POLICY"

# ============================================================================
# Core Workflows (5 functions)
# ============================================================================

# Multi-AI Full Orchestrate (5-8分) - Balanced Multi-AI workflow
# P2-1 & P2-2: YAML-driven with parallel execution
# AsyncThink v4.0 Canary: Simple Fork-Join Workflow
# Fork-Join基本パターン（Qwen + Droid並列実行）
multi-ai-simple-fork-join() {
    local task="$*"

    # P1-1: Input sanitization
    task=$(sanitize_input "$task") || return 1

    # M-1修正: セキュアな一時ファイル生成（mktemp + chmod 600）
    local temp_file_qwen
    local temp_file_droid
    temp_file_qwen=$(mktemp /tmp/fork-1-qwen-XXXXXX) || {
        log_error "Failed to create secure temp file for Qwen"
        return 1
    }
    temp_file_droid=$(mktemp /tmp/fork-2-droid-XXXXXX) || {
        log_error "Failed to create secure temp file for Droid"
        rm -f "$temp_file_qwen"
        return 1
    }

    # M-1修正: パーミッション設定（所有者のみ読み書き）
    chmod 600 "$temp_file_qwen" || {
        log_error "Failed to set permissions on Qwen temp file"
        rm -f "$temp_file_qwen" "$temp_file_droid"
        return 1
    }
    chmod 600 "$temp_file_droid" || {
        log_error "Failed to set permissions on Droid temp file"
        rm -f "$temp_file_qwen" "$temp_file_droid"
        return 1
    }

    # M-1修正: 自動クリーンアップ（EXIT/INT/TERMシグナル時）
    # set -u対策: 変数未定義時のエラーを回避
    trap 'rm -f "${temp_file_qwen:-}" "${temp_file_droid:-}"' EXIT INT TERM

    show_multi_ai_banner
    log_info "Task: $task"
    log_info "Profile: simple-fork-join (AsyncThink v4.0 Canary)"
    log_info "Mode: Fork-Join parallel execution (2 workers)"
    echo ""

    # DAG可視化
    log_info "📊 Visualizing Fork-Join DAG structure..."
    bash "$SCRIPT_DIR/lib/fork-join-visualizer.sh" \
        "$PROJECT_ROOT/config/multi-ai-profiles.yaml" \
        "simple-fork-join" || true
    echo ""

    # Phase 2では完全なFork-Join実行エンジンを使用
    # 現在は基本的な並列実行でシミュレート
    log_info "🔀 Starting Fork-Join execution (simulated)..."
    echo ""

    # FORK-1: Qwen高速プロトタイプ（並列実行）
    log_phase_start "FORK-1: Qwen - Fast Prototype" "qwen"
    local qwen_start=$(date +%s)
    local qwen_output=""
    (
        qwen_output=$(call_ai "qwen" "Task: $task\n\nRole: 高速プロトタイプ実装\nTimeout: 300秒" 300 2>&1)
        echo "$qwen_output" > "$temp_file_qwen"
    ) &
    local qwen_pid=$!

    # FORK-2: Droidエンタープライズ実装（並列実行）
    log_phase_start "FORK-2: Droid - Enterprise Implementation" "droid"
    local droid_start=$(date +%s)
    local droid_output=""
    (
        droid_output=$(call_ai "droid" "Task: $task\n\nRole: エンタープライズ品質実装\nTimeout: 900秒" 900 2>&1)
        echo "$droid_output" > "$temp_file_droid"
    ) &
    local droid_pid=$!

    log_info "⏳ Parallel execution started (PIDs: qwen=$qwen_pid, droid=$droid_pid)"
    echo ""

    # JOIN待機ポリシー選択（Phase 2, Week 15-16）
    case "$JOIN_POLICY" in
        eager)
            join_policy_eager $qwen_pid $droid_pid "$temp_file_qwen" "$temp_file_droid" $qwen_start $droid_start
            local join_exit=$?
            ;;
        lazy)
            join_policy_lazy $qwen_pid $droid_pid "$temp_file_qwen" "$temp_file_droid" $qwen_start $droid_start
            local join_exit=$?
            ;;
        hybrid)
            join_policy_hybrid $qwen_pid $droid_pid "$temp_file_qwen" "$temp_file_droid" $qwen_start $droid_start 300
            local join_exit=$?
            ;;
        *)
            log_error "Unknown JOIN_POLICY: $JOIN_POLICY"
            return 1
            ;;
    esac

    echo ""

    # 結果読み込み
    local qwen_output=""
    local droid_output=""
    [[ -f "$temp_file_qwen" ]] && qwen_output=$(cat "$temp_file_qwen")
    [[ -f "$temp_file_droid" ]] && droid_output=$(cat "$temp_file_droid")

    # 成功判定
    if [[ $join_exit -eq 0 ]]; then
        log_info "✅ Simple Fork-Join workflow completed successfully"
        echo ""
        log_info "📝 Combined results:"
        echo "=== Qwen (Fast Prototype) ==="
        echo "$qwen_output"
        echo ""
        echo "=== Droid (Enterprise Implementation) ==="
        echo "$droid_output"
        return 0
    else
        log_error "❌ Simple Fork-Join workflow failed (exit code: $join_exit)"
        return 1
    fi
}

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

    # フィーチャーフラグ表示
    if [[ "$ENABLE_WORKTREES" == "true" ]]; then
        log_info "Mode: Git Worktrees統合モード（並列AI実行・競合ゼロ）"
    else
        log_info "Mode: Legacy並列実行モード"
    fi
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
    if [[ "$ENABLE_WORKTREES" == "true" ]]; then
        # NEW: ワークツリーベース並列実行（競合ゼロ）
        log_info "Creating worktrees for Qwen and Droid..."
        create_all_worktrees qwen droid

        log_info "Executing parallel implementations in isolated worktrees..."
        # ワークツリー内でAI実行
        (cd "$WORKTREE_BASE_DIR/qwen" && call_ai_with_context "qwen" "$qwen_prompt" 240 "$qwen_output") &
        local qwen_pid=$!
        (cd "$WORKTREE_BASE_DIR/droid" && call_ai_with_context "droid" "$droid_prompt" 900 "$droid_output") &
        local droid_pid=$!

        # Wait for both implementations
        wait $qwen_pid || log_warning "Qwen prototype timed out or failed"
        wait $droid_pid || log_warning "Droid enterprise implementation timed out or failed"

        # 結果をメインディレクトリにコピー
        [ -f "$WORKTREE_BASE_DIR/qwen/$qwen_output" ] && cp "$WORKTREE_BASE_DIR/qwen/$qwen_output" "$qwen_output"
        [ -f "$WORKTREE_BASE_DIR/droid/$droid_output" ] && cp "$WORKTREE_BASE_DIR/droid/$droid_output" "$droid_output"
    else
        # LEGACY: 直接実行（後方互換性）
        call_ai_with_context "qwen" "$qwen_prompt" 240 "$qwen_output" &
        local qwen_pid=$!
        call_ai_with_context "droid" "$droid_prompt" 900 "$droid_output" &  # 300→900秒: 実測で600秒でも大規模タスク失敗
        local droid_pid=$!

        # Wait for both implementations
        wait $qwen_pid || log_warning "Qwen prototype timed out or failed"
        wait $droid_pid || log_warning "Droid enterprise implementation timed out or failed"
    fi

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

    # クリーンアップ（ワークツリーモードの場合）
    if [[ "$ENABLE_WORKTREES" == "true" ]]; then
        log_info "Cleaning up worktrees..."
        cleanup_all_worktrees
        log_info "✓ Worktrees cleaned up successfully"
    fi
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

# ============================================================================
# Collaborative Planning Workflows (1 function)
# ============================================================================

# Multi-AI Collaborative Planning
# Purpose: Generate comprehensive implementation plan with all 7 AIs
# Output: Checklist-style Markdown document (PLAN-PROMPT.md compliant)
# Duration: ~45 minutes (Phase 1: 15min, Phase 2: 20min, Phase 3: 10min)
# P2-1 & P2-2: YAML-driven with parallel execution
multi-ai-collaborative-planning() {
    local task="$*"

    # P1-1: Input sanitization
    task=$(sanitize_input "$task") || return 1

    show_multi_ai_banner
    log_info "Task: $task"
    log_info "Profile: balanced-multi-ai (collaborative-planning workflow)"
    log_info "Mode: 7AI協調による実装計画書生成 (~45分)"
    log_info "Output: チェックリスト式Markdown (PLAN-PROMPT.md準拠)"
    echo ""
    log_info "Phase 1: Strategic Analysis (Claude, Gemini, Amp 並列 ~15分)"
    log_info "Phase 2: Detailed Design (Qwen, Droid, Codex 並列 ~20分)"
    log_info "Phase 3: Integration & Validation (Cursor → Claude順次 ~10分)"
    echo ""

    # P2-1 & P2-2: Execute workflow using YAML configuration
    execute_yaml_workflow "$DEFAULT_PROFILE" "multi-ai-collaborative-planning" "$task"
}

# Multi-AI Collaborative Testing
# Purpose: Generate comprehensive test code with all 7 AIs
# Output: Test analysis table + Test code (TESTCODE-PROMPT.md compliant)
# Duration: ~70 minutes (Phase 1: 15min, Phase 2: 20min, Phase 3: 25min, Phase 4: 10min)
# P2-1 & P2-2: YAML-driven with parallel execution
multi-ai-collaborative-testing() {
    local target="$*"

    # P1-1: Input sanitization
    target=$(sanitize_input "$target") || return 1

    show_multi_ai_banner
    log_info "Target: $target"
    log_info "Profile: balanced-multi-ai (collaborative-testing workflow)"
    log_info "Mode: 7AI協調によるテストコード生成 (~70分)"
    log_info "Output: テスト観点表 + テストコード (TESTCODE-PROMPT.md準拠)"
    echo ""
    log_info "Phase 1: Test Strategy Definition (Gemini, Amp, Droid 並列 ~15分)"
    log_info "Phase 2: Test Analysis Table (Claude, Qwen, Codex 並列 ~20分)"
    log_info "Phase 3: Test Implementation (Qwen, Droid, Codex 並列 ~25分)"
    log_info "Phase 4: Verification & Execution (Cursor → Claude順次 ~10分)"
    echo ""
    log_info "必須要件: 失敗系 ≥ 正常系、分岐網羅100%目標、Given/When/Then形式"
    echo ""

    # P2-1 & P2-2: Execute workflow using YAML configuration
    execute_yaml_workflow "$DEFAULT_PROFILE" "multi-ai-collaborative-testing" "$target"
}

# ============================================================================
# Git Worktrees Integration (Day 3)
# ============================================================================

# Execute AI task with optional Worktree isolation
#
# Usage: execute_ai_with_worktree <ai> <task> <worktree_enabled> [branch] [task_id]
#
# Args:
#   ai: AI name (qwen, droid, etc.)
#   task: Task description
#   worktree_enabled: "true" | "false"
#   branch: Optional branch name (default: feature/<ai>-<timestamp>)
#   task_id: Optional task ID (default: <ai>-<timestamp>)
#
# Returns:
#   0 on success, 1 on failure
#
# Example:
#   execute_ai_with_worktree "qwen" "Implement authentication" "true"
#
execute_ai_with_worktree() {
    local ai="$1"
    local task="$2"
    local worktree_enabled="${3:-false}"
    local branch="${4:-feature/${ai}-$(date +%Y%m%d%H%M%S)}"
    local task_id="${5:-${ai}-task-$(date +%Y%m%d%H%M%S)}"
    local timeout="${6:-300}"  # Default 5 minutes

    # Check if AI is in enabled list
    if [[ "$worktree_enabled" == "true" ]]; then
        if ! echo ",$WORKTREE_ENABLED_AIS," | grep -q ",${ai},"; then
            log_warning "Worktree not enabled for $ai, using standard execution"
            worktree_enabled="false"
        fi
    fi

    # Shadow mode: log only, don't create worktrees
    if [[ "$WORKTREE_SHADOW_MODE" == "true" ]]; then
        log_info "[Shadow Mode] Would create worktree for $ai: $branch"
        # Fall through to standard execution
        worktree_enabled="false"
    fi

    # Standard execution (no worktree)
    if [[ "$worktree_enabled" != "true" || "$ENABLE_WORKTREES" != "true" ]]; then
        log_info "Executing $ai (standard mode)"
        call_ai "$ai" "$task" "$timeout"
        return $?
    fi

    # === Worktree Execution Path ===

    log_info "Executing $ai with Worktree isolation"
    log_info "  Branch: $branch"
    log_info "  Task ID: $task_id"

    # Step 1: Create worktree
    local worktree_path
    if ! worktree_path=$(create_worktree "$ai" "$branch" "$task_id"); then
        log_error "Failed to create worktree for $ai"
        log_warning "Falling back to standard execution"
        call_ai "$ai" "$task" "$timeout"
        return $?
    fi

    log_success "Worktree created: $worktree_path"

    # Step 2: Execute AI in worktree
    local exit_code=0
    (
        cd "$worktree_path" || exit 1
        export AI_WORKSPACE="$worktree_path"
        log_info "Working in worktree: $(pwd)"

        # Call AI
        call_ai "$ai" "$task" "$timeout"
    ) || exit_code=$?

    # Step 3: Merge worktree (if successful)
    if [[ $exit_code -eq 0 ]]; then
        log_info "Merging $ai worktree..."
        if merge_worktree "$ai" "$task_id"; then
            log_success "$ai worktree merged successfully"
        else
            log_error "Failed to merge $ai worktree"
            exit_code=1
        fi
    else
        log_error "$ai execution failed in worktree"
        log_warning "Worktree left intact for debugging: $worktree_path"
        # Don't auto-cleanup on failure (manual investigation)
        return $exit_code
    fi

    # Step 4: Cleanup worktree (on success)
    if [[ $exit_code -eq 0 ]]; then
        if cleanup_worktree "$ai" "$task_id" "false"; then
            log_success "$ai worktree cleaned up"
        else
            log_warning "Failed to cleanup $ai worktree (non-fatal)"
        fi
    fi

    return $exit_code
}

# Execute multiple AIs with parallel worktrees
#
# Usage: execute_ais_with_worktrees_parallel <ai1> <ai2> ... <aiN> -- <task>
#
# Example:
#   execute_ais_with_worktrees_parallel qwen droid codex -- "Implement authentication"
#
execute_ais_with_worktrees_parallel() {
    local ais=()
    local task=""

    # Parse arguments (before --)
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--" ]]; then
            shift
            task="$*"
            break
        fi
        ais+=("$1")
        shift
    done

    if [[ ${#ais[@]} -eq 0 || -z "$task" ]]; then
        log_error "Usage: execute_ais_with_worktrees_parallel <ai1> ... -- <task>"
        return 1
    fi

    log_info "Parallel worktree execution for ${#ais[@]} AIs"

    # Step 1: Create worktrees in parallel
    if ! create_worktrees_parallel "${ais[@]}"; then
        log_error "Failed to create worktrees in parallel"
        return 1
    fi

    # Step 2: Execute AIs in parallel (TODO: implement parallel execution)
    local exit_code=0
    for ai in "${ais[@]}"; do
        execute_ai_with_worktree "$ai" "$task" "true" &
    done
    wait || exit_code=$?

    # Step 3: Cleanup worktrees in parallel
    if ! cleanup_worktrees_parallel "${ais[@]}"; then
        log_warning "Failed to cleanup worktrees in parallel (non-fatal)"
    fi

    return $exit_code
}

# Check if worktree is enabled for a specific AI
#
# Usage: is_worktree_enabled_for_ai <ai>
#
# Returns: 0 if enabled, 1 if disabled
#
is_worktree_enabled_for_ai() {
    local ai="$1"

    if [[ "$ENABLE_WORKTREES" != "true" ]]; then
        return 1
    fi

    if echo ",$WORKTREE_ENABLED_AIS," | grep -q ",${ai},"; then
        return 0
    else
        return 1
    fi
}

