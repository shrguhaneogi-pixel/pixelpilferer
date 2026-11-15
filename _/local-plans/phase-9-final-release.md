# Phase 9: Final Release, Export, and Delivery Implementation Plan

## 背景・目的
Pixel Pilferer の全フェーズ（Phase 1〜8）が完了し、アドバーサリアル QA およびソリューション検証をクリアした。
本フェーズ（Phase 9）では、最終リリースエンジニアリングおよびプロダクト監査を実施し、Windows デスクトップ版のパッケージ作成、全20レベルの完全走破検証、ドキュメント群の刷新、および最終リリースレポート `docs/RELEASE_REPORT.md` を作成する。

## 現状整理
- Godot 4.7.2 stable win64 コンソールバイナリが配備済み。
- `export_presets.cfg` 設定済み（Windows Desktop および Web）。
- Windows デスクトップパッケージ（`build/desktop/PixelPilferer.exe`, `PixelPilferer.pck`, `PixelPilferer_console.exe`）のビルド・スモークテストに成功。
- Web エクスポートテンプレート（`web_nothreads_release.zip`）は環境内に未配備であるため、Web プラットフォームは環境制約として明記（Unsupported / Template Unavailable）。
- 全 23 レベル（デモ 3 + 本編 20）が BFS/A* ソルバーで 100% 解答可能であることを証明済み。

## 受入基準
1. **完全自動検証（Step 2 & 9）:**
   - 全レベル（20本編＋3デモ）の確定解リプレイテストがパスすること。
   - 新規起動、進行保存、チャプター遷移、エンディング、設定変更、リプレイの全フローが検証されること。
2. **デスクトップリリースパッケージ（Step 3 & 6）:**
   - `build/desktop/` 配下に実行可能バイナリ、データパック、README/Controls が揃っていること。
   - スモークテスト（起動・シーンロード・終了）が正常終了（exit code 0）すること。
   - 配布用 ZIP アーカイブ `dist/PixelPilferer_Windows_v1.0.0.zip` が生成されていること。
3. **ドキュメントの更新（Step 7, 8, 10）:**
   - `README.md` にタイトル、操作方法、機能、起動方法、制限事項、ライセンスを明記。
   - `docs/RELEASE_REPORT.md` に全 12 項目（バージョン、機能一覧、検証結果、制約、GO判定等）を記述。
4. **Git リポジトリ整合性:**
   - 不要ファイルや一時ビルドキャッシュが tracked リポジトリに混入せず、作業ツリーがクリーンな状態でコミットされること。

## 実装ステップ

### Phase 1: エンドツーエンド走破・全機能検証ハーネスの作成
- `tests/test_final_release_verification.py` を作成。
  - 新規起動状態から全20レベル＋3デモレベルを解答シーケンスでリプレイ。
  - チャプター進行（1-1〜1-5 -> Ch 2 -> Ch 3 -> Ch 4 -> Grand Core -> Ending）を検証。
  - 進行セーブ、ロード、メダル判定、設定トグル（Reduced Motion, Screen Shake, Volume）を検証。
- Python master test suite および Godot in-engine test runner で実行確認。

### Phase 2: リリースパッケージング（Desktop Archive）
- `dist/` ディレクトリを作成し、不要なファイルを含めないクリーンな ZIP アーカイブを作成:
  - `PixelPilferer.exe`
  - `PixelPilferer.pck`
  - `PixelPilferer_console.exe`
  - `README.txt`（操作方法・トラブルシューティング）
- ZIP アーカイブの展開テストおよび整合性確認。

### Phase 3: ドキュメントの刷新 & プロダクト監査
- `README.md` を最新仕様、操作体系、クレジット、ビルド方法に更新。
- `docs/PROGRESS.md` を最終フェーズ完了状態に更新。
- プロダクト品質監査（ゲームプレイ、独創性、表現、安定性）の実施。
- `docs/RELEASE_REPORT.md` を作成（全12セクション、明示的 GO/NO-GO 判定）。

### Phase 4: 最終コミット
- 変更ファイルをステージングし、ローカルコミットを作成。
