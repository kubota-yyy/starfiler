# Starfiler タスクリスト

## 完了タスク

### Phase 1: プロジェクト基盤
- [x] Xcode プロジェクト作成 (macOS 15+, Swift 5.9+)
- [x] App Sandbox 有効化
- [x] Security-Scoped Bookmarks によるファイルアクセス
- [x] MVVM + Service Layer アーキテクチャ構築
- [x] AppDelegate / MainWindowController 構成

### Phase 2: デュアルペインレイアウト
- [x] NSSplitView ベースの左右ペイン構成
- [x] NSTableView によるファイル一覧表示
- [x] ファイル名・サイズ・更新日カラム
- [x] アクティブペイン切り替え (Tab)
- [x] ステータスバー (パス表示・アイテム数・マーク数)

### Phase 3: ファイルシステムサービス
- [x] FileSystemService (ファイル列挙・作成・移動・コピー・削除・リネーム)
- [x] SecurityScopedBookmarkService (ブックマーク管理・参照カウント)
- [x] プロトコルベース DI (FileSystemProviding, SecurityScopedBookmarkProviding)

### Phase 4: Vim スタイルキーバインド
- [x] KeyInterpreter + KeybindingManager + KeyAction システム
- [x] Normal / Visual / Filter モード
- [x] マルチキーシーケンス対応 (gg, dd, cw)
- [x] JSON ベースのキーバインド設定 (DefaultKeybindings.json)
- [x] ユーザーカスタムキーバインド (~/Library/Application Support/)

### Phase 5: ファイル操作
- [x] コピー / 移動 / 削除 (ゴミ箱)
- [x] リネーム (インライン編集)
- [x] 新規フォルダ作成
- [x] マーク / 選択システム (Space でトグル、Visual モード範囲選択)
- [x] Undo (FileOperationQueue + UndoableOperation)
- [x] ファイル操作の非同期実行 (actor ベース)

### Phase 6: ディレクトリ監視
- [x] DirectoryMonitorService (DispatchSource.makeFileSystemObjectSource)
- [x] ファイル変更時の自動リフレッシュ

### Phase 7: ソート・フィルタ・隠しファイル
- [x] ソート (名前・サイズ・日付・逆順)
- [x] フィルタモード (/ キーでインクリメンタルフィルタ)
- [x] 隠しファイル表示切り替え (. キー)

### Phase 8: プレビューペイン
- [x] QLPreviewView による Quick Look プレビュー
- [x] プレビュー表示 / 非表示切り替え (Ctrl-p)
- [x] ディレクトリ選択時はプレビュー非表示 (ダッシュボーダー修正)
- [x] プレビューデフォルト非表示

### Phase 9: ブックマーク
- [x] BookmarksConfig (JSON 永続化)
- [x] ブックマーク追加 (B) / 一覧表示 (b)
- [x] ブックマークグループ管理
- [x] ブックマークポップオーバー UI

### Phase 10: ドラッグ & ドロップ
- [x] NSTableView ドラッグ対応
- [x] ペイン間・Finder 間のドロップ対応

### Phase 11: Spotlight 検索
- [x] NSMetadataQuery ベースの検索
- [x] Ctrl-f で検索モード

### Phase 12: ポリッシュ
- [x] メニューバー (App / File / Edit / View / Go / Window)
- [x] ウィンドウ状態復元 (位置・サイズ・アクティブペイン・パス)
- [x] アプリケーション設定の永続化 (AppConfig)
- [x] ナビゲーション履歴 (戻る H / 進む L)

### 追加実装 (Post-Phase)
- [x] ダブルクリックでフォルダ移動 / ファイル開き
- [x] Return キーでファイルを開く (フォルダ移動 + ファイル実行)
- [x] 右クリックコンテキストメニュー (Open / Reveal / Copy / Cut / Rename / Trash / New Folder)
- [x] サイドバー (お気に入り + ブックマークグループ、NSOutlineView)
- [x] サイドバー表示切り替え (Ctrl-b / Cmd+S)
- [x] キーバインド設定画面 (Keybindings UI: 閲覧 / モード切替 / 設定ファイルオープン / リセット)
- [x] Go メニュー (Home / Desktop / Documents / Downloads)
- [x] Settings メニュー (Keybindings... Cmd+,)
- [x] View メニュー拡充 (Sort / Toggle Sidebar)
- [x] FilePaneViewModel デッドコード削除

---

## 未完了タスク

### 高優先度
- [ ] ユニットテスト (ViewModel / Service 層のテストが未実装)
- [ ] エラー表示 UI (ファイル操作失敗時のユーザー通知が不足)
- [ ] システムクリップボード連携 (NSPasteboard でアプリ外コピー/ペースト)
- [ ] パス入力ナビゲーション (アドレスバーで直接パス入力して移動)

### 中優先度
- [ ] バッチリネーム (複数ファイルの一括リネーム)
- [ ] ファイル情報ダイアログ (サイズ・権限・作成日等の詳細表示)
- [ ] シンボリックリンク表示 (アイコンやラベルでリンクを区別)
- [ ] ファイルパーミッション表示 (rwx 表示)
- [ ] ブレッドクラムナビゲーション (パスの各階層をクリック移動)
- [ ] カラム幅の永続化 (テーブルカラム幅の保存・復元)
- [ ] キーバインド設定画面でのインライン編集 (GUI でキー割り当て変更)

### 低優先度
- [ ] テーマ / 外観設定 (カスタムカラースキーム)
- [ ] ローカライゼーション (日本語 / 英語)
- [ ] 大規模ディレクトリ最適化 (10,000+ ファイル時のパフォーマンス)
- [ ] NSDiffableDataSource アニメーション (テーブル更新アニメーション)
- [ ] アクセシビリティ対応 (VoiceOver / Dynamic Type)
- [ ] iCloud Drive 対応
- [ ] NSFileCoordinator による安全なファイル操作
- [ ] タブ機能 (複数タブでの並列作業)
- [ ] ファイル圧縮 / 展開 (zip 等のアーカイブ操作)
