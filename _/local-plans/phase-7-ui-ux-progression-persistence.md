# Phase 7 — UI, UX, 進行管理, アクセシビリティ, 永続化 実装計画

## 背景・目的
Pixel Pilferer のゲーム基盤（フェーズ1）、決定論的パズルエンジン（フェーズ2）、プレイアブル垂直スライス（フェーズ3）、自動ソルバー検証（フェーズ4）、全20ステージ+デモのキャンペーン設計（フェーズ5）、アート・演出・オーディオ基盤（フェーズ6）がすべて完了し、361件のテストがパスしている。
本フェーズ（Phase 7）では、プレイヤーが直感的かつ快適にゲームを体験できるよう、タイトル画面・ステージ選択・ポーズメニュー・コンテキストチュートリアル・実績メダル・ヒントUI・セーブデータ永続化と堅牢な破損復旧・アクセシビリティ設定を統合する。

## 現状整理
- `scripts/services/progress_service.gd`: 基本的なセーブ/ロード、設定保持、クリア判定が存在するが、スキーマバージョン管理、破損検出/バックアップ復旧、メダル算出ロジック、チュートリアルフラグが未実装。
- `scripts/ui/title_screen.gd` & `scenes/ui/title_screen.tscn`: 「Start Adventure」「Chapter Select」「Settings」のみ。Continue（セーブなし時は無効）、New Game（既存データがある場合の確認モーダル）、Credits モーダル、プラットフォーム安全な Quit ボタンが未実装。
- `scripts/ui/chapter_select.gd` & `scenes/ui/chapter_select.tscn`: チャプターとステージ一覧を表示するが、Gold/Silver/Bronze メダル表示やチャプター達成率表示が未統合。
- `scripts/ui/hud.gd` & `scenes/ui/hud.tscn`: ステータス・ヒント・クリア表示はあるが、ポーズボタン、メダル評価（Gold/Silver/Bronze）表示、コンテキストチュートリアルバナー表示が未統合。
- `scripts/ui/pause_menu.gd` & `scenes/ui/pause_menu.tscn`: ポーズ専用モーダルが未作成（ESCで即チャプター選択へ遷移する暫定仕様）。ゲーム状態・アンドゥ履歴を保持したまま再開・設定・リスタート・メニュー遷移ができる専用ポーズ画面が必要。
- `scripts/ui/credits_modal.gd` & `scenes/ui/credits_modal.tscn`: クレジット表示用コンポーネントが未作成。
- `scripts/ui/tutorial_overlay.gd` & `scenes/ui/tutorial_overlay.tscn`: 特定レベル初回時の軽量コンテキスト解説オーバーレイが未作成。

## 設計

### ファイル構成
```
c:/project/pixelpilferer/
├── scripts/
│   ├── main.gd                                (更新: ポーズ画面・確認モーダル・クレジット・チュートリアル連携)
│   ├── game/
│   │   └── game_controller.gd                 (更新: ポーズ状態管理、入力遮断、安全な再開)
│   ├── services/
│   │   └── progress_service.gd                (更新: スキーマv1、破損検出・復旧、メダル判定、チュートリアル追跡)
│   └── ui/
│       ├── title_screen.gd                    (更新: Continue/New Game確認/Credits/Quit)
│       ├── chapter_select.gd                  (更新: メダル★/◈/•アイコン、チャプター完了率)
│       ├── hud.gd                             (更新: ポーズボタン、メダル付クリア演出、チュートリアルバナー)
│       ├── pause_menu.gd                      (新規: Resume/Restart/Hint/Settings/Menu)
│       ├── credits_modal.gd                   (新規: クレジット表示・閉じる)
│       ├── confirm_modal.gd                   (新規: New Game上書き確認ダイアログ)
│       └── settings_menu.gd                   (更新: ハイコントラスト切り替え追加)
├── scenes/
│   └── ui/
│       ├── title_screen.tscn                  (更新: Continue/NewGame/Credits/QuitUI要素)
│       ├── chapter_select.tscn                (更新: レイアウト調整、メダル表示領域)
│       ├── hud.tscn                           (更新: ポーズボタン、チュートリアルコンテナ)
│       ├── pause_menu.tscn                    (新規: ポーズメニューシーン)
│       ├── credits_modal.tscn                 (新規: クレジットモーダルシーン)
│       └── confirm_modal.tscn                 (新規: 確認ダイアログシーン)
└── tests/
    └── test_runner.gd                         (更新: Phase 7 UI・永続化・メダル・ポーズテスト追加)
```

### 仕様

