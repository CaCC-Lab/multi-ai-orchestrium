#!/usr/bin/env bash
# Safe Quad Review Wrapper
# Automatically falls back to manual-quad-review if multi-ai-quad-review fails

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Source core libraries
source "$PROJECT_ROOT/scripts/orchestrate/lib/multi-ai-core.sh"
source "$PROJECT_ROOT/scripts/orchestrate/lib/workflows-review-quad.sh"

DESCRIPTION="${*:-最新コミットの4ツール統合レビュー}"

echo "============================================"
echo "Safe Quad Review Execution"
echo "Description: $DESCRIPTION"
echo "============================================"
echo ""

# Attempt automated multi-ai-quad-review
log_info "Attempting automated quad review..."
echo ""

if multi-ai-quad-review "$DESCRIPTION"; then
    log_success "Automated quad review completed successfully"
    exit 0
else
    AUTOMATED_EXIT_CODE=$?
    log_warning "Automated quad review failed (exit code: $AUTOMATED_EXIT_CODE)"
    log_info "Falling back to manual quad review..."
    echo ""
    
    # Fallback to manual-quad-review
    if [ -f "$PROJECT_ROOT/scripts/manual-quad-review.sh" ]; then
        log_info "Executing manual quad review..."
        exec bash "$PROJECT_ROOT/scripts/manual-quad-review.sh"
    else
        log_error "Manual quad review script not found: $PROJECT_ROOT/scripts/manual-quad-review.sh"
        log_error "Both automated and manual quad review methods unavailable"
        exit 2
    fi
fi
