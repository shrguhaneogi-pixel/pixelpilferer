# Phase 4 — Puzzle Solver and Level Validation 実装計画

## 背景・目的
Pixel Pilferer の第4フェーズとして、公式ルールエンジンに 100% 準拠した決定論的パズルソルバー、厳格なレベル構造バリデーション、解答リプレイ検証機構、およびプレイヤーの現在状態に基づくインテリジェントヒントシステムを構築する。

ソルバーは描画やシーンツリーから完全に独立し、`GameRules.apply_action` のみを状態遷移関数として用いる。簡略化された別ルールの実装は禁止し、探索上限（訪問状態数・時間）による安全停止、同色フラグメントの同値性（カノニカル化）、失敗時の具体的エラー診断を提供する。

---

## 現状整理
- **状態表現 (`scripts/core/board_state.gd`):**
  - `tiles`, `sockets`, `blocks`, `exit_cell`, `player_pos`, `player_facing`, `carried_block`, `turn_count`, `is_completed`.
  - `get_canonical_key()` は現在 `C(id, color)` を含んでおり、同色の異なるIDを持つブロックを別状態と識別してしまう課題がある（同値性確保のため `C(color)` への改修が必要）。
- **既存ソルバー (`scripts/core/puzzle_solver.gd`):**
  - A* 探索の基礎実装があるが、結果ステータスが `solved: bool` のみであり、`SOLVED`, `UNSOLVABLE`, `LIMIT_REACHED`, `INVALID_LEVEL` の区別がない。
  - BFS モードや、プレデセッサ追跡、プレイヤー現在状態からのヒント生成・自然言語解説生成が未分離。
- **レベル検証 (`scripts/services/level_repository.gd`):**
  - 基本的な幅・高さ・P・Eの存在確認のみで、壁上のブロック、虚空上のソケット、重複ID、開始時クリア、不正色、重複ブロック等の詳細バリデーションが未実装。

---

## 設計

### ファイル構成
```
c:\project\pixelpilferer\
├── scripts/
│   ├── core/
│   │   ├── board_state.gd             # [更新] 同色ブロックの完全カノニカル化 (ID除外)
│   │   ├── puzzle_solver.gd           # [更新] BFS/A* 探索, SolverStatus, 探索制限, プレデセッサ復元
│   │   └── level_validator.gd         # [新規] 厳格なレベルデータ構造バリデータ (Step 6)
│   ├── services/
│   │   ├── level_repository.gd        # [更新] LevelValidator 連携, スキーマ 1.0 対応
│   │   └── hint_service.gd            # [新規] 現在盤面からのインテリジェントヒント生成
│   └── game/
│       └── game_controller.gd         # [更新] HintService 連携による自然言語ヒント表示
├── tests/
│   ├── test_solver_validation.py      # [新規] Python 版 14 種の検証テスト
│   └── test_runner.gd                 # [更新] Godot 4.7 headless 版 14 種の検証テスト
└── docs/
    ├── PROGRESS.md                    # [更新] Phase 4 完了記録
    └── TEST_PLAN.md                   # [更新] Phase 4 テスト計画記録
```

### 技術仕様

#### 1. カノニカル状態表現 (`BoardState.get_canonical_key`)
同一色のフラグメントは交換可能（indistinguishable）であるため、内部 `id` をキーから除外し、座標・色・状態のみでソートする：
```
P(x,y,fx,fy)|C(color)|B[(x1,y1:col,bridge),(x2,y2:col,bridge),...]
```
- 手持ちなし: `C(-)`、手持ちあり: `C(color)`
- 配置ブロック: `(x, y)` 辞書順ソート、`color` と `is_bridge` のみ記録

#### 2. 決定論的パズルソルバー (`PuzzleSolver`)
- **ステータス enum:**
  - `SOLVED`: 最小手数の有効解を発見
  - `UNSOLVABLE`: 全探索空間を網羅し解が存在しないことを証明
  - `LIMIT_REACHED`: 探索制限（訪問数 / 制限時間）に到達（未解決の証明ではない）
  - `INVALID_LEVEL`: 初期状態が不正
- **探索アルゴリズム:**
  - 純粋 BFS または 最適性保証 A*（ダイクストラ / 重み付きヒューリスティック）
  - 状態遷移は `GameRules.apply_action(state, action)` のみを使用
  - プレデセッサ辞書 `parent_map[child_key] = { "parent_key": cur_key, "action": act }` により最短経路のアクション列をバックトラック復元
  - 解答の再検証（Replay Verification）: 見つかったアクション列を初期状態から `GameRules.apply_action` で再実行し、全ステップの成功と最終状態の `is_completed == true` を確認

