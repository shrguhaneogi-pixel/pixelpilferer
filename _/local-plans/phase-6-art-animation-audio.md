# Phase 6: アートディレクション・ピクセルアニメーション・オーディオ実装計画

## 背景・目的

『Pixel Pilferer』のコアゲームプレイ（決定的パズルエンジン、全20レベルのキャンペーン、ソルバー・バリデータ、プログレッション機構）は検証済みである。
Phase 6 では、ゲームプレイの厳格な正当性・決定性を100%維持しながら、本作を視認性が極めて高く、レトロモダンで洗練された2Dピクセルアート体験へと昇華させる。
操作感の向上、ピクセルグローブ操作（盗取・設置・復元）の快感、各チャプターの差別化された環境テーマ、完全オリジナルの軽量レトロプロシージャルサウンド・BGM、およびアクセシビリティ設定（Reduced Motion, High Contrast, 音量設定）を導入する。

## 現状整理

- **解像度・表示構成:** 640x360 ピクセルベース解像度、16x16 タイル、`canvas_items` + `scale_mode = "integer"`、Nearest テクスチャフィルタ、2Dピクセル整数スナップ。
- **既存スプライト (`assets/sprites/`):**
  - `pip.png`: 4方向（南、東、北、西）の基本スプライトシート (64x16)。
  - `blocks.png`: 5色（ニュートラル、シアン、アンバー、マゼンタ、エメラルド）のルーン付きキューブ (80x16)。
  - `tileset.png`: 4タイル（床、壁、ヴォイド、橋）(64x16)。
  - `sockets.png`: 5色 x 2状態（消灯、点灯）(160x16)。
  - `exit_portal.png`: 2状態（施錠、開放）(32x16)。
  - `icon.png`: 64x64 アプリケーションアイコン。
- **既存オーディオ (`assets/audio/`):**
  - 6つの基本WAV効果音 (`sfx_steal.wav`, `sfx_place.wav`, `sfx_socket.wav`, `sfx_step.wav`, `sfx_undo.wav`, `sfx_win.wav`)。
- **プロシージャル生成スクリプト (`scripts/tools/generate_assets.py`):**
  - 外部依存ゼロ（Python標準ライブラリ `struct`, `zlib`, `wave`, `math` のみ）でPNGおよび16-bit 44.1kHz WAVを直接生成可能。
- **レンダリング・ビュー構成:**
  - `BoardRenderer` (`scripts/game/board_renderer.gd`): Godot 4.7 専用 `TileMapLayer`（Void, Floor, Socket, Wall）と `EntityContainer`。
  - `PlayerView` (`scripts/view/player_view.gd`): Pip の移動・向き・所持ブロック表示。
  - `BlockView` (`scripts/view/block_view.gd`): 個別ブロックのスケール・パーティクル演出。
  - `AudioService` (`scripts/services/audio_service.gd`): SE 再生と音量管理。
  - `SettingsMenu` (`scripts/ui/settings_menu.gd`) / `ProgressService` (`scripts/services/progress_service.gd`): 設定永続化。

## 設計

### ファイル構成

