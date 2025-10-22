#!/bin/bash
# CodeRabbit Review Integration Script - 7AI対応 VibeLogger統合版
# Version: 1.0
# Purpose: Execute CodeRabbit code review with fallback to alternative implementation
# 7AI Team: Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor

set -euo pipefail

# ========================================
# Configuration
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CODERABBIT_REVIEW_TIMEOUT=${CODERABBIT_REVIEW_TIMEOUT:-900}  # Default: 15 minutes
OUTPUT_DIR="${OUTPUT_DIR:-logs/coderabbit-reviews}"
COMMIT_HASH="${COMMIT_HASH:-HEAD}"
VERBOSE=${VERBOSE:-false}
DEBUG=${DEBUG:-false}

# VibeLogger Setup
VIBE_LOG_DIR="$PROJECT_ROOT/logs/ai-coop/$(date +%Y%m%d)"
mkdir -p "$VIBE_LOG_DIR" "$OUTPUT_DIR"

# VibeLogger output file
VIBE_LOG_FILE="$VIBE_LOG_DIR/coderabbit_review_$(date +%H).jsonl"

# ========================================
# Colors
# ========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'  # No Color

# ========================================
# Utility Functions
# ========================================

# Log error message to stderr (prevents stdout pollution - MP-6 P0 bug fix)
log_error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
}

# Log success message to stdout
log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Log warning message to stdout
log_warning() {
    echo -e "${YELLOW}⚠️  Warning: $1${NC}"
}

# Log info message to stdout
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Cross-platform millisecond timestamp (P1 fix: macOS/BSD compatibility)
get_timestamp_ms() {
    local ts
    ts=$(date +%s%3N 2>/dev/null)
    # Check if %N is supported (GNU date) by seeing if output contains literal %
    if [[ "$ts" == *"%"* ]]; then
        # %N not supported (macOS/BSD), fallback to seconds + 000
        echo "$(date +%s)000"
    else
        echo "$ts"
    fi
}

# ========================================
# TTY Detection and Headless Mode Setup (Task 7.4 fix)
# ========================================

# Detect if running in CI/CD environment
detect_ci_env() {
    # Common CI/CD environment variables
    if [[ -n "${CI:-}" ]] || \
       [[ -n "${GITHUB_ACTIONS:-}" ]] || \
       [[ -n "${GITLAB_CI:-}" ]] || \
       [[ -n "${JENKINS_HOME:-}" ]] || \
       [[ -n "${CIRCLECI:-}" ]] || \
       [[ -n "${TRAVIS:-}" ]] || \
       [[ -n "${BITBUCKET_BUILD_NUMBER:-}" ]] || \
       [[ -n "${BUILDKITE:-}" ]]; then
        return 0  # Is CI/CD environment
    fi
    return 1  # Not CI/CD environment
}

# Detect if TTY is available
detect_tty() {
    # Check if stdin is a TTY
    if [ -t 0 ]; then
        return 0  # TTY available
    fi
    return 1  # No TTY (background execution, pipe, etc.)
}

# Setup CodeRabbit headless mode if needed (Task 7.4: TTY problem fix)
setup_coderabbit_headless() {
    local is_ci=false
    local has_tty=false
    local should_set_headless=false

    # Detect CI environment
    if detect_ci_env; then
        is_ci=true
    fi

    # Detect TTY
    if detect_tty; then
        has_tty=true
    fi

    # Decision logic: Set headless if no TTY or in CI
    if [ "$has_tty" = false ] || [ "$is_ci" = true ]; then
        should_set_headless=true
    fi

    # Apply CODERABBIT_HEADLESS if needed
    if [ "$should_set_headless" = true ]; then
        export CODERABBIT_HEADLESS=true
        log_info "CodeRabbit headless mode enabled (TTY: $has_tty, CI: $is_ci)"
    else
        log_info "CodeRabbit interactive mode (TTY available)"
    fi

    # Log environment for debugging
    if [ "$VERBOSE" = true ]; then
        log_info "  CI Environment: $is_ci"
        log_info "  TTY Available: $has_tty"
        log_info "  Headless Mode: ${CODERABBIT_HEADLESS:-false}"
    fi
}

# ========================================
# Help and Validation Functions
# ========================================

# Show help message
show_help() {
    cat << 'EOF'
╔════════════════════════════════════════════════════════════════════════════╗
║                    CodeRabbit Review Script v1.0                           ║
║                      7AI協調レビューシステム                                ║
╚════════════════════════════════════════════════════════════════════════════╝

USAGE:
    coderabbit-review.sh [OPTIONS]

DESCRIPTION:
    Execute CodeRabbit code review with Smart Wrapper and generate
    comprehensive reports. Part of the 7AI collaborative development system.

OPTIONS:
    -t, --timeout <seconds>       CodeRabbit execution timeout (default: 900)
                                  Valid range: 60-3600 seconds
                                  Recommended: 900s (15 minutes)

    -c, --commit <hash>           Target commit for review (default: HEAD)
                                  Examples: HEAD, HEAD~1, abc1234, main, v1.0.0

    -o, --output <directory>      Output directory for review results
                                  (default: logs/coderabbit-reviews)
                                  Directory will be created if it doesn't exist

    -v, --verbose                 Enable verbose output
                                  Shows detailed execution information

    -d, --debug                   Enable debug mode
                                  Activates Bash trace (set -x) and verbose output

    -h, --help                    Show this help message and exit

ENVIRONMENT VARIABLES:
    CODERABBIT_REVIEW_TIMEOUT     Timeout in seconds (overridden by --timeout)
    OUTPUT_DIR                    Output directory (overridden by --output)
    COMMIT_HASH                   Commit to review (overridden by --commit)

    Priority: Command-line arguments > Environment variables > Defaults

EXAMPLES:
    # Basic usage (all defaults)
    $ ./scripts/coderabbit-review.sh

    # Review specific commit with custom timeout
    $ ./scripts/coderabbit-review.sh --commit abc1234 --timeout 1200

    # Custom output directory with verbose logging
    $ ./scripts/coderabbit-review.sh -o /tmp/reviews -v

    # Debug mode for troubleshooting
    $ ./scripts/coderabbit-review.sh --debug

    # Review previous commit
    $ ./scripts/coderabbit-review.sh --commit HEAD~1

OUTPUT STRUCTURE:
    logs/coderabbit-reviews/
    ├── YYYYMMDD_HHMMSS_<hash>_coderabbit.log     # Raw CodeRabbit output
    ├── YYYYMMDD_HHMMSS_<hash>_coderabbit.json    # Structured JSON report
    ├── YYYYMMDD_HHMMSS_<hash>_coderabbit.md      # Human-readable Markdown
    ├── latest_coderabbit.json -> (symlink)       # Always points to latest
    └── latest_coderabbit.md -> (symlink)         # Always points to latest

EXIT CODES:
    0    Success - Review completed successfully
    1    Error - Review failed or invalid arguments

7AI TEAM:
    This script is part of the 7AI collaborative development system:
    - Claude 4 (CTO): Strategic planning, architecture
    - Gemini 2.5 (CIO): Web search, security analysis
    - Amp (PM): Project management, long-term context
    - Qwen Code: Fast prototyping (37s)
    - Droid: Enterprise-grade implementation (180s)
    - Codex: Code review, optimization
    - Cursor: IDE integration, testing

VERSION:
    coderabbit-review.sh v1.0
    Part of MP-7: CodeRabbit Review Integration
    Created: 2025-10-16
    7AI Team: Claude, Gemini, Amp, Qwen, Droid, Codex, Cursor
EOF
}

