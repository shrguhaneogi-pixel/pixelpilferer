# Pixel Pilferer 全体実装・検証計画

## 背景・目的

Pixel Pilferer は、Godot 4.7.2 stable および GDScript を対象とした 2D トップダウン・ピクセルアート・パズルアドベンチャーゲームである。
プレイヤーは主人公 Pip となり、Pixel Glove を用いてグリッド世界からブロックを「盗み」、所持し、別のセルへ配置することで道を切り拓く。
本タスクの目的は、描画やフレームレートから完全に独立した決定論的ドメインモデル、全 20 ステージ（4 チャプター × 5 ステージ）、全ステージの BFS 解法検証、リッチなピクセルアート表現、アンドゥ・リスタート、サウンド、および Web/デスクトップ向けのエクスポート基盤を自律的に構築・検証することである。

## 現状整理

- **環境:** Windows 10/11 (AMD64)、Git、Python 3.14、Node.js / npm 利用可能。
- **Godot バイナリ:** システム PATH および探索パス上に未インストール（`verify_environment.ps1` で確認）。そのため、Godot 4.7 準拠の GDScript コードベース（`RefCounted`, `TileMapLayer`, `Vector2i`）と並行して、即時検証可能なリファレンス検証ハーネス（Python）を整備し、論理モデル・全 20 面の BFS 解法・アンドゥ検証を 100% 数学的に保証する。
- **リポジトリ構成:**
  - `project.godot`（320x180、整数スケール、Nearest フィルタ、入力マッピング定義済）
  - `export_presets.cfg`（Windows Desktop / Single-threaded Web 定義済）
  - `docs/`（`GAME_DESIGN.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `TEST_PLAN.md`, `PROGRESS.md` 整備済）
  - `.agents/skills/godot-4-7-gameplay/`（Godot 4.7 規約・リファレンス文書配備済）

## 設計

### ファイル構成

```text
c:/project/pixelpilferer/
├── project.godot
├── export_presets.cfg
├── docs/
│   ├── GAME_DESIGN.md
│   ├── ARCHITECTURE.md
│   ├── DECISIONS.md
│   ├── TEST_PLAN.md
│   └── PROGRESS.md
├── scripts/
│   ├── core/
│   │   ├── constants.gd
│   │   ├── board_state.gd
│   │   ├── game_rules.gd
│   │   ├── history_manager.gd
│   │   ├── level_data.gd
│   │   └── puzzle_solver.gd
│   ├── view/
│   │   ├── level_view.gd
│   │   ├── player_view.gd
│   │   ├── block_view.gd
│   │   ├── pixel_camera.gd
│   │   └── audio_manager.gd
│   └── ui/
│       ├── hud.gd
│       ├── title_screen.gd
│       ├── chapter_select.gd
│       └── settings_menu.gd
├── data/
│   └── levels/
│       ├── ch1_levels.json
│       ├── ch2_levels.json
│       ├── ch3_levels.json
│       └── ch4_levels.json
├── assets/
│   ├── sprites/
│   │   ├── pip.png
│   │   ├── blocks.png
│   │   ├── tileset.png
│   │   ├── sockets.png
│   │   ├── exit_portal.png
│   │   └── icon.png
│   └── sfx/
│       ├── sfx_steal.wav
│       ├── sfx_place.wav
│       ├── sfx_socket.wav
│       ├── sfx_step.wav
│       ├── sfx_undo.wav
│       └── sfx_win.wav
├── tests/
│   ├── test_runner.gd
│   ├── test_domain_model.py
│   ├── test_puzzle_solver.py
│   └── run_tests.py
└── _/local-plans/
    └── pixel-pilferer-foundation-and-gameplay.md
