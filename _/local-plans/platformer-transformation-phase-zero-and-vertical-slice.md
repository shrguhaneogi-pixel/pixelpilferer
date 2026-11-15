# PIXEL PILFERER: 2D Platformer Architecture Migration & Vertical Slice Plan

## 背景・目的

PIXEL PILFERER は現在、2D トップダウン・ターン制グリッドパズルゲームとしてバージョン 1.0.0 が完成・検証・リリースされている（全 1,227 テスト通過）。
本タスクの目的は、本作をマリオ風の操作感・明瞭さ・ペーシング・レベル構造を備えつつ、固有メカニクス「Pixel Glove（環境ブロックの抜き取り・携行・足場としての空中設置）」を中核とした**オリジナル 2D サイドスクロール・パズルプラットフォーマー**へと段階的に移行することである。

これは単なる見た目の横視点化ではなく、**離散ターン制グリッドシミュレーションから連続物理＋離散タイル編集のハイブリッドアーキテクチャへの根本的なゲームプレイ移行**である。
本計画では、Phase Zero（詳細設計・移行仕様・リスク管理・テスト計画）を策定し、Milestone B（単離テストシーンでの CharacterBody2D 移動プロトタイプ）および Milestone C（「The Broken Crossing」バーティカルスライス）を段階的に実証・検証する手順を定義する。

## 現状整理

- **エンジン・環境**: Godot 4.7.2 stable (`gl_compatibility` レンダラー、解像度 640x360、integer スケーリング、ピクセルスナップ有効)。
- **保持・再利用可能なシステム**:
  - `ProgressService.gd`: 二重セーブ永続化、暗黙的破損バックアップ復元、設定・メダル管理。
  - `AudioService.gd`: マスター/BGM/SE ボリューム、ピッチ変調付きシンセサイズ音源。
  - `SettingsMenu.gd`, `ConfirmModal.gd`, `CreditsModal.gd`: UI モーダルコンポーネント。
  - `Constants.gd`: 色定数（Cyan, Amber, Magenta, Emerald, Neutral）および色覚特性対応ルーン（`◆`, `▲`, `■`, `●`, `✚`）。
- **リファクタリング・置換対象**:
  - `BoardModel.gd` / `GameRules.gd`: 4 方向ターン制 $(S_t, \text{Action}) \to S_{t+1}$ は連続ジャンプ曲線・重力・速度を扱えないため、物理層と分離。
  - `PlayerView.gd`: トップダウンのボビング描画からサイドビュー用のアニメーション・向き制御へ刷新。
  - `TileMapLayer`: 16x16 の動的衝突判定更新・同期が必要。
  - トップダウン BFS ソルバー (`puzzle_solver.gd`): 離散グリッド探索ではジャンプ可能距離や空中動作を検証できないため、静的検証＋スクリプト化された物理トラバーサル検証に分割。
- **Git リファレンス**: `db57e05` (v1.0.0 リリース点)。

## 設計

### ファイル構成

```
c:/project/pixelpilferer/
├── docs/
│   ├── PLATFORMER_DESIGN.md        # [新規] 物理・移動・ジャンプ・Pixel Glove・カメラ仕様書
│   ├── PLATFORMER_MIGRATION.md     # [新規] システム別移行分類（保持/改修/置換/廃止）
│   ├── PLATFORMER_RISK_REGISTER.md # [新規] 物理タイル衝突同期・頭上衝突・カメラジッター等のリスク台帳
│   └── PLATFORMER_TEST_PLAN.md     # [新規] 3 段階検証戦略（Level 1 静的 / Level 2 編集 / Level 3 物理）
├── scenes/
│   └── test/
│       ├── platformer_prototype.tscn # [新規] Milestone B 移動プロトタイプ検証シーン
│       └── broken_crossing.tscn      # [新規] Milestone C バーティカルスライス受入シーン
├── scripts/
│   ├── platformer/
│   │   ├── player_platformer.gd    # [新規] CharacterBody2D 操作（加減速、可変ジャンプ、コヨーテ、バッファ）
│   │   ├── pixel_glove.gd          # [新規] 1 ブロック保持制限、照準インジケータ、盗取・設置ロジック
│   │   ├── platform_tile_manager.gd# [新規] 動的ブロック同期、衝突保証、浮遊足場生成
│   │   └── platformer_camera.gd    # [新規] 水平追従、ルックアヘッド、垂直デッドゾーン
│   └── test/
│       ├── test_platformer_movement.gd # [新規] Milestone B 自動移動・物理アサーションランナー
│       └── test_broken_crossing.gd     # [新規] Milestone C 9 ステップ受入シナリオ自動検証ランナー
└── _/local-plans/
    └── platformer-transformation-phase-zero-and-vertical-slice.md # 本計画ファイル
```