#### 1. セーブデータスキーマ (Schema Version 1)
```json
{
  "schema_version": 1,
  "unlocked_level": "ch1_01",
  "completed_levels": {
    "demo_01": 5,
    "ch1_01": 8
  },
  "settings": {
    "master_volume": 1.0,
    "sfx_volume": 1.0,
    "music_volume": 0.8,
    "sfx_enabled": true,
    "music_enabled": true,
    "reduced_motion": false,
    "screen_shake": true,
    "high_contrast": false
  },
  "tutorial_seen": {
    "demo_01": true,
    "ch2_01": true
  }
}
```
- 破損検出: JSON パース失敗時または必須フィールド欠落時、`user://pixel_save.bak` に退避しデフォルト値で安全に初期化（クラッシュ回避）。
- メダル算出:
  - Gold: 手数 == 各ステージ最小手数 $M^*$
  - Silver: 手数 $\le M^* + 3$
  - Bronze: クリア（手数 $> M^* + 3$）

#### 2. ポーズ画面仕様 (`PauseMenu`)
- ESCキーまたはHUDのポーズボタンで表示。
- ゲームループ・タイマー・Tween・入力バッファを一時停止。
- 表示項目:
  - 「Resume」（ゲーム再開）
  - 「Restart」（ステージ最初から）
  - 「Hint」（ヒント表示）
  - 「Settings」（音量・アクセシビリティ設定）
  - 「Level Select」（チャプター画面へ）
  - 「Title Screen」（タイトルへ）
- 再開時: アンドゥ履歴、保持ブロック、盤面状態が一切破壊されず継続。

#### 3. コンテキストチュートリアル仕様
- 対象ステージ初回開始時に非侵入型（ゲームプレイを邪魔しない下部/上部トーストまたはワンキーで閉じられるバナー）で表示:
  - `demo_01`: "WASD / 方向キーで移動。ブロックに向かって進むと回収（スチール）します。"
  - `demo_02`: "E または スペースで正面とインタラクト。ブロックを床に置いて通路を開けましょう。"
  - `demo_03`: "Zキーでアンドゥ、Rキーでリセット。青く光る脱出ポータルへ到達してください。"
  - `ch1_01`: "Shift + 方向キーでその場から隣接ブロックを操作できます。"
  - `ch2_01`: "穴（Void）にブロックを置くと、渡れる橋（Bridge）になります。"
  - `ch2_04`: "橋を渡ったあと振り返って回収（スチール）すれば、連続で穴を跳び越えられます。"
  - `ch3_01`: "ソケットにブロックをはめ込むと、脱出ポータルのロックが解除されます。"
  - `ch4_01`: "色のついたソケットには、同色のカラーブロックをはめ込む必要があります。"
- 閉じる操作: 任意の移動入力またはESC/スペースで非表示化。
- 一度見たチュートリアルは `tutorial_seen` に保存され、再訪時には非表示。

#### 4. メインメニュー拡張
- Continue: 保存データが存在する場合のみ有効化。最高到達ステージを即座に再開。
- New Game: セーブデータが初期状態でない場合、「進行状況をリセットして最初から始めますか？」の確認モーダルを表示。
- Credits: 開発クレジット、ライセンス、デザイン理念をモーダル表示。
- Quit: デスクトップ環境では `get_tree().quit()`、Web環境（HTML5）では非表示または無効化。

## 受入基準

- 受入基準 1: 初回起動時に Continue ボタンが無効化されており、ステージをクリアすると Continue ボタンが有効化され、次回起動時に最高到達ステージから再開できる。
- 受入基準 2: 既存の進行状況がある状態で New Game を押すと確認ダイアログが表示され、「Cancel」で中断、「Confirm」で進行データがリセットされてデモ1から開始される。
- 受入基準 3: ゲームプレイ中に ESC キーまたはポーズボタンを押すとポーズメニューが開き、ゲーム入力が一時停止され、「Resume」を押すとアンドゥ履歴・保持アイテム・位置が完全に維持された状態で再開できる。
- 受入基準 4: セーブファイルが破損（不正なJSONなど）している場合、バックアップが作成され、エラーで停止することなくデフォルト値で安全に起動・復旧する。
- 受入基準 5: ステージクリア時に、最小手数に応じた Gold（完全一致）、Silver（最小+3手以内）、Bronze（クリア）のメダルがHUDに表示され、チャプター選択画面にも実績メダルが反映される。
- 受入基準 6: 特定のチュートリアル対象ステージで初回プレイ時にコンテキスト解説が表示され、移動やキー入力で閉じられ、進行データに記録されて再表示されない。
- 受入基準 7: 設定画面で「ハイコントラストモード」のトグルが機能し、セーブデータに保存・復元される。
- 受入基準 8: Headless テストランナーにおいて、上記の全遷移・データ整合性・ポーズ復帰・メダル算出・破損復旧のテストケースが 100% パスする。

## 実装ステップ

