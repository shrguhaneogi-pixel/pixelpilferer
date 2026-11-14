# Phase 3 — Playable Vertical Slice 実装計画

## 背景・目的
Phase 2 で高信頼・決定論的なパズルエンジン（`BoardState`, `GameRules`, `ActionResult`, 28 テスト, プロパティファジング）が確立された。
Phase 3 では、このテスト済みエンジンに完全準拠した **真にプレイ可能で視覚的に明快な Vertical Slice（垂直スライス）** を構築する。

プレイヤーが実際にゲームを起動し、WASD/矢印キー・Shift+方向・E・マウス隣接クリックで直感的に操作でき、ブロックの強奪・虚空への架橋・ソケット起動・アンドゥ・リスタートを行い、3つのデモパズルを快適に解ける状態を実現する。

---

## 現状整理
- **エンジン基盤:** Godot 4.7.2 stable (`gl_compatibility`, 640x360 整数スケーリング).
- **コアモジュール:**
  - `scripts/core/board_state.gd`: 状態表現、カノニカルハッシュ、ディープコピー
  - `scripts/core/game_rules.gd`: 決定論的遷移 `apply_action(state, action) -> ActionResult`
  - `scripts/core/board_model.gd`: 履歴管理とシグナル通知
  - `scripts/core/puzzle_solver.gd`: A* 探索ソルバー
- **レンダラー・ビューの現状:**
  - `scripts/game/board_renderer.gd`: TileMapLayers とエンティティのスケルトンが存在するが、地形タイルやソケットの描画が未結線
  - `scripts/game/game_controller.gd`: キー入力は一部対応しているが、Shift+方向入力やマウス隣接クリック、入力ロック/バッファが未実装
  - `scripts/view/player_view.gd`: 移動アニメーション・向き切り替えの基礎あり。パーティクル・強奪・設置アニメーションの強化が必要
  - `scripts/ui/hud.gd`: ターン数・タイトル表示あり。持っているブロックの明確なグラフィカルインジケータやソケット状況表示が不足
- **アセット:**
  - `assets/sprites/pip.png` (64x16, 4方向)
  - `assets/sprites/blocks.png` (80x16, 5色)
  - `assets/sprites/tileset.png` (64x16: 床, 壁, 虚空, 橋)
  - `assets/sprites/sockets.png` (160x16: 5色 x 2状態 [非アクティブ, アクティブ])
  - `assets/sprites/exit_portal.png` (32x16: 施錠, 解錠)
  - `assets/audio/` (sfx_step, sfx_steal, sfx_place, sfx_socket, sfx_undo, sfx_win)

---

## 設計

### ファイル構成
```
c:\project\pixelpilferer\
├── data/
│   └── levels/
│       └── demo_levels.json           # [新規] 3つの検証用デモレベル (Demo A, B, C)
├── scenes/
│   ├── game/
│   │   └── board.tscn                 # [更新] BoardRenderer シーン構成
│   ├── ui/
│   │   └── hud.tscn                   # [更新] CarriedBlockDisplay, SocketStatus, Undo/Restart
│   └── main.tscn                      # [更新] メインシーン結線
├── scripts/
│   ├── core/
│   │   └── constants.gd               # [確認] アクション・タイル定数
│   ├── game/
│   │   ├── board_renderer.gd          # [更新] 完全な地形・ソケット・ポータル・ブロック描画
│   │   └── game_controller.gd         # [更新] Shift+方向, E, マウスクリック, 入力バッファ, アンドゥ復帰
│   ├── view/
│   │   ├── player_view.gd             # [更新] 移動Tween (120ms), ピクセルパーティクル, 手持ち描画
│   │   ├── block_view.gd              # [更新] 強奪/設置Tween, 橋表示, ソケット発光パルス
│   │   └── pixel_camera.gd            # [更新] ピクセルパーフェクト追従・スナップ
│   ├── ui/
│   │   └── hud.gd                     # [更新] 手持ちブロックアイコン, ソケット達成状況, 操作ガイド
│   └── services/
│       └── level_repository.gd        # [更新] demo_levels.json 読み込み対応
├── tests/
│   ├── test_runner.gd                 # [更新] Phase 3 垂直スライス自動検証ケース追加
│   └── test_vertical_slice.py         # [新規] デモレベル3種のA*解法・入力マッピングテスト
└── docs/
    ├── PROGRESS.md                    # [更新] Phase 3 完了記録
    └── TEST_PLAN.md                   # [更新] Phase 3 動作検証手順
```

