# PIXEL PILFERER: Milestone D — Reusable Level Architecture & Multi-Level Progression Plan

## 背景・目的

Milestone B（単離物理移動プロトタイプ）および Milestone C（「The Broken Crossing」9ステップ受入バーティカルスライス）の検証完了により、Pixel Pilferer における連続物理レイヤー（`CharacterBody2D`）と離散タイル編集レイヤー（`PixelGlove` + `PlatformTileManager`）のハイブリッド結合の成立が実証された。

次の重要マイルストーンである **Milestone D — 再利用可能なレベルアーキテクチャ（Reusable Level Architecture）** の目的は、特定のテストシーンに依存した個別ハードコードを排し、あらゆるステージを均一かつ堅牢に運用できる**共通レベルアーキテクチャ**を構築することである。

具体的には以下を実現する：
1. **共通レベル基本クラス・コンポーネント (`PlatformerLevel`)**: プレイヤー、カメラ、動的タイル管理、出口ポータル、チェックポイント、ハザード、色付きソケット、回路ドア、収集要素を一元管理。
2. **安全なチェックポイント復元ポリシー**: プレイヤーがハザードに落下・死亡した際、チェックポイント到達時点の「プレイヤー座標」「手持ちブロック」「全動的ブロックの配置」「ソケット起動状態」「収集物状態」を完全かつ無矛盾に復元。
3. **色付きソケット・回路連動システム (`ChromaticSocket`, `LockedDoor`)**: 盗取した特定色ブロック（Neutral/Cyan/Amber/Magenta/Emerald）をソケットに挿入することで、対応するエネルギー防壁が開閉し、ゴールへの道が開くメカニクス。
4. **収集アイテム (`CollectibleShard`)**: ステージ探索を促進するデータシャード（1〜3個/面）。
5. **3つの独立した実証ステージの制作**:
   - `level_01_stolen_ledge.tscn`: 高台足場生成と基礎プラットフォーミング。
   - `level_02_hazard_leap.tscn`: ハザード棘、チェックポイント復元、クレバス空中足場架橋。
   - `level_03_conduit_gate.tscn`: シアン色ソケット、回路連動防壁解除、複合パズル。
6. **一貫したレベルリセット (R) と連続ステージ進行 (`LevelProgressionController`)**:
   - 個別レベル内での即時初期化。
   - レベルクリア時の次ステージ連続ロードと永続セーブ更新。

---

## 現状整理

- **エンジン・環境**: Godot 4.7.2 stable (`gl_compatibility` レンダラー、解像度 640x360、integer スケーリング、ピクセルスナップ有効)。
- **検証済みシステム**:
  - `player_platformer.gd`: CharacterBody2D 移動、可変ジャンプ、コヨーテタイム、ジャンプバッファ、シミュレーション入力機能。
  - `pixel_glove.gd`: 1ブロック制限、28px 射程、プレイヤー重複防止、照準インジケータ。
  - `platform_tile_manager.gd`: 即時 `StaticBody2D` 物理生成、色・ルーンメタデータ、スナップショット復元。
  - `exit_portal.gd`: 接触検知、アンロック制御。
  - `platformer_camera.gd`: 水平スムージング、ルックアヘッド、ピクセル丸め。
  - `test_platformer_movement.gd`: 10/10 PASS。
  - `test_broken_crossing.gd`: 9/9 PASS。
  - `run_tests.py`: 361/361 全既存トップダウン回帰テスト PASS。

---

## 設計

### ファイル構成