```text
c:/project/pixelpilferer/
├── assets/
│   ├── audio/
│   │   ├── music_ambient.wav         # [新規] オリジナル8小節レトロアンビエントBGM
│   │   ├── sfx_bump.wav              # [新規] 移動不可・無効操作用バンプSE
│   │   ├── sfx_chapter_restored.wav  # [新規] チャプター完了・世界復元チャイムSE
│   │   ├── sfx_exit_open.wav         # [新規] ソケット全点灯ポータル開放SE
│   │   ├── sfx_place.wav             # [更新] メカニカルロック＋低音スナップSE
│   │   ├── sfx_socket.wav            # [更新] 和音エネルギーチャージSE
│   │   ├── sfx_steal.wav             # [更新] 周波数スイープ吸引SE
│   │   ├── sfx_step.wav              # [更新] 軽快なピクセル足音SE
│   │   ├── sfx_ui_click.wav          # [新規] UIボタンクリックSE
│   │   ├── sfx_undo.wav              # [更新] 逆再生巻き戻しSE
│   │   └── sfx_win.wav               # [更新] 5音凱旋ファンファーレSE
│   └── sprites/
│       ├── blocks.png                # [更新] コントラストと幾何学ルーンを強化した5色ブロック
│       ├── exit_portal.png           # [更新] 施錠時パドロック、開放時渦巻エネルギーポータル
│       ├── pip.png                   # [更新] 陰影・フード・Cyan発光バイザー・ピクセルグローブ
│       ├── sockets.png               # [更新] 幾何学インレイ・エネルギー導線・アクティブ発光
│       ├── tileset.png               # [更新] 4チャプター用マルチカラー・テクスチャ差別化タイルセット
│       └── icon.png                  # [維持] 64x64 アプリケーションアイコン
├── docs/
│   ├── ART_SPECIFICATION.md          # [新規] アート・アニメーション・サウンド仕様書
│   ├── CAMPAIGN_VALIDATION.md        # [維持] 20レベル検証マトリクス
│   ├── PROGRESS.md                   # [更新] Phase 6 進捗・成果記録
│   └── TEST_PLAN.md                  # [更新] Phase 6 テストケース拡充
├── scripts/
│   ├── game/
│   │   ├── board_renderer.gd         # [更新] チャプターパレット・環境変調・復元波演出
│   │   └── game_controller.gd        # [更新] 新規SEトリガー、ポータル開放検知、BGM連携
│   ├── services/
│   │   ├── audio_service.gd          # [更新] BGMループ再生、全SE対応、音量・ミュート統合
│   │   └── progress_service.gd       # [更新] BGM/SFX音量、画面揺れ、ハイコントラスト設定
│   ├── tools/
│   │   └── generate_assets.py        # [更新] 新規SE、BGM、高解像度化・チャプター別テクスチャ生成
│   ├── ui/
│   │   ├── chapter_select.gd         # [更新] チャプターテーマプレビュー・UIクリックSE
│   │   ├── hud.gd                    # [更新] ポータル開放バナー、高コントラストバッジ、UIクリック音
│   │   └── settings_menu.gd          # [更新] BGM音量・SFX音量・Reduced Motion・画面揺れトグル
│   └── view/
│       ├── block_view.gd             # [更新] 吸引・設置・ソケット活性化のパーティクル・パルス演出
│       └── player_view.gd            # [更新] アイドル呼吸ボブ、所持浮遊ボブ、勝利ホップ
└── tests/
    └── test_runner.gd                # [更新] Phase 6 視覚・音響・アクセシビリティ自動検証テスト追加
```

### 仕様

#### 1. アート仕様 & レトロモダンピクセルスタイル
- **解像度:** 640x360（16:9アスペクト、整数スケールで 720p/1080p/1440p/4K にブレなく追従）。
- **Pip (プレイヤー):**
  - フード付き盗賊。顔面は漆黒の影の中にネオンシアンの発光アイ（バイザー）。
  - 右手に特殊装備「Pixel Glove」（ネオンシアンの電磁コア）。
  - 静止時は1.2秒周期の微細な上下1pxアイドル呼吸Tween。
  - ブロック所持時はPip頭上に浮かぶブロックが同期して緩やかに浮遊。
  - レベルクリア時は歓喜のジャンプ（勝利ホップ）。
- **地形タイル (形状とテクスチャによる明確な識別性):**
  - 床: リベット付き敷石パターン。移動境界が明確。
  - 固定壁: 明暗ベベルと目地が施された重厚な石組み。
  - ヴォイド: 漆黒の深淵に微細な星屑粒子が散らばる。
  - 橋: ヴォイドの上に架けられたシアンのガイドレール付き金属/木製デッキ。
- **チャプター環境カラーテーマ:**
  - Chapter 0 (Demo): Neon Night（ミッドナイトブルー + ネオンシアン）
  - Chapter 1: The Stolen Street（スレートグレー石畳 + 琥珀の街灯 + 柔らかいシアン）
  - Chapter 2: The Broken Bridges（ディープネイビー + ターコイズスカイウェイ + 虚空のきらめき）
  - Chapter 3: The Forgotten Vault（漆黒黒曜石 + メタリックサーキット + 黄金コンジット）
  - Chapter 4: The Chromatic Core（色彩の完全覚醒 — 4色の光彩が溢れる神殿）
- **ピクセルグローブ演出:**
  - **STEAL:** 吸引対象ブロックから8方向ピクセル粒子が中央（グローブ）へ収束し、ブロックがスケールダウン消滅。Pip頭上に所持ブロックが弾むようにポップ。
  - **PLACE:** 所持ブロックが手元へ吸い込まれ、目標セルにブロックが弾むように実体化（`TRANS_BACK`）。微小な着地ダスト粒子。ヴォイド設置時は橋レールが即座に同期。
  - **RESTORE (ソケット点灯):** ソケットから放射状に色彩ショックウェーブが発生し、ブロックが1.2倍にマイクロパルス。全ソケット達成時は脱出ポータルが閉鎖石造りから光彩渦巻きへ開通。

