# Starfiler 仕様候補（あふ / yazi / ForkLift 調査）

- 作成日: 2026-02-11
- 目的: 既存の Starfiler に対して、先行ファイラーの仕様をベースに「次に実装する候補機能」を選べる状態にする
- 対象バージョン（調査時点）:
  - あふｗ: v1.67（2026-01-01 更新）
  - Yazi: docs version 26.1.22 / README（2026-02-11時点の main）
  - ForkLift: v4.5（2026-02-10表記）

## 1. 3製品の仕様要点（Starfiler向けに要約）

| 領域 | あふ / あふｗ | yazi | ForkLift | Starfiler 現状 |
|---|---|---|---|---|
| 操作思想 | キーボード主体、2画面、軽量 | Vimライク、非同期中心、拡張前提 | GUI中心、2ペイン、統合転送管理 | Vimスタイル + 2ペインは実装済み |
| 拡張性 | 外部ツール連携（あふｗこまんど等） | Luaプラグイン、`ya pkg` で配布/更新 | コマンド連携、外部アプリ連携 | キーバインド拡張はあるが、プラグイン基盤は未実装 |
| 検索/選択 | インクリメンタル検索重視 | インクリメンタル検索、`fd/rg/fzf/zoxide` 連携 | 名前/拡張子/タグ/内容検索 | フィルタとSpotlight検索は実装済み |
| プレビュー/閲覧 | 画像・テキスト・バイナリの内蔵閲覧 | スクロールプレビュー、各種プレビュー連携 | Previewパネル、動画/PDF/テキスト編集 | Quick Look ベースは実装済み |
| 一括処理 | キーカスタマイズや外部連携で補完 | Bulk Rename/Archive/Task管理 | Multi-Rename（プリセット含む）、Sync | バッチリネームは未実装（既存タスクあり） |
| 同期/転送 | 軽量ローカル運用寄り | 非同期タスク + VFS + 外部連携 | 双方向Sync、転送キュー、ログ/進捗 | 非同期操作はあるが Sync UI/転送管理UIは未実装 |
| リモート | DLL/外部ツール拡張前提 | VFS・プラグインで拡張 | SFTP/FTP/WebDAV/S3/SMB等を統合 | リモート接続は未実装 |
| セッション | （軽量運用） | タブ・複数インスタンス連携（DDS） | Tabs / Workspaces | 履歴はあるがタブ/ワークスペースは未実装 |

## 2. Starfiler 仕様候補（選択用）

スコア基準:
- 価値: High / Mid / Low
- 工数: S / M / L / XL

| ID | 候補機能 | 価値 | 工数 | 由来 | 既存 `docs/tasks.md` との関係 |
|---|---|---|---|---|---|
| SF-01 | バッチリネーム 2.0（正規表現/連番/日付/ケース変換/プリセット） | High | M | yazi, ForkLift | 既存「バッチリネーム」を拡張具体化 |
| SF-02 | 2ペイン同期（片方向/双方向、差分確認、除外ルール、Synclet保存） | High | L | ForkLift | 新規 |
| SF-03 | Task Center（進捗、キャンセル、失敗再実行、操作ログ） | High | M-L | yazi, ForkLift | 既存エラー表示UI不足を包含 |
| SF-04 | ユーザースクリプト/プラグイン実行基盤（MVP） | High | L | yazi, あふｗ | 新規 |
| SF-05 | プラグイン配布/更新（`ya pkg`類似の軽量PM） | Mid | XL | yazi | 新規（SF-04後） |
| SF-06 | Smart Enter / Smart Filter（単一子ディレクトリ自動降下など） | Mid | S-M | yazi, あふｗ | 既存フィルタ機能の強化 |
| SF-07 | Preview Plus（内蔵テキスト/バイナリビューア強化、検索、文字コード対応） | High | M-L | あふｗ | 新規 |
| SF-08 | Gitステータス表示（差分バッジ + 最小操作） | Mid | M | yazi, ForkLift | 新規 |
| SF-09 | リモート接続基盤（まずは SFTP/SMB/WebDAV） | High | XL | ForkLift, yazi | 新規 |
| SF-10 | ワークスペース/セッション保存（ペイン状態+タブ） | Mid | M-L | ForkLift, yazi | 既存「タブ機能」を上位化 |
| SF-11 | アーカイブをフォルダとして参照 + 展開/圧縮統合 | Mid | M-L | yazi, ForkLift | 既存「圧縮/展開」を上位化 |
| SF-12 | 外部制御CLI（既存ウィンドウへの reveal/cd 命令） | Mid | M | あふｗこまんど, yazi DDS | 新規 |

## 3. すぐ選びやすい推奨セット

### A. すぐ価値が出る（短中期）
1. SF-01 バッチリネーム 2.0
2. SF-03 Task Center
3. SF-07 Preview Plus

### B. 差別化が強い（中長期）
1. SF-02 2ペイン同期
2. SF-09 リモート接続基盤
3. SF-04 + SF-05 拡張基盤

## 4. 実装依頼テンプレート

以下フォーマットで指定すれば、そのまま設計〜実装に着手可能。

```md
実装依頼:
- 候補ID: SF-01
- スコープ: MVP（プリセット保存は次フェーズ）
- 対象OS: macOS 15+
- 受け入れ条件:
  - 正規表現置換が可能
  - 連番と日付挿入が可能
  - Dry-run で変更前後を確認できる
```

## 5. 参照元（公式）

- あふｗ公式配布/説明: https://afxw.sakura.ne.jp/akt_afxw.html
- あふｗスクリーンショット/機能説明: https://afxw.sakura.ne.jp/akt_afxwss.html
- Yazi README: https://github.com/sxyazi/yazi
- Yazi Features: https://yazi-rs.github.io/features/
- Yazi Plugins docs: https://yazi-rs.github.io/docs/plugins/overview
- Yazi CLI (`ya pkg`): https://yazi-rs.github.io/docs/cli
- Yazi DDS: https://yazi-rs.github.io/docs/dds
- ForkLift 製品ページ（機能一覧）: https://binarynights.com/
- ForkLift マニュアル: https://binarynights.com/manual