# Validate timeout value
validate_timeout() {
    local timeout=$1

    # Check if numeric
    if ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
        log_error "Invalid timeout value: '$timeout'"
        log_info "Expected: positive integer between 60 and 3600"
        log_info "Example: --timeout 900"
        return 1
    fi

    # Check range
    if [ "$timeout" -lt 60 ]; then
        log_error "Timeout too short: ${timeout}s"
        log_info "Minimum allowed: 60s (1 minute)"
        log_info "Recommended: 900s (15 minutes) for CodeRabbit"
        log_info "Usage: --timeout 900"
        return 1
    fi

    if [ "$timeout" -gt 3600 ]; then
        log_error "Timeout too long: ${timeout}s"
        log_info "Maximum allowed: 3600s (1 hour)"
        log_info "Recommended: 900s (15 minutes) for CodeRabbit"
        return 1
    fi

    return 0
}

# Validate output directory
validate_output_dir() {
    local dir=$1

    # Check if empty
    if [ -z "$dir" ]; then
        log_error "Output directory cannot be empty"
        return 1
    fi

    # Create directory if it doesn't exist
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" 2>/dev/null || {
            log_error "Failed to create output directory: $dir"
            log_info "Check parent directory permissions"
            return 1
        }
        log_success "Created output directory: $dir"
    fi

    # Check write permission
    if [ ! -w "$dir" ]; then
        log_error "Output directory is not writable: $dir"
        log_info "Check permissions: ls -ld $dir"
        log_info "Or specify different directory with: --output /tmp/reviews"
        return 1
    fi

    return 0
}

# Validate commit hash
validate_commit() {
    local commit=$1

    # Check if empty
    if [ -z "$commit" ]; then
        log_error "Commit hash cannot be empty"
        return 1
    fi

    # Check if git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        log_info "Current directory: $(pwd)"
        log_info "Initialize with: git init"
        return 1
    fi

    # Check if commit exists
    if ! git rev-parse --verify "${commit}^{commit}" >/dev/null 2>&1; then
        log_error "Commit not found: $commit"
        log_info "Available recent commits:"
        git log --oneline -5 2>/dev/null || log_info "  (git log failed)"
        return 1
    fi

    return 0
}

# ========================================
# Argument Parsing
# ========================================

parse_args() {
    # Set defaults from environment variables or hardcoded values
    CODERABBIT_REVIEW_TIMEOUT=${CODERABBIT_REVIEW_TIMEOUT:-900}
    OUTPUT_DIR=${OUTPUT_DIR:-logs/coderabbit-reviews}
    COMMIT_HASH=${COMMIT_HASH:-HEAD}
    VERBOSE=${VERBOSE:-false}
    DEBUG=${DEBUG:-false}

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--timeout)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    log_error "Option $1 requires an argument"
                    log_info "Example: $1 900"
                    show_help
                    exit 1
                fi
                CODERABBIT_REVIEW_TIMEOUT="$2"
                shift 2
                ;;
            -c|--commit)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    log_error "Option $1 requires an argument"
                    log_info "Example: $1 HEAD~1"
                    show_help
                    exit 1
                fi
                COMMIT_HASH="$2"
                shift 2
                ;;
            -o|--output)
                if [ -z "$2" ] || [[ "$2" == -* ]]; then
                    log_error "Option $1 requires an argument"
                    log_info "Example: $1 /tmp/reviews"
                    show_help
                    exit 1
                fi
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--debug)
                DEBUG=true
                VERBOSE=true  # Debug mode automatically enables verbose
                set -x  # Enable Bash trace
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                log_error "Unexpected argument: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Validate all parameters
    validate_timeout "$CODERABBIT_REVIEW_TIMEOUT" || exit 1
    validate_output_dir "$OUTPUT_DIR" || exit 1
    validate_commit "$COMMIT_HASH" || exit 1

    # Show configuration in verbose mode
    if [ "$VERBOSE" = true ]; then
        log_info "=== Configuration ==="
        log_info "Timeout: ${CODERABBIT_REVIEW_TIMEOUT}s"
        log_info "Output: $OUTPUT_DIR"
        log_info "Commit: $COMMIT_HASH"
        log_info "Verbose: $VERBOSE"
        log_info "Debug: $DEBUG"
        log_info "===================="
    fi
}

# ========================================
# Prerequisites Check
# ========================================

check_prerequisites() {
    log_info "Checking prerequisites..."

    # ========================================
    # 1. Git Repository確認
    # ========================================
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository"
        log_info "Current directory: $(pwd)"
        log_info "Initialize with: git init"
        exit 1
    fi
    log_success "Git repository detected"

    # ========================================
    # 2. Commit存在確認
    # ========================================
    if ! git rev-parse --verify "${COMMIT_HASH}^{commit}" >/dev/null 2>&1; then
        log_error "Commit not found: $COMMIT_HASH"
        log_info "Available recent commits:"
        git log --oneline -5 2>/dev/null || log_info "  (git log failed)"
        exit 1
    fi

    local commit_short=$(git rev-parse --short "$COMMIT_HASH")
    log_success "Target commit: $commit_short ($COMMIT_HASH)"

    # ========================================
    # 3. Smart Wrapper確認（警告のみ）
    # ========================================
    local smart_wrapper="$PROJECT_ROOT/bin/coderabbit-smart.sh"

    if [[ -x "$smart_wrapper" ]]; then
        log_success "CodeRabbit Smart Wrapper found"
        USE_SMART_WRAPPER="true"
    else
        log_warning "CodeRabbit Smart Wrapper not found at $smart_wrapper"
        log_info "Will try direct CLI or alternative implementation"
        USE_SMART_WRAPPER="false"
    fi

    # ========================================
    # 4. CodeRabbit CLI確認（警告のみ）
    # ========================================
    if command -v coderabbit >/dev/null 2>&1; then
        local cr_version
        cr_version=$(coderabbit --version 2>&1 | head -1 || echo "unknown")
        log_success "CodeRabbit CLI found: $cr_version"
        USE_CODERABBIT_CLI="true"
    elif command -v cr >/dev/null 2>&1; then
        local cr_version
        cr_version=$(cr --version 2>&1 | head -1 || echo "unknown")
        log_success "CodeRabbit CLI (cr) found: $cr_version"
        USE_CODERABBIT_CLI="true"
    else
        log_warning "CodeRabbit CLI not installed"
        log_info "Install: npm install -g coderabbit"
        log_info "Will use alternative implementation if needed"
        USE_CODERABBIT_CLI="false"
    fi

    # ========================================
    # 5. 代替AI確認（情報のみ）
    # ========================================
    local available_ai=""
    for ai_tool in claude gemini qwen droid cursor codex; do
        if command -v "$ai_tool" >/dev/null 2>&1; then
            available_ai="$available_ai $ai_tool"
        fi
    done

    if [[ -n "$available_ai" ]]; then
        log_info "Available AI tools for fallback:$available_ai"
    else
        log_info "No AI tools detected for enhanced analysis"
    fi

    # ========================================
    # 6. 出力ディレクトリ確認
    # ========================================
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR" || {
            log_error "Failed to create output directory: $OUTPUT_DIR"
            exit 1
        }
        log_success "Created output directory: $OUTPUT_DIR"
    else
        log_success "Output directory exists: $OUTPUT_DIR"
    fi

    # ========================================
    # 7. 書き込み権限確認
    # ========================================
    if [ ! -w "$OUTPUT_DIR" ]; then
        log_error "Output directory is not writable: $OUTPUT_DIR"
        log_info "Check permissions: ls -ld $OUTPUT_DIR"
        exit 1
    fi

    # ========================================
    # 8. TTY Detection and Headless Mode Setup (Task 7.4)
    # ========================================
    setup_coderabbit_headless

    log_success "Prerequisites check passed"
    return 0
}

