# PIXEL PILFERER: REBOUND — Reality Snapback & Vertical Slice Plan

## 背景・目的

本タスクの目的は、ゲームジャムテーマ **「BOUNCE BACK」**（反発・跳ね返り・元の場所への復元）を中核ゲームプレイメカニクスへと昇華させた新システム **「Reality Snapback（現実復元バウンス）」** を Pixel Pilferer に統合し、その完全な動作を保証する単離バーティカルスライスを構築・検証することである。

### 解決する課題
- 従来の足場設置は永続的（静止固定）であり、プレイヤーはブロックを一度置けばいつでも何度でも利用できた。
- 「BOUNCE BACK」テーマを反映し、**「盗取したブロックは一時的な跳躍バネとして設置可能だが、跳躍後に元の場所へスナップバック（復元）する」** という動的かつ時間制限的なパズル構造を導入する。
- ソケットへの設置時は `ANCHORED`（固定）となり、回路を永続起動できるため、同一リソースに対して「大跳躍のための使い捨てバネ」と「扉を開けるための回路アンカー」という 2 つの相反する用途のジレンマを生み出す。

### 期待される成果
1. 明示的ステートマシン（`HOME`, `CARRIED`, `PLACED`, `TRIGGERED`, `RETURNING`, `ANCHORED`）を持つ `MovableFragment2D` の実装。
2. 上部着地時のみ大跳躍（`BOUNCE_VELOCITY = -370.0 px/s`）を発火し、側面・下部接触では発火しないバネ挙動。
3. プレイヤー離脱後の安全なスナップバックアニメーションと、プレイヤー重複時の安全な遅延復元プロトコル（スタック死・めり込みの根絶）。
4. 11 ステップ受入基準を 100% 満たすバーティカルスライス `scenes/test/rebound_vertical_slice.tscn` の構築。
5. エッジケース（側面衝突、空中復元、重複遅延、リスタート中断）を網羅する自動検証スイート `scripts/test/test_rebound_vertical_slice.gd` の全項目 PASS。

---

## 現状整理

- **エンジン・環境**: Godot 4.7.2 stable (`gl_compatibility` レンダラー、解像度 640x360、integer スケーリング、ピクセルスナップ有効)。
- **既存のプラットフォーマー資産**:
  - `player_platformer.gd`: CharacterBody2D 移動、可変ジャンプ（`JUMP_VELOCITY = -225.0`）、コヨーテ、バッファ、シミュレーション入力。
  - `pixel_glove.gd`: 28px 射程、1 個制限、盗取・設置ロジック。
  - `platform_tile_manager.gd`: 動的ブロックの物理管理とスナップショット復元。
  - `chromatic_socket.gd` & `locked_door.gd`: 色一致回路ドア。
  - Milestone B, C, D の全テスト（454 アサーション）が 100% 合格中。

---

## 設計

### ファイル構成

```
c:/project/pixelpilferer/
├── scripts/
│   ├── platformer/
│   │   ├── movable_fragment_2d.gd      # [新規] フラグメント本体（ステートマシン、バネ判定、スカッシュ＆ストレッチ、復元アニメ）
│   │   ├── ghost_frame_2d.gd           # [新規] 盗取元の空枠ゴースト表示（点線・パルス枠）
│   │   ├── player_platformer.gd        # [改修] bounce(launch_velocity) メソッド追加、バネ着地処理
│   │   ├── pixel_glove.gd              # [改修] MovableFragment2D との連携、ソケット設置判定（ANCHORED vs PLACED）
│   │   └── platform_tile_manager.gd    # [改修] MovableFragment2D の登録・復元・安全重複チェック
│   └── test/
│       └── test_rebound_vertical_slice.gd # [新規] 11ステップ受入＋エッジケース自動テストランナー
├── scenes/
│   ├── platformer/
│   │   └── components/
│   │       ├── movable_fragment_2d.tscn # [新規] バネ付きフラグメントシーン
│   │       └── ghost_frame_2d.tscn      # [新規] ゴースト枠シーン
│   └── test/
│       └── rebound_vertical_slice.tscn  # [新規] 11ステップ受入検証用バーティカルスライスステージ
└── _/local-plans/
    └── reality-snapback-rebound-vertical-slice.md # 本計画ファイル
```

### 仕様