### Phase 1: 永続化と進行管理サービスの拡張 (`ProgressService`)
1. スキーマバージョン (`schema_version: 1`) と必須フィールド検証を追加。
2. セーブ破損時のフォールバックおよびバックアップ (`pixel_save.bak`) 処理の実装。
3. ステージ別最小手数マップの統合と `get_level_medal(level_id, turns)` の実装。
4. チュートリアル既読管理 (`is_tutorial_seen`, `mark_tutorial_seen`) の実装。
5. `has_saved_game()` および `get_continue_target()` の実装。

### Phase 2: UIモーダルコンポーネントの作成
1. 確認モーダル (`ConfirmModal` / `scenes/ui/confirm_modal.tscn`) の作成。
2. クレジットモーダル (`CreditsModal` / `scenes/ui/credits_modal.tscn`) の作成。
3. ポーズメニュー (`PauseMenu` / `scenes/ui/pause_menu.tscn`) の作成（Resume, Restart, Hint, Settings, Level Select, Title Screen）。

### Phase 3: メインメニュー (`TitleScreen`) と設定の拡張
1. `scenes/ui/title_screen.tscn` に Continue, New Game, Credits, Quit ボタンを配置。
2. `scripts/ui/title_screen.gd` で Continue の有効/無効制御、New Game 確認フロー、Credits ポップアップ、Quit 制御を実装。
3. `scenes/ui/settings_menu.tscn` および `scripts/ui/settings_menu.gd` にハイコントラスト設定を追加。

### Phase 4: HUD & チャプター選択画面の強化
1. `scenes/ui/hud.tscn` にポーズボタン、チュートリアルバナー、メダルアイコン領域を追加。
2. `scripts/ui/hud.gd` でメダル表示（Gold/Silver/Bronze）、チュートリアルメッセージ表示・非表示を実装。
3. `scripts/ui/chapter_select.gd` で各ステージのメダル表示（★ Gold, ◈ Silver, • Bronze）およびチャプター完了数（例: 5/5）を更新。

### Phase 5: ゲームコントローラー & メインゲーム統合
1. `GameController` にポーズ状態フラグと入力ブロックを追加。
2. `MainGame` (`scripts/main.gd`) にポーズ画面のインスタンス化、Continue 起動、New Game リセット確認、チュートリアル自動トリガーを接続。
3. レベルクリア時のメダル付与およびエンディングシーケンス演出の連携。

### Phase 6: 包括的テストと検証
1. `tests/test_runner.gd` に `_test_phase7_ui_progression_persistence()` を追加（セーブ整合性、破損復旧、メダル算出、ポーズ入力、チュートリアル）。
2. Godot headless テストの実行と全アサーション合格の確認。
3. Python テストハーネス (`tests/run_tests.py`, `tests/test_campaign_audit.py`) の実行。

## 受入基準トレーサビリティ

| 受入基準 | 実現するタスク |
|----------|----------------|
| 受入基準 1 (Continueボタンと再開) | Phase 1 (5), Phase 3 (1, 2), Phase 5 (2) |
| 受入基準 2 (New Game 確認ダイアログ) | Phase 2 (1), Phase 3 (2), Phase 5 (2) |
| 受入基準 3 (ポーズメニューと状態保持) | Phase 2 (3), Phase 4 (1), Phase 5 (1, 2) |
| 受入基準 4 (セーブ破損時の安全復旧) | Phase 1 (1, 2) |
| 受入基準 5 (メダル算出とHUD・選択画面表示) | Phase 1 (3), Phase 4 (2, 3), Phase 5 (3) |
| 受入基準 6 (コンテキストチュートリアル) | Phase 1 (4), Phase 4 (1, 2), Phase 5 (2) |
| 受入基準 7 (ハイコントラスト設定) | Phase 1 (1), Phase 3 (3) |
| 受入基準 8 (包括的自動テスト検証) | Phase 6 (1, 2, 3) |

## 並列実行戦略
- Phase 1 (ProgressService 拡張) と Phase 2 (UI モーダル作成) は相互に干渉せず並行して実装可能。
- Phase 3, 4, 5 は Phase 1, 2 の API に基づいて統合を行う。

## 検証方法
1. Godot Headless テストの実行:
   ```bash
   godot --headless --script res://tests/test_runner.gd
   ```
   期待結果: 終了コード 0、全テスト（380+ 件）が PASS。
2. Python キャンペーン検証ハーネスの実行:
   ```bash
   python tests/run_tests.py
   python tests/test_campaign_audit.py
   ```
   期待結果: 終了コード 0、23 ステージすべてが検証可能でエラーなし。

## 将来の拡張
- スピードラン用タイマーモード（RTAタイマーHUD）。
- Steam クラウドセーブおよび Steam 実績同期アダプター。
- カスタムレベルエディタ用セーブスロット拡張。
