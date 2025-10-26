#!/usr/bin/env bash
# review-dispatcher.sh - ルールベース自動ルーティング
# Version: 1.0.0
# Purpose: Git diffの内容を分析し、適切なレビュータイプを自動選択
# Reference: OPTION_D++_IMPLEMENTATION_PLAN.md Phase 3A.2.1

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Multi-AI Review Script
MULTI_AI_REVIEW="${SCRIPT_DIR}/multi-ai-review.sh"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ============================================================================
# P3A.2.1.1: コンテキスト分析
# ============================================================================

analyze_git_diff() {
    local commit="${1:-HEAD}"

    # Git diffを取得
    local diff_output=$(git diff "${commit}^" "$commit" 2>/dev/null || git show "$commit" 2>/dev/null)

    if [[ -z "$diff_output" ]]; then
        echo "Error: No changes found for commit $commit" >&2
        return 1
    fi

    # 結果を返す（グローバル変数に格納）
    ANALYZED_DIFF="$diff_output"
    echo "$diff_output"
}

analyze_file_types() {
    local diff="$1"

    # ファイル種別を判定
    local has_security_files=false
    local has_config_files=false
    local has_test_files=false
    local has_docs_files=false

    # セキュリティ関連ファイル
    if echo "$diff" | grep -qE "diff --git.*/(auth|security|crypto|jwt|token|password|credentials|secrets)"; then
        has_security_files=true
    fi

    # 設定ファイル
    if echo "$diff" | grep -qE "diff --git.*/(.env|config\.(yml|yaml|json|toml)|docker|Dockerfile)"; then
        has_config_files=true
    fi

    # テストファイル
    if echo "$diff" | grep -qE "diff --git.*/test|spec|__tests__"; then
        has_test_files=true
    fi

    # ドキュメントファイル
    if echo "$diff" | grep -qE "diff --git.*/(README|docs|\.md)"; then
        has_docs_files=true
    fi

    # 結果を返す（グローバル変数に格納）
    HAS_SECURITY_FILES=$has_security_files
    HAS_CONFIG_FILES=$has_config_files
    HAS_TEST_FILES=$has_test_files
    HAS_DOCS_FILES=$has_docs_files
}

analyze_change_size() {
    local diff="$1"

    # 変更行数を計算
    local added_lines=$(echo "$diff" | grep -c "^+" | grep -v "^+++" || echo 0)
    local deleted_lines=$(echo "$diff" | grep -c "^-" | grep -v "^---" || echo 0)
    local changed_lines=$((added_lines + deleted_lines))

    # ファイル数を計算
    local changed_files=$(echo "$diff" | grep -c "^diff --git" || echo 0)

    # 結果を返す（グローバル変数に格納）
    CHANGED_LINES=$changed_lines
    CHANGED_FILES=$changed_files
}

analyze_security_keywords() {
    local diff="$1"

    local security_score=0

    # セキュリティクリティカルなキーワードを検索
    local keywords=(
        "password" "passwd" "secret" "token" "apikey" "api_key"
        "auth" "authentication" "authorization" "credential"
        "crypto" "encrypt" "decrypt" "hash" "salt"
        "jwt" "oauth" "session" "cookie"
        "sql" "query" "exec" "eval" "system"
        "input" "sanitize" "validate" "escape"
        "xss" "csrf" "injection" "rce"
    )

    for keyword in "${keywords[@]}"; do
        if echo "$diff" | grep -qi "$keyword"; then
            security_score=$((security_score + 1))
        fi
    done

    # 結果を返す（グローバル変数に格納）
    SECURITY_SCORE=$security_score
}

# ============================================================================
# P3A.2.1.2: ルールベース自動タイプ選択（拡張: 5AI対応）
# ============================================================================

analyze_ui_ux_files() {
    local diff="$1"

    # UI/UX関連ファイルを判定
    local has_ui_files=false

    # UI/UXファイルパターン
    if echo "$diff" | grep -qE "diff --git.*/(.tsx|.jsx|.vue|components|styles|ui|frontend)"; then
        has_ui_files=true
    fi

    # 結果を返す（グローバル変数に格納）
    HAS_UI_FILES=$has_ui_files
}

