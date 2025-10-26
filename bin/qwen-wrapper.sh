#!/usr/bin/env bash
OUTPUT_FILE="/home/ryu/projects/multi-ai-orchestrium/tests/fixtures/qwen-valid.json"
EXIT_CODE=0

if [ -f "$OUTPUT_FILE" ]; then
    cat "$OUTPUT_FILE"
fi

exit $EXIT_CODE