#### 1. フラグメントステートマシン (`MovableFragment2D`)
```gdscript
enum State {
    HOME,       # 初期配置セルで待機中。通常地形として振る舞う。ゴースト枠は非表示。
    CARRIED,    # Pip の Pixel Glove に携行中。物理コリジョンは無効化、Pip に追従。
    PLACED,     # 空中・地上グリッドに設置完了。上面がバネとして待機。ホーム位置にゴースト枠表示。
    TRIGGERED,  # Pip が上面に着地し、跳躍力を付与した直後。スカッシュ＆ストレッチ実行中。
    RETURNING,  # Pip がバネから離脱した。コリジョンを安全に無効化し、Tween で home_cell へ飛翔帰還。
    ANCHORED    # ソケット内に配置され、回路を起動。バネ機能は停止し、永続足場・導線として固定。
}
```

- **バネ判定の厳密性**:
  - フラグメント上面に高さ 4px の `SpringSensor` (`Area2D`, Collision Layer 4, Mask 1: Player) を配置。
  - 発火条件:
    1. `state == State.PLACED`
    2. プレイヤーの垂直速度 $v_y > 0$（上からの落下着地）。
    3. プレイヤーの中心 $y$ がブロック上面付近（めり込み・側面からの接触ではない）。
  - 発火時のアクション:
    - プレイヤーに対して `player.bounce(-370.0)` を呼び出し、跳躍初速を上書き（通常ジャンプ -225 に対し、約 2.7 倍の到達高度 110px / 約 7 タイル分の超大ジャンプ）。
    - 自身の状態を `State.TRIGGERED` に変更。
    - スカッシュ＆ストレッチアニメーション: `scale = Vector2(1.35, 0.65)` → `Vector2(0.85, 1.15)` → `Vector2(1.0, 1.0)`。
    - ピクセルパーティクル放射。
- **安全なスナップバック (`State.RETURNING` → `State.HOME`)**:
  - プレイヤーが上面から離脱（Airborne 化または距離 > 20px）した瞬間、スナップバックシーケンスを開始。
  - `CollisionShape2D.set_deferred("disabled", true)` で設置場所のコリジョンを同フレーム内に完全消去。
  - Tween により 0.2 秒かけて `global_position` を `home_cell` の中心座標へ移動。
  - **安全重複プロトコル**:
    - 到着時、`home_cell` のバウンディングボックス（16x16）がプレイヤーの `get_player_bounds()` と重なっていないかを判定。
    - 重なっている場合: コリジョン有効化を遅延（`is_restoration_deferred = true`）し、半透明の待機状態で待機。プレイヤーが退去した次の物理フレームでコリジョンを有効化。
    - 重なっていない場合: 即座にコリジョンを有効化し、`state = State.HOME` に復帰。ゴースト枠を非表示化。

#### 2. ゴースト枠 (`GhostFrame2D`)
- フラグメントが `HOME` 以外の状態のとき、`home_cell` に破線の 16x16 枠線と淡いルーンマークを表示。
- プレイヤーに対して「このブロックは元々ここにあった」「バウンス後にここへ戻ってくる」ことを直感的に予告。

#### 3. 11 ステップ受入シナリオ（「Rebound Vertical Slice」）
1. Pip は安全な足場から開始し、通常通り左右に走行およびジャンプ可能。
2. Pip は高台手前の壁面にあるマークされた可動フラグメントを盗取。
3. 盗取元の壁面に識別可能な空枠（ゴーストフレーム）が出現し、壁面は通過可能になる。
4. Pip はフラグメントを抱えて渡れない高低差クレバスへ移動。
5. Pip は空中グリッドの指定セルへフラグメントを設置。
6. 設置されたブロックは Pip を支える足場となり、上面にバネインジケータが表示される。
7. Pip がブロック上面に着地すると、強力な跳躍力（$v_y = -370\text{ px/s}$）で真上へ打ち上げられる。
8. Pip はリバウンドの高さを活かして、通常ジャンプでは届かない超高台（高度差 80px）へ着地登頂。
9. Pip が離脱した後、トリガーされたブロックは設置地点のコリジョンを破棄し、飛翔アニメーションを経て元の壁面ゴースト枠へ安全にスナップバック復元される。
10. Pip は高台のゴールポータルへ到達し、正常にレベルクリア状態へ移行。
11. リスタート（`R` キー）により、すべてのフラグメント・ゴースト枠・足場が完全な初期状態へとリセットされる。

---

## 受入基準