# ========================================
# VibeLogger Functions
# ========================================

vibe_tool_start() {
    local action="$1"
    local commit="$2"
    local timeout="$3"

    # Safe JSON generation using jq to prevent injection
    jq -n \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg event "tool.start" \
        --arg action "$action" \
        --arg commit "$commit" \
        --argjson timeout "$timeout" \
        --arg execution_mode "coderabbit_review" \
        --arg human_note "CodeRabbitレビュー実行開始: コミット $commit" \
        '{
            timestamp: $timestamp,
            event: $event,
            action: $action,
            metadata: {
                commit: $commit,
                timeout_sec: $timeout,
                execution_mode: $execution_mode
            },
            human_note: $human_note,
            ai_context: {
                tool: "CodeRabbit",
                integration: "7AI",
                ai_team: ["Claude", "Gemini", "Amp", "Qwen", "Droid", "Codex", "Cursor"],
                todo: "analyze_code,detect_issues,suggest_improvements"
            }
        }' >> "$VIBE_LOG_FILE"
}

vibe_tool_done() {
    local action="$1"
    local status="$2"
    local issues="$3"
    local exec_time="$4"

    # Safe JSON generation using jq to prevent injection
    jq -n \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg event "tool.done" \
        --arg action "$action" \
        --arg status "$status" \
        --argjson issues "$issues" \
        --argjson exec_time "$exec_time" \
        --arg human_note "CodeRabbitレビュー完了: $status ($issues issues, ${exec_time}ms)" \
        '{
            timestamp: $timestamp,
            event: $event,
            action: $action,
            status: $status,
            metadata: {
                issues_found: $issues,
                execution_time_ms: $exec_time
            },
            human_note: $human_note
        }' >> "$VIBE_LOG_FILE"
}

# ========================================
# CodeRabbit Execution Functions
# ========================================

execute_coderabbit_review() {
    # ========================================
    # 1. 初期化フェーズ
    # ========================================
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short=$(git rev-parse --short "$COMMIT_HASH" 2>/dev/null || echo "unknown")
    local output_file="$OUTPUT_DIR/${timestamp}_${commit_short}_coderabbit.log"
    local status=0
    local start_time=$(get_timestamp_ms)

    # ========================================
    # 2. VibeLogger: tool.start
    # ========================================
    vibe_tool_start "coderabbit_review" "$commit_short" "$CODERABBIT_REVIEW_TIMEOUT"

    # ========================================
    # 3. Layer 1: Smart Wrapper実行
    # ========================================
    local smart_wrapper="$PROJECT_ROOT/bin/coderabbit-smart.sh"

    if [[ -x "$smart_wrapper" ]]; then
        # Smart Wrapper実行（優先）+ --plain for non-interactive output
        if timeout "$CODERABBIT_REVIEW_TIMEOUT" \
           "$smart_wrapper" --force --plain > "$output_file" 2>&1; then

            # 成功: メトリクス収集 + VibeLogger記録
            status=0
            local end_time=$(get_timestamp_ms)
            local execution_time=$((end_time - start_time))

            # 問題数カウント（CodeRabbit出力パターン）
            local issues_found
            issues_found=$(grep -icE "(Critical|High|Medium|Low|Security|Performance)" "$output_file" 2>/dev/null || echo "0")

            # VibeLogger: tool.done (success)
            vibe_tool_done "coderabbit_review" "success" "$issues_found" "$execution_time"

            # 戻り値出力（stdout汚染防止のため、ここだけecho許可）
            echo "$output_file:$status"
            return 0
        else
            # Smart Wrapper失敗: Layer 2へフォールバック
            status=$?
            # エラーログ（stderrへ直接、log_*関数は使用しない）
            echo "⚠️  Smart Wrapper failed (exit $status), trying Layer 2..." >&2
            # TTY問題の可能性を示唆
            if grep -q "Raw mode is not supported" "$output_file" 2>/dev/null; then
                echo "   💡 Hint: TTY problem detected. Headless mode: ${CODERABBIT_HEADLESS:-false}" >&2
                echo "   💡 To force headless mode: export CODERABBIT_HEADLESS=true" >&2
            fi
        fi
    else
        # Smart Wrapper不在: Layer 2へスキップ
        echo "⚠️  Smart Wrapper not found at $smart_wrapper, trying Layer 2..." >&2
    fi

    # ========================================
    # 4. Layer 2: Direct CLI実行
    # ========================================
    # CodeRabbit CLIコマンドを直接実行
    local cr_cmd=""
    if command -v coderabbit >/dev/null 2>&1; then
        cr_cmd="coderabbit"
    elif command -v cr >/dev/null 2>&1; then
        cr_cmd="cr"
    fi

    if [[ -n "$cr_cmd" ]]; then
        # Direct CLI実行 + --plain for non-interactive output
        if timeout "$CODERABBIT_REVIEW_TIMEOUT" \
           "$cr_cmd" --plain > "$output_file" 2>&1; then

            # 成功: メトリクス収集 + VibeLogger記録
            status=0
            local end_time=$(get_timestamp_ms)
            local execution_time=$((end_time - start_time))

            local issues_found
            issues_found=$(grep -icE "(Critical|High|Medium|Low|Security|Performance)" "$output_file" 2>/dev/null || echo "0")

            vibe_tool_done "coderabbit_review" "success" "$issues_found" "$execution_time"

            echo "$output_file:$status"
            return 0
        else
            # Direct CLI失敗: Layer 3へフォールバック
            status=$?
            echo "⚠️  Direct CLI failed (exit $status), using Layer 3..." >&2
            # TTY問題の可能性を示唆
            if grep -q "Raw mode is not supported" "$output_file" 2>/dev/null; then
                echo "   💡 Hint: TTY problem detected. Headless mode: ${CODERABBIT_HEADLESS:-false}" >&2
                echo "   💡 To force headless mode: export CODERABBIT_HEADLESS=true" >&2
                echo "   💡 This should have been automatically set - check your environment" >&2
            fi
        fi
    else
        # CLI未インストール: Layer 3へスキップ
        echo "⚠️  CodeRabbit CLI not found, using Layer 3..." >&2
    fi

    # ========================================
    # 5. Layer 3: Alternative Implementation
    # ========================================
    # 全フォールバック失敗時は代替実装を呼び出し
    echo "ℹ️  Using alternative implementation (git diff + AI analysis)" >&2

    local alternative_result
    alternative_result=$(execute_alternative_review)

    # 代替実装の結果を返す
    echo "$alternative_result"
    return 0
}

# ========================================
# Alternative Implementation (stub for Task 3.6)
# ========================================

