# Migration Guide: v3.1 → v3.2

**Release Date**: 2025-10-24
**Breaking Changes**: None
**Recommended Migration Time**: 0 minutes (automatic)

## Overview

Version 3.2 introduces the **File-Based Prompt System**, enabling support for large prompts (>1KB) with zero breaking changes. All existing code continues to work without modification.

## What's New

### File-Based Prompt System

**Automatic routing** for prompts >1KB:
- Small prompts (<1KB): No change
- Large prompts (≥1KB): Automatically routed through secure temporary files

**Key Benefits**:
- ✅ Support for prompts up to 1MB (100x increase)
- ✅ <200ms overhead for 100KB prompts
- ✅ Automatic security (chmod 600, auto-cleanup)
- ✅ Zero code changes required

## Breaking Changes

**None**. This is a backward-compatible release.

### API Compatibility

| Function | v3.1 | v3.2 | Status |
|----------|------|------|--------|
| `call_ai()` | ✅ | ✅ | Unchanged |
| `call_ai_with_context()` | N/A | ✅ New | New (optional) |
| `sanitize_input()` | Max 2KB | Max 100KB | Enhanced |
| `sanitize_input_for_file()` | ✅ | ✅ | Unchanged |

## Migration Path

### Option 1: No Action Required (Recommended)

**Who**: All users

**What to do**: Nothing! Your code will automatically benefit from the new system.

**Example**:
```bash
# v3.1 code (still works in v3.2)
call_ai "claude" "$my_prompt" 300

# v3.2 enhancement: Automatically handles large prompts
LARGE_PROMPT=$(cat 10kb-spec.txt)
call_ai "claude" "$LARGE_PROMPT" 600  # Now works! (failed in v3.1)
```

### Option 2: Explicit File-Based Routing (Advanced)

**Who**: Users who want explicit control over routing

**What to do**: Use `call_ai_with_context()` instead of `call_ai()`

**Benefits**:
- Explicit size threshold control
- Better logging/metrics
- Future-proof for advanced features

**Example**:
```bash
# Before (v3.1)
call_ai "gemini" "$prompt" 300 "/tmp/output.txt"

# After (v3.2 - optional upgrade)
call_ai_with_context "gemini" "$prompt" 300 "/tmp/output.txt"
```

**Migration steps**:
1. Find all `call_ai` invocations: `grep -r "call_ai " scripts/`
2. Replace with `call_ai_with_context` (optional)
3. No functional change (behavior identical)

### Option 3: Custom Configuration (Power Users)

**Who**: Users with specific requirements (custom thresholds, disabled file routing, etc.)

**What to do**: Customize `config/multi-ai-profiles.yaml`

**Example**:
```yaml
# config/multi-ai-profiles.yaml

file_based_prompts:
  enabled: true  # Set to false to disable file routing globally

  thresholds:
    small: 2048  # Changed from 1024 (1KB) to 2048 (2KB)
    medium: 204800  # Changed from 100KB to 200KB
    large: 2097152  # Changed from 1MB to 2MB

  routing:
    auto: true  # Set to false for manual control
    prefer_file: false  # Set to false to prefer command-line when possible
```

**Migration steps**:
1. Copy default config: `cp config/multi-ai-profiles.yaml config/my-profiles.yaml`
2. Edit `file_based_prompts` section
3. Point to custom config: `export MULTI_AI_PROFILE=config/my-profiles.yaml`

## Updated Behaviors

### 1. `sanitize_input()` Enhanced Capacity

**Change**: Increased from 2KB to 100KB maximum

**Impact**: Workflows can now pass larger prompts without manual file handling

**Before (v3.1)**:
```bash
# Failed with "Input too long" error
large_prompt=$(head -c 10000 /dev/zero | tr '\0' 'A')
sanitize_input "$large_prompt"  # ❌ Error: Input too long (10000 > 2000 bytes)
```