### 技術仕様

#### 1. ボード描画システム (`BoardRenderer`)
- グリッド座標系: 1セル = 16x16 ピクセル。
- 地形タイル描画:
  - `tileset.png` (0: Floor, 1: Wall, 2: Void, 3: Bridge).
  - 床・壁・虚空を `state.tiles` から正確にグリッド配置（TileMapLayer または個別 Sprite2D / レンダリングバッチ）。
  - ソケット描画: `sockets.png` から `state.sockets` と現在の起動状態 `is_socket_satisfied(pos)` に応じてテクスチャフレーム `color * 2 + (1 if active else 0)` を描画。
  - ゴール出口: `exit_portal.png`（`state.is_all_sockets_satisfied()` で Frame 0 [施錠] / Frame 1 [解錠] 切替）。
  - ブロック描画: `blocks.png`（床の上=障害物 z_index=2, 虚空の上=橋 z_index=0 半透明/低縮尺）。

#### 2. 入力ハンドリング (`GameController`)
- 移動入力:
  - `W` / `↑` -> `MOVE_NORTH`
  - `D` / `→` -> `MOVE_EAST`
  - `S` / `↓` -> `MOVE_SOUTH`
  - `A` / `←` -> `MOVE_WEST`
- インタラクト入力:
  - `Shift + W/↑` -> `INTERACT_NORTH`
  - `Shift + D/→` -> `INTERACT_EAST`
  - `Shift + S/↓` -> `INTERACT_SOUTH`
  - `Shift + A/←` -> `INTERACT_WEST`
  - `E` / `Space` -> 向いている方向へのインタラクト
- マウス入力:
  - ボード上のマウスクリックイベントを検知し、クリックされたセル座標 `clicked_cell = floor(local_mouse_pos / 16)` を計算。
  - `clicked_cell - player_pos` が隣接4方向のいずれか（マンハッタン距離 = 1）であれば、対応する `INTERACT_*` アクションを発火。
- アンドゥ / リスタート / ポーズ:
  - `Z` / `U` -> `handle_undo()`
  - `R` -> `handle_restart()`
  - `Esc` -> ポーズ / メニュー
- 入力バッファ・ロック:
  - アニメーション中（約120ms）の先行キー入力を1件のみバッファリングし、アニメーション終了直後に適用。連打によるスキップや状態破壊を完全防止。
  - アンドゥまたはリスタート実行時は即座に進行中 Tween を `kill()` し、即時スナップ。

#### 3. 視覚エフェクトとフィードバック
- **強奪エフェクト:** ブロックが Pip に向かって収縮（Tween 0.10s）＋ Pixel Particles（4〜6個の微小正方形がグローブに吸い込まれる）＋ `sfx_steal.wav`。
- **設置エフェクト:** グローブから対象セルへ射出・拡大（Tween 0.12s, EaseOutBack）＋ 接地ピクセルバースト ＋ `sfx_place.wav`。
- **ソケット起動エフェクト:** ソケットが鮮やかに発光パルス（Scale 1.0 -> 1.2 -> 1.0, Modulate 明度上昇）＋ `sfx_socket.wav` ＋ ポータルが即座に開口。
- **無効アクション:** 進行不可の壁/虚空への移動時、わずかなスプライトのバンプ（2ピクセル前進して戻る 0.06s）＋鈍い衝突音。論理状態は一切変化しない。
- **Reduced Motion 設定:** `reduced_motion = true` の場合は Tween やパーティクルをスキップし即時切り替え。

#### 4. デモパズル 3 種 (`data/levels/demo_levels.json`)
- **Demo A: "The Obstructed Path" (障害物ブロックの強奪)**
  - 目的: 狭い通路を塞ぐブロックを吸い取り、脱出路を開けて出口へ到達する。
  - 特徴: 初心者にブロック強奪と持ち運びを教える。
- **Demo B: "Chasm Bridge" (虚空への架橋)**
  - 目的: 足場のない虚空（Void）の溝にブロックを設置して橋を作り、渡って出口へ到達する。
  - 特徴: 虚空ブロック＝橋のルールを直感的に体験させる。