#### 3. 形式的レベルバリデータ (`LevelValidator`)
`validate_level_dict(d: Dictionary) -> Dictionary`
以下の違反を検知し、レベル ID・フィールド名・違反座標を含む詳細なエラーメッセージを返す：
- `id` / `name` 欠落・空文字列
- `width` / `height` が正の整数でない、または行数・文字数が不一致
- 未知の文字（許可: `#`, `.`, `V`, ` `, `P`, `E`, `S`, `1`, `2`, `3`, `4`）
- `player_start` または `layout` 内 `P` の欠落・重複・不正座標（壁や虚空の中）
- `exit` または `layout` 内 `E` の欠落・重複・不正座標（壁や虚空の中）
- ブロックの不正色（0..4 以外）
- 複数のブロックが同一セルに重複配置
- 固定壁（`#`）の上にブロックが配置されている
- 壁や虚空の上にソケットが配置されている
- プレイヤー開始位置にブロックが重なっている
- 出口セルにブロックが重なっている
- 初期状態で既にクリア条件を満たしている（明示的フラグ `allow_start_completed` なし）

#### 4. インテリジェントヒント基盤 (`HintService`)
- プレイヤーの**現在の BoardState**（動かしたブロック、手持ちフラグメント、現在位置、ソケット達成状況）を入力
- `PuzzleSolver.solve(current_state)` を実行
- 解が見つかった場合、次の一手 `actions[0]` を自然言語と方向付きで解説：
  - 例: "Place your carried Cyan fragment to the east to bridge the chasm."
  - 例: "Siphon the Amber block to the south into your Pixel Glove."
  - 例: "Step west toward the exit portal."
- `LIMIT_REACHED` の場合: "Search budget reached. Try undoing a few steps or restart."
- `UNSOLVABLE` の場合: "No path to victory from this position. Press Z to Undo or R to Restart."

---

## 受入基準 (利用者視点)

1. **完全な探索信頼性:**
   - 単純ルート、ブロック強奪、虚空架橋、ソケット起動、複数ブロック交換を要するパズルで最適な手順を発見できる。
   - 不可能パズルで確実に `UNSOLVABLE` を返し、探索上限超過時は `LIMIT_REACHED` を返す。
2. **厳格なデータバリデーション:**
   - 壁上ブロック、虚空上ソケット、開始位置重複などの不正レベルを検知し、具体的エラー（セル座標付き）を出力して拒否する。
3. **解答リプレイ検証の堅牢性:**
   - ソルバーが出力したアクション列を `GameRules` で最初から最後まで再生し、1手もエラーなくゴール開口・到達することを確認。
4. **ヒントの即時性と文脈対応:**
   - 盤面を数手進めた途中状態からヒントを要求しても、現在の状況に即した有効な次の一手を自然言語で提示する。
5. **テスト全件合格:**
   - Godot 4.7.2 headless テストおよび Python テストが全件成功（exit code 0）。

---

## 実装ステップ

### Phase 4.1: カノニカル状態表現の改修 (同色ブロック同値性)
- `scripts/core/board_state.gd` の `get_canonical_key()` を改修し、手持ちブロックから `id` を除外して `color` のみ使用。
- 同色の配置順・手持ち入れ替えによるカノニカルキー一致テストを実装。

### Phase 4.2: 決定論的パズルソルバー & 解答リプレイ機構の実装
- `scripts/core/puzzle_solver.gd` を拡張：
  - `SolverStatus` (SOLVED, UNSOLVABLE, LIMIT_REACHED, INVALID_LEVEL) の導入
  - プレデセッサによる最短アクション復元
  - 状態数制限・時間制限セーフガード
  - 解答リプレイ検証関数 `replay_solution(initial_state, actions)` の実装

### Phase 4.3: 形式的レベルバリデータの実装
- `scripts/core/level_validator.gd` を新規作成。14 項目にわたる厳格なスキーマ＆配置検証ロジックを実装。
- `LevelRepository` を `LevelValidator` に接続。

### Phase 4.4: インテリジェントヒントサービスの実装
- `scripts/services/hint_service.gd` を新規作成。現在盤面からの解決と文脈に応じた自然言語ヒント文字列生成を実装。
- `GameController.handle_hint()` を `HintService` に接続。

### Phase 4.5: 14 項目の自動テスト実装と検証
- `tests/test_solver_validation.py` および `tests/test_runner.gd` に仕様書記載の 14 項目テストを実装。
- Godot 4.7.2 headless および Python テストを実行し全件合格を確認。
- `/code-reviewer` チェックを実施し、ローカル Git コミット作成。
