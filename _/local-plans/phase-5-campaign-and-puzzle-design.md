# Phase 5 — Complete Campaign and Puzzle Design 実装計画

## 背景・目的
Pixel Pilferer の第5フェーズとして、全4章・計20レベルからなる完成版パズルキャンペーンを設計・構築・検証・統合する。
各章は明確な学習曲線（1: 導入 → 2: 練習 → 3: 結合 → 4: ひねり → 5: 章フィナーレ）に従い、プレイヤーが新ルールを安全かつ直感的に習得できるように構成する。
第4フェーズで確立した決定論的 BFS ソルバー、厳格なレベルバリデータ、およびリプレイ検証機構を用いて全20レベルの完全解と最適手数を数学的に証明・監査する。

---

## 現状整理
- **既存レベル (`data/levels/`):**
  - `demo_levels.json`: チュートリアル3レベル (`demo_01`, `demo_02`, `demo_03`) は Phase 3 で動作確認済み。
  - `ch1_levels.json` 〜 `ch4_levels.json`: 初期プロトタイプ版が配置されているが、第1章に虚空やソケットが含まれるなど、今回の設計要件（第1章は純粋な障害物移動、第2章で虚空架橋、第3章でニュートラルソケット、第4章で色付きソケット）と乖離している。
- **検証基盤:**
  - `LevelValidator`: 14項目の幾何・実体・スキーマ検査。
  - `PuzzleSolver`: BFS 探索、`SolverStatus`、プレデセッサバックトラックによる最小手数保証、`verify_solution` によるリプレイ検証。
  - `ProgressService`: `user://pixel_save.json` によるクリア状況・ベスト手数・アンロック状態の永続化。

---

## 設計

### ファイル構成
```
c:\project\pixelpilferer\
├── data/
│   └── levels/
│       ├── ch1_levels.json            # [更新] Chapter 1: The Stolen Street (障害物除去・移動)
│       ├── ch2_levels.json            # [更新] Chapter 2: The Broken Bridges (虚空架橋・回収)
│       ├── ch3_levels.json            # [更新] Chapter 3: The Forgotten Vault (ソケット起動・複数配置)
│       └── ch4_levels.json            # [更新] Chapter 4: The Chromatic Core (色合わせ・総合試練)
├── scripts/
│   ├── services/
│   │   └── progress_service.gd        # [更新] 章クリアフラグ・全クリア検出
│   ├── ui/
│   │   ├── chapter_select.gd          # [更新] アンロック制限、章クリア環境ストーリー表示
│   │   └── hud.gd                     # [更新] キャンペーンエンディング画面表示
│   └── main.gd                        # [更新] 第4章フィナーレ後のエンディング遷移
├── tests/
│   ├── test_campaign_audit.py         # [新規] 全20レベルの厳格な難易度曲線・手順・監査スクリプト
│   ├── test_puzzle_solver.py          # [更新] 新20レベルの A*/BFS 最適手数追跡
│   └── test_runner.gd                 # [更新] Godot ネイティブでの新20レベル全件検証
└── docs/
    ├── CAMPAIGN_VALIDATION.md         # [新規] 20レベル検証レポート（手数・状態数・メカニクス）
    ├── PROGRESS.md                    # [更新] Phase 5 完了記録
    └── TEST_PLAN.md                   # [更新] Phase 5 テスト計画記録
```

---

## 章構成と難易度曲線

### Chapter 1: The Stolen Street
- **テーマ:** 廃れた街並みと機械構造。
- **主メカニクス:** グリッド移動、床上の障害物強奪、手持ち運搬、配置による通路確保、Undo / Restart。
- **制約:** 虚空架橋やソケットは一切登場させない。
- **レベル設計:**
  - `ch1_01` (Blocked Alley): 1マスの障害物が通路を塞ぐ。手持ちに吸い取り、そのまま出口へ（最短5手）。
  - `ch1_02` (The Turnout): 通路上のブロックを吸い取り、横の退避ポケットへ配置して出口への直線を開放（最短7手）。
  - `ch1_03` (Narrow Passage): ブロックを置く場所の選択。誤った場所に置くと自分が閉じ込められる（最短8手）。
  - `ch1_04` (Squeeze Route): ブロックを後ろの窪みへ一時退避させてすれ違い、出口へ進む（最短10手）。
  - `ch1_05` (Street Finale): 2つのブロックをそれぞれ別のポケットへ整理して二重ゲートを開通（最短13手）。

### Chapter 2: The Broken Bridges
- **テーマ:** 崩れた古代の通路と虚空。
- **主メカニクス:** 通行不能な虚空、虚空へのブロック配置（架橋）、橋の回収（後ろから吸い取り）、手持ち1個のルート計画。
- **制約:** ソケットは登場させない。
- **レベル設計:**
  - `ch2_01` (First Gap): 手持ちのブロックを1マスの虚空へ配置して橋を作り、渡る（最短6手）。
  - `ch2_02` (Obstacle to Bridge): まず床の障害物を吸い取り、それを運んで虚空に架橋（最短8手）。
  - `ch2_03` (Island Hop): 橋を架けて中央の中継島へ渡り、そこから出口へ（最短9手）。
  - `ch2_04` (The Leapfrog): 1マスの橋を渡った後、後ろを振り向いて橋を回収し、次の虚空に架け直す（最短12手）。
  - `ch2_05` (Abyss Cross Finale): 2つのブロックを駆使して多段階の亀裂を渡り切るフィナーレ（最短15手）。

