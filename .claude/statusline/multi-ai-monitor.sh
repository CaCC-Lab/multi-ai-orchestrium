#!/bin/bash
# 7AI Monitor for Statusline v2 display
# Shows: A:n G:n Q:n D:n Co:n Cu:n Cl:n
# 7AI Team: Amp, Gemini, Qwen, Droid, Codex, Cursor, Claude

# Dependency check
check_dependencies() {
    local missing=()
    command -v ps >/dev/null 2>&1 || missing+=("ps")
    command -v grep >/dev/null 2>&1 || missing+=("grep")
    command -v wc >/dev/null 2>&1 || missing+=("wc")

    if [ ${#missing[@]} -gt 0 ]; then
        echo "⚠️ Missing: ${missing[*]}"
        return 1
    fi
    return 0
}

# Check dependencies before proceeding
check_dependencies || exit 1

# Count running AI processes
# Regex patterns match:
#   - (^|/) : Start of line or after slash (prevents "clamp" matching "amp")
#   - cmd : The actual command name
#   - (-wrapper\.sh| -|$) : Either wrapper script, space+args, or end of string
count_ai_processes() {
    # Match: /path/to/amp, amp-wrapper.sh, amp -args (NOT: clamp, example)
    local amp=$(ps aux | grep -E "(^|/)amp(-wrapper\.sh| -|$)" | grep -v grep | wc -l)
    local gemini=$(ps aux | grep -E "(^|/)gemini(-wrapper\.sh| -|$)" | grep -v grep | wc -l)
    local qwen=$(ps aux | grep -E "(^|/)qwen(-wrapper\.sh| -|$)" | grep -v grep | wc -l)
    local droid=$(ps aux | grep -E "(^|/)droid(-wrapper\.sh| -|$)" | grep -v grep | wc -l)
    local codex=$(ps aux | grep -E "(^|/)codex(-wrapper\.sh| -|$)" | grep -v grep | wc -l)
    # cursor-agent or cursor-wrapper.sh
    local cursor=$(ps aux | grep -E "(^|/)cursor(-agent|-wrapper\.sh| -|$)" | grep -v grep | wc -l)
    # Keep existing pattern for claude background processes
    local claude_bg=$(ps aux | grep -E "claude.*bg|background" | grep -v grep | wc -l)

    echo "A:$amp G:$gemini Q:$qwen D:$droid Co:$codex Cu:$cursor Cl:$claude_bg"
}

# Single execution (statusline scripts are called periodically by the system)
# Get AI counts
ai_status=$(count_ai_processes)

# Count background shells
bg_count=$(ps aux | grep -E "bash.*&$|sleep" | grep -v grep | wc -l)

# Build status message
if [[ $ai_status == "A:0 G:0 Q:0 D:0 Co:0 Cu:0 Cl:0" ]]; then
    echo "🤖 7AI Ready | BG:$bg_count | Idle"
else
    echo "🤖 AI[$ai_status] | BG:$bg_count | Running..."
fi