### 仕様

1. **連続物理レイヤー (`CharacterBody2D`)**:
   - `_physics_process()` 内で `move_and_slide()` を実行。
   - 最大水平速度: `120 px/s`、加速度: `800 px/s²`、減速度/摩擦: `1000 px/s²`。
   - 重力: `600 px/s²`、最大落下速度（ターミナルベロシティ）: `320 px/s`。
   - ジャンプ初速: `-220 px/s`（約 2.5 タイル分のジャンプ高）。
   - 可変ジャンプ: ジャンプキー離下時に上向き速度を半減（ショートジャンプ可能）。
   - コヨーテタイム: `0.08 s` (80ms)、ジャンプ先行入力バッファ: `0.10 s` (100ms)。
2. **離散タイル編集レイヤー (`PixelGlove`)**:
   - 保持容量: 厳密に 1 個。
   - インタラクション射程: プレイヤー中心から 28 ピクセル（約 1.75 タイル）。
   - 盗取条件: 射程内、手持ちが空、指定された可動ブロック（Neutral/Color）。
   - 設置条件: 射程内、手持ちあり、対象セルが空（`EMPTY` / `AIR`）、不透過静止地形と重ならない、プレイヤー自身のコリジョンボックスと重ならない。
   - 物理同期: 設置されたブロックは StaticBody2D または TileMapLayer 衝突シェイプとして即座に物理空間に登録され、同フレーム内で上に乗ることが可能。重力で落下せず、空中固定足場となる。
3. **9 ステップ受入シナリオ（「The Broken Crossing」）**:
   1. Pip は安全な足場から開始し、左右に走行可能。
   2. 応答性の高い操作で高台のレッジへジャンプ登頂。
   3. 壁面にあるマークされた可動ブロックを盗取。
   4. 抜き取られた壁面は通り抜け可能な開口部となり、衝突が崩壊しない。
   5. ブロックを抱えて途切れた橋（クレバス）へ移動。
   6. 空中グリッドへブロックを設置し、堅牢な浮遊足場を生成。
   7. 設置した足場へ飛び乗り、クレバスを安全に横断。
   8. ゴールポータルへ到達し、正常にクリア状態へ移行。
   9. リスタート（R キー）により、初期状態（壁面のブロック、空洞のクレバス）へ完全に復元。

## 受入基準

- **AC 1 (Phase Zero 文書化)**: `docs/PLATFORMER_DESIGN.md`、`docs/PLATFORMER_MIGRATION.md`、`docs/PLATFORMER_RISK_REGISTER.md`、`docs/PLATFORMER_TEST_PLAN.md` が作成され、全アーキテクチャが明文化されていること。
- **AC 2 (Milestone B 物理プロトタイプ)**: `platformer_prototype.tscn` において、`test_platformer_movement.gd` がヘッドレス CLI で実行され、水平加減速・ジャンプ・可変高度・コヨーテタイム・先行入力・壁衝突が 100% 合格すること。
- **AC 3 (Milestone C バーティカルスライス)**: `broken_crossing.tscn` において、`test_broken_crossing.gd` が実行され、上記 9 ステップの受入シナリオがすべて PASS すること。
- **AC 4 (後退ゼロ・回帰検証)**: 既存の v1.0.0 トップダウンテスト群が破壊されず、影響を受けないこと。

## 実装ステップ