```
c:/project/pixelpilferer/
├── scripts/
│   └── platformer/
│       ├── platformer_level.gd         # [新規] 再利用可能なレベル基底クラス（コンポーネント統括、リセット、進行）
│       ├── checkpoint.gd               # [新規] チェックポイント（Area2D、状態スナップショット保存、視覚効果）
│       ├── hazard_zone.gd              # [新規] 棘・奈落等のハザード（Area2D、接触時に安全なリスポーン発火）
│       ├── collectible_shard.gd        # [新規] データシャード（Area2D、浮遊ボビング、収集カウント、復元対応）
│       ├── chromatic_socket.gd         # [新規] 色・ルーン付きソケット（タイル一致検知、回路信号送出）
│       ├── locked_door.gd              # [新規] ソケット連動防壁（StaticBody2D、衝突・描画の動的開閉）
│       ├── level_progression_controller.gd # [新規] 複数レベルの順次進行・リザルト・セーブ更新
│       ├── player_platformer.gd        # [改修] リスポーン・チェックポイント座標対応の強化
│       └── platform_tile_manager.gd    # [改修] 動的スナップショット（引数付き）の完全復元メソッド追加
├── scenes/
│   └── platformer/
│       ├── components/
│       │   ├── checkpoint.tscn         # [新規] チェックポイントコンポーネントシーン
│       │   ├── hazard_zone.tscn        # [新規] ハザードコンポーネントシーン
│       │   ├── collectible_shard.tscn  # [新規] 収集シャードコンポーネントシーン
│       │   ├── chromatic_socket.tscn   # [新規] クロマティックソケットコンポーネントシーン
│       │   └── locked_door.tscn        # [新規] ロックドアコンポーネントシーン
│       └── levels/
│           ├── level_01_stolen_ledge.tscn # [新規] 実証ステージ 1: 足場作成と高台登頂
│           ├── level_02_hazard_leap.tscn  # [新規] 実証ステージ 2: 棘ハザードとチェックポイント復元
│           └── level_03_conduit_gate.tscn # [新規] 実証ステージ 3: シアンソケットと回路防壁解除
├── scripts/
│   └── test/
│       └── test_platformer_milestone_d.gd # [新規] Milestone D 3段階検証自動テストランナー
└── _/local-plans/
    └── milestone-d-reusable-level-architecture.md # 本計画ファイル
```

### 仕様

#### 1. `PlatformerLevel` (再利用可能なレベル基本クラス)
- **統括責任**:
  - `TileMapLayer`: 静的床・壁・プラットフォーム地形。
  - `PlatformTileManager`: 動的ブロック管理。
  - `PlayerPlatformer`: プレイヤー制御。
  - `PlatformerCamera`: 追従カメラ。
  - `ExitPortal`: レベルクリア判定。
  - `Checkpoints`: 登録されたすべての `Checkpoint`。
  - `Hazards`: 登録されたすべての `HazardZone`。
  - `Collectibles`: 登録されたすべての `CollectibleShard`。
  - `Sockets`: 登録されたすべての `ChromaticSocket`。
  - `Doors`: 登録されたすべての `LockedDoor`。
- **スナップショット復元ポリシー (`CheckpointSnapshot`)**:
  - スナップショット構造:
    ```gdscript
    {
        "player_pos": Vector2,
        "carried_block": Variant, # null or Dictionary
        "blocks": Array[Dictionary], # [{cell: Vector2i, color: int, symbol: String}]
        "collected_shards": Array[String], # 収集済みシャードID
        "satisfied_sockets": Array[String] # 起動済みソケットID
    }
    ```
  - **初期スナップショット (`initial_snapshot`)**: レベル開始時（Turn 0）の状態。
  - **チェックポイントスナップショット (`checkpoint_snapshot`)**: チェックポイント到達時の状態。
  - **ハザード接触時**: `checkpoint_snapshot` へ巻き戻し、プレイヤーをチェックポイント位置へ再配置。
  - **レベルリセット (`R` キー)**: `initial_snapshot` へ巻き戻し、プレイヤーを初期スタート地点へ再配置。
- **クリア条件 (`check_exit_condition`)**:
  - レベル内の全「必須ソケット」が満たされている場合のみ `ExitPortal.is_locked = false` となる。
  - 必須ソケット数が 0 の場合は常時アンロック。

#### 2. `Checkpoint`
- `Area2D` (Collision Layer 4, Mask 1: Player)。
- 未到達時は非アクティブ（青白い微光）、到達時にアクティブ（エメラルド色発光＋パルス）。
- 一度アクティブになったチェックポイントは、再進入しても二重保存しない。
- `level.on_checkpoint_reached(self)` を呼び出す。

