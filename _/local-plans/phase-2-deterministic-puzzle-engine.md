# Phase 2 — 決定論的パズルエンジンの仕様強化と完全検証計画

## 背景・目的

Pixel Pilferer の中核をなす決定論的グリッドパズルエンジンを、設計仕様および要求契約に完全に合致するよう強化・拡張する。
本エンジンは、描画やフレームレートから完全に独立し、ゲームプレイ、アンドゥ/リスタート、レベル検証、A*/BFS ソルバー探索、およびランダム化プロパティテスト（ファジング）を単一の真実の情報源として駆動する。
ルール仕様（移動・窃盗・配置・架橋・ソケット適合・ゴール判定・完全アンドゥ・状態等価性判定）の網羅的なテストスイート（最低28項目＋ランダム不変性テスト）を構築し、グラフィカルシーンなしで全パスすることを実証する。

## 現状整理

- **環境:** Godot 4.7.2 stable (`Godot_v4.7.2-stable_win64_console.exe`) および Python 3.14 が稼働中。
- **既存実装:**
  - `scripts/core/constants.gd`: 方向ベクトル、ActionType (8種+UNDO/RESTART)、TileType (FLOOR/VOID/WALL)、BlockColor。
  - `scripts/core/board_state.gd`: 不変・複製可能な状態スナップショット。
  - `scripts/core/game_rules.gd`: 状態遷移関数 $(S_t, a) \to S_{t+1}$。
  - `scripts/core/board_model.gd`: 状態とアンドゥ履歴を保持するモデルラッパー。
  - `scripts/core/history_manager.gd`: スナップショットベースのアンドゥ・リスタート。
  - `scripts/core/puzzle_solver.gd`: A* / BFS パズルソルバー。
- **改修・強化ポイント:**
  1. `GameRules.apply_action()` の戻り値を仕様で求められている構造化アクション結果（`success`, `action`, `source_cell`, `target_cell`, `block_id`, `block_color`, `is_bridge`, `is_completed`, `rejection_reason`, `message`, `next_state`）へ拡張。
  2. ソケットが0個のレベル（ソケットなし）で出口到達時に即時クリアとなる判定の確実化。
  3. `get_state_hash()` / 状態同一性関数の正規化（ブロックの内部登録順に依存しない順序独立性、move count や undo 履歴を含めない純粋な盤面キー）。
  4. 28項目の個別ユニットテスト＋ランダムアクション系列（プロパティテスト/ファジングテスト）の完全実装。
  5. 特設テストボード「障害物からブロック窃盗 → 穴へ配置して架橋 → 橋を渡ってゴール到達」の実証シナリオテスト。

## 設計

### ファイル構成

```text
c:/project/pixelpilferer/
├── scripts/
│   └── core/
│       ├── constants.gd           # 8方向アクション、TileType, BlockColor
│       ├── board_state.gd         # 純粋グリッド状態、正規化ハッシュキー
│       ├── game_rules.gd          # 構造化アクション結果を返す状態遷移関数
│       ├── board_model.gd         # モデル統括・シグナル発火
│       ├── history_manager.gd     # 履歴スナップショット管理
│       └── puzzle_solver.gd       # A*/BFS ソルバー
├── tests/
│   ├── test_runner.gd             # Godot Headless 総合テストハーネス（28テスト＋ランダムテスト）
│   ├── test_domain_model.py       # Python 側デュアル検証（全28テスト＋ファジング）
│   ├── test_puzzle_solver.py      # 全20面解法検証
│   └── run_tests.py               # マスター実行スクリプト
└── _/local-plans/
    └── phase-2-deterministic-puzzle-engine.md
```

### 仕様詳細

1. **構造化アクション結果 (ActionResult):**
   ```gdscript
   {
       "success": bool,
       "action": int,
       "source_cell": Vector2i,
       "target_cell": Vector2i,
       "block_id": int,          # ブロック操作がない場合は -1
       "block_color": int,       # なしの場合は -1
       "is_bridge": bool,
       "is_completed": bool,
       "rejection_reason": StringName, # 失敗時の理由識別子
       "message": String,
       "next_state": BoardState
   }
   ```
2. **状態正規化キー (`get_canonical_key()`):**
   - プレイヤー位置 `(x, y)`
   - プレイヤー向き `(dx, dy)`
   - 所持ブロック `(id, color)` または `None`
   - 配置ブロック: 座標順 `(x, y)` でソートした `[(x, y, color, is_bridge), ...]`
   - ※ターン数・アンドゥスタック・アニメーション状態は除外（探索同一性を保証）。