- **AC 1 (6 ステートマシンの厳格遵守)**: `MovableFragment2D` が `HOME`, `CARRIED`, `PLACED`, `TRIGGERED`, `RETURNING`, `ANCHORED` の 6 状態を正確に遷移し、不正な状態遷移（例: CARRIED から直接 RETURNING など）を例外なく拒絶すること。
- **AC 2 (バネ着地と方向制御の保証)**: 上部着地時のみ `BOUNCE_VELOCITY`（-370 px/s）が発火し、側面衝突や下部衝突では一切発火せず通常の壁・天井衝突となること。また跳躍中も水平移動入力（空中制御）が 100% 応答すること。
- **AC 3 (スナップバックと衝突の無矛盾性)**: 跳躍離脱後に設置場所のコリジョンが即座に無効化され、残骸コリジョンが存在しないこと。さらにホーム位置への帰還時にプレイヤーとのスタックが発生せず、安全重複遅延プロトコルが機能すること。
- **AC 4 (ソケットアンカーの独立性)**: ソケットに設置されたフラグメントは `ANCHORED` 状態となり、上面に着地してもバネ跳躍およびスナップバックが発生せず、永続的な回路接続として維持されること。
- **AC 5 (11 ステップ受入自動テスト PASS)**: `scenes/test/rebound_vertical_slice.tscn` において、`test_rebound_vertical_slice.gd` が 11 ステップ全項目およびエッジケース検証（側面衝突、重複復元、リスタート中断）において 100% PASS すること。
- **AC 6 (後退ゼロ)**: 既存の Milestone B, C, D および Phase 1〜9 の全回帰テストが引き続き合格すること。

---

## 実装ステップ

### Phase 1: コアコンポーネントの実装
1. `scripts/platformer/movable_fragment_2d.gd` および `scenes/platformer/components/movable_fragment_2d.tscn` の実装。
2. `scripts/platformer/ghost_frame_2d.gd` および `scenes/platformer/components/ghost_frame_2d.tscn` の実装。
3. `scripts/platformer/player_platformer.gd` に `bounce(launch_velocity: float)` を追加。

### Phase 2: タイルマネージャーとグローブの統合
1. `scripts/platformer/pixel_glove.gd` を改修し、ソケットセルへの設置時は `ANCHORED`、一般セルへの設置時は `PLACED`（バネ）として展開。
2. `scripts/platformer/platform_tile_manager.gd` を改修し、`MovableFragment2D` のライフサイクル、ゴースト枠管理、復元時の遅延重複判定を一元管理。

### Phase 3: バーティカルスライスシーンの構築
1. `scenes/test/rebound_vertical_slice.tscn` を構築（開始地点、壁面フラグメント、渡れない超高台、ゴールポータル、ソケット検証サブエリア）。

### Phase 4: 自動検証テストランナーの実装と実行
1. `scripts/test/test_rebound_vertical_slice.gd` を作成。
   - 11 ステップ受入シナリオの自動物理シミュレーション。
   - 側面衝突非発火検証。
   - 復元時プレイヤー重複遅延検証。
   - リスタート・死亡時の安全初期化検証。
2. Godot CLI ヘッドレス実行による実証確認。
3. 既存回帰テスト群の実行。

### Phase 5: レビュー・文書化・ローカル Git コミット
1. コード品質レビュー（型安全性、Tween メモリリーク防止）。
2. `docs/PROGRESS.md` の更新。
3. ローカル Git コミットの作成。

---

## 受入基準トレーサビリティ

| 受入基準 | 実現するタスク |
|---|---|
| AC 1 (6 ステートマシン) | Phase 1: 1, Phase 2: 1, 2 |
| AC 2 (バネ着地・方向制御) | Phase 1: 1, 3, Phase 4: 1 |
| AC 3 (スナップバック・重複遅延) | Phase 1: 1, 2, Phase 2: 2, Phase 4: 1 |
| AC 4 (ソケットアンカー) | Phase 1: 1, Phase 2: 1, Phase 4: 1 |
| AC 5 (11 ステップ受入) | Phase 3: 1, Phase 4: 1, 2 |
| AC 6 (後退ゼロ) | Phase 4: 3 |

---

## 検証方法

1. **バーティカルスライス受入自動テスト**:
   ```powershell
   & "C:\Users\Dell\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --script res://scripts/test/test_rebound_vertical_slice.gd
   ```
2. **Milestone D / C / B 回帰テスト**:
   ```powershell
   & "C:\Users\Dell\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --script res://scripts/test/test_platformer_milestone_d.gd
   & "C:\Users\Dell\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --script res://scripts/test/test_broken_crossing.gd
   & "C:\Users\Dell\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --script res://scripts/test/test_platformer_movement.gd
   ```
3. **マスター回帰テスト**:
   ```powershell
   python tests/run_tests.py
   ```