analyze_production_files() {
    local diff="$1"

    # プロダクション/エンタープライズ関連ファイルを判定
    local has_prod_files=false

    # プロダクションファイルパターン
    if echo "$diff" | grep -qE "diff --git.*/(.Dockerfile|docker-compose|.ya?ml|Makefile|package.json|build|deploy)"; then
        has_prod_files=true
    fi

    # 結果を返す（グローバル変数に格納）
    HAS_PROD_FILES=$has_prod_files
}

determine_review_type() {
    local commit="${1:-HEAD}"

    echo -e "${BLUE}ℹ${NC} Analyzing commit: $commit"

    # コンテキスト分析を実行
    analyze_git_diff "$commit" > /dev/null
    analyze_file_types "$ANALYZED_DIFF"
    analyze_change_size "$ANALYZED_DIFF"
    analyze_security_keywords "$ANALYZED_DIFF"
    analyze_ui_ux_files "$ANALYZED_DIFF"
    analyze_production_files "$ANALYZED_DIFF"

    # 分析結果を表示
    echo -e "${BLUE}ℹ${NC} Analysis Results:"
    echo "  - Changed Files: $CHANGED_FILES"
    echo "  - Changed Lines: $CHANGED_LINES"
    echo "  - Security Score: $SECURITY_SCORE"
    echo "  - Security Files: $HAS_SECURITY_FILES"
    echo "  - Config Files: $HAS_CONFIG_FILES"
    echo "  - Test Files: $HAS_TEST_FILES"
    echo "  - Docs Files: $HAS_DOCS_FILES"
    echo "  - UI/UX Files: $HAS_UI_FILES"
    echo "  - Production Files: $HAS_PROD_FILES"
    echo ""

    # ルールベース判定
    local review_type=""
    local reason=""

    # ルール1: セキュリティスコアが高い（5以上）
    if [[ $SECURITY_SCORE -ge 5 ]]; then
        review_type="security"
        reason="High security score ($SECURITY_SCORE security keywords detected)"

    # ルール2: セキュリティ関連ファイルが含まれる
    elif [[ "$HAS_SECURITY_FILES" == "true" ]]; then
        review_type="security"
        reason="Security-related files detected"

    # ルール3: 設定ファイルの変更でセキュリティキーワードがある
    elif [[ "$HAS_CONFIG_FILES" == "true" ]] && [[ $SECURITY_SCORE -ge 2 ]]; then
        review_type="security"
        reason="Config files with security keywords detected"

    # ルール4: 大規模変更（500行以上）
    elif [[ $CHANGED_LINES -gt 500 ]]; then
        review_type="enterprise"
        reason="Large-scale changes ($CHANGED_LINES lines) detected"

    # ルール5: 多数のファイル変更（10ファイル以上）
    elif [[ $CHANGED_FILES -gt 10 ]]; then
        review_type="enterprise"
        reason="Multiple files ($CHANGED_FILES files) changed"

    # ルール6: ドキュメントのみの変更
    elif [[ "$HAS_DOCS_FILES" == "true" ]] && [[ $CHANGED_LINES -lt 100 ]]; then
        review_type="quality"
        reason="Documentation changes detected"

    # ルール7: テストファイルの変更
    elif [[ "$HAS_TEST_FILES" == "true" ]]; then
        review_type="quality"
        reason="Test files changed"

    # ルール8: デフォルト（通常の変更）
    else
        review_type="quality"
        reason="Standard code changes"
    fi

    # 判定結果を返す（グローバル変数に格納）
    DETERMINED_TYPE=$review_type
    DETERMINATION_REASON=$reason

    echo -e "${GREEN}✓${NC} Determined Review Type: ${YELLOW}$review_type${NC}"
    echo -e "${BLUE}ℹ${NC} Reason: $reason"
    echo ""
}

# ============================================================================
# P4.1.2: 5AI自動選択ロジック（新規）
# ============================================================================

