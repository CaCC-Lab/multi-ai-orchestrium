#!/usr/bin/env bash
# setup-permissions.sh - Grant execute permissions to all shell scripts
# Version: 1.0.0
# Purpose: Automatically set +x on all .sh files in the project

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Multi-AI Orchestrium${NC}"
echo -e "${BLUE}  Setup Permissions${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Counter
TOTAL=0
SUCCESS=0
FAILED=0

echo -e "${YELLOW}Searching for shell scripts...${NC}"
echo ""

# Find all .sh files and add execute permission
while IFS= read -r -d '' file; do
    TOTAL=$((TOTAL + 1))

    # Get relative path for display
    RELATIVE_PATH="${file#$PROJECT_ROOT/}"

    # Check if file already has execute permission
    if [[ -x "$file" ]]; then
        echo -e "${GREEN}✓${NC} Already executable: ${RELATIVE_PATH}"
        SUCCESS=$((SUCCESS + 1))
    else
        # Add execute permission
        if chmod +x "$file" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Added permission:   ${RELATIVE_PATH}"
            SUCCESS=$((SUCCESS + 1))
        else
            echo -e "${RED}✗${NC} Failed:            ${RELATIVE_PATH}"
            FAILED=$((FAILED + 1))
        fi
    fi
done < <(find "$PROJECT_ROOT" -type f -name "*.sh" ! -path "*/.*" -print0)

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total scripts found: ${TOTAL}"
echo -e "${GREEN}Successfully processed: ${SUCCESS}${NC}"

if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: ${FAILED}${NC}"
    echo ""
    echo -e "${YELLOW}Note: Some files may require sudo permissions${NC}"
    exit 1
else
    echo -e "${GREEN}All scripts are now executable!${NC}"
fi

echo ""
echo -e "${BLUE}You can now run scripts directly:${NC}"
echo -e "  ${GREEN}./scripts/orchestrate/orchestrate-multi-ai.sh${NC}"
echo -e "  ${GREEN}./bin/claude-wrapper.sh --prompt \"test\"${NC}"
echo -e "  ${GREEN}./check-multi-ai-tools.sh${NC}"
echo ""