```

### 仕様

1. **ドメインモデル:**
   - 座標系: `Vector2i`
   - アクション: `MOVE_NORTH`, `MOVE_EAST`, `MOVE_SOUTH`, `MOVE_WEST`, `INTERACT_NORTH`, `INTERACT_EAST`, `INTERACT_SOUTH`, `INTERACT_WEST`, `UNDO`, `RESTART`
   - タイル: `FLOOR`, `VOID`, `WALL`, `SOCKET`, `EXIT`
   - ブロック属性: `NEUTRAL`, `CYAN`, `AMBER`, `MAGENTA`, `EMERALD`
   - 状態遷移関数: $S_{t+1} = f(S_t, Action)$（副作用なし、不変スナップショット生成）
2. **ルール不変条件:**
   - 所持可能ブロック数は最大 1 個
   - 斜め移動・斜めインタラクト不可
   - 床上のブロックは障害物、穴（VOID）上のブロックは橋（歩行可能）
   - 橋ブロックは穴から盗み戻すことが可能（穴に戻る）
   - 壁・自分・他ブロック・ゴールへのブロック配置は不可
   - 全ソケット満たされた状態でのみゴールがアクティブ化
3. **解法検証:**
   - BFS アルゴリズムにより、全 20 面の最短解を導出・検証し、手詰まりのないことを証明

## 受入基準

1. **基本ルール検証:** 全ての移動・ブロック窃盗・配置・橋架橋・ソケット適合ルールがテストで 100% パスすること（コマンド: `python tests/run_tests.py`）。
2. **アンドゥ・リスタートの完全性:** 任意の手順後に Undo で正確に 1 手前の状態に戻り、Restart で初期状態 $S_0$ に戻ること。
3. **全 20 面のパズル解法証明:** 全 20 面（Ch1: 5面, Ch2: 5面, Ch3: 5面, Ch4: 5面）が BFS ソルバーによって検証され、最短手順が特定されていること。
4. **Godot 4.7 準拠コード:** 全 GDScript スクリプトが厳格な静的型付け、`TileMapLayer` 構造、`Callable` シグナルを用いていること。
5. **ピクセルアートアセット:** 16x16 スプライト（Pip、ブロック各種、ソケット、タイル、ポータル、アイコン）がリポジトリ内に生成・配備されていること。
6. **UI・オーディオ・進行状況保存:** HUD、タイトル画面、チャプター選択、設定（音量・Reduced Motion）、セーブデータ管理が実装されていること。

## 実装ステップ

### Phase 1: ドキュメントおよびプロジェクト基盤（完了）
1. `docs/` に `GAME_DESIGN.md`, `ARCHITECTURE.md`, `DECISIONS.md`, `TEST_PLAN.md`, `PROGRESS.md` を作成。
2. `project.godot` および `export_presets.cfg` を設定。
3. 環境検証スクリプトを実行し、現状を把握。

### Phase 2: 決定論的ドメインモデルとテストランナーの実装
1. `scripts/core/constants.gd` / `scripts/core/board_state.gd` / `scripts/core/game_rules.gd` / `scripts/core/history_manager.gd` を実装。
2. `scripts/core/puzzle_solver.gd` を実装（BFS探索アルゴリズム）。
3. `tests/test_domain_model.py`、`tests/test_puzzle_solver.py`、`tests/run_tests.py` を実装し、全ルールと不変条件を検証。
4. `tests/test_runner.gd`（Godot Headless 用テストランナー）を作成。

### Phase 3: 全 20 面のレベル設計と数学的解法検証
1. Chapter 1 (1-1 〜 1-5: The Stolen Street) の設計とデータ化。
2. Chapter 2 (2-1 〜 2-5: The Broken Bridges) の設計とデータ化。
3. Chapter 3 (3-1 〜 3-5: The Forgotten Vault) の設計とデータ化。
4. Chapter 4 (4-1 〜 4-5: The Chromatic Core) の設計とデータ化。
5. 全 20 面をテストランナーに投入し、BFS で解法を自動探索・解法手順数を出力・検証。

### Phase 4: ピクセルアートアセットとサウンドの生成
1. 16x16 ピクセルアート（Pip、5色ブロック、ソケット、壁、床、Void、出口、アプリアイコン）を生成。
2. 8-bit / レトロ風 WAV 効果音（窃盗、配置、ソケット起動、歩行、アンドゥ、クリア）を生成。
3. `assets/` ディレクトリに配置。

### Phase 5: Godot 4.7 ビューアダプターとシーン構築
1. `scripts/view/player_view.gd`（トゥイーン補間、所持ブロック表示）。
2. `scripts/view/block_view.gd`（ブロック配置・移動アニメーション）。
3. `scripts/view/level_view.gd`（`TileMapLayer` を用いたグリッド描画・状態同期）。
4. `scripts/view/pixel_camera.gd`（ピクセル丸めカメラ）。
5. `scripts/view/audio_manager.gd`（効果音再生）。
6. シーンファイル（`scenes/level.tscn`, `scenes/main.tscn`）を作成。

### Phase 6: UI・設定・セーブデータ・最終検証
1. HUD、タイトル、チャプター選択、設定画面の実装。
2. Reduced Motion 設定、セーブデータ保存/読み込み機能の実装。
3. 全テスト実行・README 更新・Git コミット。

## 受入基準トレーサビリティ

| 受入基準 | 実現するタスク |
|----------|----------------|
| 1. 基本ルール検証 | Phase 2 (Task 1-3) |
| 2. アンドゥ・リスタートの完全性 | Phase 2 (Task 1, 3) |
| 3. 全 20 面のパズル解法証明 | Phase 3 (Task 1-5) |
| 4. Godot 4.7 準拠コード | Phase 2, Phase 5 |
| 5. ピクセルアートアセット | Phase 4 (Task 1-3) |
| 6. UI・オーディオ・進行状況保存 | Phase 5, Phase 6 |

## 並列実行戦略

- Phase 2 のドメインモデル開発とテストランナー整備は並行して実施。
- Phase 3 のレベルデータ設計とソルバー検証は、チャプター毎に順次バッチ検証可能。
- Phase 4 のアセット生成はドメインモデルと独立して進行可能。

## 検証方法

1. **ドメインモデル & ルール検証:**
   ```bash
   python tests/run_tests.py
   ```
   期待結果: 全テスト（移動、衝突、窃盗、配置、架橋、ソケット適合、アンドゥ、リスタート）がパスし、終了コード 0 を返す。
2. **20 ステージ解法検証:**
   ```bash
   python tests/test_puzzle_solver.py
   ```
   期待結果: 20 面全てに解が存在し、各ステージの最短ステップ数および解法手番シーケンスが表示され、終了コード 0 を返す。
3. **Godot Headless スイート（エンジン導入時）:**
   ```bash
   godot --headless --script res://tests/test_runner.gd
   ```