determine_ai_reviewer() {
    local commit="${1:-HEAD}"

    echo -e "${BLUE}ℹ${NC} Analyzing commit for AI reviewer selection: $commit"

    # コンテキスト分析を実行
    analyze_git_diff "$commit" > /dev/null
    analyze_file_types "$ANALYZED_DIFF"
    analyze_change_size "$ANALYZED_DIFF"
    analyze_security_keywords "$ANALYZED_DIFF"
    analyze_ui_ux_files "$ANALYZED_DIFF"
    analyze_production_files "$ANALYZED_DIFF"

    # 分析結果を表示
    echo -e "${BLUE}ℹ${NC} Analysis Results:"
    echo "  - Changed Files: $CHANGED_FILES"
    echo "  - Changed Lines: $CHANGED_LINES"
    echo "  - Security Score: $SECURITY_SCORE"
    echo "  - Security Files: $HAS_SECURITY_FILES"
    echo "  - UI/UX Files: $HAS_UI_FILES"
    echo "  - Docs Files: $HAS_DOCS_FILES"
    echo "  - Production Files: $HAS_PROD_FILES"
    echo ""

    # 5AIルールベース判定（優先度順）
    local ai_name=""
    local reason=""

    # Priority 1: Security (Gemini)
    if [[ $SECURITY_SCORE -ge 5 ]] || [[ "$HAS_SECURITY_FILES" == "true" ]]; then
        ai_name="gemini"
        reason="Security-related changes detected (Security Score: $SECURITY_SCORE)"

    # Priority 2: Documentation (Amp)
    elif [[ "$HAS_DOCS_FILES" == "true" ]]; then
        ai_name="amp"
        reason="Documentation changes detected"

    # Priority 3: UI/UX (Cursor)
    elif [[ "$HAS_UI_FILES" == "true" ]]; then
        ai_name="cursor"
        reason="UI/UX changes detected"

    # Priority 4: Production/Enterprise (Droid)
    elif [[ "$HAS_PROD_FILES" == "true" ]] || [[ $CHANGED_LINES -gt 500 ]] || [[ $CHANGED_FILES -gt 10 ]]; then
        ai_name="droid"
        reason="Production/enterprise changes detected (Lines: $CHANGED_LINES, Files: $CHANGED_FILES)"

    # Priority 5: Code Implementation (Qwen - default)
    else
        ai_name="qwen"
        reason="Code implementation changes (default)"
    fi

    # 判定結果を返す（グローバル変数に格納）
    DETERMINED_AI=$ai_name
    AI_DETERMINATION_REASON=$reason

    echo -e "${GREEN}✓${NC} Determined AI Reviewer: ${YELLOW}${ai_name^}${NC}"
    echo -e "${BLUE}ℹ${NC} Reason: $reason"
    echo ""
}

# ============================================================================
# P3A.2.1.3: 複数タイプ並列実行
# ============================================================================

should_run_multiple_types() {
    # 複数タイプを並列実行すべきかを判定

    # 条件1: セキュリティスコアが高く、かつ大規模変更
    if [[ $SECURITY_SCORE -ge 5 ]] && [[ $CHANGED_LINES -gt 300 ]]; then
        echo "all"
        return 0
    fi

    # 条件2: セキュリティファイルかつ多数のファイル変更
    if [[ "$HAS_SECURITY_FILES" == "true" ]] && [[ $CHANGED_FILES -gt 5 ]]; then
        echo "all"
        return 0
    fi

    # 単一タイプで十分
    echo "$DETERMINED_TYPE"
}

# ============================================================================
# レビュー実行
# ============================================================================

execute_review() {
    local commit="$1"
    local review_type="$2"
    shift 2
    local additional_args=("$@")

    echo -e "${BLUE}ℹ${NC} Executing review with type: ${YELLOW}$review_type${NC}"
    echo -e "${BLUE}ℹ${NC} Commit: $commit"

    if [[ ! -f "$MULTI_AI_REVIEW" ]]; then
        echo -e "${RED}✗${NC} Error: multi-ai-review.sh not found at $MULTI_AI_REVIEW"
        return 1
    fi

    # レビュー実行
    bash "$MULTI_AI_REVIEW" --type "$review_type" --commit "$commit" "${additional_args[@]}"
}

execute_ai_review() {
    local commit="$1"
    local ai_name="$2"
    shift 2
    local additional_args=("$@")

    echo -e "${BLUE}ℹ${NC} Executing review with AI: ${YELLOW}${ai_name^}${NC}"
    echo -e "${BLUE}ℹ${NC} Commit: $commit"

    if [[ ! -f "$MULTI_AI_REVIEW" ]]; then
        echo -e "${RED}✗${NC} Error: multi-ai-review.sh not found at $MULTI_AI_REVIEW"
        return 1
    fi

    # AI レビュー実行
    bash "$MULTI_AI_REVIEW" --ai "$ai_name" --commit "$commit" "${additional_args[@]}"
}

# ============================================================================
# ヘルプメッセージ
# ============================================================================