execute_alternative_review() {
    # ========================================
    # 1. 初期化フェーズ
    # ========================================
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short
    commit_short=$(git rev-parse --short "$COMMIT_HASH" 2>/dev/null || echo "unknown")
    local output_file="$OUTPUT_DIR/${timestamp}_${commit_short}_alt.log"
    local status=0
    local start_time
    start_time=$(get_timestamp_ms)

    # ========================================
    # 2. VibeLogger: tool.start (alternative mode)
    # ========================================
    vibe_tool_start "alternative_review" "$commit_short" "$CODERABBIT_REVIEW_TIMEOUT"

    # ========================================
    # 3. Git Diff取得
    # ========================================
    local diff_content
    diff_content=$(git show --no-color --pretty=format:"" "$COMMIT_HASH" 2>/dev/null || echo "No diff available for commit $COMMIT_HASH")

    # ========================================
    # 4. 基本レポート生成
    # ========================================
    {
        echo "# Alternative Code Review Report"
        echo ""
        echo "## ℹ️  Review Mode"
        echo ""
        echo "This is an **alternative implementation** review, used when CodeRabbit CLI is not available."
        echo ""
        echo "- ✅ Basic pattern matching"
        echo "- ✅ Security analysis"
        echo "- ✅ Code quality checks"
        echo "- ⚠️  Limited to git diff analysis"
        echo ""
        echo "## 📋 Commit Information"
        echo ""
        echo "- **Commit**: \`$COMMIT_HASH\` (\`$commit_short\`)"
        echo "- **Date**: $(date)"
        echo "- **Author**: $(git show --format="%an <%ae>" -s "$COMMIT_HASH" 2>/dev/null || echo "unknown")"
        echo "- **Message**: $(git show --format="%s" -s "$COMMIT_HASH" 2>/dev/null || echo "unknown")"
        echo ""
        echo "## 📊 Code Changes"
        echo ""
        echo "\`\`\`diff"
        echo "$diff_content"
        echo "\`\`\`"
        echo ""
    } > "$output_file"

    # ========================================
    # 5. 基本メトリクス抽出（最適化版 - O(n²) → O(n)）
    # ========================================
    # パフォーマンス修正: 文字列連結の代わりにgrepで直接カウント
    local additions_count
    additions_count=$(echo "$diff_content" | grep -c "^+" 2>/dev/null || echo "0")
    local deletions_count
    deletions_count=$(echo "$diff_content" | grep -c "^-" 2>/dev/null || echo "0")

    # パターンマッチング用に追加行のみを抽出（メモリ効率的な方法）
    local additions
    additions=$(echo "$diff_content" | grep "^+" 2>/dev/null || echo "")
    local deletions
    deletions=$(echo "$diff_content" | grep "^-" 2>/dev/null || echo "")

    # ========================================
    # 6. パターンマッチング分析
    # ========================================
    {
        echo "## 🔍 Automated Analysis"
        echo ""
        echo "### Changes Summary"
        echo ""
        echo "- **Lines Added**: $additions_count"
        echo "- **Lines Removed**: $deletions_count"
        echo "- **Net Change**: $((additions_count - deletions_count)) lines"
        echo ""
        echo "### Potential Issues Detected"
        echo ""
    } >> "$output_file"

    local issues_found=0

    # セキュリティ問題検出: Dynamic Code Execution
    if echo "$additions" | grep -qE "exec\(|eval\(|importlib\.|os\.system|subprocess\.call"; then
        {
            echo "#### 🔴 **Critical - Dynamic Code Execution**"
            echo ""
            echo "**Description**: Detected potential dynamic code execution patterns that could lead to security vulnerabilities."
            echo ""
            echo "**Patterns Found**:"
            echo '```'
            echo "$additions" | grep -E "exec\(|eval\(|importlib\.|os\.system|subprocess\.call"
            echo '```'
            echo ""
            echo "**Recommendation**: Avoid dynamic code execution. Use safer alternatives like \`ast.literal_eval()\` or predefined function mappings."
            echo ""
        } >> "$output_file"
        issues_found=$((issues_found + 1))
    fi

    # 機密情報検出: Sensitive Information
    if echo "$additions" | grep -E "password|secret|token|api_key|private_key" | grep -qv -E "hash|encrypt|obfuscate|example|placeholder"; then
        {
            echo "#### 🔴 **Critical - Sensitive Information**"
            echo ""
            echo "**Description**: Detected potential sensitive information in code that should be externalized."
            echo ""
            echo "**Patterns Found**:"
            echo '```'
            echo "$additions" | grep -E "password|secret|token|api_key|private_key" | grep -v -E "hash|encrypt|obfuscate|example|placeholder"
            echo '```'
            echo ""
            echo "**Recommendation**: Move credentials to environment variables or secure vault (e.g., AWS Secrets Manager, HashiCorp Vault)."
            echo ""
        } >> "$output_file"
        issues_found=$((issues_found + 1))
    fi

    # SQL Injection リスク
    if echo "$additions" | grep -qE "execute\(.*%s|cursor\.execute\(.*\+|query.*=.*\+"; then
        {
            echo "#### 🟠 **High - SQL Injection Risk**"
            echo ""
            echo "**Description**: Detected potential SQL injection vulnerability from string concatenation in queries."
            echo ""
            echo "**Patterns Found**:"
            echo '```'
            echo "$additions" | grep -E "execute\(.*%s|cursor\.execute\(.*\+|query.*=.*\+"
            echo '```'
            echo ""
            echo "**Recommendation**: Use parameterized queries or prepared statements."
            echo ""
        } >> "$output_file"
        issues_found=$((issues_found + 1))
    fi

    # TODO/FIXME コメント
    if echo "$additions" | grep -qE "TODO|FIXME|HACK|XXX|BUG"; then
        {
            echo "#### 🟡 **Medium - TODO/FIXME Comments**"
            echo ""
            echo "**Description**: Found TODO/FIXME comments that should be addressed before merging."
            echo ""
            echo "**Comments Found**:"
            echo '```'
            echo "$additions" | grep -E "TODO|FIXME|HACK|XXX|BUG"
            echo '```'
            echo ""
            echo "**Recommendation**: Create tracking issues for each TODO/FIXME or resolve them before merging."
            echo ""
        } >> "$output_file"
        issues_found=$((issues_found + 1))
    fi

    # デバッグ文検出
    if echo "$additions" | grep -qE "print\(|console\.log|console\.debug|debugger|pdb\.set_trace"; then
        {
            echo "#### 🟡 **Medium - Debug Statements**"
            echo ""
            echo "**Description**: Found debug statements that should be removed before production deployment."
            echo ""
            echo "**Debug Statements Found**:"
            echo '```'
            echo "$additions" | grep -E "print\(|console\.log|console\.debug|debugger|pdb\.set_trace"
            echo '```'
            echo ""
            echo "**Recommendation**: Use proper logging framework (e.g., Python logging, Winston for Node.js)."
            echo ""
        } >> "$output_file"
        issues_found=$((issues_found + 1))
    fi

    # ハードコードされたURL/パス
    if echo "$additions" | grep -qE "http://localhost|127\.0\.0\.1|/tmp/|C:\\\\"; then
        {
            echo "#### 🟢 **Low - Hardcoded Paths**"
            echo ""
            echo "**Description**: Found hardcoded URLs or file paths that may not work in all environments."
            echo ""
            echo "**Hardcoded Values Found**:"
            echo '```'
            echo "$additions" | grep -E "http://localhost|127\.0\.0\.1|/tmp/|C:\\\\"
            echo '```'
            echo ""
            echo "**Recommendation**: Use environment-specific configuration or environment variables."
            echo ""
        } >> "$output_file"
        issues_found=$((issues_found + 1))
    fi

    # 問題が見つからない場合
    if [ "$issues_found" -eq 0 ]; then
        {
            echo "✅ **No major issues detected** by automated pattern matching."
            echo ""
            echo "This does not guarantee the code is problem-free. Manual review is still recommended."
            echo ""
        } >> "$output_file"
    fi

    # ========================================
    # 7. コード品質提案
    # ========================================
    {
        echo "### 📝 Code Quality Suggestions"
        echo ""
        echo "- **Security**: Review all changes for security implications, especially authentication and data handling"
        echo "- **Error Handling**: Ensure proper error handling and recovery mechanisms are implemented"
        echo "- **Testing**: Add unit tests for new functionality and edge cases"
        echo "- **Documentation**: Update relevant documentation, docstrings, and comments"
        echo "- **Style Guide**: Follow project-specific code style and formatting guidelines"
        echo "- **Performance**: Consider performance implications of changes, especially in loops and database queries"
        echo "- **Logging**: Use structured logging with appropriate log levels (DEBUG, INFO, WARNING, ERROR)"
        echo ""
    } >> "$output_file"

    # ========================================
    # 8. AI拡張分析（利用可能な場合）
    # ========================================
    local available_ai=""
    local ai_priority=("gemini" "qwen" "droid" "cursor" "codex")

    for ai_tool in "${ai_priority[@]}"; do
        if command -v "$ai_tool" >/dev/null 2>&1; then
            available_ai="$ai_tool"
            break
        fi
    done

    if [[ -n "$available_ai" ]]; then
        {
            echo "## 🤖 AI-Enhanced Analysis ($available_ai)"
            echo ""
        } >> "$output_file"

        local ai_analysis_file="/tmp/ai_analysis_$$_$RANDOM.log"
        local ai_prompt="Please analyze the following code changes and provide:
1. Security vulnerabilities
2. Performance implications
3. Best practice violations
4. Suggestions for improvement

Code changes:
\`\`\`diff
$(echo "$diff_content" | head -200)
\`\`\`

Provide a structured review with specific, actionable recommendations."

        local prompt_file="/tmp/ai_prompt_$$_$RANDOM.txt"
        echo "$ai_prompt" > "$prompt_file"

        case $available_ai in
            gemini)
                if timeout 300 bash -c "gemini -p \"\$(cat '$prompt_file')\" -y" > "$ai_analysis_file" 2>&1; then
                    cat "$ai_analysis_file" >> "$output_file"
                    echo "" >> "$output_file"
                else
                    echo "⚠️  Gemini analysis timed out or failed" >> "$output_file"
                    echo "" >> "$output_file"
                fi
                ;;
            qwen)
                if timeout 300 bash -c "qwen -p \"\$(cat '$prompt_file')\" -y" > "$ai_analysis_file" 2>&1; then
                    cat "$ai_analysis_file" >> "$output_file"
                    echo "" >> "$output_file"
                else
                    echo "⚠️  Qwen analysis timed out or failed" >> "$output_file"
                    echo "" >> "$output_file"
                fi
                ;;
            droid)
                if timeout 900 bash -c "droid exec --auto high \"\$(cat '$prompt_file')\"" > "$ai_analysis_file" 2>&1; then
                    cat "$ai_analysis_file" >> "$output_file"
                    echo "" >> "$output_file"
                else
                    echo "⚠️  Droid analysis timed out or failed" >> "$output_file"
                    echo "" >> "$output_file"
                fi
                ;;
            cursor)
                if timeout 600 bash -c "cursor-agent -p \"\$(cat '$prompt_file')\" --print" > "$ai_analysis_file" 2>&1; then
                    cat "$ai_analysis_file" >> "$output_file"
                    echo "" >> "$output_file"
                else
                    echo "⚠️  Cursor analysis timed out or failed" >> "$output_file"
                    echo "" >> "$output_file"
                fi
                ;;
            codex)
                if timeout 600 bash -c "codex exec \"\$(cat '$prompt_file')\"" > "$ai_analysis_file" 2>&1; then
                    cat "$ai_analysis_file" >> "$output_file"
                    echo "" >> "$output_file"
                else
                    echo "⚠️  Codex analysis timed out or failed" >> "$output_file"
                    echo "" >> "$output_file"
                fi
                ;;
        esac

        # クリーンアップ
        rm -f "$prompt_file" "$ai_analysis_file"
    else
        # AI利用不可の場合
        {
            echo "## 💡 Enhanced Analysis"
            echo ""
            echo "No AI tools are available for enhanced analysis. For comprehensive review:"
            echo ""
            echo "1. **Use Claude Code**: Paste the code changes into Claude Code with a review prompt"
            echo "2. **Install AI CLI**: Consider installing \`gemini\`, \`qwen\`, or other AI tools"
            echo "3. **Manual Review**: Conduct thorough manual code review focusing on:"
            echo "   - Security vulnerabilities"
            echo "   - Edge cases and error handling"
            echo "   - Performance bottlenecks"
            echo "   - Code maintainability"
            echo ""
        } >> "$output_file"
    fi

    # ========================================
    # 9. アクションアイテム生成
    # ========================================
    {
        echo "## ✅ Action Items"
        echo ""
        echo "Based on this automated review, consider the following actions:"
        echo ""
        echo "1. 🔴 **Address Critical Issues**: Fix all security vulnerabilities before merging"
        echo "2. 🟠 **Review High Priority**: Investigate high-priority issues and determine appropriate fixes"
        echo "3. 🟡 **Consider Medium Priority**: Evaluate medium-priority suggestions for code quality improvement"
        echo "4. 🧪 **Add Tests**: Ensure adequate test coverage for all new code paths"
        echo "5. 📚 **Update Docs**: Update documentation to reflect code changes"
        echo "6. 👥 **Peer Review**: Request manual peer review from team members"
        echo ""
    } >> "$output_file"

    # ========================================
    # 10. レビューフッター
    # ========================================
    {
        echo "---"
        echo ""
        echo "**Review Generated**: $(date)"
        echo "**Review Type**: Alternative Implementation (Pattern Matching + AI)"
        echo "**Commit**: \`$commit_short\` (\`$COMMIT_HASH\`)"
        echo ""
        echo "> ⚠️  **Note**: This is an automated alternative review. For production-grade analysis, use CodeRabbit CLI or comprehensive manual review."
        echo ""
    } >> "$output_file"

    # ========================================
    # 11. VibeLogger: tool.done
    # ========================================
    local end_time
    end_time=$(get_timestamp_ms)
    local execution_time=$((end_time - start_time))

    vibe_tool_done "alternative_review" "success" "$issues_found" "$execution_time"

    # ========================================
    # 12. 戻り値出力
    # ========================================
    echo "$output_file:$status"
    return 0
}

# ========================================
# Output Parsing Functions
# ========================================

parse_coderabbit_output() {
    local log_file="$1"

    # ========================================
    # 1. 初期化フェーズ
    # ========================================
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short
    commit_short=$(git rev-parse --short "$COMMIT_HASH" 2>/dev/null || echo "unknown")
    local json_file="$OUTPUT_DIR/${timestamp}_${commit_short}_coderabbit.json"
    local md_file="$OUTPUT_DIR/${timestamp}_${commit_short}_coderabbit.md"

    # ========================================
    # 2. CodeRabbit出力パターン検出（テキスト形式 + JSON形式対応）
    # ========================================

    # 出力形式を自動検出
    # --plain mode: "File: ...\nLine: ...\nType: ..." パターン
    # JSON mode: "Files Analyzed: N" パターン
    local files_analyzed
    local total_issues
    local critical_count
    local high_count
    local medium_count
    local low_count
    local security_count
    local performance_count
    local best_practices_count

    if grep -q "^File: " "$log_file" 2>/dev/null; then
        # ========================================
        # テキスト形式パーサー（--plain mode）
        # ========================================

        # ファイル数: 一意の "File:" エントリをカウント
        files_analyzed=$(grep "^File: " "$log_file" 2>/dev/null | sort -u | wc -l | tr -d ' ')
        if ! [[ "$files_analyzed" =~ ^[0-9]+$ ]]; then
            files_analyzed=0
        fi

        # 総問題数: "Type:" エントリをカウント
        total_issues=$(grep -c "^Type: " "$log_file" 2>/dev/null || echo "0")
        if ! [[ "$total_issues" =~ ^[0-9]+$ ]]; then
            total_issues=0
        fi

        # 重要度別カウント: Type行の次のComment:ブロックから判定
        # potential_issue, refactor_suggestion, nitpick などの分類を重要度にマッピング
        # potential_issue → High/Medium
        # refactor_suggestion → Medium/Low
        # nitpick → Low

        # Type: potential_issue のカウント（Highとして扱う）
        high_count=$(grep -c "^Type: potential_issue" "$log_file" 2>/dev/null || echo "0")
        if ! [[ "$high_count" =~ ^[0-9]+$ ]]; then
            high_count=0
        fi

        # Type: refactor_suggestion のカウント（Mediumとして扱う）
        medium_count=$(grep -c "^Type: refactor_suggestion" "$log_file" 2>/dev/null || echo "0")
        if ! [[ "$medium_count" =~ ^[0-9]+$ ]]; then
            medium_count=0
        fi

        # Type: nitpick のカウント（Lowとして扱う）
        low_count=$(grep -c "^Type: nitpick" "$log_file" 2>/dev/null || echo "0")
        if ! [[ "$low_count" =~ ^[0-9]+$ ]]; then
            low_count=0
        fi

        # Critical: コメント内容に "Critical" または "CRITICAL" または "🔴" が含まれる場合
        critical_count=$(grep -A 20 "^Type: " "$log_file" | grep -icE "(Critical|CRITICAL|🔴|security.*vulnerab|injection|exploit)" || echo "0")
        if ! [[ "$critical_count" =~ ^[0-9]+$ ]]; then
            critical_count=0
        fi

        # カテゴリ別カウント: コメント内容から推定
        # Security: "security", "セキュリティ", "脆弱性" などのキーワード
        security_count=$(grep -A 20 "^Type: " "$log_file" | grep -icE "(security|セキュリティ|脆弱性|vulnerability|injection|XSS|CSRF)" || echo "0")
        if ! [[ "$security_count" =~ ^[0-9]+$ ]]; then
            security_count=0
        fi

        # Performance: "performance", "パフォーマンス", "最適化" などのキーワード
        performance_count=$(grep -A 20 "^Type: " "$log_file" | grep -icE "(performance|パフォーマンス|最適化|optimize|slow|inefficient)" || echo "0")
        if ! [[ "$performance_count" =~ ^[0-9]+$ ]]; then
            performance_count=0
        fi

        # Best Practices: その他の問題（total - security - performance）
        best_practices_count=$((total_issues - security_count - performance_count))
        if [ "$best_practices_count" -lt 0 ]; then
            best_practices_count=0
        fi

    else
        # ========================================
        # JSON形式パーサー（従来のJSON-like mode）
        # ========================================

        # ファイル数抽出
        files_analyzed=$(grep -oP "Files Analyzed:\s*\K\d+" "$log_file" 2>/dev/null || echo "0")
        if ! [[ "$files_analyzed" =~ ^[0-9]+$ ]]; then
            files_analyzed=0
        fi

        # 総問題数抽出
        total_issues=$(grep -oP "Issues Found:\s*\K\d+" "$log_file" 2>/dev/null || echo "0")
        if ! [[ "$total_issues" =~ ^[0-9]+$ ]]; then
            total_issues=0
        fi

        # 重要度別カウント
        critical_count=$(grep -oP "Critical:\s*\K\d+" "$log_file" 2>/dev/null || echo "0")
        if ! [[ "$critical_count" =~ ^[0-9]+$ ]]; then
            critical_count=0
        fi

        high_count=$(grep -oP "High:\s*\K\d+" "$log_file" 2>/dev/null || echo "0")
        if ! [[ "$high_count" =~ ^[0-9]+$ ]]; then
            high_count=0
        fi

        medium_count=$(grep -oP "Medium:\s*\K\d+" "$log_file" 2>/dev/null || echo "0")
        if ! [[ "$medium_count" =~ ^[0-9]+$ ]]; then
            medium_count=0
        fi

        low_count=$(grep -oP "Low:\s*\K\d+" "$log_file" 2>/dev/null || echo "0")
        if ! [[ "$low_count" =~ ^[0-9]+$ ]]; then
            low_count=0
        fi

        # カテゴリ別カウント
        security_count=$(grep -oP "Security Issues:\s*\K\d+" "$log_file" 2>/dev/null || echo "0")
        if ! [[ "$security_count" =~ ^[0-9]+$ ]]; then
            security_count=0
        fi

        performance_count=$(grep -oP "Performance Issues:\s*\K\d+" "$log_file" 2>/dev/null || echo "0")
        if ! [[ "$performance_count" =~ ^[0-9]+$ ]]; then
            performance_count=0
        fi

        best_practices_count=$(grep -oP "Best Practices:\s*\K\d+" "$log_file" 2>/dev/null || echo "0")
        if ! [[ "$best_practices_count" =~ ^[0-9]+$ ]]; then
            best_practices_count=0
        fi
    fi

    # 品質スコア抽出（あれば）
    local code_quality_score
    code_quality_score=$(grep -oP "Code Quality Score:\s*\K\d+" "$log_file" 2>/dev/null || echo "0")
    if ! [[ "$code_quality_score" =~ ^[0-9]+$ ]]; then
        code_quality_score=0
    fi

    local security_score
    security_score=$(grep -oP "Security Score:\s*\K\d+" "$log_file" 2>/dev/null || echo "0")
    if ! [[ "$security_score" =~ ^[0-9]+$ ]]; then
        security_score=0
    fi

    local maintainability_score
    maintainability_score=$(grep -oP "Maintainability Score:\s*\K\d+" "$log_file" 2>/dev/null || echo "0")
    if ! [[ "$maintainability_score" =~ ^[0-9]+$ ]]; then
        maintainability_score=0
    fi

    # ========================================
    # 3. JSON レポート生成
    # ========================================
    cat > "$json_file" <<EOF
{
  "metadata": {
    "tool": "coderabbit",
    "version": "0.1.0",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "commit": "$COMMIT_HASH",
    "commit_short": "$commit_short",
    "execution_time_ms": 0,
    "timeout_s": $CODERABBIT_REVIEW_TIMEOUT
  },
  "summary": {
    "files_analyzed": $files_analyzed,
    "total_issues": $total_issues,
    "severity": {
      "critical": $critical_count,
      "high": $high_count,
      "medium": $medium_count,
      "low": $low_count
    },
    "categories": {
      "security": $security_count,
      "performance": $performance_count,
      "best_practices": $best_practices_count
    }
  },
  "metrics": {
    "code_quality_score": $code_quality_score,
    "security_score": $security_score,
    "maintainability_score": $maintainability_score
  },
  "issues": [],
  "files": [],
  "log_file": "$log_file"
}
EOF

    # ========================================
    # 4. Markdown レポート生成
    # ========================================
    cat > "$md_file" <<EOF
# CodeRabbit Code Review Report

**Generated**: $(date +"%Y-%m-%d %H:%M:%S")
**Commit**: \`$commit_short\` (\`$COMMIT_HASH\`)
**Execution Time**: Auto-detected
**Timeout**: ${CODERABBIT_REVIEW_TIMEOUT}s

---

## 📊 Summary

- **Files Analyzed**: $files_analyzed
- **Total Issues**: $total_issues
- **Critical Issues**: $critical_count 🔴
- **High Priority**: $high_count 🟠
- **Medium Priority**: $medium_count 🟡
- **Low Priority**: $low_count 🟢

### Issue Categories

- **Security**: $security_count issues
- **Performance**: $performance_count issues
- **Best Practices**: $best_practices_count issues

---

## 📈 Quality Metrics

EOF

    # 品質スコアセクション（スコアが存在する場合のみ）
    if [ "$code_quality_score" -gt 0 ] || [ "$security_score" -gt 0 ] || [ "$maintainability_score" -gt 0 ]; then
        cat >> "$md_file" <<EOF
- **Code Quality Score**: $code_quality_score/100
- **Security Score**: $security_score/100
- **Maintainability Score**: $maintainability_score/100

EOF
    else
        echo "No quality metrics available in this review." >> "$md_file"
        echo "" >> "$md_file"
    fi

    cat >> "$md_file" <<EOF
---

## 🔍 Detailed Analysis

EOF

    # ========================================
    # 5. 重要度別問題抽出
    # ========================================

    # Critical Issues
    if [ "$critical_count" -gt 0 ]; then
        cat >> "$md_file" <<EOF
### 🔴 Critical Issues ($critical_count)

EOF
        awk '/^=== Critical Issues ===/,/^===/ {
            if ($0 !~ /^===/) print
        }' "$log_file" | head -50 >> "$md_file" 2>/dev/null || echo "See full log for details" >> "$md_file"
        echo "" >> "$md_file"
    fi

    # High Priority Issues
    if [ "$high_count" -gt 0 ]; then
        cat >> "$md_file" <<EOF
### 🟠 High Priority Issues ($high_count)

EOF
        awk '/^=== High Priority ===/,/^===/ {
            if ($0 !~ /^===/) print
        }' "$log_file" | head -50 >> "$md_file" 2>/dev/null || echo "See full log for details" >> "$md_file"
        echo "" >> "$md_file"
    fi

    # Medium Priority Issues
    if [ "$medium_count" -gt 0 ]; then
        cat >> "$md_file" <<EOF
### 🟡 Medium Priority Issues ($medium_count)

EOF
        echo "See full log for complete details of medium priority issues." >> "$md_file"
        echo "" >> "$md_file"
    fi

    # Low Priority Issues
    if [ "$low_count" -gt 0 ]; then
        cat >> "$md_file" <<EOF
### 🟢 Low Priority Issues ($low_count)

EOF
        echo "See full log for complete details of low priority issues." >> "$md_file"
        echo "" >> "$md_file"
    fi

    # ========================================
    # 6. カテゴリ別分析
    # ========================================
    if [ "$security_count" -gt 0 ]; then
        cat >> "$md_file" <<EOF
---

## 🔒 Security Analysis ($security_count issues)

EOF
        awk '/^=== Security Issues ===/,/^===/ {
            if ($0 !~ /^===/) print
        }' "$log_file" | head -30 >> "$md_file" 2>/dev/null || echo "See full log for security details" >> "$md_file"
        echo "" >> "$md_file"
    fi

    if [ "$performance_count" -gt 0 ]; then
        cat >> "$md_file" <<EOF
---

## ⚡ Performance Analysis ($performance_count issues)

EOF
        awk '/^=== Performance Issues ===/,/^===/ {
            if ($0 !~ /^===/) print
        }' "$log_file" | head -30 >> "$md_file" 2>/dev/null || echo "See full log for performance details" >> "$md_file"
        echo "" >> "$md_file"
    fi

    # ========================================
    # 7. アクションアイテム
    # ========================================
    cat >> "$md_file" <<EOF
---

## ✅ Action Items

Based on the CodeRabbit review, prioritize the following actions:

EOF

    if [ "$critical_count" -gt 0 ]; then
        echo "1. 🔴 **URGENT**: Address $critical_count critical issue(s) immediately" >> "$md_file"
    fi

    if [ "$high_count" -gt 0 ]; then
        echo "2. 🟠 **High Priority**: Review and fix $high_count high priority issue(s)" >> "$md_file"
    fi

    if [ "$security_count" -gt 0 ]; then
        echo "3. 🔒 **Security**: Investigate $security_count security issue(s)" >> "$md_file"
    fi

    if [ "$performance_count" -gt 0 ]; then
        echo "4. ⚡ **Performance**: Optimize $performance_count performance issue(s)" >> "$md_file"
    fi

    if [ "$medium_count" -gt 0 ]; then
        echo "5. 🟡 **Medium**: Consider addressing $medium_count medium priority issue(s)" >> "$md_file"
    fi

    echo "" >> "$md_file"

    # ========================================
    # 8. フルログ参照
    # ========================================
    cat >> "$md_file" <<EOF
---

## 📂 Full Analysis

**Complete Log**: \`$log_file\`

For detailed analysis including:
- File-by-file breakdown
- Code snippets with issues
- Specific recommendations
- Additional context

Refer to the complete log file above.

---

**Tool**: CodeRabbit CLI v0.1.0
**Mode**: --prompt-only
**Generated by**: coderabbit-review.sh (7AI Integration)
EOF

    # ========================================
    # 9. 戻り値出力
    # ========================================
    echo "$json_file:$md_file"
}

parse_alternative_output() {
    local log_file="$1"

    # ========================================
    # 1. 初期化フェーズ
    # ========================================
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local commit_short
    commit_short=$(git rev-parse --short "$COMMIT_HASH" 2>/dev/null || echo "unknown")
    local json_file="$OUTPUT_DIR/${timestamp}_${commit_short}_alt.json"
    local md_file="$OUTPUT_DIR/${timestamp}_${commit_short}_alt.md"

    # ========================================
    # 2. 代替実装出力パターン検出
    # ========================================
    # 行数カウント
    local additions_count
    additions_count=$(grep -oP "Lines Added:\s*\*\*\K\d+" "$log_file" 2>/dev/null || echo "0")
    if ! [[ "$additions_count" =~ ^[0-9]+$ ]]; then
        # フォールバック: diff内の + 行カウント
        additions_count=$(grep -c "^+" "$log_file" 2>/dev/null || echo "0")
    fi

    local deletions_count
    deletions_count=$(grep -oP "Lines Removed:\s*\*\*\K\d+" "$log_file" 2>/dev/null || echo "0")
    if ! [[ "$deletions_count" =~ ^[0-9]+$ ]]; then
        # フォールバック: diff内の - 行カウント
        deletions_count=$(grep -c "^-" "$log_file" 2>/dev/null || echo "0")
    fi

    # 問題検出（絵文字パターン）
    local critical_count
    critical_count=$(grep -c "🔴" "$log_file" 2>/dev/null || echo "0")

    local high_count
    high_count=$(grep -c "🟠" "$log_file" 2>/dev/null || echo "0")

    local medium_count
    medium_count=$(grep -c "🟡" "$log_file" 2>/dev/null || echo "0")

    local low_count
    low_count=$(grep -c "🟢" "$log_file" 2>/dev/null || echo "0")

    local total_issues=$((critical_count + high_count + medium_count + low_count))

    # AI分析実行確認
    local ai_analysis_performed="false"
    if grep -q "## 🤖 AI-Enhanced Analysis" "$log_file" 2>/dev/null; then
        ai_analysis_performed="true"
    fi

    # ========================================
    # 3. JSON レポート生成
    # ========================================
    cat > "$json_file" <<EOF
{
  "metadata": {
    "tool": "alternative",
    "version": "1.0.0",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "commit": "$COMMIT_HASH",
    "commit_short": "$commit_short",
    "execution_time_ms": 0,
    "review_type": "pattern_matching"
  },
  "summary": {
    "lines_added": $additions_count,
    "lines_removed": $deletions_count,
    "net_change": $((additions_count - deletions_count)),
    "total_issues": $total_issues,
    "severity": {
      "critical": $critical_count,
      "high": $high_count,
      "medium": $medium_count,
      "low": $low_count
    }
  },
  "analysis": {
    "ai_analysis_performed": $ai_analysis_performed,
    "pattern_matching": true,
    "security_scan": true
  },
  "log_file": "$log_file"
}
EOF

    # ========================================
    # 4. Markdown レポート生成（簡略版）
    # ========================================
    # ヘッダー追加
    cat > "$md_file" <<EOF
# Alternative Code Review Report (Pattern Matching)

**Generated**: $(date +"%Y-%m-%d %H:%M:%S")
**Commit**: \`$commit_short\` (\`$COMMIT_HASH\`)
**Review Type**: Alternative Implementation

---

## 📊 Quick Summary

- **Lines Added**: $additions_count
- **Lines Removed**: $deletions_count
- **Net Change**: $((additions_count - deletions_count)) lines
- **Total Issues Detected**: $total_issues
  - 🔴 Critical: $critical_count
  - 🟠 High: $high_count
  - 🟡 Medium: $medium_count
  - 🟢 Low: $low_count
- **AI Analysis**: $([ "$ai_analysis_performed" = "true" ] && echo "✅ Performed" || echo "❌ Not performed")

---

EOF

    # 元のログファイル内容を追加（ヘッダーを除く）
    tail -n +2 "$log_file" >> "$md_file" 2>/dev/null

    # ========================================
    # 5. 戻り値出力
    # ========================================
    echo "$json_file:$md_file"
}

# ========================================
# Symlink Management Functions
# ========================================

create_symlinks() {
    local json_file="$1"
    local md_file="$2"
    local suffix="${3:-coderabbit}"  # Default: coderabbit

    # ========================================
    # 1. 入力検証
    # ========================================
    if [ -z "$json_file" ] || [ -z "$md_file" ]; then
        log_warning "Symlink creation skipped: missing file paths"
        return 1
    fi

    if [ ! -f "$json_file" ]; then
        log_warning "Symlink creation skipped: JSON file does not exist: $json_file"
        return 1
    fi

    if [ ! -f "$md_file" ]; then
        log_warning "Symlink creation skipped: Markdown file does not exist: $md_file"
        return 1
    fi

    # ========================================
    # 2. 相対パス生成
    # ========================================
    # 同一ディレクトリ内なので、basenameのみで十分
    local json_basename
    json_basename=$(basename "$json_file")
    local md_basename
    md_basename=$(basename "$md_file")

    # リンク名
    local json_link="$OUTPUT_DIR/latest_${suffix}.json"
    local md_link="$OUTPUT_DIR/latest_${suffix}.md"

    # ========================================
    # 3. JSON シンボリックリンク作成
    # ========================================
    # -sfオプション: symbolic + force (既存リンク上書き)
    if ln -sf "$json_basename" "$json_link" 2>/dev/null; then
        log_info "Symlink created: $(basename "$json_link") -> $json_basename"
    else
        # 作成失敗（権限不足など）
        log_warning "Failed to create symlink: $json_link"
        log_info "  Reason: Permission denied or read-only filesystem"
        log_info "  Impact: Latest review must be accessed directly via $json_file"
        # 失敗してもスクリプトは継続（警告のみ）
    fi

    # ========================================
    # 4. Markdown シンボリックリンク作成
    # ========================================
    if ln -sf "$md_basename" "$md_link" 2>/dev/null; then
        log_info "Symlink created: $(basename "$md_link") -> $md_basename"
    else
        log_warning "Failed to create symlink: $md_link"
        log_info "  Reason: Permission denied or read-only filesystem"
        log_info "  Impact: Latest review must be accessed directly via $md_file"
    fi

    # ========================================
    # 5. 検証（オプション）
    # ========================================
    # リンクが実際に有効か確認
    if [ -L "$json_link" ] && [ -e "$json_link" ]; then
        log_success "Valid symlink: $(basename "$json_link")"
    elif [ -e "$json_link" ]; then
        log_warning "Symlink exists but target is invalid: $json_link"
    fi

    if [ -L "$md_link" ] && [ -e "$md_link" ]; then
        log_success "Valid symlink: $(basename "$md_link")"
    elif [ -e "$md_link" ]; then
        log_warning "Symlink exists but target is invalid: $md_link"
    fi

    return 0  # 失敗してもスクリプト継続のため0を返す
}

# ========================================
# Main Execution Logic
# ========================================

main() {
    # ========================================
    # 1. 引数パース
    # ========================================
    parse_args "$@"

    # ========================================
    # 2. 前提条件チェック
    # ========================================
    check_prerequisites

    # ========================================
    # 3. CodeRabbit実行
    # ========================================
    log_info "Starting CodeRabbit review..."
    log_info "Commit: $COMMIT_HASH"
    log_info "Timeout: ${CODERABBIT_REVIEW_TIMEOUT}s"
    echo ""

    # execute_coderabbit_review() はstdout汚染防止のため、
    # stderr を 2>/dev/null しない（警告メッセージを表示）
    local review_result
    review_result=$(execute_coderabbit_review)
    local review_status=$?

    if [ $review_status -ne 0 ]; then
        log_error "CodeRabbit review failed with exit code $review_status"
        exit 1
    fi

    # ========================================
    # 4. 結果パース
    # ========================================
    # 戻り値フォーマット: "$log_file:$status"
    local log_file="${review_result%%:*}"   # 最初の : より前
    local exec_status="${review_result##*:}"  # 最後の : より後

    if [ ! -f "$log_file" ] || [ ! -s "$log_file" ]; then
        log_error "Review output file not found or empty: $log_file"
        exit 1
    fi

    log_success "CodeRabbit review completed"
    log_info "Raw output: $log_file"
    echo ""

    # ========================================
    # 5. 出力パース（JSON/Markdown生成）
    # ========================================
    log_info "Parsing review output..."

    local parse_result=""
    local suffix=""

    # ファイル名から suffix 判定（coderabbit or alt）
    if [[ "$log_file" == *"_coderabbit.log" ]]; then
        suffix="coderabbit"
        parse_result=$(parse_coderabbit_output "$log_file")
    elif [[ "$log_file" == *"_alt.log" ]]; then
        suffix="alt"
        parse_result=$(parse_alternative_output "$log_file")
    else
        log_error "Unknown log file format: $log_file"
        exit 1
    fi

    # パース結果フォーマット: "$json_file:$md_file"
    local json_file="${parse_result%%:*}"
    local md_file="${parse_result##*:}"

    if [ ! -f "$json_file" ] || [ ! -f "$md_file" ]; then
        log_error "Parse output files not found: $json_file, $md_file"
        exit 1
    fi

    log_success "Parsing complete"
    log_info "JSON report: $json_file"
    log_info "Markdown report: $md_file"
    echo ""

    # ========================================
    # 6. シンボリックリンク作成
    # ========================================
    log_info "Creating symlinks to latest review..."
    create_symlinks "$json_file" "$md_file" "$suffix"
    echo ""

    # ========================================
    # 7. 完了サマリー
    # ========================================
    log_success "Review workflow complete!"
    echo ""
    echo "📊 Review Summary:"
    echo "  - Raw Output:      $log_file"
    echo "  - JSON Report:     $json_file"
    echo "  - Markdown Report: $md_file"
    echo "  - Latest Symlinks: latest_${suffix}.json, latest_${suffix}.md"
    echo ""
    echo "To view the report:"
    echo "  $ cat $md_file"
    echo ""

    return 0
}

# ========================================
# Script Invocation
# ========================================

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