**After (v3.2)**:
```bash
# Now succeeds automatically
large_prompt=$(head -c 10000 /dev/zero | tr '\0' 'A')
sanitize_input "$large_prompt"  # ✅ Success: Routed through file system
```

### 2. Character Validation Relaxed for Large Prompts

**Change**: Prompts >2KB skip strict character validation

**Rationale**: Large prompts are typically from files/workflows (safe), not user input

**Impact**: Markdown, JSON, shell scripts in prompts now work correctly

**Before (v3.1)**:
```bash
# Failed with "Invalid characters detected"
markdown=$(cat README.md)
sanitize_input "$markdown"  # ❌ Error: Invalid characters ($ in code blocks)
```

**After (v3.2)**:
```bash
# Now succeeds (relaxed validation for >2KB)
markdown=$(cat README.md)
sanitize_input "$markdown"  # ✅ Success: Markdown preserved
```

**Security Note**: Small prompts (<2KB) still have strict validation.

### 3. Wrapper `--stdin` Support

**Change**: All 7 AI wrappers now support `--stdin` flag for file input

**Impact**: Explicit file-based input for advanced use cases

**Example**:
```bash
# v3.1: Not supported
echo "$prompt" | ./bin/claude-wrapper.sh  # ❌ No stdin support

# v3.2: Supported
echo "$prompt" | ./bin/claude-wrapper.sh --stdin  # ✅ Explicit stdin mode
# Or:
./bin/claude-wrapper.sh --stdin < /tmp/my-prompt.txt  # ✅ File redirect
```

## Testing Your Migration

### Validation Checklist

- [ ] **Existing workflows still work**: Run your v3.1 workflows without changes
- [ ] **Large prompts succeed**: Test with 10KB+ prompts
- [ ] **No file leaks**: Check `/tmp` after workflow completion (`ls -lh /tmp/prompt-*`)
- [ ] **Performance acceptable**: Measure overhead for your use case

### Test Script

```bash
#!/bin/bash
# test-migration.sh

set -e

source scripts/orchestrate/orchestrate-multi-ai.sh

# Test 1: Small prompt (should work as before)
echo "Test 1: Small prompt (<1KB)"
small_result=$(call_ai "claude" "Hello, test" 60)
echo "✅ PASS: Small prompt"

# Test 2: Large prompt (new in v3.2)
echo "Test 2: Large prompt (10KB)"
large_prompt=$(head -c 10240 /dev/zero | tr '\0' 'A')
large_result=$(call_ai "claude" "$large_prompt" 120)
echo "✅ PASS: Large prompt"

# Test 3: No file leaks
echo "Test 3: File cleanup"
leaked_files=$(ls /tmp/prompt-* 2>/dev/null | wc -l)
if [ "$leaked_files" -eq 0 ]; then
    echo "✅ PASS: No file leaks"
else
    echo "❌ FAIL: Found $leaked_files leaked files"
    exit 1
fi

echo ""
echo "🎉 All migration tests passed!"
```

Run:
```bash
bash test-migration.sh
```

## Rollback Plan

### If You Encounter Issues

**Option 1: Disable File-Based Routing**

```yaml
# config/multi-ai-profiles.yaml
file_based_prompts:
  enabled: false  # Revert to v3.1 behavior
```

**Option 2: Downgrade to v3.1**

```bash
# Git rollback
git checkout v3.1.0

# Or: Manual revert
git revert <commit-hash-of-v3.2>
```

**Option 3: Report Issue**

File a bug report with:
- Error message
- Prompt size
- AI tool used
- Steps to reproduce

## Performance Considerations

### Expected Overhead

| Prompt Size | Overhead | When to Optimize |
|-------------|----------|------------------|
| < 1KB | 0ms | Never |
| 1KB-10KB | 5-15ms | Only if latency-critical |
| 10KB-100KB | 15-90ms | Consider caching |
| 100KB-1MB | 90-200ms | Review necessity |

### Optimization Tips