#### 2. サウンドデザイン & BGM仕様
- **完全自己完結型WAV合成 (44.1kHz, 16-bit Mono):**
  - `sfx_step.wav`: 40ms 軽微なステップ音。
  - `sfx_steal.wav`: 140ms 低域から高域への吸引チャープ。
  - `sfx_place.wav`: 120ms 低域インパクト＋クリック。
  - `sfx_bump.wav`: 80ms 低周波矩形波バンプ。
  - `sfx_undo.wav`: 120ms 高域から低域への巻き戻しフラッター。
  - `sfx_socket.wav`: 350ms メジャートライアド（C5-E5-G5-C6）のエネルギーチャージアルペジオ。
  - `sfx_exit_open.wav`: 450ms ポータル覚醒ドローン音。
  - `sfx_win.wav`: 650ms 5音構成の凱旋ファンファーレ。
  - `sfx_ui_click.wav`: 40ms クリック音。
  - `sfx_chapter_restored.wav`: 1000ms 7音構成の世界復元和音。
  - `music_ambient.wav`: 4小節ループのチルアウト・レトロシンセアンビエント（ソフトサイン波ベース＋優しいアルペジオ、BGMとして邪魔にならない控えめな音量）。
- **AudioService 統合:**
  - SE 再生・BGM 再生を管理。
  - Master音量、Music音量、SFX音量、ミュート切り替え。
  - `linear_to_db` とセーフガードクランプ（0.0001〜1.0）により音割れ・エラー防止。

#### 3. アクセシビリティ & 設定互換性
- **Reduced Motion:** 有効時はパーティクル発生停止、スケーリングTween省略、即時セルスナップ、アイドル呼吸無効化。
- **Screen Shake:** 有効時のみポータル開放時等に微細なカメラインパルス（振幅2px以下、持続0.15s以下）。
- **High Contrast:** ブロックおよびソケットの記号（◆, ▲, ■, ●, ✚）をくっきり太線化。
- **集中管理:** `ProgressService` の設定辞書（キャッシュ付き）で一元管理し、シーン遷移時も設定が保持される。

## 受入基準

1. **識別性:** 床、壁、ヴォイド、橋、5色ブロック、5色ソケット、施錠/開放ポータルが初見で即座に識別可能であること。
2. **Pipアニメーション:** 4方向の移動、アイドル呼吸、所持ブロック浮遊、盗取、設置、バンプ、勝利ホップが正常に動作すること。
3. **グローブ演出:** STEAL、PLACE、RESTORE の視覚演出がテンポ良く動作し、高速入力時やUndo/Restart時にも状態矛盾や残留を起こさないこと。
4. **チャプター統一感:** 4つのチャプターが共通の世界観を保ちつつ、固有のカラーパレット・環境変調を持つこと。
5. **オーディオ:** 10種以上のSEおよびアンビエントBGMが実装され、ゲームプレイを補完しながらも音なしでもパズルが解けること。
6. **アクセシビリティ:** 音量スライダー、SFX/BGMトグル、Reduced Motion 設定がすべての視覚・音響演出に反映されること。
7. **回帰なし:** 既存の全313件のテスト（および全23レベルのソルバー解法）が100%成功し、新規テストも含めて exit code 0 で通過すること。
8. **実機描画検証:** Godot レンダリング環境下でテスト実行および画面整合性が検証されること。

## 実装ステップ

### Phase 1: アセットジェネレータ拡張 & アート仕様策定
1. `docs/ART_SPECIFICATION.md` を作成し、アート・アニメーション・パレット・オーディオの完全な仕様を明文化する。
2. `scripts/tools/generate_assets.py` を拡張し、改良版スプライト（Pip, blocks, tileset, sockets, exit_portal）および新規SE群（`sfx_bump.wav`, `sfx_exit_open.wav`, `sfx_ui_click.wav`, `sfx_chapter_restored.wav`, `music_ambient.wav`）をプロシージャル生成する。
3. アセットを再生成し、ファイル存在と整合性を確認する。