#### 3. `HazardZone`
- `Area2D` (Collision Layer 4, Mask 1: Player)。
- 棘や奈落など、プレイヤーが触れた瞬間に `level.on_player_hit_hazard()` を呼ぶ。
- プレイヤーの死亡処理（速度リセット、位置復元、スナップショット復元）を安全に実行。

#### 4. `CollectibleShard`
- `Area2D` (Collision Layer 4, Mask 1: Player)。
- 浮遊ボビングアニメーション（`sin(time * 4.0) * 3.0`）。
- 接触時に `collected` シグナルを発火し、自身を非表示・コリジョン無効化。
- チェックポイント復元時、チェックポイント保存前に未取得だった場合は再出現。

#### 5. `ChromaticSocket` & `LockedDoor`
- `ChromaticSocket`:
  - 属性: `socket_id: String`, `required_color: int` (1: Cyan 等), `grid_cell: Vector2i`。
  - `tile_manager.block_placed` および `block_stolen` を監視。
  - `grid_cell` に `required_color` と一致するブロックが存在するとき `is_satisfied = true`。
  - 一致しないブロックが置かれた場合は `is_satisfied = false`。
  - 状態変化時に `satisfaction_changed(bool)` シグナルを発火。
- `LockedDoor`:
  - `StaticBody2D` (Collision Layer 2: Solid Terrain, Mask 1: Player)。
  - `socket_id` にバインド。ソケットが satisfied になると `is_open = true`（コリジョン無効化、透明化）。
  - ソケットからブロックが抜かれると再ロック（コリジョン有効化、可視化）。

#### 6. 3 つの検証レベルの設計
1. **Level 1 ("The Stolen Ledge")**:
   - 目的: 基本的な足場作成と踏み台ジャンプ。
   - 壁の前に 1 個の Neutral ブロック。
   - 4 タイル高（64px）の壁。プレイヤーのジャンプ力（40.8px）では直登不可。
   - 壁の手前にブロックを置くことで 2 段ジャンプ可能となり登頂。
   - シャード 1 個、必須ソケット 0。
2. **Level 2 ("The Hazard Leap")**:
   - 目的: 棘ハザード、チェックポイント、空中足場架橋。
   - 安全な手前エリアに Cyan ブロック。
   - 中間地点にチェックポイント。
   - その先に 5 タイル幅の棘ピット（跳躍可能限界 5.44 タイルだがマージンなしでは極めて危険）。
   - 空中グリッドにブロックを配置して中間足場を作成し、安全横断。
   - 落下テスト: 棘に触れるとチェックポイントへ安全に復帰することを確認。
   - シャード 2 個、必須ソケット 0。
3. **Level 3 ("The Conduit Gate")**:
   - 目的: シアンソケット、回路防壁、複合パズル。
   - 高台の壁に Cyan ブロックが埋まっている。
   - 出口の手前に LockedDoor（エネルギー防壁）が立ちはだかる。
   - 床に Cyan ソケットが存在。
   - ブロックを盗取し、ソケットに配置すると防壁が解除され、出口へ到達可能。
   - シャード 3 個、必須ソケット 1。

---

## 受入基準

- **AC 1 (共通レベル基底クラス)**: `platformer_level.gd` が上記コンポーネント（チェックポイント、ハザード、シャード、ソケット、ドア、リセット）を統一的に管理し、レベル固有の場当たり的コードが存在しないこと。
- **AC 2 (安全なチェックポイント復元)**: ハザード接触時、直前のチェックポイントでのブロック配置・手持ち・シャード・ソケット状態が 100% 正確に復元され、物理コリジョンの不整合やキャラのスタックが発生しないこと。
- **AC 3 (3 レベル連続実行と検証)**: Level 1、Level 2、Level 3 の 3 ステージが同一のアーキテクチャ上で動作し、`test_platformer_milestone_d.gd` による自動テストで Level 1 静的検証、Level 2 離散編集・復元検証、Level 3 物理トラバーサル検証が全項目 PASS すること。
- **AC 4 (レベル連続進行とセーブ連動)**: Level 1 クリア → Level 2 クリア → Level 3 クリアと自動遷移し、各レベルの完了およびシャード収集数が `ProgressService` に安全に記録されること。
- **AC 5 (後退ゼロ)**: 既存の全テスト（Milestone B、Milestone C、Phase 1〜9 トップダウン 361 テスト）が 100% 成功し続けること。