### Phase 0: アーキテクチャ調査と仕様策定
1. `docs/PLATFORMER_DESIGN.md` の作成（物理定数、ジャンプ曲線、Glove 仕様、カメラ仕様）。
2. `docs/PLATFORMER_MIGRATION.md` の作成（既存コード分類：保持・改修・置換・廃止）。
3. `docs/PLATFORMER_RISK_REGISTER.md` の作成（衝突同期遅延、すり抜け、頭上衝突、セーブ復元等のリスクと対策）。
4. `docs/PLATFORMER_TEST_PLAN.md` の作成（3 段階検証戦略と自動化シナリオ）。

### Phase 1: Milestone B — 単離プラットフォーマー移動プロトタイプ
1. `scripts/platformer/player_platformer.gd` の実装（CharacterBody2D、加減速、可変ジャンプ、コヨーテ、バッファ）。
2. `scripts/platformer/platformer_camera.gd` の実装（水平追従、先行注視、ピクセル整数丸め）。
3. `scenes/test/platformer_prototype.tscn` の構築（地面、ジャンプ台、隙間、段差）。
4. `scripts/test/test_platformer_movement.gd` の作成と CLI ヘッドレス実行・検証。

### Phase 2: Milestone C — Pixel Glove バーティカルスライス「The Broken Crossing」
1. `scripts/platformer/platform_tile_manager.gd` の実装（動的ブロック管理、即時物理コリジョン同期、色属性）。
2. `scripts/platformer/pixel_glove.gd` の実装（照準レイキャスト、盗取、1 個制限、足場設置、プレイヤー重複拒否）。
3. `scenes/test/broken_crossing.tscn` の構築（高台、壁面ブロック、渡れないクレバス、ゴールポータル、リセット）。
4. `scripts/test/test_broken_crossing.gd` の作成と 9 ステップ受入自動テスト実行・検証。

### Phase 3: レビュー・検証・Git コミット
1. コード品質レビュー（静的型付け、不要ログ除去、安全な Tween/タイマー）。
2. 全体リグレッションテストの実行。
3. ローカル Git コミットの作成。

## 受入基準トレーサビリティ

| 受入基準 | 実現するタスク |
|---|---|
| AC 1 (Phase Zero 文書化) | Phase 0: タスク 1, 2, 3, 4 |
| AC 2 (Milestone B 物理プロトタイプ) | Phase 1: タスク 1, 2, 3, 4 |
| AC 3 (Milestone C バーティカルスライス) | Phase 2: タスク 1, 2, 3, 4 |
| AC 4 (後退ゼロ・回帰検証) | Phase 3: タスク 1, 2, 3 |

## 並列実行戦略

- ドキュメント策定（Phase 0）は単一の一貫した基準で作成。
- Milestone B（物理移動）と動的タイル管理（Tile Manager）の基礎設計は直交しており、独立してテスト可能。

## 検証方法

1. **Phase 0 文書検証**:
   - `docs/` 内の 4 ファイルが存在し、数式・定数・移行分類・リスク対策が網羅されていることを確認。
2. **Milestone B 物理テスト**:
   - `Godot_v4.7.2-stable_win64_console.exe --headless --script res://scripts/test/test_platformer_movement.gd` を実行し、全アサーション合格を確認。
3. **Milestone C 9 ステップ検証**:
   - `Godot_v4.7.2-stable_win64_console.exe --headless --script res://scripts/test/test_broken_crossing.gd` を実行し、0/9 から 9/9 への完全合格を確認。
4. **既存テスト回帰確認**:
   - `python tests/run_tests.py` を実行し、既存テスト群に破壊がないことを確認。

## 将来の拡張

- Milestone D: 再利用可能なレベルアーキテクチャ（チェックポイント、ハザード、色付きソケット、回路）。
- Milestone E: 4 つのワールド（The Stolen Street, The Broken Bridges, The Forgotten Vault, The Chromatic Core）のピクセルアート・パララックス・オーディオ。
- Milestone F: 20 レベルキャンペーンの設計・検証。
- Milestone G: メニュー・セーブ統合・エクスポート。