### Phase 2: ビュー・アニメーションシステムの強化 (Pip, BlockView, BoardRenderer)
1. `scripts/view/player_view.gd` にアイドル呼吸ボブ、所持ブロック同期浮遊、勝利ホップ、Tweenキャンセル安全処理を実装する。
2. `scripts/view/block_view.gd` に改善された吸引収束・設置展開・ソケットパルス演出を実装する。
3. `scripts/game/board_renderer.gd` にチャプター別パレット変調、ソケット全点灯ポータル開放エフェクト、微小カメラ揺れ（設定連動）を実装する。

### Phase 3: オーディオサービス & BGMループ統合
1. `scripts/services/audio_service.gd` を拡張し、BGMループストリーミング、新規SE（バンプ、ポータル開放、UIクリック、チャプター復元）メソッド、および独立ボリューム制御（Master, BGM, SFX）を実装する。
2. `scripts/game/game_controller.gd` に新規SE再生タイミング（バンプ、ポータル全開放時の歓喜音、BGM開始）を接続する。

### Phase 4: UI・設定・アクセシビリティ連動
1. `scripts/services/progress_service.gd` に BGM音量、BGM有効化、画面揺れ設定の永続化キーを追加する。
2. `scripts/ui/settings_menu.gd` および `res://scenes/ui/settings_menu.tscn` に BGM音量・画面揺れトグルを追加し、設定変更が直ちに `AudioService` / `BoardRenderer` へ伝播するように更新する。
3. `scripts/ui/hud.gd` および `scripts/ui/chapter_select.gd` にボタンクリックSEを連動させる。

### Phase 5: テストスイート拡充・品質保証・ドキュメント更新
1. `tests/test_runner.gd` に Phase 6 用テストセクション（`_test_phase6_art_animation_audio`）を追加（スプライトサイズ・フレーム数検証、AudioService全SE・BGM検証、Reduced Motion連動、音量クランプ、チャプターテーマ適用）。
2. Headless Godot テストスイート（325+ アサーション）を実行し、全件合格を確認する。
3. Python テストスイート（`run_tests.py`, `test_campaign_audit.py`）を実行し、全23レベルの解法に1件の回帰もないことを確認する。
4. `docs/PROGRESS.md` および `docs/TEST_PLAN.md` を更新する。
5. `/code-reviewer` チェックと `/simplify` リファインメントを実施する。
6. ローカル Git コミットを作成する（リモートプッシュは行わない）。

## 受入基準トレーサビリティ

| 受入基準 | 実現するタスク |
|----------|----------------|
| 1. 識別性 | Phase 1-2 (generate_assets.py 改良タイル・ブロック・ソケットスプライト生成) |
| 2. Pipアニメーション | Phase 2-1 (player_view.gd アイドルボブ・所持浮遊・勝利ホップ) |
| 3. グローブ演出 | Phase 2-2 (block_view.gd 吸引・実体化・ソケットショックウェーブ演出) |
| 4. チャプター統一感 | Phase 2-3 (board_renderer.gd チャプター環境パレット変調) |
| 5. オーディオ | Phase 1-2 & Phase 3-1, 3-2 (generate_assets.py SE/BGM生成, audio_service.gd 統合) |
| 6. アクセシビリティ | Phase 4-1, 4-2 (progress_service.gd, settings_menu.gd, board_renderer.gd) |
| 7. 回帰なし | Phase 5-2, 5-3 (Godot headless テスト & Python テストハーネス) |
| 8. 実機描画検証 | Phase 5-2 (Godot CLI 実行とコンソールログ検証) |

## 並列実行戦略

- **Phase 1 (アセット生成・仕様作成)** は純粋な Python スクリプトおよびドキュメント作成であり、Godot 側コードと完全分離して実行可能。
- **Phase 2 (ビュー演出強化)** と **Phase 3 (オーディオ統合)** はそれぞれ独立して実装・テスト可能。

## 検証方法

1. **アセット生成検証:**
   ```powershell
   python scripts/tools/generate_assets.py
   ```
   全スプライト (PNG) と全SE・BGM (WAV) がエラーなく生成されることを確認。

2. **Godot Headless テストスイート検証:**
   ```powershell
   & "C:\Users\Dell\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" --headless --script res://tests/test_runner.gd
   ```
   全テスト成功 (0 failed, exit code 0) を確認。

3. **Master Python テストスイート検証:**
   ```powershell
   python tests/run_tests.py
   ```
   全23レベル検証済み、exit code 0 を確認。

## 将来の拡張

- 動的ポストプロセスシェーダー（CRTフィルター、ブルーム効果 — `gl_compatibility` レンダラーとの互換性を保ちつつオプション追加）。
- タイルマップオートタイリング（周辺壁との接続ルール自動化）。