---

## 実装ステップ

### Phase 1: コアコンポーネントの実装
1. `scripts/platformer/platform_tile_manager.gd` に `capture_snapshot() -> Array` と `restore_snapshot(snapshot: Array) -> void` を追加。
2. `scripts/platformer/checkpoint.gd` および `scenes/platformer/components/checkpoint.tscn` の実装。
3. `scripts/platformer/hazard_zone.gd` および `scenes/platformer/components/hazard_zone.tscn` の実装。
4. `scripts/platformer/collectible_shard.gd` および `scenes/platformer/components/collectible_shard.tscn` の実装。
5. `scripts/platformer/chromatic_socket.gd` および `scenes/platformer/components/chromatic_socket.tscn` の実装。
6. `scripts/platformer/locked_door.gd` および `scenes/platformer/components/locked_door.tscn` の実装。

### Phase 2: 再利用可能なレベル基本クラスの実装
1. `scripts/platformer/platformer_level.gd` の実装（初期化、シグナル結合、スナップショット管理、ハザード処理、リセット処理、出口制御）。
2. `scripts/platformer/level_progression_controller.gd` の実装（レベル順次ロード、進行度保存、UI 通知）。

### Phase 3: 3 つの実証レベルの構築
1. `scenes/platformer/levels/level_01_stolen_ledge.tscn` の構築（Level 1: 踏み台ジャンプ、シャード 1）。
2. `scenes/platformer/levels/level_02_hazard_leap.tscn` の構築（Level 2: 棘、チェックポイント、空中足場、シャード 2）。
3. `scenes/platformer/levels/level_03_conduit_gate.tscn` の構築（Level 3: シアンソケット、ロックドア、シャード 3）。

### Phase 4: 自動検証テストランナーの実装と実行
1. `scripts/test/test_platformer_milestone_d.gd` の作成。
   - Test Suite 1: Level 1 静的データ完全性検証。
   - Test Suite 2: チェックポイント復元・ハザードリスポーン・ソケット開閉検証。
   - Test Suite 3: 3 レベル連続物理トラバーサル＆クリア検証。
   - Test Suite 4: 進行度永続セーブ検証。
2. Godot CLI ヘッドレス実行による実証確認。
3. 既存回帰テスト（Milestone B, C, Python テストスイート）の実行。

### Phase 5: レビュー・文書化・ローカル Git コミット
1. コード品質レビュー（静的型付け、メモリリーク防止）。
2. `docs/PROGRESS.md` の更新。
3. ローカル Git コミットの作成。

---

## 受入基準トレーサビリティ

| 受入基準 | 実現するタスク |
|---|---|
| AC 1 (共通レベル基底クラス) | Phase 1: 1〜6, Phase 2: 1 |
| AC 2 (安全なチェックポイント復元) | Phase 1: 1〜3, Phase 2: 1, Phase 4: 1 |
| AC 3 (3 レベル連続実行と検証) | Phase 3: 1〜3, Phase 4: 1, 2 |
| AC 4 (レベル連続進行とセーブ連動) | Phase 2: 2, Phase 4: 1 |
| AC 5 (後退ゼロ) | Phase 4: 3 |

---

## 検証方法

1. **Milestone D 自動テスト実行**:
   ```powershell
   & "C:\Users\Dell\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --script res://scripts/test/test_platformer_milestone_d.gd
   ```
2. **Milestone B & C 回帰確認**:
   ```powershell
   & "C:\Users\Dell\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --script res://scripts/test/test_platformer_movement.gd
   & "C:\Users\Dell\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --script res://scripts/test/test_broken_crossing.gd
   ```
3. **マスター回帰テスト実行**:
   ```powershell
   python tests/run_tests.py
   ```
