# Git Worktrees統合テスト実行手順書

## 前提条件

- メインリポジトリ: `/home/ryu/projects/multi-ai-orchestrium`
- 新しいターミナルセッションで実行すること
- mainブランチにいること

## テスト1: 環境クリーンアップと確認

```bash
cd /home/ryu/projects/multi-ai-orchestrium

# 既存Worktreeの確認
git worktree list

# もし既存Worktreeがあれば削除
git worktree prune -v
rm -rf worktrees/

# mainブランチに切り替え
git checkout main
```

## テスト2: MVP検証スクリプト実行（基本動作確認）

```bash
# 非インタラクティブモードで全テスト実行
NON_INTERACTIVE=true bash scripts/worktree-mvp-validation.sh
```

**期待される結果:**
- ✓ ワークツリー作成成功（<100ms）
- ✓ ブランチ作成成功
- ✓ コミット成功
- ✓ マージ成功
- ✓ 並列ワークツリー作成成功
- ✓ 競合解決成功
- 最終判定: GO

## テスト3: Multi-AI統合テスト（高速プロトタイプ）

### 3-1. ステータス確認ツールのテスト

```bash
# Worktree統合モードを有効化してステータス確認
ENABLE_WORKTREES=true bash scripts/orchestrate/lib/multi-ai-worktrees-status.sh
```

**期待される結果:**
```
============================================================
Git Worktrees 統合状態 - Multi-AI Orchestrium
============================================================

AI        Status  Branch                  Changes
------    ------  ------                  -------
Claude    ⚫ 未作成
Gemini    ⚫ 未作成
Amp       ⚫ 未作成
Qwen      ⚫ 未作成
Droid     ⚫ 未作成
Codex     ⚫ 未作成
Cursor    ⚫ 未作成
```

### 3-2. 実際のMulti-AIワークフロー実行

```bash
# ENABLE_WORKTREES=true で高速プロトタイプ実行
cd /home/ryu/projects/multi-ai-orchestrium

ENABLE_WORKTREES=true bash -c '
source scripts/orchestrate/orchestrate-multi-ai.sh
multi-ai-speed-prototype "Worktreeテスト: 簡単なREADME.mdファイルを作成して各AIの特徴を説明"
'
```

**実行時間:** 約2-4分

**別ターミナルで監視（オプション）:**

```bash
# ターミナル2: Worktreeリアルタイム監視
watch -n 1 'git worktree list'

# ターミナル3: Worktreesディレクトリ監視
watch -n 1 'ls -la worktrees/ 2>/dev/null || echo "worktrees未作成"'

# ターミナル4: AIプロセス監視
watch -n 2 'ps aux | grep -E "(gemini|qwen|amp|droid|codex|claude|cursor)" | grep -v grep'
```

## テスト4: 完全オーケストレーション（推奨）

```bash
ENABLE_WORKTREES=true bash -c '
source scripts/orchestrate/orchestrate-multi-ai.sh
multi-ai-full-orchestrate "Worktreeテスト: Git Worktree統合の完全検証レポート作成"
'
```

**実行時間:** 約5-8分

## 実行後の確認項目

### 4-1. Worktree作成確認

```bash
# 作成されたWorktreeを確認
git worktree list

# 期待される出力例:
# /home/ryu/projects/multi-ai-orchestrium                ea33d88 [main]
# /home/ryu/projects/multi-ai-orchestrium/worktrees/qwen abc1234 [worktree/qwen/task-123]
# /home/ryu/projects/multi-ai-orchestrium/worktrees/droid def5678 [worktree/droid/task-123]
# ...
```

### 4-2. Worktree状態ファイル確認

```bash
# NDJSON状態ファイル
cat worktrees/.worktree-state.ndjson

# 期待される形式:
# {"ai":"qwen","path":"worktrees/qwen","branch":"worktree/qwen/task-123","status":"completed","created_at":"2025-11-06T12:34:56+09:00"}
```

### 4-3. ログ確認

```bash
# VibeLoggerログ
ls -lart logs/vibe/$(date +%Y%m%d)/

# 最新ログの内容確認
tail -20 logs/vibe/$(date +%Y%m%d)/*.jsonl | jq -r '.human_note'
```

### 4-4. 生成ファイル確認

```bash
# 7AI協調ディスカッションの出力確認
ls -la logs/7ai-discussions/

# 生成されたファイル確認（タスクによる）
git status
git diff
```

### 4-5. クリーンアップ確認

```bash
# Worktreeが自動削除されたか確認
git worktree list

# worktreesディレクトリが空か確認
ls -la worktrees/ 2>/dev/null || echo "worktreesディレクトリなし（正常）"
```

## トラブルシューティング

### 問題1: Worktreeが作成されない

```bash
# デバッグモードで実行
set -x
ENABLE_WORKTREES=true bash -c '
source scripts/orchestrate/orchestrate-multi-ai.sh
multi-ai-speed-prototype "テスト"
'
```

### 問題2: Worktreeが残ったまま

```bash
# 手動クリーンアップ
git worktree prune -v
rm -rf worktrees/

# ブランチ削除
git branch | grep "worktree/" | xargs -r git branch -D
```

### 問題3: "Mode: Legacy並列実行モード"と表示される

**原因:** ENABLE_WORKTREESが正しく設定されていない

**解決策:**
```bash
# 環境変数を確認
echo "$ENABLE_WORKTREES"

# 正しく設定
export ENABLE_WORKTREES=true
source scripts/orchestrate/orchestrate-multi-ai.sh
```

### 問題4: タイムアウトエラー

