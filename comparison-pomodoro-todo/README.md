# 📊 ポモドーロTodoアプリ 比較実験

同じ要件定義書を使って、3つの異なるアプローチで実装した結果を比較する実験です。

---

## 🎯 実験の目的

**「複数AI協調 vs 単独AI」どちらが優れているか？**

同じ要件で実装して、以下を比較します：

| 比較項目 | 説明 |
|---------|------|
| **速度** | 実装にかかった時間 |
| **品質** | コードの品質、バグの有無 |
| **完成度** | 機能の実装度合い |
| **パフォーマンス** | 動作速度、メモリ効率 |
| **UX** | 使いやすさ、デザイン |

---

## 🧪 実験方法

### 入力（同じ）
すべての方式で**まったく同じプロンプト**を使用：
- [`prompt.txt`](./prompt.txt) - ポモドーロTodoアプリの要件定義書

### 出力（異なる）
3つの異なる実装方式：

#### 1️⃣ Multi-AI（複数AI協調）
```bash
cd 1-multi-ai
./run.sh
````

- 複数のAI（Claude, Gemini, Qwen, Amp）が協調
- 各AIが専門分野を担当
- 並列実行で高速化

#### 2️⃣ Claude単独

```bash
cd 2-claude-solo
./run.sh
```

- Claudeだけで全機能を実装

#### 3️⃣ Codex単独

```bash
cd 3-codex-solo
./run.sh
```

- Codexだけで全機能を実装

---

## 📁 ディレクトリ構成

```
comparison-pomodoro-todo/
├── README.md                    # ← このファイル
├── requirements.md              # 要件定義書（参照用）
├── prompt.txt                   # 実験用プロンプト（requirements.mdと同一）
│
├── 1-multi-ai/                  # 複数AI協調
│   ├── run.sh                   # 実行スクリプト
│   ├── execution-log.txt        # 詳細ログ
│   ├── execution-log-summary.md # サマリー
│   ├── timeline.md              # タイムライン
│   ├── ai-collaboration.md      # AI協調の詳細
│   ├── metrics.json             # 計測データ
│   ├── screenshots/             # スクリーンショット
│   └── output/                  # 生成されたアプリ
│       ├── index.html
│       ├── app.js
│       └── style.css
│
├── 2-claude-solo/               # Claude単独
│   ├── run.sh
│   ├── execution-log.txt
│   ├── metrics.json
│   ├── screenshots/
│   └── output/
│       ├── index.html
│       ├── app.js
│       └── style.css
│
├── 3-codex-solo/                # Codex単独
│   ├── run.sh
│   ├── execution-log.txt
│   ├── metrics.json
│   ├── screenshots/
│   └── output/
│       ├── index.html
│       ├── app.js
│       └── style.css
│
└── comparison-report.md         # 📊 詳細な比較レポート
```

---

## 🚀 実験の実行方法

### 前提条件

```bash
# Multi-AI Orchestriumフレームワークのインストール
git clone https://github.com/yourusername/multi-ai-orchestrium.git
cd multi-ai-orchestrium
source scripts/orchestrate/orchestrate-multi-ai.sh
```

### 実験の実行

#### 1. Multi-AI版を実行

```bash
cd examples/comparison-pomodoro-todo/1-multi-ai
./run.sh

# または手動で
multi-ai-chatdev-develop "$(cat ../prompt.txt)"
```

#### 2. Claude単独版を実行

```bash
cd ../2-claude-solo
./run.sh

# または手動で
claude "$(cat ../prompt.txt)"
```

#### 3. Codex単独版を実行

```bash
cd ../3-codex-solo
./run.sh

# または手動で
codex "$(cat ../prompt.txt)"
```

#### 4. 比較レポートを確認

```bash
cd ..
cat comparison-report.md
```

---

## 📊 結果の概要

実験完了後、以下のような比較データが得られます：

### 速度比較（例）

|方式|所要時間|短縮率|
|---|---|---|
|Multi-AI|2分15秒|-|
|Claude単独|3分42秒|+64%|
|Codex単独|4分18秒|+91%|

### 品質比較（例）

|方式|総合点|検出バグ数|修正バグ数|
|---|---|---|---|
|Multi-AI|96/100|6件|6件|
|Claude単独|75.5/100|3件|2件|
|Codex単独|60/100|1件|1件|

詳細は [`comparison-report.md`](https://claude.ai/chat/comparison-report.md) を参照してください。

---

## 📖 各ログファイルの説明

### `execution-log.txt`

- 最も詳細なログ（生ログ）
- すべての実行ステップを記録
- デバッグ時に便利

### `execution-log-summary.md`

- 見やすくフォーマットされたログ
- 各フェーズの概要と結果
- 検出された問題と修正内容
- **最初に読むべきログ**

### `timeline.md`

- 時系列で実行過程を表示
- 各AIがいつ何をしたか
- 並列実行の様子が分かる

### `ai-collaboration.md`（Multi-AIのみ）

- AIごとの役割と特徴
- 協調パターンの詳細
- 生成されたコード例

### `metrics.json`

- 機械可読な計測データ
- 時間、行数、バグ数など
- 自動分析やグラフ生成に使用

---

## 🎓 学べること

### 1. 複数AI協調の効果

- 並列実行による高速化
- 専門分野の分担による品質向上
- 問題検出と自動修正の仕組み

### 2. 各AIの特徴

- Claudeの強み：要件定義、JavaScript実装、レビュー
- Geminiの強み：アーキテクチャ設計、統合テスト
- Qwenの強み：HTML構造、アクセシビリティ
- Ampの強み：CSSデザイン、アニメーション

### 3. 実装の違い

- タイマーの精度実装
- エラーハンドリングの違い
- コード構造の違い
- UXへの配慮の違い

---

## 🔧 カスタマイズ方法

### 要件を変更したい場合

1. `requirements.md` を編集
2. 同じ内容を `prompt.txt` にコピー
3. 各方式で再実行

### 評価基準を変更したい場合

1. `requirements.md` の「評価基準」セクションを編集
2. `comparison-report.md` のテンプレートを更新

### 他のサンプルアプリで実験したい場合

1. 新しい要件定義書を作成
2. 同じディレクトリ構成で新しい比較実験フォルダを作成
3. `run.sh` をコピーして使用

---

## 📝 実験の再現性

この実験は完全に再現可能です：

1. **同じプロンプト**: `prompt.txt` を使用
2. **同じ環境**: 実行環境の情報を `metrics.json` に記録
3. **同じ評価基準**: `requirements.md` で明確に定義

実験を再実行すれば、同じ結果が得られるはずです。

---

## 🤝 コントリビューション

この比較実験の改善案があれば、ぜひIssueやPRでお知らせください：

- 新しい評価項目の追加
- 他のAIとの比較
- 異なるアプリでの比較実験
- 評価基準の改善

---

## 📄 ライセンス

この比較実験および生成されたコードはMIT Licenseで提供されています。

---

## 📚 関連ドキュメント

- [要件定義書](https://claude.ai/chat/requirements.md) - 詳細な仕様
- [比較レポート](https://claude.ai/chat/comparison-report.md) - 実験結果の詳細
- [Multi-AIのログ](https://claude.ai/chat/1-multi-ai/execution-log-summary.md)
- [Claudeのログ](https://claude.ai/chat/2-claude-solo/execution-log.txt)
- [Codexのログ](https://claude.ai/chat/3-codex-solo/execution-log.txt)

---

**実験バージョン**: 1.0  
**実験日**: 2025-10-23  
**フレームワーク**: Multi-AI Orchestrium v1.0