**For 10KB-100KB prompts**:
```bash
# Before: Multiple calls with same large context
for item in "${items[@]}"; do
    call_ai "claude" "$large_context + $item" 300
done

# After: Pre-process context, pass only deltas
context_summary=$(call_ai "claude" "$large_context: summarize" 300)
for item in "${items[@]}"; do
    call_ai "claude" "$context_summary + $item" 60  # Much faster
done
```

**For >100KB prompts**:
- Consider splitting into smaller chunks
- Use streaming APIs (Phase 6 feature)
- Enable compression (Phase 6 feature)

## FAQ

### Q: Do I need to change my code?

**A**: No. All existing code works without modification.

### Q: Will my workflows be slower?

**A**: For prompts <1KB, no change. For large prompts (>1KB), expect 5-200ms overhead depending on size.

### Q: Is file-based routing secure?

**A**: Yes. Files have `chmod 600` permissions, unique names, and automatic cleanup.

### Q: Can I disable file-based routing?

**A**: Yes, set `file_based_prompts.enabled: false` in YAML config.

### Q: What if `/tmp` is full?

**A**: System automatically falls back to truncated command-line input. Set `TMPDIR` to alternative location.

### Q: Do all 7 AI tools support this?

**A**: Yes. Claude, Gemini, Amp, Qwen, Droid, Codex, and Cursor all support file-based input.

### Q: What about binary prompts (images, PDFs)?

**A**: Not yet supported. Planned for Phase 7.

### Q: Can I use this with TDD workflows?

**A**: Yes. TDD workflows automatically benefit from file-based routing for large test specifications.

## Troubleshooting

### Issue: "File creation failed, falling back to truncated command-line"

**Symptom**: Warning message in logs, prompt truncated to 1KB

**Cause**: `/tmp` full or no write permission

**Solution**:
```bash
# Check disk space
df -h /tmp

# Use custom TMPDIR
export TMPDIR=/home/user/tmp
mkdir -p $TMPDIR
chmod 700 $TMPDIR
```

### Issue: Prompt still rejected for >2KB

**Symptom**: "Input too long" error for prompts >2KB

**Cause**: Using old `sanitize_input()` directly instead of through `call_ai()`

**Solution**: Use `call_ai()` or `call_ai_with_context()` (not `sanitize_input()` directly)

### Issue: Temporary files not cleaned up

**Symptom**: Files remain in `/tmp` after workflow completion

**Cause**: Script killed with `SIGKILL` (not `SIGTERM`)

**Solution**: Use `kill -TERM` instead of `kill -9` for graceful shutdown

### Issue: Performance degradation

**Symptom**: Workflows slower than v3.1

**Cause**: All prompts routed through files (threshold too low)

**Solution**: Increase threshold in YAML config:
```yaml
file_based_prompts:
  thresholds:
    small: 10240  # 10KB (from 1KB)
```

## Resources

- **Detailed Documentation**: `docs/FILE_BASED_PROMPT_SYSTEM.md`
- **CHANGELOG**: `CHANGELOG.md` (v3.2.0 section)
- **User Guide**: `CLAUDE.md` (section: "ファイルベースプロンプトシステム")
- **Test Suite**: `tests/phase1-file-based-prompt-test.sh`
- **Support**: File issues at `https://github.com/your-repo/multi-ai-orchestrium/issues`

## Timeline

- **2025-10-24**: v3.2.0 released (File-Based Prompt System)
- **2025-10-23**: v3.1.0 released (TDD workflows, YAML configuration)
- **2025-10-22**: v3.0.0 released (Multi-AI architecture)

## Next Steps

1. ✅ Review this migration guide
2. ✅ Run test script (`test-migration.sh`)
3. ✅ Test your workflows with large prompts
4. ✅ Update documentation if needed
5. ✅ Monitor `/tmp` disk usage in production
6. ⏭️ Explore Phase 6 features (compression, streaming)

---

**Questions?** File an issue or consult `docs/FILE_BASED_PROMPT_SYSTEM.md`.

**Happy migrating!** 🚀