3. **無効アクション時の不変性保証:**
   - アクション失敗時、`next_state` は一切変更されず（向き変更のみ必要に応じて反映されるか、あるいは完全不変）、不正な履歴エントリは作成されない。

## 受入基準

1. **28項目の必須テストケースが全てパスすること:**
   - 移動（通常床、壁衝突拒絶、盤面境界拒絶、未架橋Void拒絶、床ブロック衝突拒絶）
   - ブロック窃盗（隣接取得、所持時拒絶、色保持、斜め拒絶）
   - ブロック配置（床配置、Void架橋配置、架橋歩行、重複セル拒絶、自位置配置拒絶、出口配置拒絶）
   - ソケット規則（無色ソケット、有色ソケット一致、不一致、色不消費、ソケット動的評価）
   - クリア条件（ソケット未充足時出口到達、ソケット充足時出口到達、ソケットなしレベル出口到達）
   - アンドゥ/リスタート（移動後、取得後、配置後、クリア後、リスタート、不正操作時の履歴非生成）
   - 状態等価性（ブロック格納順に依存しない同一ハッシュキー生成）
   - 再回収（配置後の再窃盗と穴への再復元）
2. **ランダムファジングテスト:**
   - 500回以上の連続ランダムアクション実行において、各ステップ毎に以下のアサーションをパスすること:
     - 全エンティティが境界内にある
     - 同一セルに2つ以上のブロックが存在しない
     - 通常床上においてプレイヤーとブロックが重なっていない
     - 所持中のブロックが盤上に同時に存在しない
     - 不変地形（壁・Void・床）が破壊されていない
     - アンドゥ実行で直前の状態と100%一致する
3. **実証シナリオテストのクリア:**
   - 「障害物からブロック窃盗 → 穴へ配置して架橋 → 橋を渡ってゴール到達」の統合テストがヘッドレスで成功すること。
4. **Godot Headless および Python デュアルハーネスで exit code 0:**
   - `godot --headless --script res://tests/test_runner.gd`
   - `python tests/run_tests.py`

## 実装ステップ

### Phase 2.1: ドメインモデルの戻り値と状態正規化の強化
1. `scripts/core/board_state.gd` に `get_canonical_key()` を実装（ソート済みブロック・所持状態・プレイヤー座標）。
2. `scripts/core/game_rules.gd` の `apply_action()` を改修し、完全な構造化 ActionResult 辞書を返すように更新。ソケット数 0 のレベルにおけるゴール到達判定を明示化。
3. `scripts/core/board_model.gd` が ActionResult をそのまま返し、失敗時には履歴スタックを積まないことを保証。

### Phase 2.2: 28項目テスト＋プロパティファジングテストの実装 (Python & GDScript)
1. `tests/test_domain_model.py` に全28テストケースおよび500ステップのランダムプロパティテストを実装。
2. `tests/test_runner.gd` に GDScript 側の全28テストケースおよび実証シナリオテストを実装。
3. 実証シナリオ（障害物ブロック窃盗 → 穴架橋 → 渡河 → ゴール）の単独テスト関数を作成。

### Phase 2.3: 静的検証・コードレビュー・シンプル化
1. `/warpgrep` および静的型チェックで型付け・無駄な複雑さ・デッドコードを精査。
2. `/code-reviewer` の観点でエッジケース・安全性を点検。
3. `/simplify` の観点で冗長な分岐を整理。

### Phase 2.4: 実行検証とコミット
1. `godot --headless --script res://tests/test_runner.gd` を実行し、全件パスを確認。
2. `python tests/run_tests.py` を実行し、全件パスを確認。
3. ドキュメント（`TEST_PLAN.md`, `PROGRESS.md`, `ARCHITECTURE.md`）を更新。
4. ローカル Git コミットを作成（リモート push なし）。

## 受入基準トレーサビリティ

| 受入基準 | 実現タスク |
|----------|------------|
| 28項目必須テストケース | Phase 2.1, Phase 2.2 (Task 1, 2) |
| ランダムファジングテスト | Phase 2.2 (Task 1) |
| 実証シナリオテスト | Phase 2.2 (Task 3) |
| デュアルテスト実行 (Exit Code 0) | Phase 2.4 (Task 1, 2) |
| Git コミット & ドキュメント整合 | Phase 2.4 (Task 3, 4) |

## 検証方法

```bash
# 1. Godot 4.7.2 Headless Test Runner
Godot_v4.7.2-stable_win64_console.exe --headless --script res://tests/test_runner.gd

# 2. Master Python Test Suite
python tests/run_tests.py
```
両方のテストが全項目 PASS、exit code 0 を返すことを確認する。
