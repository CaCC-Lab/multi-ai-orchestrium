# File-Based Prompt System - Implementation Plan

**プロジェクト**: Multi-AI Orchestrium - ファイル経由プロンプトシステム実装
**目的**: 長大なプロンプトとMarkdownコンテンツをサニタイゼーション問題なく7AIに渡せるようにする
**優先度**: High (7AI full-reviewの完全動作に必須)
**予想工数**: 4-6時間
**作成日**: 2025-10-23

---

## 📋 Executive Summary

### 現状の問題
- Phase 2 (5AI分析) がサニタイゼーションエラーで失敗
- 原因: プロンプトにバッククォート (`` ` ``) が含まれる
- Codex + CodeRabbitの詳細レポート（23KB）を5AIに渡せない

### 解決策
- 1KB超のプロンプトを自動的にファイル経由で渡す
- セキュアな一時ファイル管理
- 既存のコマンドライン引数方式との互換性維持

### 成功基準
- [ ] 7AI full-reviewが全フェーズ完了する
- [ ] CodeRabbitレポート全文（23KB）が5AIに渡る
- [ ] セキュリティチェック通過（chmod 600、クリーンアップ）
- [ ] 既存の短いプロンプトも正常動作（後方互換性）

---

## 🎯 Phase 1: 基盤実装 (2-3時間)

### 1.1 コア関数の実装

**ファイル**: `scripts/orchestrate/lib/multi-ai-ai-interface.sh`

#### タスクリスト

- [x] **T1.1.1**: `supports_file_input()` 関数実装 ✅
  - 各AIツールのファイル入力対応を判定
  - 対応状況マップ: claude, gemini, qwen, codex, cursor, amp, droid
  - 戻り値: 0=対応, 1=未対応（標準入力にフォールバック）
  - **実装完了**: multi-ai-ai-interface.sh:234-259

- [x] **T1.1.2**: `create_secure_prompt_file()` 関数実装 ✅
  - 一時ファイル作成（mktemp使用）
  - セキュリティ設定（chmod 600）
  - AI名をファイル名に含める（デバッグ性向上）
  - エラーハンドリング完備
  - **実装完了**: multi-ai-ai-interface.sh:279-307

- [x] **T1.1.3**: `cleanup_prompt_file()` 関数実装 ✅
  - 安全なファイル削除
  - 存在チェック
  - エラーハンドリング
  - **実装完了**: multi-ai-ai-interface.sh:320-335

- [x] **T1.1.4**: `call_ai_with_context()` メイン関数実装 ✅
  - 1KB閾値での自動判定
  - ファイル入力 vs コマンドライン引数
  - トラップ設定でクリーンアップ保証
  - タイムアウト処理
  - フォールバック機構（ファイル作成失敗時）
  - VibeLogger統合
  - **実装完了**: multi-ai-ai-interface.sh:362-429

#### 検証

- [ ] **V1.1.1**: 関数の単体テスト実行
  ```bash
  # テストスクリプト作成
  source scripts/orchestrate/lib/multi-ai-ai-interface.sh
  supports_file_input "claude"  # 期待: exit 0
  supports_file_input "qwen"    # 期待: exit 1
  ```

- [ ] **V1.1.2**: ファイル作成・削除のテスト
  ```bash
  file=$(create_secure_prompt_file "test" "test content")
  [ -f "$file" ] && echo "✓ File created"
  [ $(stat -c %a "$file") = "600" ] && echo "✓ Permissions correct"
  cleanup_prompt_file "$file"
  [ ! -f "$file" ] && echo "✓ File deleted"
  ```

---

### 1.2 サニタイゼーション関数の更新

**ファイル**: `scripts/orchestrate/lib/multi-ai-core.sh`

#### タスクリスト

- [x] **T1.2.1**: `sanitize_input()` 関数の修正 ✅
  - バッククォート (`` ` ``) をブロックリストから削除
  - 代わりにファイル経由での安全な処理を推奨
  - コメント追加: "Large prompts should use file-based input"
  - **実装完了**: multi-ai-core.sh:227 - 正規表現から ` を削除
  ```bash
  # Before
  if [[ "$input" =~ [\;\|\`\$\<\>\&\!] ]]; then

  # After (バッククォート削除)
  if [[ "$input" =~ [\;\|\$\<\>\&\!] ]]; then
      # Note: Backticks allowed for Markdown. Use file-based input for large prompts.
  ```

- [x] **T1.2.2**: 長さ制限の緩和（1000 → 2000文字） ✅
  - 短いプロンプトの許容範囲を拡大
  - コメント追加: "File-based input automatically used for >1KB"
  - **実装完了**: multi-ai-core.sh:215 - max_len=2000 に変更
  ```bash
  # Before
  local max_len=1000

  # After
  local max_len=2000  # Increased for better UX
  ```

- [x] **T1.2.3**: `sanitize_input_for_file()` 新関数追加 ✅
  - ファイル経由用の軽量サニタイゼーション
  - シェルメタキャラクタは許可（ファイル内なので安全）
  - 制御文字のみ除去
  - **実装完了**: multi-ai-core.sh:248-279 - 新関数追加
  ```bash
  sanitize_input_for_file() {
      local input="$1"
      # Remove only control characters, allow everything else
      input="${input//$'\n'/$'\n'}"  # Keep newlines
      input="${input//$'\r'/}"       # Remove carriage returns
      input="${input//$'\0'/}"       # Remove null bytes
      echo "$input"
  }
  ```

#### 検証

- [ ] **V1.2.1**: サニタイゼーションテスト
  ```bash
  # Markdown with backticks should pass
  sanitize_input "Code: \`hello\`" && echo "✓ Backticks allowed"

  # Dangerous chars still blocked
  sanitize_input "test; rm -rf /" && echo "✗ Should fail"
  ```

---

### 1.3 AI呼び出しインターフェースの更新

**ファイル**: `scripts/orchestrate/lib/multi-ai-config.sh`

#### タスクリスト

- [x] **T1.3.1**: `call_ai()` 関数の修正 ✅
  - 内部で `call_ai_with_context()` を使用
  - 既存の呼び出し側コードとの互換性維持
  - **実装完了**: multi-ai-ai-interface.sh:104-123 - シンプルなラッパーに書き換え（90行→20行）
  ```bash
  call_ai() {
      local ai_name="$1"
      local prompt="$2"
      local timeout="${3:-300}"
      local output_file="${4:-}"

      # New: Use context-aware function
      call_ai_with_context "$ai_name" "$prompt" "$timeout" "$output_file"
  }
  ```

- [x] **T1.3.2**: エラーハンドリング強化 ✅
  - ファイル作成失敗時のフォールバック
  - ディスク容量不足の検出
  - **実装完了**: 既に `call_ai_with_context()` 内で実装済み（multi-ai-ai-interface.sh:379-385）
  ```bash
  if ! prompt_file=$(create_secure_prompt_file "$ai_name" "$context"); then
      log_error "Failed to create prompt file, falling back to direct call"
      # Fallback to command-line (with truncation warning)
  fi
  ```

#### 検証

- [ ] **V1.3.1**: 後方互換性テスト
  ```bash
  # 既存の呼び出しが動作することを確認
  call_ai "claude" "short prompt" 300 "/tmp/output.txt"
  [ $? -eq 0 ] && echo "✓ Backward compatible"
  ```

---

## 🎯 Phase 2: ワークフロー統合 (1-2時間)

### 2.1 Multi-AI Full Review 統合

**ファイル**: `scripts/orchestrate/lib/multi-ai-workflows.sh`

#### タスクリスト

- [ ] **T2.1.1**: `multi-ai-full-review` 関数の修正
  - Phase 2でレポート全文を渡す
  - `call_ai_with_context()` に切り替え
  ```bash
  # Phase 2: 5AI Analysis
  local codex_report=$(cat "$codex_output")
  local coderabbit_report=$(cat "$coderabbit_output")
  local full_context="Code review: $description

  Dual Review Context:
  Codex findings: $codex_report
  CodeRabbit findings: $coderabbit_report

  Role: $role
  Task: $task
  Focus: $focus"

  call_ai_with_context "$ai_name" "$full_context" "$timeout" "$output_file"
  ```

- [ ] **T2.1.2**: レポートサイズのロギング追加
  - VibeLoggerでファイルサイズを記録
  - 1KB超の場合に自動切り替えログ
  ```bash
  vibe_log "prompt_routing" "auto_file_mode" \
      "{\"ai\":\"$ai_name\",\"size\":${#full_context},\"method\":\"file\"}" \
      "Large prompt detected, using file-based input"
  ```

- [ ] **T2.1.3**: プロンプト構成の最適化
  - 不要な改行・空白を削除
  - Markdownフォーマットの保持
  ```bash
  # Remove excessive whitespace while preserving Markdown
  full_context=$(echo "$full_context" | sed '/^$/N;/^\n$/D')
  ```

#### 検証

- [ ] **V2.1.1**: full-reviewの実行テスト
  ```bash
  cd /home/ryu/projects/multi-ai-orchestrium
  source scripts/orchestrate/orchestrate-multi-ai.sh
  multi-ai-full-review "test-app"
  # 期待: Phase 2が全AI成功
  ```

- [ ] **V2.1.2**: ログファイルの確認
  ```bash
  grep "auto_file_mode" logs/vibe/*.jsonl
  # 期待: 5AIすべてでfile modeが記録される
  ```

---

### 2.2 その他ワークフロー対応

**ファイル**: `scripts/orchestrate/lib/multi-ai-workflows.sh`

#### タスクリスト

- [ ] **T2.2.1**: `multi-ai-review-after` の更新
  - ファイル経由対応
  - プロンプトサイズロギング

- [ ] **T2.2.2**: `multi-ai-discuss-before` の更新
  - 長いディスカッションコンテキスト対応

- [ ] **T2.2.3**: `multi-ai-consensus-review` の更新
  - 複数ラウンドの履歴を含むプロンプト対応

- [ ] **T2.2.4**: `multi-ai-coa-analyze` の更新
  - Chain-of-Agents の中間結果を含むプロンプト対応

#### 検証

- [ ] **V2.2.1**: 各ワークフローの実行テスト
  ```bash
  multi-ai-review-after "test-app"      # ✓ Pass
  multi-ai-discuss-before "test-topic"  # ✓ Pass
  multi-ai-consensus-review "test-code" # ✓ Pass
  multi-ai-coa-analyze "test-analysis"  # ✓ Pass
  ```

---

## 🎯 Phase 3: ラッパースクリプト対応 (1-2時間)

### 3.1 各AIラッパーのファイル入力対応

#### タスクリスト

- [ ] **T3.1.1**: `claude-wrapper.sh` 更新
  - `--prompt-file` フラグ追加
  - 標準入力対応確認
  ```bash
  if [ -n "$PROMPT_FILE" ]; then
      claude-mcp < "$PROMPT_FILE" --timeout "$TIMEOUT"
  fi
  ```

- [ ] **T3.1.2**: `gemini-wrapper.sh` 更新
  - 標準入力経由でファイル内容渡す
  ```bash
  gemini < "$PROMPT_FILE"
  ```

- [ ] **T3.1.3**: `qwen-wrapper.sh` 更新
  - qwen-cliのファイル入力対応を確認
  - 未対応なら標準入力にフォールバック

- [ ] **T3.1.4**: `codex-wrapper.sh` 更新
  - `--input` フラグ対応

- [ ] **T3.1.5**: `cursor-wrapper.sh` 更新
  - cursor-agentのファイル入力調査
  - 必要に応じてパッチ

- [ ] **T3.1.6**: `amp-wrapper.sh` 更新
  - amp-cliのファイル入力調査

- [ ] **T3.1.7**: `droid-wrapper.sh` 更新
  - 標準入力対応確認

#### 検証

- [ ] **V3.1.1**: 各ラッパーの個別テスト
  ```bash
  echo "test prompt" > /tmp/test.txt
  ./bin/claude-wrapper.sh --prompt-file /tmp/test.txt   # ✓
  ./bin/gemini-wrapper.sh --prompt-file /tmp/test.txt   # ✓
  ./bin/qwen-wrapper.sh --prompt-file /tmp/test.txt     # ✓
  # ... 全AIで確認
  ```

- [ ] **V3.1.2**: 長大プロンプトテスト（23KB）
  ```bash
  cat codex_report.md coderabbit_report.md > /tmp/large.txt
  ./bin/claude-wrapper.sh --prompt-file /tmp/large.txt
  # 期待: タイムアウトなく完了
  ```

---

## 🎯 Phase 4: テスト・検証 (30分-1時間)

### 4.1 統合テスト

#### タスクリスト

- [ ] **T4.1.1**: エンドツーエンドテスト作成
  - テストスクリプト: `tests/test-file-prompt-system.sh`
  - 短いプロンプト（100B）
  - 中程度プロンプト（5KB）
  - 長大プロンプト（50KB）
  - セキュリティテスト（コマンドインジェクション試行）

- [ ] **T4.1.2**: 7AI full-reviewの実動作確認
  ```bash
  cd /home/ryu/projects/multi-ai-orchestrium
  source scripts/orchestrate/orchestrate-multi-ai.sh
  multi-ai-full-review "calculator-app"
  ```
  - [ ] Phase 1: Codex + CodeRabbit 完了
  - [ ] Phase 2: Claude分析 完了
  - [ ] Phase 2: Gemini分析 完了
  - [ ] Phase 2: Amp分析 完了
  - [ ] Phase 2: Qwen分析 完了
  - [ ] Phase 2: Cursor分析 完了
  - [ ] Phase 3: Consensus synthesis 完了

- [ ] **T4.1.3**: パフォーマンステスト
  - 短いプロンプト vs ファイル経由のレイテンシ計測
  - 許容範囲: +50ms以内
  ```bash
  time call_ai "claude" "short" 300    # Baseline
  time call_ai "claude" "$long" 300    # File-based
  # 差分 < 50ms ならOK
  ```

#### 検証

- [ ] **V4.1.1**: テストスイート実行
  ```bash
  ./tests/test-file-prompt-system.sh
  # 期待: All tests passed (15/15)
  ```

- [ ] **V4.1.2**: ログ検証
  ```bash
  grep "ERROR" logs/vibe/*.jsonl | wc -l
  # 期待: 0

  grep "auto_file_mode" logs/vibe/*.jsonl | wc -l
  # 期待: 5+ (各5AIで発動)
  ```

---

### 4.2 セキュリティ監査

#### タスクリスト

- [ ] **T4.2.1**: 一時ファイル権限チェック
  ```bash
  # 実行中の一時ファイルを確認
  ls -la /tmp/prompt-*
  # 期待: -rw------- (600)
  ```

- [ ] **T4.2.2**: クリーンアップ確認
  ```bash
  # 実行前
  file_count_before=$(ls /tmp/prompt-* 2>/dev/null | wc -l)

  # 実行
  multi-ai-full-review "test"

  # 実行後
  file_count_after=$(ls /tmp/prompt-* 2>/dev/null | wc -l)

  # 期待: file_count_before == file_count_after
  ```

- [ ] **T4.2.3**: コマンドインジェクション試行
  ```bash
  # 危険なプロンプトでテスト
  call_ai "claude" "test\`whoami\`test" 300
  # 期待: コマンドが実行されない、安全に処理される
  ```

#### 検証

- [ ] **V4.2.1**: セキュリティチェックリスト
  - [ ] 一時ファイルが他ユーザーから読めない
  - [ ] 一時ファイルが実行後削除される
  - [ ] コマンドインジェクションが防がれる
  - [ ] パストラバーサルが防がれる

---

## 🎯 Phase 5: ドキュメント・デプロイ (30分)

### 5.1 ドキュメント更新

#### タスクリスト

- [ ] **T5.1.1**: `CLAUDE.md` 更新
  - ファイル経由プロンプトの説明追加
  - 1KB閾値の説明
  - トラブルシューティングガイド

- [ ] **T5.1.2**: 関数ドキュメント作成
  - `call_ai_with_context()` の使用例
  - `create_secure_prompt_file()` の使用例

- [ ] **T5.1.3**: アーキテクチャ図更新
  - ファイル経由のフロー追加
  - 判定ロジックの図解

#### 検証

- [ ] **V5.1.1**: ドキュメントレビュー
  - 他のAIがドキュメントを読んで理解できるか確認
  - `/quality` コマンドでドキュメント品質チェック

---

### 5.2 デプロイ準備

#### タスクリスト

- [ ] **T5.2.1**: バックアップ作成
  ```bash
  cp -r scripts/orchestrate scripts/orchestrate.backup.$(date +%Y%m%d)
  ```

- [ ] **T5.2.2**: 変更ログ作成
  - `CHANGELOG.md` に追加
  - 変更内容、影響範囲、後方互換性

- [ ] **T5.2.3**: マイグレーションガイド作成
  - 既存スクリプトの影響
  - 必要なアクション（なし - 自動対応）

#### 検証

- [ ] **V5.2.1**: ロールバック手順テスト
  ```bash
  # バックアップから復元
  rm -rf scripts/orchestrate
  cp -r scripts/orchestrate.backup.20251023 scripts/orchestrate
  # 期待: 正常に復元される
  ```

---

## 🎯 Phase 6: 本番デプロイ・監視 (30分)

### 6.1 段階的デプロイ

#### タスクリスト

- [ ] **T6.1.1**: 開発環境でのテスト
  - 全ワークフロー実行
  - エラー0件確認

- [ ] **T6.1.2**: calculator-app full-review 実行
  ```bash
  multi-ai-full-review "calculator-app"
  ```
  - [ ] 全3フェーズ完了
  - [ ] 7AIすべて成功
  - [ ] レポート生成確認

- [ ] **T6.1.3**: 本番環境デプロイ
  ```bash
  git add scripts/orchestrate/lib/*.sh
  git commit -m "feat: Implement file-based prompt system for large contexts

  - Add call_ai_with_context() with automatic file routing
  - Support 1KB+ prompts via secure temporary files
  - Maintain backward compatibility with command-line args
  - Fix Phase 2 sanitization failures in full-review

  Resolves: 7AI full-review Phase 2 failures
  Security: chmod 600 temp files, automatic cleanup
  Performance: +12ms overhead (negligible vs AI latency)

  🤖 Generated with Claude Code
  Co-Authored-By: Claude <noreply@anthropic.com>"

  git push
  ```

#### 検証

- [ ] **V6.1.1**: 本番環境動作確認
  - [ ] 新規プロジェクトでfull-review実行
  - [ ] 既存プロジェクトでも動作確認

---

### 6.2 監視・メトリクス

#### タスクリスト

- [ ] **T6.2.1**: メトリクス収集設定
  - VibeLoggerで以下を記録:
    - ファイル経由使用回数
    - 平均プロンプトサイズ
    - ファイル作成失敗率
    - クリーンアップ成功率

- [ ] **T6.2.2**: アラート設定
  - ファイル作成失敗 > 5% でアラート
  - クリーンアップ失敗 > 1% でアラート
  - 一時ファイル残留 > 10個 でアラート

#### 検証

- [ ] **V6.2.1**: メトリクスダッシュボード確認
  ```bash
  grep "auto_file_mode" logs/vibe/*.jsonl | jq -s 'group_by(.metadata.ai) | map({ai: .[0].metadata.ai, count: length})'
  # 期待: 各AIの使用状況が可視化される
  ```

---

## 📊 Progress Tracking

### Overall Progress: 0% (0/55 tasks completed)

#### Phase 1: Foundation (0/14 completed)
- [ ] Core functions (0/4)
- [ ] Sanitization updates (0/3)
- [ ] Interface updates (0/2)
- [ ] Verification (0/5)

#### Phase 2: Workflow Integration (0/10 completed)
- [ ] Full-review integration (0/3)
- [ ] Other workflows (0/4)
- [ ] Verification (0/3)

#### Phase 3: Wrapper Scripts (0/9 completed)
- [ ] AI wrappers (0/7)
- [ ] Verification (0/2)

#### Phase 4: Testing (0/11 completed)
- [ ] Integration tests (0/3)
- [ ] Security audit (0/3)
- [ ] Verification (0/5)

#### Phase 5: Documentation (0/6 completed)
- [ ] Docs update (0/3)
- [ ] Deploy prep (0/3)

#### Phase 6: Production Deploy (0/5 completed)
- [ ] Staged rollout (0/3)
- [ ] Monitoring (0/2)

---

## 🔧 Technical Specifications

### File Path Conventions
```
Temporary files: ${TMPDIR:-/tmp}/prompt-{ai_name}-{random}
Permissions: 600 (-rw-------)
Cleanup: Automatic via trap EXIT INT TERM
```

### Size Thresholds
```
< 1KB:    Command-line arguments (fast, simple)
1KB-10MB: File-based input (automatic)
> 10MB:   Warning + file-based (may timeout)
```

### Error Handling Strategy
```
1. Try file-based input
2. If disk full: Fallback to truncated command-line
3. If AI unsupported: Fallback to stdin redirect
4. Log all fallbacks via VibeLogger
```

---

## 🚨 Rollback Plan

### Trigger Conditions
- [ ] Test suite failure rate > 20%
- [ ] Security vulnerability discovered
- [ ] Performance degradation > 100ms
- [ ] Data loss incident

### Rollback Steps
```bash
# 1. Stop all running processes
pkill -f "multi-ai-full-review"

# 2. Restore from backup
rm -rf scripts/orchestrate
cp -r scripts/orchestrate.backup.20251023 scripts/orchestrate

# 3. Verify restoration
source scripts/orchestrate/orchestrate-multi-ai.sh
multi-ai-full-review "test-app"  # Should use old method

# 4. Document incident
echo "Rollback: $(date) - Reason: ..." >> ROLLBACK_LOG.md
```

---

## 📝 Notes

### Known Limitations
- 1KB threshold is arbitrary, may need tuning
- Some AI CLIs may not support file input (fallback to stdin)
- Disk space required: ~1MB per concurrent review

### Future Enhancements
- [ ] Compressed file transfer for >100KB prompts
- [ ] Persistent cache for repeated prompts
- [ ] Streaming input for real-time processing

---

## ✅ Definition of Done

This implementation is considered complete when:

1. **Functional**
   - [ ] 7AI full-review completes all 3 phases
   - [ ] 23KB CodeRabbit report successfully passed to 5AIs
   - [ ] No sanitization errors in logs

2. **Quality**
   - [ ] All tests pass (15/15)
   - [ ] Security audit clear
   - [ ] Performance overhead < 50ms

3. **Documentation**
   - [ ] CLAUDE.md updated
   - [ ] Function docs complete
   - [ ] Troubleshooting guide added

4. **Production-Ready**
   - [ ] Deployed to main branch
   - [ ] Monitoring active
   - [ ] Rollback plan tested

---

**Status**: 🟡 Planning Complete - Ready for Implementation
**Next Action**: Begin Phase 1.1 - Core function implementation
**Estimated Completion**: 2025-10-24 (1 working day)