show_help() {
    cat <<EOF
Usage: review-dispatcher.sh [OPTIONS]

Automatically determines the appropriate review type or AI reviewer based on git diff analysis.

OPTIONS:
  --commit HASH         Commit hash to review (default: HEAD)
  --dry-run            Show determined review type/AI without executing
  --force-type TYPE    Override automatic type determination (security|quality|enterprise)
  --force-ai AI        Override automatic AI selection (gemini|qwen|cursor|amp|droid)
  --mode MODE          Selection mode: type (default) | ai
  --help               Show this help message

AUTOMATIC RULES (--mode type):
  - Security Review: Security keywords (≥5) or security-related files
  - Enterprise Review: Large changes (≥500 lines) or many files (≥10)
  - Quality Review: Test files, documentation, or standard changes
  - All Reviews: Critical changes (security + large scale)

AUTOMATIC RULES (--mode ai):
  - Gemini: Security-related changes (auth, crypto, secrets)
  - Amp: Documentation changes (README, .md files)
  - Cursor: UI/UX changes (components, styles, frontend)
  - Droid: Production/enterprise changes (build, deploy, large-scale)
  - Qwen: Code implementation (default)

EXAMPLES:
  # Auto-detect review type for latest commit (type mode)
  review-dispatcher.sh

  # Auto-detect AI reviewer (ai mode)
  review-dispatcher.sh --mode ai

  # Dry-run to see what would be selected
  review-dispatcher.sh --dry-run --mode ai

  # Override automatic AI detection
  review-dispatcher.sh --force-ai gemini

  # Review specific commit with AI mode
  review-dispatcher.sh --commit abc123 --mode ai

EOF
}

# ============================================================================
# Main Function
# ============================================================================

main() {
    local commit="HEAD"
    local dry_run=false
    local force_type=""
    local force_ai=""
    local mode="type"
    local additional_args=()

    # 引数解析
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --commit)
                commit="$2"
                shift 2
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --force-type)
                force_type="$2"
                shift 2
                ;;
            --force-ai)
                force_ai="$2"
                shift 2
                ;;
            --mode)
                mode="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                additional_args+=("$1")
                shift
                ;;
        esac
    done

    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║ Review Dispatcher - Automatic Type/AI Detection                     ║"
    echo "║ Phase 3A.2.1 + Phase 4.1.2: Rule-Based Auto-Routing                ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""

    # モード選択
    if [[ "$mode" == "ai" ]]; then
        # AI モード
        echo -e "${BLUE}ℹ${NC} Running in AI mode (5AI individual reviewers)"
        echo ""

        # AI決定
        if [[ -n "$force_ai" ]]; then
            DETERMINED_AI="$force_ai"
            AI_DETERMINATION_REASON="Forced by --force-ai option"
            echo -e "${YELLOW}⚠${NC} Using forced AI: ${force_ai^}"
            echo ""
        else
            determine_ai_reviewer "$commit"
        fi

        # Dry-runモード
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${GREEN}✓${NC} Dry-run mode: Would execute review with AI ${YELLOW}${DETERMINED_AI^}${NC}"
            echo -e "${BLUE}ℹ${NC} Reason: $AI_DETERMINATION_REASON"
            exit 0
        fi

        # AI レビュー実行
        execute_ai_review "$commit" "$DETERMINED_AI" "${additional_args[@]}"
    else
        # Type モード（既存ロジック）
        echo -e "${BLUE}ℹ${NC} Running in type mode (security/quality/enterprise)"
        echo ""

        # タイプ決定
        if [[ -n "$force_type" ]]; then
            DETERMINED_TYPE="$force_type"
            DETERMINATION_REASON="Forced by --force-type option"
            echo -e "${YELLOW}⚠${NC} Using forced type: $force_type"
            echo ""
        else
            determine_review_type "$commit"
        fi

        # 複数タイプ実行判定
        local final_type=$(should_run_multiple_types)

        if [[ "$final_type" != "$DETERMINED_TYPE" ]]; then
            echo -e "${YELLOW}⚠${NC} Critical changes detected. Running all review types."
            echo ""
        fi

        # Dry-runモード
        if [[ "$dry_run" == "true" ]]; then
            echo -e "${GREEN}✓${NC} Dry-run mode: Would execute review with type ${YELLOW}$final_type${NC}"
            echo -e "${BLUE}ℹ${NC} Reason: $DETERMINATION_REASON"
            exit 0
        fi

        # レビュー実行
        execute_review "$commit" "$final_type" "${additional_args[@]}"
    fi
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