**原因:** AI CLIの応答が遅い

**解決策:**
```bash
# タイムアウトを延長
export CLAUDE_MCP_TIMEOUT=900s
export GEMINI_TIMEOUT=900s
ENABLE_WORKTREES=true bash -c '
source scripts/orchestrate/orchestrate-multi-ai.sh
multi-ai-speed-prototype "テスト"
'
```

### 問題5: 中断後にWorktreeが残る（Phase 0で修正済み）

**症状:** Ctrl+Cで中断した後、Worktreeが削除されない

**修正内容（2025-11-08）:**
- trap管理の改善（setup/teardown関数）
- リトライメカニズム追加（3回、自動--force）
- クリーンアップ成功率: 85.7% → 100%

**手動クリーンアップ（必要な場合）:**
```bash
# Worktree一覧確認
git worktree list

# 強制削除
git worktree remove worktrees/qwen --force
git worktree prune -v
rm -rf worktrees/

# ブランチ削除
git branch -D worktree/qwen/task-123
```

### 問題6: ChatDevワークフローでタイムアウト（Phase 1.1で発生）

**症状:** `multi-ai-chatdev-develop`でClaude CEO taskが300秒でタイムアウト

**原因:** ChatDev方式は5フェーズ（CEO→CTO→Programmers→Reviewer→Tester）で時間がかかる

**解決策:**
```bash
# Option A: 直接実装方式に切り替え（推奨）
# Option B: タイムアウト延長
export CLAUDE_MCP_TIMEOUT=600s

# Option C: タスクを小分けにする
```

## 成功基準

✅ **Phase 0.5 MVP検証:**
- ワークツリー作成時間: <5000ms
- ディスク使用量: <1000MB
- マージ時間: <10000ms
- 競合解決: 手動でOK
- クリーンアップ成功率: 100%

✅ **Phase 1 Multi-AI統合:**
- 7個のWorktreeが並列作成される
- 各AIが独立したWorktreeで実行
- ファイル競合が発生しない
- 実行完了後に自動クリーンアップ
- ログに"Git Worktrees統合モード有効"と表示

✅ **Phase 2 本番運用:**
- 全ワークフロー（full-orchestrate, speed-prototype, enterprise-quality, hybrid-development）で動作
- エラーハンドリングが適切
- ロールバック機能が動作
- パフォーマンスが許容範囲内

## Phase 0 修正内容（2025-11-08実装完了）

### 修正内容
1. **Trap管理の改善** (PR #1: commit 08bae0f)
   - `setup_worktree_cleanup_trap()`: EXIT/INT/TERM trapの設定
   - `teardown_worktree_cleanup_trap()`: 正常終了時のtrap解除
   - 4ワークフロー全てでtrapライフサイクル管理を実装

2. **リトライメカニズムの追加**
   - 最大3回のリトライ
   - 自動`--force`エスカレーション
   - クリーンアップ成功率: 85.7% → 100%

3. **レビュー完了**
   - Quad Review実施（10AI）: 8.5/10 APPROVED
   - セキュリティレビュー: リスクスコア 2/10 (LOW)
   - 技術的負債: 5項目（全てスコープ外）

### 影響を受けたファイル
- `scripts/orchestrate/lib/worktree-cleanup.sh`
- `scripts/orchestrate/lib/workflows-core.sh`

### 検証済みワークフロー
- ✅ multi-ai-speed-prototype
- ✅ multi-ai-full-orchestrate
- ✅ multi-ai-enterprise-quality
- ✅ multi-ai-hybrid-development

## Phase 1.2 自動テスト（2025-11-08実装）

### 全ワークフロー統合テスト

Phase 1.2で4つのワークフローを自動テストするスクリプトを実装しました。

```bash
# 全ワークフロー統合テスト実行
bash scripts/test-all-worktree-workflows.sh
```

**テスト内容:**
1. multi-ai-speed-prototype（2 worktrees expected）
2. multi-ai-full-orchestrate（7 worktrees expected）
3. multi-ai-enterprise-quality（3 worktrees expected）
4. multi-ai-hybrid-development（4 worktrees expected）

**テストレポート:**
- 実行時間測定
- Worktree作成数確認
- クリーンアップ検証
- 成功率計算
- レポート保存: `logs/worktree-integration-tests/test-report-TIMESTAMP.md`

**期待される結果:**
```
✅ All workflows passed. Worktree integration is working correctly.
Total Tests: 4
Passed: 4
Failed: 0
Success Rate: 100.0%
```

## 実行例

```bash
# 最小限のテスト（推奨）
cd /home/ryu/projects/multi-ai-orchestrium
git checkout main
git worktree prune -v && rm -rf worktrees/

ENABLE_WORKTREES=true bash -c '
source scripts/orchestrate/orchestrate-multi-ai.sh
multi-ai-speed-prototype "Worktree統合テスト: 各AIが自己紹介Markdownを作成"
'

# 実行完了後
git worktree list
cat worktrees/.worktree-state.ndjson 2>/dev/null
ls -la logs/7ai-discussions/
```

## 次のステップ

1. ✅ テスト2（MVP検証）で基本動作確認
2. ✅ テスト3-1（ステータス確認）でツール動作確認
3. ✅ テスト3-2（高速プロトタイプ）で実際のMulti-AI統合確認
4. ✅ テスト4（完全オーケストレーション）で本番レベル確認
5. 📝 結果をGIT_WORKTREES_INTEGRATION_REPORT.mdにまとめる

---

**作成日:** 2025-11-06
**バージョン:** 1.0
**対象:** Git Worktrees v2.0統合テスト