### Chapter 3: The Forgotten Vault
- **テーマ:** 古代の機械遺構と導力回路。
- **主メカニクス:** ニュートラルソケット（任意ブロックで通電）、出口開放条件、ソケットを埋めたままの移動、複数ブロック管理。
- **レベル設計:**
  - `ch3_01` (Conduit Awakening): 単一の分かりやすいソケット。ブロックを配置すると出口のロックが解除（最短7手）。
  - `ch3_02` (The Vault Pocket): ソケットが側道の小部屋にある。ブロックをソケットに嵌めてからメイン通路を戻り出口へ（最短10手）。
  - `ch3_03` (Conduit & Chasm): ブロック2個。1個は虚空の橋として残し、もう1個をソケットに嵌める（最短12手）。
  - `ch3_04` (Constrained Transfer): 狭い部屋でブロックを一時中継しながら目的のソケットへ運搬（最短15手）。
  - `ch3_05` (Vault Masterwork): 2箇所のソケットと虚空の組み合わせ。両方のソケットに通電した状態で出口へ（最短18手）。

### Chapter 4: The Chromatic Core
- **テーマ:** 聖なるピクセルコア。世界に色彩を取り戻す。
- **主メカニクス:** 色付きフラグメント（Cyan, Amber, Magenta, Emerald）と色一致ソケット、複数色の運搬、全メカニクスの統合。
- **レベル設計:**
  - `ch4_01` (Prismatic Intro): Cyan ソケットと Cyan ブロックの導入（最短7手）。
  - `ch4_02` (Duo Resonators): Cyan と Amber の2色。色を正しく対応するソケットへ配分（最短12手）。
  - `ch4_03` (Chromatic Bridge): 虚空を渡る足場にしつつ、最終的に指定色のソケットへ運搬（最短14手）。
  - `ch4_04` (Triad Conduits): Cyan, Amber, Magenta の3色を中央デポを介して順次搬送（最短18手）。
  - `ch4_05` (The Grand Core): 4色（Cyan, Amber, Magenta, Emerald）すべてのソケットを通電させ、世界のコアを完全に再起動する最終試練（最短24〜30手）。

---

## 受入基準
1. **完全な20レベルの配備:**
   - 4章 × 5レベルの計20レベルが JSON 形式で authored され、各章の教育的テーマに100%合致している。
2. **形式検証全件合格:**
   - `LevelValidator` により全20レベルの構文、実体、境界、開始・出口条件がエラー・警告ゼロで合格。
3. **決定論的解の完全証明:**
   - 全20レベルが `PuzzleSolver` (BFS) により最適手順で解決可能であり、最短手数・訪問状態数が記録されている。
   - `PuzzleSolver.verify_solution` によるリプレイ検証が全ステップ成功し、最終状態で確実に `is_completed == true` となる。
4. **進行度とアンロックの整合性:**
   - 未クリアレベルはロックされ、クリアにより次のレベルおよび次章が順次アンロックされる。
   - レベル再挑戦やリスタートを行っても大域的進捗が喪失しない。
5. **最終エンディングの到達:**
   - レベル 4-5 をクリアした際、ゲームクリア演出（コア修復メッセージ・クリア手数記録）が表示される。
6. **テスト全件合格:**
   - Godot 4.7.2 headless テストおよび Python テストが全件 exit code 0 で合格。

---

## 実装ステップ

### Phase 5.1: 20レベルデータの作成と難易度曲線設計
- `data/levels/ch1_levels.json` 〜 `ch4_levels.json` を新設計に基づいて作成。
- 各レベルのサイズ、初期配置、障害物、ソケット、ヒント文を定義。

### Phase 5.2: 自動ソルバー監査スクリプトと検証レポート生成
- `tests/test_campaign_audit.py` を実装。
- 全20レベルに対して `LevelValidator` 検査、BFS 探索、リプレイ検証、ショートカット有無、必要手数を自動測定。
- `docs/CAMPAIGN_VALIDATION.md` を生成。

### Phase 5.3: 章演出・ストーリーテリング・エンディングの実装
- `ProgressService` に章完了追跡とエンディングフラグを追加。
- `ChapterSelect` に章ごとの復興テキストとアンロック状態を反映。
- `MainGame` / `HUD` に第4章クリア時のエンディング画面を追加。

### Phase 5.4: 自動テストスイートの更新と全件検証
- `tests/test_puzzle_solver.py`、`tests/run_tests.py`、`tests/test_runner.gd` を更新。
- Godot 4.7.2 headless および Python テストを実行し 100% 合格を確認。

### Phase 5.5: レビュー・簡素化・ローカル Git コミット
- `/code-reviewer` チェックを実施。
- ドキュメント (`docs/PROGRESS.md`, `docs/TEST_PLAN.md`) を更新し、ローカルコミットを作成。