- **Demo C: "Chromatic Socket" (ソケット起動と脱出)**
  - 目的: 施錠されたポータルを開くため、Cyan ブロックを Cyan ソケットへ運び、起動させてから脱出する。
  - 特徴: ソケットとカラー一致、ゴール開口のメカニクスを完結させる。

#### 5. HUD インターフェース (`scenes/ui/hud.tscn`)
- レベルタイトル表示（例: `Demo A: The Obstructed Path`）
- 手持ちブロック表示（Pixel Glove アイコン ＋ 保持中のブロック色スプライト。手ぶらのときは「Empty」表示）
- ソケット状況表示（例: `Sockets: 1/1 Active`）
- ターン数表示（`Moves: X`）
- ボタン群: Undo (`Z`), Restart (`R`), Hint (`H`), Menu (`Esc`)

---

## 受入基準 (利用者視点)

1. **起動とメニュー遷移:** ゲーム起動時に Title から Demo 選択またはスタートで直ちに Demo A がロードされる。
2. **操作体系の直感性:**
   - WASD / 矢印キーで Pip が滑らかにグリッド移動する。
   - `Shift + 方向` または `E` / `Space` で目の前のブロックを吸い取れる。
   - 隣接セルをクリックして直接ブロックの強奪・設置ができる。
3. **視覚フィードバックの明確性:**
   - グローブにブロックを持っていることが HUD および Pip の頭上表示で一目でわかる。
   - 虚空にブロックを置くと明確に「橋」のテクスチャ／半透明状態になり、渡れる。
   - ソケットに適合ブロックを置くとパルス発光し、出口ポータルが即座に開く。
4. **可逆性の保証:**
   - 移動、強奪、設置、クリア直前、いずれのタイミングでも `Z`（Undo）で完全に戻せる。
   - アニメーション中に Undo や Restart を押しても状態のズレやスタックが発生しない。
5. **テスト全件合格:**
   - `godot --headless --script res://tests/test_runner.gd` が全件パス。
   - `python tests/run_tests.py` が全件パス。

---

## 実装ステップ

### Phase 3.1: デモレベルデータとリポジトリ拡張
1. `data/levels/demo_levels.json` を作成（Demo A, Demo B, Demo C）。
2. `LevelRepository` にデモチャプター（Chapter 0 またはデモ読み込みAPI）を追加。
3. A* ソルバーで 3 つのデモレベルが最適手順でクリア可能であることを自動検証。

### Phase 3.2: ボードレンダラーと完全な視覚表現の実装
1. `BoardRenderer` を改修し、`tileset.png`, `sockets.png`, `blocks.png`, `exit_portal.png` を用いた床・壁・虚空・ソケット・ポータルの完全描画を実装。
2. ソケットのアクティブ/非アクティブ切り替え、ポータルの開閉ビジュアルをモデル状態と同期。
3. 虚空上の橋ブロックと床上の障害物ブロックの視覚的差異（Z-index, modulate, scale）を明示。

### Phase 3.3: プレイヤーアニメーションとパーティクル演出
1. `PlayerView` に移動Tween（120ms）、方向転換、頭上ブロック表示、バンプフィードバックを追加。
2. 強奪時・設置時のブロック拡大縮小Tweenとピクセルパーティクルエフェクトを追加。
3. ソケット起動時の発光パルスTweenを追加。
4. `reduced_motion` モードの完全バイパスを実装。

### Phase 3.4: 統合入力ハンドラーとマウス隣接インタラクション
1. `GameController` の入力処理を拡張:
   - WASD / 矢印キー
   - Shift + 方向
   - E / Space コンテキストインタラクト
   - マウス隣接セルのクリック判定 (`get_local_mouse_position()`)
2. アニメーション中の入力バッファリング（120ms）と、Undo/Restart 発生時の即時アニメーションキャンセル・スナップを実装。

### Phase 3.5: HUD の拡張とデモフロー
1. HUD に手持ちブロックスロット、ソケット達成ステータス、操作ヘルプ表示を追加。
2. Demo A -> Demo B -> Demo C のスムーズな自動遷移とクリアモーダルを接続。

### Phase 3.6: 自動テスト・検証とコードレビュー
1. `tests/test_runner.gd` に Phase 3 の入力・描画同期・デモクリア検証ケースを追加。
2. Godot 4.7.2 headless でテストを実行し全件合格を確認。
3. `/code-reviewer` チェックとリファクタリング。
4. ローカル Git コミット作成。
